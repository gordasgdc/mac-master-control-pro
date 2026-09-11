import Foundation
import CryptoKit

// MARK: - Scanare de duplicate: actor asincron, fara acumulare (2026-09-11)
//
// Inlocuieste `DuplicateFinderService.scan` (sincron, blocant). Cele patru
// defecte reale gasite la audit, fiecare cu fixul lui aici:
//
// 1. CRASH pe volume mari. Varianta veche construia `[Int64: [String]]` cu
//    TOATE caile inainte de orice hashing — pe 1,44 TB inseamna sute de mii
//    de String-uri vii simultan. (Acelasi fisier cita Regula 21 pentru
//    hashing, corect, dar o incalca la enumerare.) Acum: doua treceri, iar
//    prima retine doar un CONTOR per dimensiune, nu caile.
// 2. Hash COMPLET pe fiecare candidat — pe fisiere video de zeci de GB citea
//    terabytes degeaba. Acum: cascada dimensiune -> primii 64 KB -> complet.
// 3. Fara anulare. Acum: `Task.checkCancellation()` intre fisiere.
// 4. Rezultatele traiau in `@State` pe View si se pierdeau la schimbarea
//    tab-ului. Rezolvat in DuplicateFinderViewModel (singleton).

public struct DuplicateScanProgress: Sendable {
    public enum Phase: Sendable {
        case enumerating        // numar fisierele; nu stiu inca totalul
        case prefiltering       // hash pe primii 64 KB
        case hashing            // hash complet, doar candidatii ramasi
        case finished

        public var label: String {
            switch self {
            case .enumerating: return "Caut fișiere…"
            case .prefiltering: return "Compar rapid conținutul…"
            case .hashing: return "Verific fișierele identice…"
            case .finished: return "Gata"
            }
        }
    }

    public let phase: Phase
    public let filesSeen: Int
    public let currentPath: String
    public let bytesFound: Int64
    /// `nil` in faza de enumerare — nu se stie totalul, deci arcul pulseaza
    /// in loc sa minta cu un procent inventat.
    public let fraction: Double?

    public init(phase: Phase, filesSeen: Int = 0, currentPath: String = "", bytesFound: Int64 = 0, fraction: Double? = nil) {
        self.phase = phase
        self.filesSeen = filesSeen
        self.currentPath = currentPath
        self.bytesFound = bytesFound
        self.fraction = fraction
    }
}

public enum DuplicateScanEvent: Sendable {
    case progress(DuplicateScanProgress)
    case group(DuplicateGroup)
    case finished(totalReclaimable: Int64)
    case failed(String)
}

/// Limitator de rată pentru evenimentele de progres.
///
/// [FIX 2026-09-11] Cauza rotiței de așteptare raportate de Cristi: în faza de
/// hashing se emitea un eveniment la FIECARE fișier. Fiecare traversează spre
/// ViewModel-ul `@MainActor`, atinge un `@Published` și declanșează o
/// redesenare SwiftUI — pe zeci de mii de fișiere înseamnă mii de redesenări
/// pe secundă, iar main thread-ul se sufocă. Scanarea chiar rula în fundal,
/// corect; ceea ce bloca UI-ul era RAPORTAREA ei.
///
/// 10 actualizări pe secundă sunt peste ce percepe ochiul ca „live", la o
/// fracțiune din cost. Evenimentele de tip `.group` și `.finished` NU se
/// limitează niciodată — acelea poartă rezultate, nu progres.
private struct EmitThrottle {
    private var last: TimeInterval = 0
    private let minimumInterval: TimeInterval = 0.1

    mutating func shouldEmit(force: Bool = false) -> Bool {
        let now = ProcessInfo.processInfo.systemUptime
        guard !force else { last = now; return true }
        guard now - last >= minimumInterval else { return false }
        last = now
        return true
    }
}

public actor DuplicateScanService {
    public static let shared = DuplicateScanService()

    private var currentTask: Task<Void, Never>?

    public init() {}

    public func cancel() {
        currentTask?.cancel()
        currentTask = nil
    }

    public var isRunning: Bool { currentTask != nil && !(currentTask?.isCancelled ?? true) }

    /// Fluxul de evenimente al unei scanari. Consumatorul (ViewModel) itereaza
    /// `for await` — nicio stare comuna mutabila intre actor si UI.
    public func scan(roots: [String], minimumBytes: Int64 = 1024) -> AsyncStream<DuplicateScanEvent> {
        AsyncStream { continuation in
            let task = Task.detached(priority: .utility) {
                do {
                    try await Self.run(roots: roots, minimumBytes: minimumBytes, emit: { continuation.yield($0) })
                } catch is CancellationError {
                    // Anulare ceruta de user — nu e o eroare de raportat.
                } catch {
                    continuation.yield(.failed(error.localizedDescription))
                }
                continuation.finish()
            }
            self.currentTask = Task { await task.value }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Motorul

    private static func run(roots: [String], minimumBytes: Int64, emit: @Sendable (DuplicateScanEvent) -> Void) async throws {
        // ---- TRECEREA 1: doar contorizam dimensiunile. -------------------
        // Cheia optimizarii de memorie: aici NU retinem nicio cale. Un Int64
        // + un Int per dimensiune distincta, oricat de multe fisiere ar fi.
        var throttle = EmitThrottle()
        var countBySize: [Int64: Int] = [:]
        var seen = 0
        var totalBytes: Int64 = 0

        for root in roots {
            try forEachFile(in: root, minimumBytes: minimumBytes) { path, size in
                countBySize[size, default: 0] += 1
                seen += 1
                totalBytes += size
                if seen % 500 == 0, throttle.shouldEmit() {
                    emit(.progress(DuplicateScanProgress(
                        phase: .enumerating, filesSeen: seen,
                        currentPath: path, bytesFound: totalBytes, fraction: nil)))
                }
            }
        }

        // Dimensiunile unice nu pot avea duplicate — eliminate fara nicio
        // citire de continut.
        let duplicateSizes = Set(countBySize.filter { $0.value > 1 }.keys)
        countBySize.removeAll(keepingCapacity: false)
        guard !duplicateSizes.isEmpty else {
            emit(.finished(totalReclaimable: 0)); return
        }

        // ---- TRECEREA 2: retinem DOAR candidatii reali. ------------------
        var bySize: [Int64: [String]] = [:]
        for root in roots {
            try forEachFile(in: root, minimumBytes: minimumBytes) { path, size in
                guard duplicateSizes.contains(size) else { return }
                bySize[size, default: []].append(path)
            }
        }

        let candidateGroups = bySize.values.filter { $0.count > 1 }
        bySize.removeAll(keepingCapacity: false)
        let totalCandidates = candidateGroups.reduce(0) { $0 + $1.count }
        var processed = 0
        var totalReclaimable: Int64 = 0

        // Pe un disc extern rotativ, mai multe fire de I/O simultane
        // INCETINESC (capul fizic sare intre zone). Pe SSD intern, paralelismul
        // ajuta. Nu presupunem — citim tipul volumului.
        let lanes = ioLaneCount(for: roots)

        for paths in candidateGroups {
            try Task.checkCancellation()

            // ---- Etapa A: hash pe primii 64 KB. --------------------------
            // Aici se castiga grosul timpului: doua fisiere video de 40 GB cu
            // aceeasi dimensiune dar continut diferit se despart citind 64 KB
            // fiecare, nu 80 GB. Varianta veche le citea integral pe amandoua.
            var byPrefix: [String: [String]] = [:]
            try await withLimitedTaskGroup(paths, lanes: lanes) { path in
                let h = Self.hash(ofFileAt: path, maxBytes: 64 * 1024)
                return (path, h)
            } handle: { path, hash in
                processed += 1
                if let hash { byPrefix[hash, default: []].append(path) }
                if processed % 25 == 0, throttle.shouldEmit() {
                    emit(.progress(DuplicateScanProgress(
                        phase: .prefiltering, filesSeen: processed,
                        currentPath: path, bytesFound: totalBytes,
                        fraction: totalCandidates > 0 ? Double(processed) / Double(totalCandidates) : nil)))
                }
            }

            // ---- Etapa B: hash complet, doar pentru cei ramasi. ----------
            for (_, samePrefix) in byPrefix where samePrefix.count > 1 {
                try Task.checkCancellation()
                var byFull: [String: [String]] = [:]
                try await withLimitedTaskGroup(samePrefix, lanes: lanes) { path in
                    let h = Self.hash(ofFileAt: path, maxBytes: nil)
                    return (path, h)
                } handle: { path, hash in
                    if let hash { byFull[hash, default: []].append(path) }
                    // Limitat: altfel un grup cu mii de candidati inunda
                    // MainActor-ul cu redesenari si blocheaza UI-ul.
                    if throttle.shouldEmit() {
                        emit(.progress(DuplicateScanProgress(
                            phase: .hashing, filesSeen: processed,
                            currentPath: path, bytesFound: totalBytes,
                            fraction: totalCandidates > 0 ? Double(processed) / Double(totalCandidates) : nil)))
                    }
                }

                for (hash, dupes) in byFull where dupes.count > 1 {
                    let files = dupes.map { Self.describe($0) }
                    let group = DuplicateGroup(id: hash, files: files)
                    totalReclaimable += group.reclaimableBytes
                    // Grupul pleaca spre UI IMEDIAT si nu mai e retinut aici —
                    // userul vede rezultate pe masura ce apar, iar memoria
                    // ramane plafonata indiferent de cate duplicate exista.
                    emit(.group(group))
                }
                byFull.removeAll(keepingCapacity: false)
            }
            byPrefix.removeAll(keepingCapacity: false)
        }

        emit(.progress(DuplicateScanProgress(phase: .finished, filesSeen: processed, bytesFound: totalBytes, fraction: 1)))
        emit(.finished(totalReclaimable: totalReclaimable))
    }

    // MARK: - Ajutoare

    /// Enumerare prin `FileManager`, dar FARA sa construiasca vreo lista —
    /// fiecare fisier e predat imediat si uitat (Regula 21).
    /// Sincrona, nu `async`: `DirectoryEnumerator` se itereaza prin
    /// `makeIterator()`, indisponibil din context asincron (eroare in Swift 6).
    /// Ruleaza oricum intr-un `Task.detached`, deci blocheaza doar acel task,
    /// niciodata UI-ul. `Task.checkCancellation()` e sincron, deci anularea
    /// functioneaza neschimbat.
    private static func forEachFile(in root: String, minimumBytes: Int64, _ body: (String, Int64) throws -> Void) throws {
        let fm = FileManager.default
        guard let e = fm.enumerator(
            at: URL(fileURLWithPath: root),
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsPackageDescendants, .skipsHiddenFiles]
        ) else { return }

        var sinceCheck = 0
        while let url = e.nextObject() as? URL {
            sinceCheck += 1
            if sinceCheck >= 200 { try Task.checkCancellation(); sinceCheck = 0 }
            try autoreleasepool {
                guard let v = try? url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                      v.isRegularFile == true,
                      let size = v.fileSize, Int64(size) >= minimumBytes else { return }
                try body(url.path, Int64(size))
            }
        }
    }

    /// `TaskGroup` cu numar MARGINIT de sarcini simultane. Fara plafon, un grup
    /// cu 10.000 de candidati ar porni 10.000 de task-uri deodata — exact
    /// tiparul care umple memoria si satureaza discul.
    private static func withLimitedTaskGroup(
        _ items: [String],
        lanes: Int,
        work: @escaping @Sendable (String) -> (String, String?),
        handle: (String, String?) throws -> Void
    ) async throws {
        // Index simplu, nu `makeIterator()`: acesta din urma e indisponibil
        // din context async (devine eroare in Swift 6).
        var next = 0
        try await withThrowingTaskGroup(of: (String, String?).self) { group in
            while next < items.count && next < lanes {
                let item = items[next]; next += 1
                group.addTask { work(item) }
            }
            while let (path, hash) = try await group.next() {
                try handle(path, hash)
                try Task.checkCancellation()
                if next < items.count {
                    let item = items[next]; next += 1
                    group.addTask { work(item) }
                }
            }
        }
    }

    /// Hash pe bucati fixe (Regula 21). `maxBytes == nil` = fisier intreg.
    private static func hash(ofFileAt path: String, maxBytes: Int?) -> String? {
        guard let handle = FileHandle(forReadingAtPath: path) else { return nil }
        defer { try? handle.close() }
        var hasher = SHA256()
        var remaining = maxBytes ?? Int.max
        let chunkSize = 4 * 1024 * 1024
        while remaining > 0 {
            let want = min(chunkSize, remaining)
            let stop = autoreleasepool { () -> Bool in
                guard let chunk = try? handle.read(upToCount: want), !chunk.isEmpty else { return true }
                hasher.update(data: chunk)
                remaining -= chunk.count
                return false
            }
            if stop { break }
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private static func describe(_ path: String) -> DuplicateFile {
        let attrs = try? FileManager.default.attributesOfItem(atPath: path)
        return DuplicateFile(
            id: path, path: path,
            sizeBytes: (attrs?[.size] as? Int64) ?? 0,
            modifiedDate: attrs?[.modificationDate] as? Date
        )
    }

    /// Cate citiri simultane are sens pe volumul dat. Un HDD extern rotativ
    /// pierde timp cu miscarea capului daca il ataci din 10 fire deodata;
    /// un SSD intern profita de paralelism.
    private static func ioLaneCount(for roots: [String]) -> Int {
        let anyExternal = roots.contains { root in
            let v = try? URL(fileURLWithPath: root).resourceValues(forKeys: [.volumeIsInternalKey])
            return v?.volumeIsInternal == false
        }
        return anyExternal ? 4 : max(2, min(8, ProcessInfo.processInfo.activeProcessorCount))
    }
}
