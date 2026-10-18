import XCTest
import CryptoKit
@testable import MacMasterControlProCore

/// Probă de regresie: profilul OFICIAL (aplicația instalată) rămâne identic înainte și după orice face un build izolat:
/// pornire, expirarea probei, resetare, ștergere de date și închidere. Citește doar; nu modifică profilul oficial.
final class IsolationTests: XCTestCase {
    private func fingerprint() -> String {
        var parts: [String] = []
        let fm = FileManager.default
        let dir = AppProfile.officialSupportDirectory
        if let e = fm.enumerator(at: dir, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey]) {
            for case let u as URL in e {
                let v = try? u.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey])
                let h = (v?.isDirectory ?? false) ? "dir" : (try? Data(contentsOf: u)).map { SHA256.hash(data: $0).map { String(format: "%02x", $0) }.joined().prefix(12) }.map(String.init) ?? "?"
                parts.append("\(u.path.dropFirst(dir.path.count))|\(v?.fileSize ?? -1)|\(v?.contentModificationDate?.timeIntervalSince1970 ?? 0)|\(h)")
            }
        }
        let dom = UserDefaults.standard.persistentDomain(forName: AppProfile.officialBundleID) ?? [:]
        parts.append("defaults:" + dom.keys.sorted().map { "\($0)=\(dom[$0]!)" }.joined(separator: ";"))
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "com.gordasgdc.macmastercontrolpro.secrets",
                                kSecMatchLimit as String: kSecMatchLimitAll, kSecReturnAttributes as String: true]
        var out: AnyObject?; let st = SecItemCopyMatching(q as CFDictionary, &out)
        parts.append("keychain:\(st):\((out as? [[String: Any]])?.count ?? 0)")
        let logs = AppProfile.officialLogsDirectoryForTests
        parts.append("logs:" + ((try? fm.contentsOfDirectory(atPath: logs.path)) ?? []).sorted().map { "\($0):\((try? fm.attributesOfItem(atPath: logs.appendingPathComponent($0).path)[.size] as? Int) ?? 0)" }.joined(separator: ","))
        return SHA256.hash(data: Data(parts.joined(separator: "\n").utf8)).map { String(format: "%02x", $0) }.joined()
    }

    func testTestRunnerIsIsolatedFromOfficialProfile() {
        XCTAssertTrue(AppProfile.isIsolated)
        XCTAssertNotEqual(AppProfile.supportDirectory.path, AppProfile.officialSupportDirectory.path)
        XCTAssertNotEqual(AppProfile.keychainService, "com.gordasgdc.macmastercontrolpro.secrets")
        XCTAssertFalse(AppProfile.defaults === UserDefaults.standard)
    }

    func testOfficialProfileUnchangedByStartExpiryResetAndClose() throws {
        // Excepția explicită: jurnalul oficial (~/Library/Logs/MasterControlStudioPro) poate fi scris doar de aplicația oficială.
        let before = fingerprint()

        // pornire + expirare + sesiune nouă
        final class Clock { var t = Date(timeIntervalSince1970: 1_900_000_000) }
        let c = Clock(); let acct = "iso-test-\(UUID().uuidString)"
        let a = CommunityAccess(account: acct, now: { c.t })
        a.tick(active: true)
        for _ in 0..<650 { c.t = c.t.addingTimeInterval(1); a.tick(active: true) }
        XCTAssertFalse(a.mode.allowsFeatures)
        c.t = c.t.addingTimeInterval(172_900); a.tick(active: false)
        XCTAssertTrue(a.mode.allowsFeatures)

        // scrieri în profilul izolat + resetare automată de demo + resetare explicită + dezinstalare de date
        AppProfile.defaults.set("x", forKey: "MacMasterControlPro.theme")
        try FileManager.default.createDirectory(at: AppProfile.supportDirectory.appendingPathComponent("DiskCache"), withIntermediateDirectories: true)
        try "c".write(to: AppProfile.supportDirectory.appendingPathComponent("DiskCache/a"), atomically: true, encoding: .utf8)
        DemoProfile.wipe()
        let backup = try AppProfile.resetUserConfiguration(backupRoot: FileManager.default.temporaryDirectory.appendingPathComponent("iso-bk-\(UUID().uuidString)"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: backup.appendingPathComponent("preferences.plist").path))
        SelfUninstaller.removeUserData()   // pe profilul IZOLAT
        SecretStore.set("v", account: acct + ".probe"); SecretStore.delete(account: acct + ".probe")
        DiagnosticLog.write(.info, tag: "iso", event: "probe"); DiagnosticLog.flush()
        SecretStore.delete(account: acct); SecretStore.delete(account: acct + ".key")

        XCTAssertEqual(before, fingerprint(), "profilul oficial s-a modificat")
    }

    func testDemoWipeIsNoopOnOfficialProfile() throws {
        let fake = FileManager.default.temporaryDirectory.appendingPathComponent("fake-official-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: fake.appendingPathComponent("DiskCache"), withIntermediateDirectories: true)
        try "cfg".write(to: fake.appendingPathComponent("settings.json"), atomically: true, encoding: .utf8)
        try "cache".write(to: fake.appendingPathComponent("DiskCache/x"), atomically: true, encoding: .utf8)
        AppProfile.overrideBundleID = AppProfile.officialBundleID; AppProfile.overrideOfficialDir = fake
        defer { AppProfile.overrideBundleID = nil; AppProfile.overrideOfficialDir = nil }
        XCTAssertFalse(AppProfile.isIsolated)
        XCTAssertEqual(AppProfile.supportDirectory.path, fake.path)
        DemoProfile.wipe()   // pe profilul oficial: nu are voie să șteargă nimic
        XCTAssertTrue(FileManager.default.fileExists(atPath: fake.appendingPathComponent("settings.json").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: fake.appendingPathComponent("DiskCache/x").path))
    }
}
