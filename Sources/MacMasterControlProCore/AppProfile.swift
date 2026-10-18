import Foundation
import CryptoKit

/// Izolarea profilului. Ediția instalată (bundle ID oficial) folosește profilul oficial; ORICE altceva (build de test, demonstrativ,
/// rulare din linie de comandă, runner de teste, sau `MCSP_PROFILE_DIR` setat) folosește un profil SEPARAT: director, preferințe, Keychain,
/// jurnale. Un build izolat nu citește și nu modifică niciodată profilul oficial.
public enum AppProfile {
    public static let officialBundleID = "com.gordasgdc.macmastercontrolpro"
    nonisolated(unsafe) static var overrideBundleID: String?
    nonisolated(unsafe) static var overrideRoot: URL?
    nonisolated(unsafe) static var overrideOfficialDir: URL?   // doar teste

    static var bundleID: String { overrideBundleID ?? Bundle.main.bundleIdentifier ?? ProcessInfo.processInfo.processName }
    private static var explicitRoot: URL? {
        if let o = overrideRoot { return o }
        if let p = ProcessInfo.processInfo.environment["MCSP_PROFILE_DIR"], !p.isEmpty { return URL(fileURLWithPath: p, isDirectory: true) }
        return nil
    }

    public static var isIsolated: Bool { explicitRoot != nil || bundleID != officialBundleID }

    /// Identificator scurt, sigur pentru nume de fișier/serviciu.
    static var isolationID: String { bundleID.replacingOccurrences(of: "[^A-Za-z0-9.]", with: "_", options: .regularExpression) }

    /// Sufix STABIL (SHA-256 al căii) pentru o rădăcină explicită: profile diferite nu se amestecă, același profil rămâne același între rulări.
    private static var rootTag: String {
        guard let r = explicitRoot else { return "" }
        return "." + SHA256.hash(data: Data(r.path.utf8)).prefix(6).map { String(format: "%02x", $0) }.joined()
    }

    private static var home: URL { FileManager.default.homeDirectoryForCurrentUser }

    /// Directorul oficial (neatins de build-urile izolate).
    public static var officialSupportDirectory: URL { overrideOfficialDir ?? home.appendingPathComponent("Library/Application Support/MacMasterControlPro", isDirectory: true) }

    /// Directorul de date al profilului curent (setări, cache, baze de date, scripturi).
    public static var supportDirectory: URL {
        if let r = explicitRoot { return r }
        if bundleID == officialBundleID { return officialSupportDirectory }
        return home.appendingPathComponent("Library/Application Support/MCSP-Isolated/\(isolationID)", isDirectory: true)
    }

    /// Doar pentru probe de regresie: jurnalele ediției oficiale.
    public static var officialLogsDirectoryForTests: URL { home.appendingPathComponent("Library/Logs/MasterControlStudioPro", isDirectory: true) }

    public static var logsDirectory: URL {
        isolated(official: home.appendingPathComponent("Library/Logs/MasterControlStudioPro", isDirectory: true), isolatedSub: "Logs")
    }

    public static var keychainService: String {
        isolated(official: "com.gordasgdc.macmastercontrolpro.secrets", isolatedValue: "com.gordasgdc.macmastercontrolpro.secrets.iso.\(isolationID)\(rootTag)")
    }

    /// Preferințe: suita izolată pentru build-uri izolate, domeniul standard doar pentru ediția oficială.
    public static var defaults: UserDefaults {
        guard isolated() else { return .standard }
        return UserDefaults(suiteName: "mcsp.iso.\(isolationID)\(rootTag)") ?? .standard
    }
    private static func isolated() -> Bool { isIsolated }
    private static func isolated(official: URL, isolatedSub: String) -> URL { isIsolated ? supportDirectory.appendingPathComponent(isolatedSub, isDirectory: true) : official }
    private static func isolated(official: String, isolatedValue: String) -> String { isIsolated ? isolatedValue : official }

    // MARK: - Resetare EXPLICITĂ a configurației (niciodată automată)

    /// Ce s-ar șterge la o resetare (pentru confirmare). Nu atinge nimic.
    public static func resetPreview() -> [String] {
        var l = ["Setările aplicației (temă, limbă, folderele alese, profil)"]
        if FileManager.default.fileExists(atPath: supportDirectory.path) { l.append("Cache-uri și fișiere locale din \(supportDirectory.path)") }
        l.append("Parola de aplicație SMTP (dacă a fost salvată)")
        l.append("NU se șterg: licența/starea de acces, conturile rclone, jurnalele, instantaneul Modului Randare")
        return l
    }

    /// Reset al configurației utilizatorului, cu COPIE DE SIGURANȚĂ făcută înainte. Se cheamă DOAR dintr-o acțiune explicită a utilizatorului.
    @discardableResult
    public static func resetUserConfiguration(backupRoot: URL? = nil) throws -> URL {
        let fm = FileManager.default
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let backup = (backupRoot ?? supportDirectory.deletingLastPathComponent().appendingPathComponent("MacMasterControlPro-Backups", isDirectory: true))
            .appendingPathComponent(stamp, isDirectory: true)
        try fm.createDirectory(at: backup, withIntermediateDirectories: true)
        if fm.fileExists(atPath: supportDirectory.path) { try fm.copyItem(at: supportDirectory, to: backup.appendingPathComponent("support", isDirectory: true)) }
        let dict = defaults.dictionaryRepresentation().filter { !$0.key.hasPrefix("NS") && !$0.key.hasPrefix("Apple") }
        let data = try PropertyListSerialization.data(fromPropertyList: dict, format: .xml, options: 0)
        try data.write(to: backup.appendingPathComponent("preferences.plist"))
        for key in dict.keys where !key.hasPrefix("MMSP.access.") { defaults.removeObject(forKey: key) }
        SecretStore.delete(account: "smtp.appPassword")
        if let items = try? fm.contentsOfDirectory(atPath: supportDirectory.path) {
            let keep: Set<String> = ["RenderModeSnapshot.json"]
            for n in items where !keep.contains(n) && !n.hasSuffix(".sh") { try? fm.removeItem(at: supportDirectory.appendingPathComponent(n)) }
        }
        DiagnosticLog.write(.warning, tag: "profile", event: "config.reset-by-user", fields: ["backup": backup.lastPathComponent])
        return backup
    }
}
