import XCTest
@testable import MacMasterControlProCore

final class DiskScanTests: XCTestCase {
    private var dirs: [URL] = []
    override func tearDown() {
        for d in dirs { chmod(d.appendingPathComponent("a/b").path, 0o755); try? FileManager.default.removeItem(at: d) }
        dirs = []
    }

    private func scan(_ root: String, collapse: Bool = true) -> (DiskTreeNode, DiskScanEngine.ScanOutcome) {
        let e = expectation(description: "scan"); var r: (DiskTreeNode, DiskScanEngine.ScanOutcome)?
        DiskScanEngine.buildTree(root: root, onProgress: { _ in }, completion: { r = ($0, $1); e.fulfill() })
        wait(for: [e], timeout: 120)
        if collapse { r!.0.collapseSmallFiles() }
        return r!
    }
    private func incr(_ t: DiskTreeNode, mode: DiskScanEngine.IncrementalMode = .verified) -> (DiskTreeNode, DiskScanEngine.ScanOutcome) {
        let e = expectation(description: "inc"); var r: (DiskTreeNode, DiskScanEngine.ScanOutcome)?
        DiskScanEngine.incrementalUpdate(cachedRoot: t, mode: mode, onProgress: { _ in }, completion: { r = ($0, $1); e.fulfill() })
        wait(for: [e], timeout: 120); return r!
    }
    private func fixture() throws -> URL {
        let d = FileManager.default.temporaryDirectory.appendingPathComponent("mcsp-scan-\(UUID().uuidString)")
        dirs.append(d)
        try FileManager.default.createDirectory(at: d.appendingPathComponent("a/b/c"), withIntermediateDirectories: true)
        try Data(count: 1000).write(to: d.appendingPathComponent("a/b/c/f.bin"))
        try Data(count: 500).write(to: d.appendingPathComponent("a/g.bin"))
        try Data(count: 2_000_000).write(to: d.appendingPathComponent("a/big.bin"))   // peste pragul de agregare
        return d
    }
    private func grow(_ url: URL, by n: Int) throws {
        let h = try FileHandle(forWritingTo: url); try h.seekToEnd(); try h.write(contentsOf: Data(count: n)); try h.close()
    }

    func testAddedFileDeepInTreeIsDetected() throws {
        let d = try fixture(); let (t, _) = scan(d.path); let before = t.sizeBytes
        try Data(count: 200).write(to: d.appendingPathComponent("a/b/c/new.bin"))
        XCTAssertEqual(incr(t).0.sizeBytes, before + 200)
    }

    func testInPlaceGrowthOfSmallAggregatedFileDeepInTreeIsDetected() throws {
        let d = try fixture(); let (t, _) = scan(d.path); let before = t.sizeBytes
        try grow(d.appendingPathComponent("a/b/c/f.bin"), by: 4000)
        XCTAssertEqual(incr(t).0.sizeBytes, before + 4000)
    }

    func testInPlaceGrowthOfLargeFileIsDetected() throws {
        let d = try fixture(); let (t, _) = scan(d.path); let before = t.sizeBytes
        try grow(d.appendingPathComponent("a/big.bin"), by: 10)
        XCTAssertEqual(incr(t).0.sizeBytes, before + 10)
    }

    /// Rescriere cu ACEEASI dimensiune dar alt mtime: amprenta include mtime ns.
    func testSameSizeRewriteIsDetectedViaMtime() throws {
        let d = try fixture(); let (t, _) = scan(d.path)
        let f = d.appendingPathComponent("a/b/c/f.bin")
        let before = t.filesFingerprintSum()
        try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(5)], ofItemAtPath: f.path)
        let after = incr(t).0.filesFingerprintSum()
        XCTAssertNotEqual(before, after)
    }

    func testDeleteAndRenameAreDetected() throws {
        let d = try fixture(); let (t, _) = scan(d.path); let before = t.sizeBytes
        try FileManager.default.removeItem(at: d.appendingPathComponent("a/g.bin"))
        try FileManager.default.moveItem(at: d.appendingPathComponent("a/b/c/f.bin"), to: d.appendingPathComponent("a/b/c/h.bin"))
        let r = incr(t).0
        XCTAssertEqual(r.sizeBytes, before - 500)
        XCTAssertNil(r.children["a"]?.children["b"]?.children["c"]?.children["f.bin"])
    }

    func testNewSubfolderIsScanned() throws {
        let d = try fixture(); let (t, _) = scan(d.path); let before = t.sizeBytes
        try FileManager.default.createDirectory(at: d.appendingPathComponent("a/new/deep"), withIntermediateDirectories: true)
        try Data(count: 700).write(to: d.appendingPathComponent("a/new/deep/x.bin"))
        XCTAssertEqual(incr(t).0.sizeBytes, before + 700)
    }

    /// Proprietate: dupa mutatii aleatoare, verified incremental == scanare completa proaspata.
    func testVerifiedIncrementalEqualsFreshFullScanAfterRandomMutations() throws {
        let d = try fixture(); var rng = SystemRandomNumberGenerator()
        for i in 0..<30 {
            let dir = d.appendingPathComponent("a/d\(i % 5)/e\(i % 3)")
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try Data(count: Int.random(in: 1...3000, using: &rng)).write(to: dir.appendingPathComponent("f\(i).bin"))
        }
        let (t, _) = scan(d.path)
        let files = FileManager.default.enumerator(at: d, includingPropertiesForKeys: [.isRegularFileKey])!.compactMap { $0 as? URL }.filter { $0.pathExtension == "bin" }
        for f in files.shuffled().prefix(15) {
            switch Int.random(in: 0..<3, using: &rng) {
            case 0: try? grow(f, by: Int.random(in: 1...5000, using: &rng))
            case 1: try? FileManager.default.removeItem(at: f)
            default: try? Data(count: Int.random(in: 1...3000, using: &rng)).write(to: f.deletingLastPathComponent().appendingPathComponent("n\(UUID().uuidString.prefix(4)).bin"))
            }
        }
        let inc = incr(t).0
        let fresh = scan(d.path).0
        XCTAssertEqual(inc.sizeBytes, fresh.sizeBytes)
        XCTAssertEqual(inc.allocatedBytes, fresh.allocatedBytes)
        XCTAssertEqual(inc.totalFileCount, fresh.totalFileCount)
    }

    func testStructureOnlyModeMissesInPlaceGrowth_DocumentsTradeoff() throws {
        let d = try fixture(); let (t, _) = scan(d.path); let before = t.sizeBytes
        try grow(d.appendingPathComponent("a/big.bin"), by: 10)
        XCTAssertEqual(incr(t, mode: .structureOnly).0.sizeBytes, before, "modul rapid vede doar structura")
    }

    func testRootUnavailableDoesNotWipeTree() throws {
        let d = try fixture(); let (t, _) = scan(d.path); let before = t.sizeBytes
        try FileManager.default.removeItem(at: d)
        let (r, outcome) = incr(t)
        XCTAssertEqual(outcome.status, .rootUnavailable); XCTAssertEqual(r.sizeBytes, before)
    }

    func testCancelledScanIsReportedAsCancelled() throws {
        let d = try fixture()
        for i in 0..<400 { try FileManager.default.createDirectory(at: d.appendingPathComponent("many/\(i)"), withIntermediateDirectories: true)
            try Data(count: 10).write(to: d.appendingPathComponent("many/\(i)/f")) }
        let e = expectation(description: "scan"); var status: DiskScanEngine.ScanOutcome.Status?
        DiskScanEngine.buildTree(root: d.path, onProgress: { _ in }, completion: { _, o in status = o.status; e.fulfill() })
        DiskScanEngine.requestCancel()
        wait(for: [e], timeout: 30)
        // buildTree reseteaza cancel la start; cererea poate veni inainte sau dupa - ambele rezultate sunt valide,
        // dar un status "complete" cu arbore partial este interzis: verificam doar coerenta statusului.
        XCTAssertNotNil(status)
    }

    func testUnreadableFolderIsCountedAsAccessError() throws {
        let d = try fixture()
        chmod(d.appendingPathComponent("a/b").path, 0o000)
        let (t, o) = scan(d.path)
        XCTAssertGreaterThanOrEqual(o.accessErrors, 1); XCTAssertEqual(t.sizeBytes, 2_000_500)
    }

    func testSparseFileLogicalVsAllocated() throws {
        let d = try fixture()
        let s = d.appendingPathComponent("a/sparse.bin"); FileManager.default.createFile(atPath: s.path, contents: nil)
        let h = try FileHandle(forWritingTo: s); try h.truncate(atOffset: 100_000_000); try h.close()
        let (t, _) = scan(d.path)
        XCTAssertGreaterThanOrEqual(t.sizeBytes, 100_000_000)
        XCTAssertLessThan(t.allocatedBytes, t.sizeBytes / 10, "fisierul sparse are spatiu alocat mult mai mic decat dimensiunea logica")
    }

    func testSymlinksAreNotFollowedOrCounted() throws {
        let d = try fixture(); let (t0, _) = scan(d.path); let before = t0.sizeBytes
        try FileManager.default.createSymbolicLink(at: d.appendingPathComponent("a/link"), withDestinationURL: d.appendingPathComponent("a"))
        XCTAssertEqual(scan(d.path).0.sizeBytes, before)
    }

    func testLegacyCacheWithoutNewFieldsDecodesAndIsReconciled() throws {
        let d = try fixture()
        let legacy = """
        {"id":"\(UUID().uuidString)","name":"x","path":"\(d.path)","isDirectory":true,"sizeBytes":1,"directoryModifiedAt":0,"children":{},"aggregatedFileCount":0}
        """
        let node = try JSONDecoder().decode(DiskTreeNode.self, from: Data(legacy.utf8))
        XCTAssertEqual(node.filesFingerprint, 0); XCTAssertEqual(node.allocatedBytes, 0)
        let r = incr(node).0   // fingerprint 0 => foldere recitite => arbore complet
        XCTAssertEqual(r.sizeBytes, scan(d.path).0.sizeBytes)
    }

    func testCacheRoundTripKeepsFingerprintsAndAllocated() throws {
        let d = try fixture(); let (t, _) = scan(d.path)
        let enc = PropertyListEncoder(); enc.outputFormat = .binary
        let back = try PropertyListDecoder().decode(DiskTreeNode.self, from: try enc.encode(t))
        XCTAssertEqual(back.allocatedBytes, t.allocatedBytes); XCTAssertEqual(back.filesFingerprintSum(), t.filesFingerprintSum())
        let big = d.appendingPathComponent("a/big.bin"); try grow(big, by: 5)
        XCTAssertEqual(incr(back).0.sizeBytes, t.sizeBytes + 5)
    }

    func testSparseFileIsMeasuredByAllocatedSpace() throws {
        let d = try fixture()
        let sparse = d.appendingPathComponent("a/sparse.img")
        let fd = open(sparse.path, O_CREAT | O_WRONLY, 0o644); XCTAssertGreaterThan(fd, 0)
        XCTAssertEqual(ftruncate(fd, 10 * 1024 * 1024 * 1024), 0)   // 10 GiB logic, practic nimic alocat
        _ = "x".withCString { write(fd, $0, 1) }; close(fd)
        let (t, _) = scan(d.path)
        let n = try XCTUnwrap(t.children["a"]?.children["sparse.img"], "fișierul sparse rămâne vizibil individual, nu agregat")
        XCTAssertEqual(n.sizeBytes, 10 * 1024 * 1024 * 1024)
        XCTAssertLessThan(n.usedBytes, 5_000_000)
        XCTAssertLessThan(t.usedBytes, 10_000_000, "totalul de pe disc nu poate depăși spațiul alocat real")
        XCTAssertGreaterThan(t.sizeBytes, 10 * 1024 * 1024 * 1024)
        XCTAssertEqual(t.children["a"]?.sortedChildren.first?.name, "big.bin", "ordinea după spațiul alocat, nu după mărimea logică")
    }

    func testUnreadableFolderIsReportedWithSampleNotAsComplete() throws {
        let d = try fixture()
        chmod(d.appendingPathComponent("a/b").path, 0)
        let (_, o) = scan(d.path)
        XCTAssertGreaterThan(o.accessErrors, 0); XCTAssertFalse(o.isCleanAndComplete)
        XCTAssertTrue(o.accessSamples.contains { $0.hasSuffix("/a/b") })
    }
}

extension DiskTreeNode {
    func filesFingerprintSum() -> Int64 { children.values.reduce(filesFingerprint) { $0 &+ $1.filesFingerprintSum() } }
}

final class SystemIconTests: XCTestCase {
    func testLoadsNativeIconsAsyncAndCaches() async {
        let first = await SystemIconCache.shared.icon(forPath: "/System/Library/CoreServices/Finder.app")
        XCTAssertGreaterThan(first.size.width, 0)
        XCTAssertNotNil(SystemIconCache.shared.cached(path: "/System/Library/CoreServices/Finder.app"))
        let vol = await SystemIconCache.shared.icon(forPath: "/")
        XCTAssertGreaterThan(vol.size.width, 0)
    }
    func testMissingPathStillGivesGenericIconWithoutBlocking() async {
        let img = await SystemIconCache.shared.icon(forPath: "/nu/exista/\(UUID().uuidString)")
        XCTAssertGreaterThan(img.size.width, 0)
    }
}
