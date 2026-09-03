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
        if let c = category("prefs-byhost", "Preferences (ByHost)", candidates(in: lib.appendingPathComponent("Preferences/ByHost"))) { categories.append(c) }
        if let c = category("savedstate", "Saved Application State", candidates(in: lib.appendingPathComponent("Saved Application State"))) { categories.append(c) }
        if let c = category("logs", "Logs", candidates(in: lib.appendingPathComponent("Logs"))) { categories.append(c) }
        if let c = category("httpstorages", "HTTP Storages", candidates(in: lib.appendingPathComponent("HTTPStorages"))) { categories.append(c) }
        if let c = category("webkit", "WebKit", candidates(in: lib.appendingPathComponent("WebKit"))) { categories.append(c) }
        if let c = category("containers", "Containers (sandbox)", candidates(in: lib.appendingPathComponent("Containers"))) { categories.append(c) }
        if let c = category("groupcontainers", "Group Containers", candidates(in: lib.appendingPathComponent("Group Containers"))) { categories.append(c) }
        if let c = category("appscripts", "Application Scripts", candidates(in: lib.appendingPathComponent("Application Scripts"))) { categories.append(c) }
        if let c = category("saved-search", "Saved Searches", candidates(in: lib.appendingPathComponent("Saved Searches"))) { categories.append(c) }
        if let c = category("autosave", "Autosave Information", candidates(in: lib.appendingPathComponent("Autosave Information"))) { categories.append(c) }
        if let c = category("icloud", "iCloud Drive (container)", candidates(in: lib.appendingPathComponent("Mobile Documents"))) { categories.append(c) }
        if let c = category("launchagents-user", "LaunchAgents (userul curent)", candidates(in: lib.appendingPathComponent("LaunchAgents"))) { categories.append(c) }

        // Locatiile de sistem — enumerare fara privilegiu (citirea listei
        // nu cere root), doar STERGEREA cere (marcate `privileged: true`).
        // Extindere (2026-09-01, cerinta explicita: "sa elimine tot tot
        // tot, sa scaneze resturi") — pana acum doar LaunchAgents/Daemons
        // de sistem erau verificate; multe aplicatii (in special cele cu
        // panouri de preferinte, plugin-uri media, sau instalate prin
        // .pkg cu root) lasa urme si in aceste locatii de sistem.
        let systemLocations: [(String, String, String)] = [
            ("launchagents-system", "LaunchAgents (sistem)", "/Library/LaunchAgents"),
            ("launchdaemons-system", "LaunchDaemons (sistem)", "/Library/LaunchDaemons"),
            ("appsupport-system", "Application Support (sistem)", "/Library/Application Support"),
            ("prefs-system", "Preferences (sistem)", "/Library/Preferences"),
            ("prefpanes", "Panouri de Preferințe (System Settings)", "/Library/PreferencePanes"),
            ("internetplugins", "Internet Plug-Ins", "/Library/Internet Plug-Ins"),
            ("quicklook", "Extensii QuickLook", "/Library/QuickLook"),
            ("widgets", "Widget-uri", "/Library/Widgets"),
            ("spotlight-importers", "Importatoare Spotlight", "/Library/Spotlight"),
            ("audio-components", "Plugin-uri Audio (Components)", "/Library/Audio/Plug-Ins/Components"),
            ("audio-vst", "Plugin-uri Audio (VST)", "/Library/Audio/Plug-Ins/VST"),
            ("contextualmenu", "Elemente de meniu contextual", "/Library/Contextual Menu Items"),
        ]
        for (id, title, path) in systemLocations {
            if let c = category(id, title, candidates(in: URL(fileURLWithPath: path)), privileged: true) { categories.append(c) }
        }

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

    /// [2026-09-03] FIX REAL, raportat de Cristi ("Hedge for Mac — imi
    /// spune ca l-a sters dar tot acolo apare"): `try? fm.trashItem(...)`
    /// ARUNCA o eroare reala (macOS refuza sa trimita la Cos un `.app` cu
    /// procesul INCA RULAND — "The operation can't be completed because
    /// [app] is in use", exact ca in Finder) — dar `try?` o ARUNCA la gunoi
    /// SILENTIOS, iar codul raporta "Sters" necondiționat, indiferent daca
    /// operatia chiar reusise. Fix, doua parti:
    /// 1. Inchide aplicatia (daca ruleaza) INAINTE de a incerca stergerea —
    ///    `NSRunningApplication.terminate()`, cu o mica asteptare ca
    ///    procesul chiar sa iasa (altfel executabilul ramane "in use" chiar
    ///    dupa `terminate()`, care e doar o CERERE asincrona de inchidere).
    /// 2. Verificare REALA dupa incercarea de stergere — `fileExists`, nu
    ///    doar absenta unei exceptii Swift - raportam succes DOAR daca
    ///    fisierul chiar a disparut de pe disc.
    public static func deleteAppBundle(_ app: InstalledApp) -> String {
        terminateIfRunning(app)

        // [2026-09-03] DIAGNOSTIC, nu doar fix - Hedge for Mac tot reapare
        // dupa un "Sters" raportat cu succes, ceea ce contrazice verificarea
        // `fileExists` de mai jos - trebuie sa vedem DE CE, nu sa ghicim din
        // nou. Includem in mesaj: proprietarul real al bundle-ului si daca
        // exista un al DOILEA exemplar cu acelasi nume in cealalta locatie
        // scanata (~/Applications vs /Applications) - un duplicat ar explica
        // exact "il sterg, tot apare" fara nicio eroare reala de stergere.
        let owner = (try? fm.attributesOfItem(atPath: app.path.path))?[.ownerAccountName] as? String ?? "necunoscut"
        let otherRoot = app.path.deletingLastPathComponent().path == "/Applications"
            ? home.appendingPathComponent("Applications").path
            : "/Applications"
        let duplicatePath = otherRoot + "/" + app.path.lastPathComponent
        let hasDuplicate = fm.fileExists(atPath: duplicatePath)
        let diagnosticSuffix = hasDuplicate
            ? " [ATENȚIE: există și \(duplicatePath) — un al doilea exemplar, neatins de această ștergere]"
            : " [proprietar: \(owner)]"

        // [2026-09-03] FIX REAL nr. 2, confirmat direct din log-ul lui
        // Cristi: "Hedge for Mac.app couldn't be moved to the trash because
        // you don't have permission to access it. [proprietar: root]" —
        // `isDeletableFile(atPath:)` intoarce TRUE (permisiunile brute pe
        // /Applications permit userului admin sa scrie acolo), dar
        // `trashItem` foloseste intern un canal diferit (Finder/
        // NSWorkspace), care CERE explicit autentificare admin pentru un
        // item detinut de root — exact promptul pe care Finder l-ar arata
        // in acelasi caz. Fix: la ORICE esec al caii neprivilegiate
        // (`isDeletableFile` fals SAU `trashItem` care arunca), trecem
        // AUTOMAT pe calea privilegiata (`PrivilegedRunner`, prompt nativ
        // de parola) — nu ne mai oprim la primul refuz.
        if fm.isDeletableFile(atPath: app.path.path) {
            do {
                try fm.trashItem(at: app.path, resultingItemURL: nil)
                Thread.sleep(forTimeInterval: 0.5) // vezi nota de mai sus
                if !fm.fileExists(atPath: app.path.path) {
                    return "Șters: \(app.path.path)\(diagnosticSuffix)"
                }
                // a "reusit" fara eroare dar fisierul tot exista - cade pe
                // calea privilegiata mai jos, ca la orice alt esec.
            } catch {
                // cade pe calea privilegiata mai jos.
            }
        }
        let result = PrivilegedRunner.run("rm -rf \"\(app.path.path)\"")
        if !result.success {
            return "EROARE la ștergerea \(app.path.path): \(result.output)\(diagnosticSuffix)"
        }
        Thread.sleep(forTimeInterval: 0.5)
        return fm.fileExists(atPath: app.path.path)
            ? "EROARE: \(app.path.path) tot există la 0.5s după ștergerea privilegiată.\(diagnosticSuffix)"
            : "Șters (privilegiat): \(app.path.path)\(diagnosticSuffix)"
    }

    /// Inchide aplicatia daca ruleaza — altfel `trashItem`/`rm -rf` pot
    /// esua cu "resource busy"/"in use" pe executabilul deschis.
    ///
    /// [2026-09-03] Extins, cerinta directa a lui Cristi: "trebuie sa poata
    /// sa-l stearga chiar daca ruleaza... sa-l oprim chiar fortat". Doua
    /// cazuri reale acoperite acum, nu doar procesul principal:
    /// 1. Aplicatia principala - `terminate()` (cerere politicoasa), apoi
    ///    `forceTerminate()` (echivalent SIGKILL) daca nu iese la timp.
    /// 2. Procese/helper-e de fundal ale ACELEIASI aplicatii, care pot avea
    ///    un bundle ID DIFERIT (multe apps au un helper separat pentru
    ///    login items/actualizari/servicii, invizibil in `NSRunningApplication`
    ///    dupa bundle ID-ul aplicatiei principale) - `pkill -f` dupa CALEA
    ///    reala a bundle-ului prinde orice proces al carui executabil traieste
    ///    sub acel `.app`, indiferent de bundle ID declarat.
    public static func terminateIfRunning(_ app: InstalledApp) {
        if let bundleID = app.bundleID {
            let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            for instance in running { instance.terminate() }
            for _ in 0..<20 {
                if NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty { break }
                Thread.sleep(forTimeInterval: 0.1)
            }
            for instance in NSRunningApplication.runningApplications(withBundleIdentifier: bundleID) {
                instance.forceTerminate()
            }
        }
        // Forteaza orice proces/helper ramas cu executabilul sub acest bundle
        // (SIGKILL, `pkill -9`) - acopera helper-e cu bundle ID diferit sau
        // procese care ignora `terminate()`/`forceTerminate()` normal.
        Shell.run("pkill -9 -f \"\(app.path.path)/\" 2>/dev/null")
        Thread.sleep(forTimeInterval: 0.3)
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
                    do {
                        try fm.trashItem(at: path, resultingItemURL: nil)
                        log(fm.fileExists(atPath: path.path)
                            ? "EROARE: \(path.path) tot există după ștergere."
                            : "Mutat la Coșul de gunoi: \(path.path)")
                    } catch {
                        log("EROARE, nu s-a putut șterge \(path.path): \(error.localizedDescription)")
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
