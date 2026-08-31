import Foundation
import AppKit

/// O aplicație instalată, detectată prin scanarea `/Applications` +
/// `~/Applications` — sursa listei pentru modulul de Dezinstalator.
public struct InstalledApp: Identifiable, Hashable {
    public let id: String // bundle identifier, sau calea daca lipseste
    public let name: String
    public let bundleID: String?
    public let path: URL

    public var icon: NSImage { NSWorkspace.shared.icon(forFile: path.path) }
}

/// O categorie de fișiere/resurse asociate unei aplicații, găsite în
/// locațiile standard macOS. Fiecare categorie e bifabilă separat —
/// Cristi alege ce șterge, nu "totul orbește" (regula globală de
/// instalare pas-cu-pas se aplică identic și la dezinstalare).
public struct UninstallCategory: Identifiable {
    public let id: String
    public let title: String
    public let paths: [URL]
    public let totalBytes: Int64
    /// Locațiile din `/Library/LaunchAgents` sau `/Library/LaunchDaemons`
    /// cer privilegii de admin la ștergere — restul (Application Support,
    /// Caches etc.) sunt în home-ul userului, ștergere directă.
    public let requiresPrivilege: Bool

    public var sizeDescription: String {
        ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
    }
}

/// Scanează și șterge TOATE urmele unei aplicații — nu doar `.app`-ul din
/// `/Applications`, spre deosebire de "trage în Coșul de gunoi", care lasă
/// mereu în urmă Application Support/Caches/Preferences/LaunchAgents etc.
/// Cerință directă (2026-08-31): "să dezinstalezi tot ce ține legătură cu
/// acea aplicație, să nu rămână nimica pe niciunde".
public enum UninstallerService {
    private static let fm = FileManager.default
    private static var home: URL { fm.homeDirectoryForCurrentUser }

    // MARK: - Scanare aplicații instalate

    public static func scanInstalledApps() -> [InstalledApp] {
        var results: [InstalledApp] = []
        for root in ["/Applications", home.appendingPathComponent("Applications").path] {
            guard let entries = try? fm.contentsOfDirectory(atPath: root) else { continue }
            for entry in entries where entry.hasSuffix(".app") {
                let url = URL(fileURLWithPath: root).appendingPathComponent(entry)
                let bundleID = Bundle(url: url)?.bundleIdentifier
                let name = entry.replacingOccurrences(of: ".app", with: "")
                results.append(InstalledApp(id: bundleID ?? url.path, name: name, bundleID: bundleID, path: url))
            }
        }
        return results.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    // MARK: - Scanare urme asociate

    /// Toate categoriile relevante pentru `app`, cu dimensiuni reale —
    /// gol daca acea categorie n-are nimic (nu se afiseaza in UI).
    public static func scanRelatedFiles(for app: InstalledApp) -> [UninstallCategory] {
        let id = app.bundleID
        let name = app.name

        func matches(_ path: URL) -> Bool {
            let last = path.lastPathComponent
            if let id, last.localizedCaseInsensitiveContains(id) { return true }
            return last.localizedCaseInsensitiveContains(name)
        }

        func candidates(in directory: URL) -> [URL] {
            guard let entries = try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return [] }
            return entries.filter(matches)
        }

        func category(_ id: String, _ title: String, _ paths: [URL], privileged: Bool = false) -> UninstallCategory? {
            guard !paths.isEmpty else { return nil }
            let total = paths.reduce(Int64(0)) { $0 + directorySize($1) }
            return UninstallCategory(id: id, title: title, paths: paths, totalBytes: total, requiresPrivilege: privileged)
        }

        let lib = home.appendingPathComponent("Library")
        var categories: [UninstallCategory] = []

        if let c = category("appsupport", "Application Support", candidates(in: lib.appendingPathComponent("Application Support"))) { categories.append(c) }
        if let c = category("caches", "Caches", candidates(in: lib.appendingPathComponent("Caches"))) { categories.append(c) }
        if let c = category("prefs", "Preferences", candidates(in: lib.appendingPathComponent("Preferences"))) { categories.append(c) }
        if let c = category("savedstate", "Saved Application State", candidates(in: lib.appendingPathComponent("Saved Application State"))) { categories.append(c) }
        if let c = category("logs", "Logs", candidates(in: lib.appendingPathComponent("Logs"))) { categories.append(c) }
        if let c = category("httpstorages", "HTTP Storages", candidates(in: lib.appendingPathComponent("HTTPStorages"))) { categories.append(c) }
        if let c = category("webkit", "WebKit", candidates(in: lib.appendingPathComponent("WebKit"))) { categories.append(c) }
        if let c = category("containers", "Containers (sandbox)", candidates(in: lib.appendingPathComponent("Containers"))) { categories.append(c) }
        if let c = category("groupcontainers", "Group Containers", candidates(in: lib.appendingPathComponent("Group Containers"))) { categories.append(c) }
        if let c = category("launchagents-user", "LaunchAgents (userul curent)", candidates(in: lib.appendingPathComponent("LaunchAgents"))) { categories.append(c) }

        // Locatiile de sistem (privilegiate) — enumerare fara privilegiu
        // (citirea listei nu cere root), doar STERGEREA cere.
        let systemLaunchAgents = URL(fileURLWithPath: "/Library/LaunchAgents")
        let systemLaunchDaemons = URL(fileURLWithPath: "/Library/LaunchDaemons")
        if let c = category("launchagents-system", "LaunchAgents (sistem)", candidates(in: systemLaunchAgents), privileged: true) { categories.append(c) }
        if let c = category("launchdaemons-system", "LaunchDaemons (sistem)", candidates(in: systemLaunchDaemons), privileged: true) { categories.append(c) }

        // Aplicatia insasi — categorie separata, mereu prima logic, dar
        // afisata distinct in UI (nu e o "urma", e produsul principal).
        return categories
    }

    /// Dimensiune totala (bytes) a unui fisier/folder — `du -sk` e mult mai
    /// rapid decat un `FileManager.enumerator` recursiv pe foldere mari de
    /// cache, si e disponibil implicit pe orice Mac.
    private static func directorySize(_ url: URL) -> Int64 {
        let output = Shell.run("du -sk \"\(url.path)\" 2>/dev/null | cut -f1")
        let kb = Int64(output.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        return kb * 1024
    }

    // MARK: - Stergere

    /// Sterge aplicatia insasi (poate cere privilegiu daca nu apartine
    /// userului curent — instalata printr-un .pkg cu root).
    public static func deleteAppBundle(_ app: InstalledApp) -> String {
        if fm.isDeletableFile(atPath: app.path.path) {
            try? fm.trashItem(at: app.path, resultingItemURL: nil)
            return "Șters: \(app.path.path)"
        }
        let result = PrivilegedRunner.run("rm -rf \"\(app.path.path)\"")
        return result.success ? "Șters (privilegiat): \(app.path.path)" : "EROARE la ștergerea \(app.path.path): \(result.output)"
    }

    /// Sterge categoriile bifate. Cele neprivilegiate direct prin
    /// FileManager (Cos de gunoi, reversibil); cele de sistem, o singura
    /// cerere de parola pentru toate (launchctl bootout + rm).
    public static func delete(categories: [UninstallCategory], log: @escaping (String) -> Void) {
        var privilegedCommands: [String] = []
        for category in categories {
            for path in category.paths {
                if category.requiresPrivilege {
                    privilegedCommands.append("launchctl bootout system \"\(path.path)\" 2>/dev/null; launchctl bootout gui/$(id -u) \"\(path.path)\" 2>/dev/null; rm -f \"\(path.path)\"")
                } else {
                    if (try? fm.trashItem(at: path, resultingItemURL: nil)) != nil {
                        log("Mutat la Coșul de gunoi: \(path.path)")
                    } else {
                        log("EROARE, nu s-a putut șterge: \(path.path)")
                    }
                }
            }
        }
        if !privilegedCommands.isEmpty {
            log("Solicit parola de admin pentru \(privilegedCommands.count) fișiere de sistem…")
            let result = PrivilegedRunner.run(privilegedCommands)
            log(result.success ? "Fișiere de sistem șterse." : "EROARE: \(result.output)")
        }
    }
}
