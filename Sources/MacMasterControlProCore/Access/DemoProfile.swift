import Foundation

/// În Demo, aplicația pornește de fiecare dată de la zero: setările utilizatorului și cache-urile aferente nu se păstrează.
/// Nu se ating: starea de acces, instantaneul Modului Randare (siguranța sistemului), jurnalele și configurația rclone externă.
public enum DemoProfile {
    static let keepPrefixes = ["MMSP.access.", "NS", "Apple", "AK", "com.apple", "WebKit", "NavPanel", "Sparkle"]

    public static func wipe(defaults: UserDefaults = .standard, supportDir: URL? = nil) {
        for key in defaults.dictionaryRepresentation().keys where !keepPrefixes.contains(where: { key.hasPrefix($0) }) {
            defaults.removeObject(forKey: key)
        }
        SecretStore.delete(account: "smtp.appPassword")
        let dir = supportDir ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("MacMasterControlPro", isDirectory: true)
        let keep: Set<String> = ["RenderModeSnapshot.json"]
        if let items = try? FileManager.default.contentsOfDirectory(atPath: dir.path) {
            for name in items where !keep.contains(name) && !name.hasSuffix(".sh") {
                try? FileManager.default.removeItem(at: dir.appendingPathComponent(name))
            }
        }
        DiagnosticLog.write(.info, tag: "access", event: "demo.profile-wiped")
    }
}
