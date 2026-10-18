import Foundation

/// În Demo, aplicația pornește de fiecare dată de la zero: setările utilizatorului și cache-urile aferente nu se păstrează.
/// Nu se ating: starea de acces, instantaneul Modului Randare (siguranța sistemului), jurnalele și configurația rclone externă.
public enum DemoProfile {
    static let keepPrefixes = ["MMSP.access.", "NS", "Apple", "AK", "com.apple", "WebKit", "NavPanel", "Sparkle"]

    /// Se aplică NUMAI profilului izolat (build demonstrativ/test) sau unor ținte date explicit (teste). Pe profilul oficial nu face NIMIC:
    /// proba nu șterge niciodată setările, conturile, credențialele sau datele utilizatorului (hotărâre proprietar, 2026-10-18).
    public static func wipe(defaults: UserDefaults? = nil, supportDir: URL? = nil) {
        let explicit = defaults != nil || supportDir != nil
        guard AppProfile.isIsolated || explicit else { DiagnosticLog.write(.info, tag: "access", event: "demo.wipe-skipped-official-profile"); return }
        let defaults = defaults ?? AppProfile.defaults
        for key in defaults.dictionaryRepresentation().keys where !keepPrefixes.contains(where: { key.hasPrefix($0) }) {
            defaults.removeObject(forKey: key)
        }
        if supportDir == nil { SecretStore.delete(account: "smtp.appPassword") }
        let dir = supportDir ?? AppProfile.supportDirectory
        let keep: Set<String> = ["RenderModeSnapshot.json", "secrets"]
        if let items = try? FileManager.default.contentsOfDirectory(atPath: dir.path) {
            for name in items where !keep.contains(name) && !name.hasSuffix(".sh") {
                try? FileManager.default.removeItem(at: dir.appendingPathComponent(name))
            }
        }
        DiagnosticLog.write(.info, tag: "access", event: "demo.profile-wiped")
    }
}
