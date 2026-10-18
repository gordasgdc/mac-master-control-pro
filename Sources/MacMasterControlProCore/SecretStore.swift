import Foundation
import Security

/// Secrete. Ediția oficială: Keychain (generic password, ThisDeviceOnly). Profil IZOLAT (build de test/demonstrativ): fișiere 0600 în profilul izolat,
/// ca testele și capturile să nu atingă Keychain-ul utilizatorului și să nu declanșeze dialoguri de acces la Keychain. Valorile nu se logheaza.
public enum SecretStore {
    public static var service: String { AppProfile.keychainService }

    private static var fileDir: URL { AppProfile.supportDirectory.appendingPathComponent("secrets", isDirectory: true) }
    private static func fileURL(_ account: String) -> URL {
        let safe = account.replacingOccurrences(of: "[^A-Za-z0-9._-]", with: "_", options: .regularExpression)
        return fileDir.appendingPathComponent(safe + ".secret")
    }

    private static func query(_ account: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    @discardableResult
    public static func set(_ value: String, account: String) -> Bool {
        if value.isEmpty { return delete(account: account) }
        if AppProfile.isIsolated {
            do {
                try FileManager.default.createDirectory(at: fileDir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
                let u = fileURL(account)
                try Data(value.utf8).write(to: u, options: .atomic)
                try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: u.path)
                return true
            } catch { return false }
        }
        let data = Data(value.utf8)
        let status = SecItemUpdate(query(account) as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecSuccess { return true }
        var add = query(account)
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let s = SecItemAdd(add as CFDictionary, nil)
        if s != errSecSuccess { DiagnosticLog.write(.error, tag: "secrets", event: "set.fail", fields: ["status": String(s)]) }
        return s == errSecSuccess
    }

    public static func get(account: String) -> String? {
        if AppProfile.isIsolated { return (try? Data(contentsOf: fileURL(account))).flatMap { String(data: $0, encoding: .utf8) } }
        var q = query(account)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let d = out as? Data else { return nil }
        return String(data: d, encoding: .utf8)
    }

    @discardableResult
    public static func delete(account: String) -> Bool {
        if AppProfile.isIsolated { try? FileManager.default.removeItem(at: fileURL(account)); return true }
        let s = SecItemDelete(query(account) as CFDictionary)
        return s == errSecSuccess || s == errSecItemNotFound
    }
}
