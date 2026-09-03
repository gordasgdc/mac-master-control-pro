import Foundation
import CryptoKit

/// Persistă/încarcă instant ultima analiză de disc completă — cerință
/// explicită de la Cristi (2026-09-04): "aplicațiile profesionale (DaisyDisk,
/// TreeSize/WizTree) nu parcurg tot discul fișier cu fișier la fiecare
/// scanare... la redeschiderea aplicației, încărcare instant din cache,
/// 0 secunde de așteptare". Un fișier de cache PER rădăcină scanată (`/`,
/// `/Volumes/X` etc.) — userul poate analiza mai multe volume, fiecare cu
/// propriul cache independent.
///
/// Format: `PropertyListEncoder` binar (rapid, compact, fără nicio
/// dependință nouă) — nu JSON text, care ar fi vizibil mai lent de
/// (de)codificat pentru un arbore cu sute de mii de noduri.
public enum DiskCacheStore {
    public struct Snapshot {
        public let rootPath: String
        public let scannedAt: Date
        public let root: DiskTreeNode

        public init(rootPath: String, scannedAt: Date, root: DiskTreeNode) {
            self.rootPath = rootPath
            self.scannedAt = scannedAt
            self.root = root
        }
    }

    private struct SnapshotFile: Codable {
        let rootPath: String
        let scannedAt: Date
        let root: DiskTreeNode
    }

    private static var cacheDirectory: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("MacMasterControlPro", isDirectory: true)
            .appendingPathComponent("DiskCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Nume de fișier stabil ÎNTRE lansări (spre deosebire de `Hashable`/
    /// `Hasher` din Swift, care randomizează sămânța per-proces special ca
    /// să prevină atacuri de hash-flooding — perfect pentru un `Dictionary`
    /// în memorie, complet nepotrivit pentru un nume de fișier persistent
    /// pe disc, care trebuie să rezolve la ACELAȘI fișier data viitoare).
    private static func fileURL(for rootPath: String) -> URL {
        let digest = SHA256.hash(data: Data(rootPath.utf8))
        let hex = digest.compactMap { String(format: "%02x", $0) }.joined().prefix(24)
        return cacheDirectory.appendingPathComponent("\(hex).mmcpdisk")
    }

    public static func load(rootPath: String) -> Snapshot? {
        let url = fileURL(for: rootPath)
        guard let data = try? Data(contentsOf: url) else { return nil }
        guard let file = try? PropertyListDecoder().decode(SnapshotFile.self, from: data) else { return nil }
        // Un cache cu alt rootPath (coliziune de hash, practic imposibilă
        // cu SHA-256, dar verificăm explicit — Regula 30, nu presupunem)
        // nu se folosește niciodată orb.
        guard file.rootPath == rootPath else { return nil }
        return Snapshot(rootPath: file.rootPath, scannedAt: file.scannedAt, root: file.root)
    }

    public static func save(_ snapshot: Snapshot) {
        let file = SnapshotFile(rootPath: snapshot.rootPath, scannedAt: snapshot.scannedAt, root: snapshot.root)
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        guard let data = try? encoder.encode(file) else { return }
        try? data.write(to: fileURL(for: snapshot.rootPath), options: .atomic)
    }

    public static func clear(rootPath: String) {
        try? FileManager.default.removeItem(at: fileURL(for: rootPath))
    }
}
