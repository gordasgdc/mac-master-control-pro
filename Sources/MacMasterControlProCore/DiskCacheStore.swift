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
        /// Foldere/fisiere ce n-au putut fi citite la ultima scanare (0 = complet).
        public let accessErrors: Int
        /// Data ultimei verificari la nivel de fisier (scanare completa sau incrementala verificata).
        public let verifiedAt: Date?
        /// Primele căi neanalizate (eșantion), pentru detalii.
        public let accessSamples: [String]

        public init(rootPath: String, scannedAt: Date, root: DiskTreeNode, accessErrors: Int = 0, verifiedAt: Date? = nil, accessSamples: [String] = []) {
            self.accessSamples = accessSamples
            self.rootPath = rootPath
            self.scannedAt = scannedAt
            self.root = root
            self.accessErrors = accessErrors
            self.verifiedAt = verifiedAt
        }
    }

    private struct SnapshotFile: Codable {
        let rootPath: String
        let scannedAt: Date
        let root: DiskTreeNode
        var accessErrors: Int?
        var verifiedAt: Date?
        var volumeUUID: String?
        /// Versiunea măsurătorii: 2 = spațiu alocat (`st_blocks`) ca măsură principală + eșantion de căi neanalizate. Cache-urile mai vechi se resping (rescanare).
        var measureVersion: Int?
        var accessSamples: [String]?
    }
    static let currentMeasureVersion = 2

    /// UUID-ul volumului pe care se afla `path` (None daca nu se poate determina).
    static func volumeUUID(of path: String) -> String? {
        try? URL(fileURLWithPath: path).resourceValues(forKeys: [.volumeUUIDStringKey]).volumeUUIDString
    }

    private static var cacheDirectory: URL {
        let dir = AppProfile.supportDirectory.appendingPathComponent("DiskCache", isDirectory: true)
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
        // Măsurătoare veche (mărime logică ca „spațiu ocupat”, fără spațiul alocat corect): cache-ul ar induce în eroare (ex. un fișier sparse de 8,8 TB
        // alocat 6,7 MB). Se respinge controlat, iar următoarea analiză îl rescrie cu măsura corectă.
        guard (file.measureVersion ?? 0) >= currentMeasureVersion else {
            DiagnosticLog.write(.info, tag: "disk", event: "cache.old-measure-rejected")
            return nil
        }
        // Alt volum montat la aceeasi cale (disc extern inlocuit): cache-ul ar minti, nu se foloseste.
        if let saved = file.volumeUUID, let now = volumeUUID(of: rootPath), saved != now {
            DiagnosticLog.write(.warning, tag: "disk", event: "cache.volume-mismatch")
            return nil
        }
        return Snapshot(rootPath: file.rootPath, scannedAt: file.scannedAt, root: file.root,
                        accessErrors: file.accessErrors ?? 0, verifiedAt: file.verifiedAt, accessSamples: file.accessSamples ?? [])
    }

    public static func save(_ snapshot: Snapshot) {
        let file = SnapshotFile(rootPath: snapshot.rootPath, scannedAt: snapshot.scannedAt, root: snapshot.root,
                                accessErrors: snapshot.accessErrors, verifiedAt: snapshot.verifiedAt,
                                volumeUUID: volumeUUID(of: snapshot.rootPath), measureVersion: currentMeasureVersion, accessSamples: snapshot.accessSamples)
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        guard let plist = try? encoder.encode(file) else {
            DiagnosticLog.write(.error, tag: "disk", event: "cache.encode-failed"); return
        }
        // [2026-09-11] Comprimat. Cache-ul unui volum de 4 TB ajunsese la
        // 2,4 GB pe disc — masurat, nu estimat. LZFSE (nativ Apple, foarte
        // rapid la decompresie) reduce de ~3,5x pe date reale, fara nicio
        // pierdere de informatie: userul vede acelasi arbore.
        let payload = compress(plist) ?? plist
        do { try payload.write(to: fileURL(for: snapshot.rootPath), options: .atomic) }
        catch { DiagnosticLog.write(.error, tag: "disk", event: "cache.write-failed", message: error.localizedDescription) }
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
