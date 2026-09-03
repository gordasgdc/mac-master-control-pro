import Foundation

public struct CleanableItem: Identifiable, Hashable {
    public let id: String       // calea, unica
    public let name: String
    public let path: String
    public let sizeBytes: Int64
    public var sizeGB: Double { Double(sizeBytes) / 1024.0 / 1024.0 / 1024.0 }

    public init(name: String, path: String, sizeBytes: Int64) {
        self.id = path
        self.name = name
        self.path = path
        self.sizeBytes = sizeBytes
    }
}

/// Mapeaza 1:1 pe menu_cleanup din Mac_Master_Control.sh. Restructurat
/// pentru selectie granulara (checkbox per item) in loc de "totul sau nimic".
public final class CleanupService: ObservableObject {
    /// [2026-09-03] Singleton — vezi comentariul din RenderModeService pentru
    /// motiv (starea nu trebuie sa se resetteze la schimbarea de meniu).
    public static let shared = CleanupService()
    public init() {}

    @Published public var items: [CleanableItem] = []
    @Published public var snapshotDates: [String] = []

    private static let cachePaths: [(name: String, path: String)] = [
        ("Xcode DerivedData", NSHomeDirectory() + "/Library/Developer/Xcode/DerivedData"),
        ("System Caches", NSHomeDirectory() + "/Library/Caches"),
        ("Adobe Media Cache", NSHomeDirectory() + "/Library/Application Support/Adobe/Common/Media Cache Files"),
        ("DaVinci Resolve CacheClip", NSHomeDirectory() + "/Library/Application Support/Blackmagic Design/DaVinci Resolve/CacheClip"),
        // Categorii tip CleanMyMac (2026-08-31), fara scanare de "malware"
        // falsa/agresiva — doar locatii reale, verificabile, care se umplu
        // in timp fara ca userul sa observe.
        ("Coșul de gunoi (Trash)", NSHomeDirectory() + "/.Trash"),
        ("Atașamente Mail descărcate", NSHomeDirectory() + "/Library/Containers/com.apple.mail/Data/Library/Mail Downloads"),
        ("Backup-uri iOS (MobileSync)", NSHomeDirectory() + "/Library/Application Support/MobileSync/Backup"),
    ]

    /// Scanare libera (permisa in Trial) - calculeaza GB per item, fara sa stearga nimic.
    @discardableResult
    public func scanReclaimable() -> [CleanableItem] {
        items = Self.cachePaths.map { entry in
            let sizeKB = Shell.run("du -sk \"\(entry.path)\" 2>/dev/null | cut -f1")
            let kb = Int64(sizeKB) ?? 0
            return CleanableItem(name: entry.name, path: entry.path, sizeBytes: kb * 1024)
        }
        return items
    }

    /// Listarea nu necesita privilegii (doar stergerea) - fara prompt admin
    /// doar pentru a deschide modulul.
    @discardableResult
    public func scanSnapshots() -> [String] {
        let raw = Shell.run("tmutil listlocalsnapshotdates 2>/dev/null")
        snapshotDates = raw.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.contains("-") }
        return snapshotDates
    }

    /// Actiune reala - sterge DOAR itemii bifati de utilizator.
    /// `log` primeste o linie per item (panou terminal live) - fara el,
    /// `2>/dev/null` inghitea orice eroare silentios si userul nu avea nicio
    /// confirmare ca ceva chiar s-a sters (bug real, gasit 2026-08-30, port
    /// al fix-ului identic de pe Windows).
    public func deleteSelected(_ selected: Set<CleanableItem>, log: ((String) -> Void)? = nil) {
        for item in selected {
            log?("Ștergere: \(item.name)…")
            // shopt -s dotglob: `*` implicit NU prinde fisierele ascunse
            // (.DS_Store etc.) - fara el, cache-uri ascunse ar ramane
            // neatinse desi userul a bifat exact acel folder.
            let output = Shell.run("setopt dotglob 2>/dev/null; rm -rfv \"\(item.path)\"/* 2>&1 | tail -n 5")
            if !output.isEmpty { log?(output) }
            log?("  ✔ \(item.name): comandă terminată.")
        }
        scanReclaimable()
    }

    public func deleteSelectedSnapshots(_ selected: Set<String>) {
        guard !selected.isEmpty else { return }
        let dates = selected.map { "\"\($0)\"" }.joined(separator: " ")
        PrivilegedRunner.run("tmutil deletelocalsnapshots \(dates)")
        scanSnapshots()
    }

    public func purgeRAMAndFlushDNS() {
        PrivilegedRunner.run(["dscacheutil -flushcache", "killall -HUP mDNSResponder", "purge"])
    }
}
