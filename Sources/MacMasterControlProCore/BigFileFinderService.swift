import Foundation

public struct BigFile: Identifiable, Hashable {
    public let id: String // calea
    public let path: String
    public let sizeBytes: Int64
    public var sizeDescription: String { ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file) }
    public var name: String { (path as NSString).lastPathComponent }
}

/// Găsitor de fișiere mari — funcție reală din CleanMyMac ("Large & Old
/// Files"), fără scanare de sistem întreg (risc de lentoare/permisiuni) —
/// scopat la folderele unde userii chiar acumulează fișiere uitate:
/// Downloads, Desktop, Documents, Movies.
public enum BigFileFinderService {
    private static let scanRoots: [String] = [
        NSHomeDirectory() + "/Downloads",
        NSHomeDirectory() + "/Desktop",
        NSHomeDirectory() + "/Documents",
        NSHomeDirectory() + "/Movies",
    ]

    /// `find` nativ, mult mai rapid decat un enumerator Swift recursiv pe
    /// zeci de mii de fisiere (Regula 21 — evitam sa incarcam totul in
    /// memorie deodata, `find` scrie direct pe pipe, citim linie cu linie).
    public static func scan(minimumMB: Int = 200, limit: Int = 100) -> [BigFile] {
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

    public static func delete(_ files: [BigFile], log: (String) -> Void) {
        let fm = FileManager.default
        for file in files {
            let url = URL(fileURLWithPath: file.path)
            if (try? fm.trashItem(at: url, resultingItemURL: nil)) != nil {
                log("Mutat la Coșul de gunoi (\(file.sizeDescription)): \(file.path)")
            } else {
                log("EROARE, nu s-a putut șterge: \(file.path)")
            }
        }
    }
}
