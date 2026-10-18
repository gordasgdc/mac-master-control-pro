import XCTest
@testable import MacMasterControlProCore

final class DiskScanTests: XCTestCase {
    private func scan(_ root: String) -> DiskTreeNode {
        let e = expectation(description: "scan"); var t: DiskTreeNode?
        DiskScanEngine.buildTree(root: root, onProgress: { _ in }, completion: { t = $0; e.fulfill() })
        wait(for: [e], timeout: 60); return t!
    }
    private func incr(_ t: DiskTreeNode) -> DiskTreeNode {
        let e = expectation(description: "inc"); var r: DiskTreeNode?
        DiskScanEngine.incrementalUpdate(cachedRoot: t, onProgress: { _ in }, completion: { r = $0; e.fulfill() })
        wait(for: [e], timeout: 60); return r!
    }
    private func fixture() throws -> URL {
        let d = FileManager.default.temporaryDirectory.appendingPathComponent("mcsp-scan-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: d.appendingPathComponent("a/b/c"), withIntermediateDirectories: true)
        try Data(count: 1000).write(to: d.appendingPathComponent("a/b/c/f.bin"))
        try Data(count: 500).write(to: d.appendingPathComponent("a/g.bin"))
        return d
    }

    func testAddedFileDeepInTreeIsDetected() throws {
        let d = try fixture(); defer { try? FileManager.default.removeItem(at: d) }
        let t = scan(d.path); XCTAssertEqual(t.sizeBytes, 1500)
        try Data(count: 200).write(to: d.appendingPathComponent("a/b/c/new.bin"))
        XCTAssertEqual(incr(t).sizeBytes, 1700)
    }

    /// Modificarea in-loc a unui fisier existent NU schimba mtime-ul folderului:
    /// actualizarea incrementala bazata doar pe mtime de director il rateaza.
    func testInPlaceGrowthOfExistingFileIsDetected() throws {
        let d = try fixture(); defer { try? FileManager.default.removeItem(at: d) }
        let t = scan(d.path)
        let h = try FileHandle(forWritingTo: d.appendingPathComponent("a/b/c/f.bin"))
        try h.seekToEnd(); try h.write(contentsOf: Data(count: 4000)); try h.close()
        // DEFECT CUNOSCUT (Lot 2): scanarea incrementala nu vede cresterea in-loc. Scoate XCTExpectFailure dupa fix.
        XCTExpectFailure("incremental pe mtime de director rateaza modificarea in-loc")
        XCTAssertEqual(incr(t).sizeBytes, 5500)
    }

    func testUnreadableFolderIsCountedNotSilent() throws {
        let d = try fixture(); defer { chmod(d.appendingPathComponent("a/b").path, 0o755); try? FileManager.default.removeItem(at: d) }
        chmod(d.appendingPathComponent("a/b").path, 0o000)
        let t = scan(d.path)
        XCTAssertEqual(t.sizeBytes, 500)
    }
}
