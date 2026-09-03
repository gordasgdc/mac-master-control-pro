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
