import Foundation
import Security

/// Secrete in Keychain (generic password), nu in UserDefaults. Valorile nu se logheaza.
public enum SecretStore {
    public static var service: String { AppProfile.keychainService }

    private static func query(_ account: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    @discardableResult
    public static func set(_ value: String, account: String) -> Bool {
        if value.isEmpty { return delete(account: account) }
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
        var q = query(account)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let d = out as? Data else { return nil }
        return String(data: d, encoding: .utf8)
    }

    @discardableResult
    public static func delete(account: String) -> Bool {
        let s = SecItemDelete(query(account) as CFDictionary)
        return s == errSecSuccess || s == errSecItemNotFound
    }
}
