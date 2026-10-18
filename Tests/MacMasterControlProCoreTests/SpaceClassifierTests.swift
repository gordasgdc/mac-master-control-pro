import XCTest
@testable import MacMasterControlProCore

final class SpaceClassifierTests: XCTestCase {
    private func node(_ path: String, _ size: Int64, dir: Bool = true, kids: [DiskTreeNode] = []) -> DiskTreeNode {
        let n = DiskTreeNode(name: (path as NSString).lastPathComponent, path: path, isDirectory: dir)
        n.sizeBytes = size; n.allocatedBytes = size; for k in kids { n.children[k.name] = k }; return n
    }
    func testRegenerableByExplicitRuleOnly() {
        XCTAssertTrue(SpaceClassifier.flags(path: "/Volumes/X/Proj/CacheClip", isDirectory: true).contains(.regenerable))
        XCTAssertTrue(SpaceClassifier.flags(path: "/Volumes/X/Proj/Optimized Media", isDirectory: true).contains(.regenerable))
        XCTAssertTrue(SpaceClassifier.flags(path: "/Volumes/X/Proj/Originale", isDirectory: true).isEmpty, "fără regulă nu se presupune nimic")
        XCTAssertTrue(SpaceClassifier.flags(path: "/Volumes/X/Proj/teste_culoare", isDirectory: true).isEmpty)
    }
    func testProtectedCannotBeRegenerableOrDuplicate() {
        let p = "/Users/a/Library/Application Support/MobileSync/Backup"
        XCTAssertEqual(SpaceClassifier.flags(path: p, isDirectory: true, duplicateSurplus: [p]), [.protected])
        XCTAssertTrue(SpaceClassifier.flags(path: "/Applications/Resolve.app", isDirectory: true).contains(.protected))
        XCTAssertTrue(SpaceClassifier.flags(path: "/Users/a/Documents", isDirectory: true).contains(.protected))
        XCTAssertFalse(SpaceClassifier.flags(path: "/Users/a/Documents/Proiect", isDirectory: true).contains(.protected))
        XCTAssertTrue(SpaceClassifier.flags(path: "/x", isDirectory: false, isAggregate: true).contains(.protected))
    }
    func testSelectionDedupesParentAndSeparatesUnverified() {
        let cc = node("/V/P/CacheClip", 48), om = node("/V/P/Optimized Media", 22), tc = node("/V/P/teste_culoare", 35)
        let inner = node("/V/P/CacheClip/sub", 10)
        let s = SpaceMath.summarize(nodes: [cc, inner, om, tc])
        XCTAssertEqual(s.recoverableBytes, 70); XCTAssertEqual(s.unverifiedBytes, 35); XCTAssertEqual(s.moveBytes, 105)
        XCTAssertEqual(Set(s.recoverable), ["/V/P/CacheClip", "/V/P/Optimized Media"])
    }
    func testVolumeTotalsHaveNoDoubleCounting() {
        // duplicat în interiorul unui element regenerabil: numărat o singură dată (în regenerabil)
        let dupInside = node("/V/P/Optimized Media/copy.mov", 9, dir: false)
        let om = node("/V/P/Optimized Media", 22, kids: [dupInside])
        let cc = node("/V/P/CacheClip", 48)
        let dupOut = node("/V/P/r1_copy.mov", 18, dir: false)
        let root = node("/V/P", 88, kids: [om, cc, dupOut])
        let t = SpaceMath.volumeTotals(root: root, duplicateSurplus: ["/V/P/Optimized Media/copy.mov", "/V/P/r1_copy.mov"])
        XCTAssertEqual(t.regenerable, 70); XCTAssertEqual(t.duplicateSurplus, 18); XCTAssertEqual(t.overlap, 9); XCTAssertEqual(t.recoverable, 88)
    }
    func testDuplicateSurplusKeepsOldestCopy() {
        let old = DuplicateFile(id: "a", path: "/a/old.mov", sizeBytes: 5, modifiedDate: Date(timeIntervalSince1970: 100))
        let new = DuplicateFile(id: "b", path: "/a/new.mov", sizeBytes: 5, modifiedDate: Date(timeIntervalSince1970: 200))
        XCTAssertEqual(SpaceClassifier.duplicateSurplus(groups: [DuplicateGroup(id: "h", files: [new, old])]), ["/a/new.mov"])
    }
}

final class TrashServiceTests: XCTestCase {
    func testMissingPathFailsWithoutDeletingAnything() {
        XCTAssertEqual(TrashService.moveToTrash(path: "/tmp/mcsp-nu-exista-\(UUID().uuidString)"), .failed("nu mai există"))
    }
    func testMovesFixtureFileToTrashRecoverably() throws {
        let f = FileManager.default.temporaryDirectory.appendingPathComponent("mcsp-test-trash-\(UUID().uuidString).txt")
        try "fixture".write(to: f, atomically: true, encoding: .utf8)
        XCTAssertEqual(TrashService.moveToTrash(path: f.path), .moved)
        XCTAssertFalse(FileManager.default.fileExists(atPath: f.path))
    }
}
