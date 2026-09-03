import Foundation

/// Selecția de foldere pentru scanarea de fișiere mari — persistată local,
/// ca userul să nu trebuiască să o refacă la fiecare deschidere. Cele 4
/// foldere implicite (`BigFileFinderService.defaultRoots`) sunt bifate
/// din start, dar pot fi debifate; userul poate adăuga oricâte foldere
/// proprii (`NSOpenPanel`, alese explicit) și le poate elimina oricând.
public final class BigFileScanFolders: ObservableObject {
    public static let shared = BigFileScanFolders()

    private static let enabledDefaultsKey = "mmc_bigfiles_enabled_defaults"
    private static let customFoldersKey = "mmc_bigfiles_custom_folders"

    @Published public var enabledDefaults: Set<String>
    @Published public var customFolders: [String]

    public init() {
        let defaults = UserDefaults.standard
        if let saved = defaults.array(forKey: Self.enabledDefaultsKey) as? [String] {
            enabledDefaults = Set(saved)
        } else {
            enabledDefaults = Set(BigFileFinderService.defaultRoots) // toate bifate implicit
        }
        customFolders = (defaults.array(forKey: Self.customFoldersKey) as? [String]) ?? []
    }

    /// Folderele efectiv de scanat acum (implicite bifate + custom).
    public var activeRoots: [String] {
        BigFileFinderService.defaultRoots.filter { enabledDefaults.contains($0) } + customFolders
    }

    public func toggleDefault(_ path: String) {
        if enabledDefaults.contains(path) { enabledDefaults.remove(path) } else { enabledDefaults.insert(path) }
        persist()
    }

    public func addCustomFolder(_ path: String) {
        guard !customFolders.contains(path), !BigFileFinderService.defaultRoots.contains(path) else { return }
        customFolders.append(path)
        persist()
    }

    public func removeCustomFolder(_ path: String) {
        customFolders.removeAll { $0 == path }
        persist()
    }

    private func persist() {
        let defaults = UserDefaults.standard
        defaults.set(Array(enabledDefaults), forKey: Self.enabledDefaultsKey)
        defaults.set(customFolders, forKey: Self.customFoldersKey)
    }
}

public struct BigFile: Identifiable, Hashable {
    public let id: String // calea
    public let path: String
    public let sizeBytes: Int64
    public var sizeDescription: String { ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file) }
    public var name: String { (path as NSString).lastPathComponent }
}

/// Găsitor de fișiere mari — funcție reală din CleanMyMac ("Large & Old
/// Files"), fără scanare de sistem întreg (risc de lentoare/permisiuni).
///
/// BUG REAL/cerință (raportat de Cristi, 2026-08-31: "el se duce singur
/// în toate astea, nu pot să selectez eu ce vreau să scanez") — folderele
/// erau hardcodate (Downloads/Desktop/Documents/Movies), fără nicio
/// posibilitate de a alege altele sau de a exclude unele. `defaultRoots`
/// rămân sugestia inițială (bifate implicit), dar `scan(roots:)` acceptă
/// acum orice listă aleasă explicit de user — vezi `BigFileScanFolders`
/// (persistă selecția + folderele custom adăugate).
public enum BigFileFinderService {
    public static let defaultRoots: [String] = [
        NSHomeDirectory() + "/Downloads",
        NSHomeDirectory() + "/Desktop",
        NSHomeDirectory() + "/Documents",
        NSHomeDirectory() + "/Movies",
    ]

    /// `find` nativ, mult mai rapid decat un enumerator Swift recursiv pe
    /// zeci de mii de fisiere (Regula 21 — evitam sa incarcam totul in
    /// memorie deodata, `find` scrie direct pe pipe, citim linie cu linie).
    public static func scan(roots scanRoots: [String], minimumMB: Int = 200, limit: Int = 100) -> [BigFile] {
        let minimumBytes = minimumMB * 1024 * 1024
        let roots = scanRoots.filter { FileManager.default.fileExists(atPath: $0) }
            .map { "\"\($0)\"" }.joined(separator: " ")
        guard !roots.isEmpty else { return [] }
        let output = Shell.run("find \(roots) -type f -size +\(minimumMB)M -exec stat -f '%z\t%N' {} \\; 2>/dev/null | sort -rn | head -n \(limit)")
        return output.split(separator: "\n").compactMap { line -> BigFile? in
            let parts = line.split(separator: "\t", maxSplits: 1)
            guard parts.count == 2, let bytes = Int64(parts[0]), bytes >= minimumBytes else { return nil }
            return BigFile(id: String(parts[1]), path: String(parts[1]), sizeBytes: bytes)
        }
    }

    /// [2026-09-03] Foloseste `PrivilegedFileOps` (extras din fix-ul de
    /// dezinstalare) - cade automat pe stergere privilegiata daca fisierul
    /// e detinut de root/alt user, in loc sa raporteze doar "EROARE" fara
    /// nicio cale de rezolvare pentru user.
    public static func delete(_ files: [BigFile], log: (String) -> Void) {
        for file in files {
            if let error = PrivilegedFileOps.delete(file.path) {
                log("EROARE, nu s-a putut șterge \(file.path): \(error)")
            } else {
                log("Mutat/șters (\(file.sizeDescription)): \(file.path)")
            }
        }
    }
}
