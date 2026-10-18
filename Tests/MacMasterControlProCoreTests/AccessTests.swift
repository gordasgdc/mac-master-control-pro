import XCTest
@testable import MacMasterControlProCore

final class AccessTests: XCTestCase {
    final class Clock { var t = Date(timeIntervalSince1970: 1_800_000_000); func now() -> Date { t } }
    private func make(_ c: Clock) -> CommunityAccess {
        let a = CommunityAccess(account: "test-demo-\(UUID().uuidString)", now: c.now); return a
    }
    private func run(_ a: CommunityAccess, _ c: Clock, seconds: Int, active: Bool = true) {
        for _ in 0..<seconds { c.t = c.t.addingTimeInterval(1); a.tick(active: active) }
    }

    func testSessionConsumesOnlyActiveTimeAndLocksAt600() {
        let c = Clock(); let a = make(c)
        a.tick(active: true)                      // prima activare pornește ceasul
        run(a, c, seconds: 300, active: false)    // inactivitate: nu consumă
        XCTAssertEqual(a.mode, .demoAvailable(remainingSeconds: 600))
        run(a, c, seconds: 599)
        guard case .demoAvailable(let r) = a.mode else { return XCTFail("trebuia să fie încă disponibil") }
        XCTAssertLessThanOrEqual(r, 2)
        run(a, c, seconds: 5)
        guard case .demoLocked(let next) = a.mode else { return XCTFail("trebuia blocat") }
        XCTAssertEqual(next.timeIntervalSince1970 - c.t.timeIntervalSince1970, 172_800, accuracy: 10)
    }

    func testNextSessionExactly48hAfterExhaustion() {
        let c = Clock(); let a = make(c); a.tick(active: true); run(a, c, seconds: 610)
        guard case .demoLocked = a.mode else { return XCTFail() }
        c.t = c.t.addingTimeInterval(172_800 - 60); XCTAssertFalse(a.mode.allowsFeatures)
        c.t = c.t.addingTimeInterval(120); XCTAssertEqual(a.mode, .demoAvailable(remainingSeconds: 600))
        a.tick(active: true); XCTAssertTrue(a.mode.allowsFeatures)
    }

    func testClockRolledBackDoesNotUnlock() {
        let c = Clock(); let a = make(c); a.tick(active: true); run(a, c, seconds: 610)
        c.t = c.t.addingTimeInterval(-200_000)
        a.tick(active: false)
        XCTAssertFalse(a.mode.allowsFeatures, "ceasul dat înapoi nu reactivează")
    }

    func testSleepGapIsNotCounted() {
        let c = Clock(); let a = make(c); a.tick(active: true)
        c.t = c.t.addingTimeInterval(3600); a.tick(active: true)   // hibernare 1h: max 5 s
        guard case .demoAvailable(let r) = a.mode else { return XCTFail() }
        XCTAssertGreaterThanOrEqual(r, 590)
    }

    func testStateSurvivesRestartAndTamperingExhausts() {
        let c = Clock(); let acct = "test-demo-\(UUID().uuidString)"
        let a = CommunityAccess(account: acct, now: c.now); a.tick(active: true); run(a, c, seconds: 100)
        let b = CommunityAccess(account: acct, now: c.now)
        guard case .demoAvailable(let r) = b.mode else { return XCTFail() }
        XCTAssertLessThan(r, 600)
        SecretStore.set(Data(repeating: 7, count: 80).base64EncodedString(), account: acct)   // stare falsificată
        let d = CommunityAccess(account: acct, now: c.now)
        XCTAssertFalse(d.mode.allowsFeatures)
    }

    func testDemoProfileWipeKeepsSafetyState() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("mcsp-wipe-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try "snap".write(to: dir.appendingPathComponent("RenderModeSnapshot.json"), atomically: true, encoding: .utf8)
        try FileManager.default.createDirectory(at: dir.appendingPathComponent("DiskCache"), withIntermediateDirectories: true)
        try "x".write(to: dir.appendingPathComponent("DiskCache/a.mmcpdisk"), atomically: true, encoding: .utf8)
        let ud = UserDefaults(suiteName: "mcsp-test-\(UUID().uuidString)")!
        ud.set(true, forKey: "MacMasterControlPro.theme"); ud.set("x", forKey: "MMSP.access.keep")
        DemoProfile.wipe(defaults: ud, supportDir: dir)
        XCTAssertNil(ud.object(forKey: "MacMasterControlPro.theme")); XCTAssertNotNil(ud.object(forKey: "MMSP.access.keep"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.appendingPathComponent("RenderModeSnapshot.json").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: dir.appendingPathComponent("DiskCache").path))
    }
}

final class MachineIDTests: XCTestCase {
    func testBase32MatchesRFC4648Vectors() {
        XCTAssertEqual(MachineID.base32Encode(Data("foobar".utf8)), "MZXW6YTBOI")
        XCTAssertEqual(MachineID.base32Encode(Data("fooba".utf8)), "MZXW6YTB")
        XCTAssertEqual(MachineID.display.count, 10)
    }
}
