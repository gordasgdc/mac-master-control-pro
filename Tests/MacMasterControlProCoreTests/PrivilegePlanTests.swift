import XCTest
@testable import MacMasterControlProCore

/// Se rulează cu `MCSP_PROFILE_DIR=<extern> MCSP_DEMO_ELEVATION=ok|cancel`: stub în locul dialogului real (nu există parolă de introdus), dar cu aceeași numărare de solicitări.
final class PrivilegePlanTests: XCTestCase {
    private func fixtures(_ n: Int) throws -> (URL, [String]) {
        let d = FileManager.default.temporaryDirectory.appendingPathComponent("mcsp-priv-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        let paths = (0..<n).map { d.appendingPathComponent("item\($0).bin").path }
        for p in paths { try Data(count: 100).write(to: URL(fileURLWithPath: p)) }
        return (d, paths)
    }
    override func setUp() { PrivilegedPlan.approver = { _, _ in true } }

    func testSelectionOfSevenIsOnePromptInsteadOfSeven() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["MCSP_DEMO_ELEVATION"] == "ok", "necesită MCSP_DEMO_ELEVATION=ok")
        let (d, paths) = try fixtures(14); defer { try? FileManager.default.removeItem(at: d) }
        // ÎNAINTE (comportamentul vechi): un plan/dialog pentru fiecare element.
        let c0 = PrivilegedRunner.promptCount
        for p in paths.prefix(7) { XCTAssertNil(PrivilegedFileOps.deleteBatch([p], trashFirst: false).results[p] ?? nil) }
        XCTAssertEqual(PrivilegedRunner.promptCount - c0, 7)
        // DUPĂ: aceeași selecție de 7 = un singur plan, un singur dialog.
        let c1 = PrivilegedRunner.promptCount
        let batch = PrivilegedFileOps.deleteBatch(Array(paths.suffix(7)), trashFirst: false)
        XCTAssertEqual(PrivilegedRunner.promptCount - c1, 1)
        XCTAssertFalse(batch.cancelled)
        for p in paths.suffix(7) { XCTAssertNil(batch.results[p] ?? nil); XCTAssertFalse(FileManager.default.fileExists(atPath: p)) }
    }

    func testCancelStopsTheWholePlanWithoutFurtherPrompts() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["MCSP_DEMO_ELEVATION"] == "cancel", "necesită MCSP_DEMO_ELEVATION=cancel")
        let (d, paths) = try fixtures(7); defer { try? FileManager.default.removeItem(at: d) }
        let c0 = PrivilegedRunner.promptCount
        let batch = PrivilegedFileOps.deleteBatch(paths, trashFirst: false)
        XCTAssertTrue(batch.cancelled)
        XCTAssertEqual(PrivilegedRunner.promptCount - c0, 1, "o singură solicitare, apoi oprire")
        for p in paths { XCTAssertTrue(FileManager.default.fileExists(atPath: p), "nimic modificat după anulare") }
    }

    func testDeclinedPlanNeverReachesTheSystemDialog() throws {
        PrivilegedPlan.approver = { _, _ in false }
        let (d, paths) = try fixtures(3); defer { try? FileManager.default.removeItem(at: d) }
        let c0 = PrivilegedRunner.promptCount
        let batch = PrivilegedFileOps.deleteBatch(paths, trashFirst: false)
        XCTAssertTrue(batch.cancelled); XCTAssertEqual(PrivilegedRunner.promptCount, c0)
        for p in paths { XCTAssertTrue(FileManager.default.fileExists(atPath: p)) }
    }

    func testProtectedPathsAreNeverDeletedPrivileged() {
        for p in ["/", "/System", "/Library", "/Users", "/Applications", "/usr/bin/..", "relative/path", "/etc"] { XCTAssertFalse(PrivilegedPlan.isSafeDeletePath(p), p) }
        XCTAssertTrue(PrivilegedPlan.isSafeDeletePath("/Applications/Some.app"))
    }
}
