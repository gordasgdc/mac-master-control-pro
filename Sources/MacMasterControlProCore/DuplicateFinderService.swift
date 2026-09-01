import Foundation
import CryptoKit

/// Selecția de foldere pentru căutarea de duplicate — persistată local,
/// pe modelul `BigFileScanFolders`. Fără foldere implicite bifate automat
/// (spre deosebire de Fișiere mari) — o scanare de duplicate pe tot
/// Downloads/Documents poate dura mult, userul alege explicit unde caută.
public final class DuplicateScanFolders: ObservableObject {
    public static let shared = DuplicateScanFolders()

    private static let key = "mmc_duplicates_folders"

    @Published public var folders: [String]

    public init() {
        folders = (UserDefaults.standard.array(forKey: Self.key) as? [String]) ?? []
    }

    public func addFolder(_ path: String) {
        guard !folders.contains(path) else { return }
        folders.append(path)
        persist()
    }

    public func removeFolder(_ path: String) {
        folders.removeAll { $0 == path }
        persist()
    }

    private func persist() {
        UserDefaults.standard.set(folders, forKey: Self.key)
    }
}

public struct DuplicateFile: Identifiable, Hashable {
    public let id: String // calea
    public let path: String
    public let sizeBytes: Int64
    public let modifiedDate: Date?
    public var name: String { (path as NSString).lastPathComponent }
    public var sizeDescription: String { ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file) }
}

public struct DuplicateGroup: Identifiable {
    public let id: String // hash-ul de continut
    public let files: [DuplicateFile]
    public var sizeBytes: Int64 { files.first?.sizeBytes ?? 0 }
    /// Cate din bytes-ii ocupati de acest grup ar fi recuperati daca ramane
    /// un singur exemplar (toate copiile in plus).
    public var reclaimableBytes: Int64 { sizeBytes * Int64(files.count - 1) }
}

/// Găsitor de duplicate — cerință directă (Cristi, 2026-09-01): "să caute
/// duplicatele, ... să vizualizez ... înainte de a alege care vreau să
/// șterg". Grupare STRICT pe hash de conținut (SHA256), nu pe nume/dată —
/// două fișiere cu același nume și aceeași dată dar conținut diferit NU
/// apar niciodată ca duplicate una de cealaltă, garantat de hash.
public enum DuplicateFinderService {
    /// Etapa 1 (ieftină): grupează pe dimensiune — fișiere cu dimensiuni
    /// unice n-au cum să fie duplicate, eliminate fără să le citim deloc.
    /// Etapa 2 (scumpă, doar pentru grupurile rămase): hash SHA256 real.
    public static func scan(
        roots scanRoots: [String],
        minimumBytes: Int64 = 1024, // ignoram fisiere sub 1KB (goale/simboluri)
        progress: ((String) -> Void)? = nil
    ) -> [DuplicateGroup] {
        let fm = FileManager.default
        var bySize: [Int64: [String]] = [:]

        for root in scanRoots {
            guard let enumerator = fm.enumerator(
                at: URL(fileURLWithPath: root),
                includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
                options: [.skipsPackageDescendants]
            ) else { continue }
            for case let url as URL in enumerator {
                guard let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                      values.isRegularFile == true,
                      let size = values.fileSize, Int64(size) >= minimumBytes else { continue }
                bySize[Int64(size), default: []].append(url.path)
            }
        }

        var groups: [DuplicateGroup] = []
        let candidates = bySize.filter { $0.value.count > 1 }
        var done = 0
        for (_, paths) in candidates {
            var byHash: [String: [String]] = [:]
            for path in paths {
                done += 1
                progress?("Verificare (\(done)): \((path as NSString).lastPathComponent)")
                guard let hash = sha256(ofFileAt: path) else { continue }
                byHash[hash, default: []].append(path)
            }
            for (hash, samePaths) in byHash where samePaths.count > 1 {
                let files = samePaths.map { path -> DuplicateFile in
                    let attrs = try? fm.attributesOfItem(atPath: path)
                    let size = (attrs?[.size] as? Int64) ?? 0
                    let modified = attrs?[.modificationDate] as? Date
                    return DuplicateFile(id: path, path: path, sizeBytes: size, modifiedDate: modified)
                }
                groups.append(DuplicateGroup(id: hash, files: files))
            }
        }
        return groups.sorted { $0.reclaimableBytes > $1.reclaimableBytes }
    }

    /// Citit în bucăți fixe (Regula 21 — zero acumulare in memorie pe
    /// fisiere mari), nu `Data(contentsOf:)` dintr-o singura bucata.
    private static func sha256(ofFileAt path: String) -> String? {
        guard let handle = FileHandle(forReadingAtPath: path) else { return nil }
        defer { try? handle.close() }
        var hasher = SHA256()
        while autoreleasepool(invoking: {
            let chunk = handle.readData(ofLength: 8 * 1024 * 1024)
            guard !chunk.isEmpty else { return false }
            hasher.update(data: chunk)
            return true
        }) {}
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    /// Mută la Coșul de gunoi (reversibil), niciodată ștergere permanentă.
    public static func delete(_ files: [DuplicateFile], log: (String) -> Void) {
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
