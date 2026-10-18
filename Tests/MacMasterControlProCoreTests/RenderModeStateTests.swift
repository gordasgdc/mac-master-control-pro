import XCTest
@testable import MacMasterControlProCore

final class RenderModeStateTests: XCTestCase {
    func testParseMdutil() {
        let out = "/:\n\tIndexing enabled. \n/System/Volumes/Data:\n\tIndexing disabled.\n/Volumes/X:\n\tError: unknown\n/Users/a/b:\n\tIndexing and searching disabled.\n"
        XCTAssertEqual(RenderModeState.parseMdutil(out), ["/": true, "/System/Volumes/Data": false, "/Users/a/b": false])
    }
    func testActivationTouchesOnlyWhatWasOn() {
        let s = RenderModeSnapshot(timeMachineAutoBackup: false, spotlight: ["/": false, "/Volumes/X Y": true], nice: [42: 0])
        XCTAssertEqual(RenderModeState.activationCommands(s), ["mdutil -i off '/Volumes/X Y'", "renice -n -15 -p 42"])
        XCTAssertEqual(RenderModeState.restoreCommands(s), ["mdutil -i on '/Volumes/X Y'", "renice -n 0 -p 42 2>/dev/null || true"])
    }
    func testNothingToDoWhenAlreadyOff() {
        let s = RenderModeSnapshot(timeMachineAutoBackup: false, spotlight: ["/": false], nice: [:])
        XCTAssertTrue(RenderModeState.activationCommands(s).isEmpty); XCTAssertTrue(RenderModeState.restoreCommands(s).isEmpty)
    }
    func testUnknownTimeMachineIsNeverTouched() {
        let s = RenderModeSnapshot(timeMachineAutoBackup: nil, spotlight: [:], nice: [:])
        XCTAssertFalse(RenderModeState.activationCommands(s).contains("tmutil disable"))
        XCTAssertFalse(RenderModeState.restoreCommands(s).contains("tmutil enable"))
    }
    func testSnapshotSurvivesRestartRoundTrip() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("rm-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let s = RenderModeSnapshot(createdAt: Date(timeIntervalSince1970: 1000), timeMachineAutoBackup: true, spotlight: ["/": true], nice: [7: 5])
        try RenderModeState.saveSnapshot(s, to: url)
        XCTAssertEqual(RenderModeState.loadSnapshot(from: url), s)
    }
    func testAutoBackupParsing() {
        XCTAssertEqual(RenderModeState.parseAutoBackup("1\n"), true); XCTAssertEqual(RenderModeState.parseAutoBackup("0"), false); XCTAssertNil(RenderModeState.parseAutoBackup("The domain/default pair does not exist"))
    }
}
