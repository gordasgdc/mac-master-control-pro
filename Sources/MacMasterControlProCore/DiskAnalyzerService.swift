import Foundation

/// Analiză vizuală de disc, gen DaisyDisk — cerință explicită de la Cristi:
/// "să vadă fiecare folder care-i cel mai mare, cât ocupă, să se poată
/// vizualiza asemănător cu DaisyDisk". Nu reface un sunburst complet (efort
/// disproporționat față de valoarea reală) — oferă în schimb drill-down
/// pe niveluri, cu bară proporțională + listă sortată, ceea ce acoperă
/// exact întrebarea reală a userului: "ce ocupă spațiul, unde".
public struct DiskEntry: Identifiable, Hashable {
    public let id: String // calea completă
    public let name: String
    public let path: String
    public let sizeBytes: Int64
    public let isDirectory: Bool
    public var sizeDescription: String { ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file) }
}

public enum DiskAnalyzerService {
    /// O singură scanare de nivel — NICIODATĂ recursivă în Swift (Regula 21,
    /// zero acumulare în memorie): `du -x -k` face treaba grea nativ, noi
    /// doar parsăm liniile deja agregate. `-x` nu traversează în alte
    /// volume montate (ex. un folder de rețea legat simbolic), exact ca
    /// Finder — evită o scanare-surpriză a unui disc extern nelegat de
    /// cel vizat explicit.
    ///
    /// Foloseste `Shell.run` (fix 2026-09-03: citire incrementală a
    /// pipe-ului) — sigur chiar și pe un folder cu sute de mii de fișiere,
    /// fără riscul de blocare descoperit la Big File Finder.
    public static func scanLevel(_ path: String) -> [DiskEntry] {
        var entries: [DiskEntry] = []

        // Subfoldere — marime recursiva (continutul lor), o linie per folder.
        let dirsOutput = Shell.run("find \"\(path)\" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null | xargs -0 -I{} du -xsk {} 2>/dev/null")
        for line in dirsOutput.split(separator: "\n") {
            let parts = line.split(separator: "\t", maxSplits: 1)
            guard parts.count == 2, let kb = Int64(parts[0]) else { continue }
            let fullPath = String(parts[1])
            entries.append(DiskEntry(
                id: fullPath, name: (fullPath as NSString).lastPathComponent,
                path: fullPath, sizeBytes: kb * 1024, isDirectory: true
            ))
        }

        // Fisiere individuale de la acest nivel (du nu le lista separat).
        let filesOutput = Shell.run("find \"\(path)\" -mindepth 1 -maxdepth 1 -type f -exec stat -f '%z\t%N' {} \\; 2>/dev/null")
        for line in filesOutput.split(separator: "\n") {
            let parts = line.split(separator: "\t", maxSplits: 1)
            guard parts.count == 2, let bytes = Int64(parts[0]) else { continue }
            let fullPath = String(parts[1])
            entries.append(DiskEntry(
                id: fullPath, name: (fullPath as NSString).lastPathComponent,
                path: fullPath, sizeBytes: bytes, isDirectory: false
            ))
        }

        return entries.sorted { $0.sizeBytes > $1.sizeBytes }
    }

    /// Radacinile initiale oferite userului — volumul de boot + orice disc
    /// extern montat acum, la fel ca targetul Spotlight Shield existent.
    public static func availableRoots() -> [DiskEntry] {
        var roots: [DiskEntry] = []
        let bootSize = (try? URL(fileURLWithPath: "/").resourceValues(forKeys: [.volumeTotalCapacityKey]))?.volumeTotalCapacity
        roots.append(DiskEntry(id: "/", name: "Macintosh HD (volum principal)", path: "/", sizeBytes: Int64(bootSize ?? 0), isDirectory: true))

        if let volumes = try? FileManager.default.contentsOfDirectory(atPath: "/Volumes") {
            for name in volumes.sorted() {
                let path = "/Volumes/\(name)"
                let isBootAlias = (try? URL(fileURLWithPath: path).resourceValues(forKeys: [.volumeUUIDStringKey]))?.volumeUUIDString
                    == (try? URL(fileURLWithPath: "/").resourceValues(forKeys: [.volumeUUIDStringKey]))?.volumeUUIDString
                guard !isBootAlias else { continue }
                let size = (try? URL(fileURLWithPath: path).resourceValues(forKeys: [.volumeTotalCapacityKey]))?.volumeTotalCapacity ?? 0
                roots.append(DiskEntry(id: path, name: name, path: path, sizeBytes: Int64(size), isDirectory: true))
            }
        }
        return roots
    }
}
