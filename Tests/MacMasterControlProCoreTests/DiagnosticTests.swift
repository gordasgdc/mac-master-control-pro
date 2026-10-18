import XCTest
@testable import MacMasterControlProCore

final class DiagnosticTests: XCTestCase {
    func testRedactsSecretsEmailsAndHome() {
        let s = DiagnosticLog.redact("password=hunter2 user a.b@gmail.com --user bob:pw token: abcDEF Bearer xyz.123 \(NSHomeDirectory())/Movies")
        XCTAssertFalse(s.contains("hunter2")); XCTAssertFalse(s.contains("gmail")); XCTAssertFalse(s.contains("bob:pw"))
        XCTAssertFalse(s.contains("abcDEF")); XCTAssertFalse(s.contains("xyz.123")); XCTAssertFalse(s.contains(NSHomeDirectory()))
    }

    func testRotationBoundsDiskUse() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("mcsp-log-\(UUID().uuidString)")
        DiagnosticLog.directoryOverride = dir
        defer { DiagnosticLog.directoryOverride = nil; try? FileManager.default.removeItem(at: dir) }
        let big = String(repeating: "x ", count: 400)
        for _ in 0..<(DiagnosticLog.maxFileBytes / 700 * (DiagnosticLog.keepArchives + 3)) {
            DiagnosticLog.write(.info, tag: "t", event: "e", message: big)
        }
        DiagnosticLog.flush()
        let files = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        XCTAssertLessThanOrEqual(files.count, DiagnosticLog.keepArchives + 1)
    }

    func testUnwritableDirectoryDoesNotCrash() {
        DiagnosticLog.directoryOverride = URL(fileURLWithPath: "/dev/null/nope")
        defer { DiagnosticLog.directoryOverride = nil }
        DiagnosticLog.write(.error, tag: "t", event: "e")
        DiagnosticLog.flush()
    }

    func testExportContainsNoSecrets() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("mcsp-exp-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        DiagnosticLog.directoryOverride = dir.appendingPathComponent("logs")
        defer { DiagnosticLog.directoryOverride = nil; try? FileManager.default.removeItem(at: dir) }
        DiagnosticLog.write(.info, tag: "t", event: "e", message: "password=SECRETVALUE9 me@x.org")
        let zip = try DiagnosticExport.export(to: dir)
        let out = Process(); out.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        let unz = dir.appendingPathComponent("unz")
        out.arguments = ["-q", zip.path, "-d", unz.path]; try out.run(); out.waitUntilExit()
        let en = FileManager.default.enumerator(at: unz, includingPropertiesForKeys: nil)!
        for case let u as URL in en where !u.hasDirectoryPath {
            let t = (try? String(contentsOf: u, encoding: .utf8)) ?? ""
            XCTAssertFalse(t.contains("SECRETVALUE9")); XCTAssertFalse(t.contains("me@x.org"))
        }
    }
}

final class SecretMigrationTests: XCTestCase {
    func testLegacyPlaintextPasswordMovesToKeychain() {
        let key = "MacMasterControlPro.emailNotifierSettings"
        let backup = AppProfile.defaults.data(forKey: key)
        let oldSecret = SecretStore.get(account: "smtp.appPassword")
        defer {
            if let backup { AppProfile.defaults.set(backup, forKey: key) } else { AppProfile.defaults.removeObject(forKey: key) }
            if let oldSecret { SecretStore.set(oldSecret, account: "smtp.appPassword") } else { SecretStore.delete(account: "smtp.appPassword") }
        }
        var legacy = EmailNotifierSettings(); legacy.enabled = true; legacy.username = "u@x.org"; legacy.appPassword = "legacy-pass-123"; legacy.recipient = "r@x.org"
        AppProfile.defaults.set(try! JSONEncoder().encode(legacy), forKey: key)
        let s = EmailNotifierService.settings
        XCTAssertEqual(s.appPassword, "legacy-pass-123"); XCTAssertEqual(s.username, "u@x.org"); XCTAssertTrue(s.enabled)
        let raw = String(data: AppProfile.defaults.data(forKey: key)!, encoding: .utf8)!
        XCTAssertFalse(raw.contains("legacy-pass-123"))
        XCTAssertEqual(SecretStore.get(account: "smtp.appPassword"), "legacy-pass-123")
    }
}
