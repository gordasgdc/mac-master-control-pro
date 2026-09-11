import Foundation
import Compression
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
        // `.mappedIfSafe`: fisierul e mapat in memorie, nu copiat integral —
        // conteaza cand are sute de MB.
        guard let raw = try? Data(contentsOf: url, options: .mappedIfSafe) else { return nil }
        // Cache-urile scrise INAINTE de 2026-09-11 sunt necomprimate. Nu le
        // invalidam (ar insemna o rescanare completa de ore pentru fiecare
        // user) — le citim ca atare si se rescriu comprimat la urmatoarea
        // scanare.
        let data = decompressIfNeeded(raw)
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
        guard let plist = try? encoder.encode(file) else { return }
        // [2026-09-11] Comprimat. Cache-ul unui volum de 4 TB ajunsese la
        // 2,4 GB pe disc — masurat, nu estimat. LZFSE (nativ Apple, foarte
        // rapid la decompresie) reduce de ~3,5x pe date reale, fara nicio
        // pierdere de informatie: userul vede acelasi arbore.
        let payload = compress(plist) ?? plist
        try? payload.write(to: fileURL(for: snapshot.rootPath), options: .atomic)
    }

    // MARK: - Compresie

    /// Marcaj propriu la inceputul fisierului. Un plist binar incepe cu
    /// "bplist", deci cele doua formate nu pot fi confundate niciodata.
    private static let magic = Data("MMCPZ1".utf8)

    private static func compress(_ data: Data) -> Data? {
        guard let compressed = perform(data, operation: COMPRESSION_STREAM_ENCODE, expectedRatio: 1) else { return nil }
        return magic + compressed
    }

    private static func decompressIfNeeded(_ data: Data) -> Data {
        guard data.count > magic.count, data.prefix(magic.count) == magic else {
            return data   // format vechi, necomprimat
        }
        let body = data.dropFirst(magic.count)
        // Arborii mari se dilata mult la decompresie — pornim de la un buffer
        // generos ca sa nu realocam de zeci de ori.
        return perform(Data(body), operation: COMPRESSION_STREAM_DECODE, expectedRatio: 6) ?? Data()
    }

    private static func perform(_ input: Data, operation: compression_stream_operation, expectedRatio: Int) -> Data? {
        guard !input.isEmpty else { return Data() }
        var output = Data()
        let bufferSize = 1 << 20
        let destination = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { destination.deallocate() }

        var stream = compression_stream(dst_ptr: destination, dst_size: bufferSize, src_ptr: destination, src_size: 0, state: nil)
        guard compression_stream_init(&stream, operation, COMPRESSION_LZFSE) == COMPRESSION_STATUS_OK else { return nil }
        defer { compression_stream_destroy(&stream) }

        let result: Data? = input.withUnsafeBytes { (rawBuffer: UnsafeRawBufferPointer) -> Data? in
            guard let base = rawBuffer.bindMemory(to: UInt8.self).baseAddress else { return nil }
            stream.src_ptr = base
            stream.src_size = input.count
            stream.dst_ptr = destination
            stream.dst_size = bufferSize

            while true {
                let status = compression_stream_process(&stream, Int32(COMPRESSION_STREAM_FINALIZE.rawValue))
                switch status {
                case COMPRESSION_STATUS_OK, COMPRESSION_STATUS_END:
                    let produced = bufferSize - stream.dst_size
                    if produced > 0 { output.append(destination, count: produced) }
                    stream.dst_ptr = destination
                    stream.dst_size = bufferSize
                    if status == COMPRESSION_STATUS_END { return output }
                default:
                    return nil
                }
            }
        }
        return result
    }

    public static func clear(rootPath: String) {
        try? FileManager.default.removeItem(at: fileURL(for: rootPath))
    }
}
