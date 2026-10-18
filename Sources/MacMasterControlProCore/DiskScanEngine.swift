import Foundation
import Darwin

/// Motor de analiză disc (nativ, fără shell).
///
/// **Scanare completă** (`buildTree`): parcurgere paralelă pe subfolderele de prim nivel, cu
/// `opendir`/`readdir`/`fstatat(AT_SYMLINK_NOFOLLOW)` (o singură trecere dă nume, tip, mărime
/// logică, spațiu alocat și mtime-ul în nanosecunde). Nu se traversează legături simbolice și nu
/// se trece pe alt volum (mount points sunt omise, ca `find -x`).
///
/// **Actualizare incrementală** (`incrementalUpdate`), două moduri:
/// - `.verified` (implicit): relistează FIECARE folder și compară amprenta fișierelor lui directe
///   (nume + mărime + alocat + mtime ns) cu cea din cache. Detectează adăugare, ștergere, redenumire
///   ȘI modificarea în-loc a oricărui fișier, la orice adâncime. Costul este un `lstat` per fișier
///   (aproximativ cât o scanare completă fără reconstruirea arborelui).
/// - `.structureOnly`: compară doar mtime-ul folderelor. Rapid, dar NU vede o modificare în-loc
///   (scrierea într-un fișier existent nu schimbă mtime-ul folderului). Doar pentru măsurători/diagnostic.
///
/// Un cache sau o scanare nu se acceptă niciodată dacă rădăcina a dispărut sau a fost înlocuită cu alt
/// volum (`ScanOutcome.rootUnavailable`); anularea întoarce `cancelled` iar apelantul NU salvează.
public enum DiskScanEngine {
    public struct Progress {
        public let filesIndexed: Int
        public let bytesIndexed: Int64
        public let accessErrors: Int
    }

    public struct ScanOutcome {
        public enum Status { case complete, cancelled, rootUnavailable }
        public let status: Status
        /// Foldere/fișiere care n-au putut fi citite (permisiuni, I/O). Rezultatul e util dar nu complet.
        public let accessErrors: Int
        /// Primele căi neanalizate (cel mult 400), pentru explicație și detalii; restul doar în contor.
        public let accessSamples: [String]
        public init(status: Status, accessErrors: Int, accessSamples: [String] = []) { self.status = status; self.accessErrors = accessErrors; self.accessSamples = accessSamples }
        public var isCleanAndComplete: Bool { status == .complete && accessErrors == 0 }
    }

    public enum IncrementalMode { case verified, structureOnly }

    private struct Entry {
        let name: String
        let isDirectory: Bool
        let size: Int64
        let allocated: Int64
        let mtimeNs: Int64
    }

    private struct Listing {
        let entries: [Entry]
        let dirMTime: Double
        let errors: Int
        let errorPaths: [String]
    }

    /// Acumulator de progres thread-safe; raportează în loturi, nu per-fișier.
    private final class ProgressCounter {
        private let lock = NSLock()
        private(set) var files = 0
        private(set) var bytes: Int64 = 0
        private(set) var accessErrors = 0
        private(set) var samples: [String] = []
        private var lastReportedAt = Date()
        func noteAccessError(_ n: Int = 1, paths: [String] = []) {
            lock.lock(); accessErrors += n
            for p in paths where samples.count < 400 { samples.append(p) }
            lock.unlock()
        }
        func add(files deltaFiles: Int, bytes deltaBytes: Int64, onProgress: @escaping (Progress) -> Void) {
            lock.lock()
            files += deltaFiles
            bytes += deltaBytes
            let now = Date()
            let due = now.timeIntervalSince(lastReportedAt) >= 1
            let snapshot = Progress(filesIndexed: files, bytesIndexed: bytes, accessErrors: accessErrors)
            if due { lastReportedAt = now }
            lock.unlock()
            if due { DispatchQueue.main.async { onProgress(snapshot) } }
        }
        var snapshot: Progress {
            lock.lock(); defer { lock.unlock() }
            return Progress(filesIndexed: files, bytesIndexed: bytes, accessErrors: accessErrors)
        }
    }

    // MARK: - Anulare

    private static let cancelLock = NSLock()
    nonisolated(unsafe) private static var _cancelRequested = false

    public static var isCancelled: Bool {
        cancelLock.lock(); defer { cancelLock.unlock() }
        return _cancelRequested
    }
    public static func requestCancel() { cancelLock.lock(); _cancelRequested = true; cancelLock.unlock() }
    private static func clearCancel() { cancelLock.lock(); _cancelRequested = false; cancelLock.unlock() }

    // MARK: - Scanare completă

    public static func buildTree(root: String, onProgress: @escaping (Progress) -> Void,
                                 completion: @escaping (DiskTreeNode, ScanOutcome) -> Void) {
        clearCancel()
        let op = DiagnosticLog.begin("disk", "scan.full")
        DispatchQueue.global(qos: .userInitiated).async {
            let resolvedRoot = URL(fileURLWithPath: root).resolvingSymlinksInPath().path
            let rootNode = DiskTreeNode(name: (resolvedRoot as NSString).lastPathComponent, path: resolvedRoot, isDirectory: true)
            guard let rootDev = deviceID(resolvedRoot) else {
                op.end("rootUnavailable", level: .warning)
                DispatchQueue.main.async { completion(rootNode, ScanOutcome(status: .rootUnavailable, accessErrors: 0)) }
                return
            }
            let counter = ProgressCounter()
            populate(node: rootNode, rootDev: rootDev, counter: counter, onProgress: onProgress, parallel: true)

            let rootStillThere = deviceID(resolvedRoot) == rootDev
            let status: ScanOutcome.Status = isCancelled ? .cancelled : (rootStillThere ? .complete : .rootUnavailable)
            let outcome = ScanOutcome(status: status, accessErrors: counter.accessErrors, accessSamples: counter.samples)
            let final = counter.snapshot
            op.end("\(status)", level: status == .complete ? .info : .warning,
                   fields: ["files": String(final.filesIndexed), "bytes": String(final.bytesIndexed),
                            "accessErrors": String(final.accessErrors)])
            DispatchQueue.main.async {
                onProgress(final)
                completion(rootNode, outcome)
            }
        }
    }

    /// Listează `node.path`, construiește fișierele directe, apoi subfolderele (paralel dacă `parallel`).
    private static func populate(node: DiskTreeNode, rootDev: dev_t, counter: ProgressCounter,
                                 onProgress: @escaping (Progress) -> Void, parallel: Bool) {
        if isCancelled { return }
        guard let listing = listDirectory(node.path, rootDev: rootDev) else {
            counter.noteAccessError(paths: [node.path])
            return
        }
        counter.noteAccessError(listing.errors, paths: listing.errorPaths)
        node.directoryModifiedAt = listing.dirMTime
        applyFiles(of: listing, to: node, collapse: false)
        reportFiles(listing, counter, onProgress)

        let dirs = listing.entries.filter { $0.isDirectory }
        var built = [DiskTreeNode?](repeating: nil, count: dirs.count)
        let lock = NSLock()
        let work: (Int) -> Void = { i in
            let e = dirs[i]
            let child = DiskTreeNode(name: e.name, path: node.path + (node.path.hasSuffix("/") ? "" : "/") + e.name, isDirectory: true)
            populate(node: child, rootDev: rootDev, counter: counter, onProgress: onProgress, parallel: false)
            lock.lock(); built[i] = child; lock.unlock()
        }
        if parallel { DispatchQueue.concurrentPerform(iterations: dirs.count, execute: work) }
        else { for i in 0..<dirs.count { work(i) } }
        for case let child? in built { node.children[child.name] = child }
        sumChildren(node)
    }

    // MARK: - Actualizare incrementală

    /// Reutilizează arborele din cache. În `.verified` rezultatul este identic cu o scanare completă.
    /// Nu salva rezultatul decât dacă `outcome.status == .complete`; la `cancelled` arborele primit poate fi
    /// parțial actualizat (reîncarcă din cache), la `rootUnavailable` nu a fost modificat.
    public static func incrementalUpdate(cachedRoot: DiskTreeNode, mode: IncrementalMode = .verified,
                                         onProgress: @escaping (Progress) -> Void,
                                         completion: @escaping (DiskTreeNode, ScanOutcome) -> Void) {
        clearCancel()
        let op = DiagnosticLog.begin("disk", "scan.incremental", fields: ["mode": "\(mode)"])
        DispatchQueue.global(qos: .userInitiated).async {
            guard let rootDev = deviceID(cachedRoot.path) else {
                op.end("rootUnavailable", level: .warning)
                DispatchQueue.main.async { completion(cachedRoot, ScanOutcome(status: .rootUnavailable, accessErrors: 0)) }
                return
            }
            let counter = ProgressCounter()
            refresh(node: cachedRoot, rootDev: rootDev, mode: mode, counter: counter, onProgress: onProgress, parallel: true)

            let rootStillThere = deviceID(cachedRoot.path) == rootDev
            let status: ScanOutcome.Status = isCancelled ? .cancelled : (rootStillThere ? .complete : .rootUnavailable)
            let final = counter.snapshot
            op.end("\(status)", level: status == .complete ? .info : .warning,
                   fields: ["changedFiles": String(final.filesIndexed), "accessErrors": String(final.accessErrors)])
            DispatchQueue.main.async {
                onProgress(final)
                completion(cachedRoot, ScanOutcome(status: status, accessErrors: final.accessErrors, accessSamples: counter.samples))
            }
        }
    }

    private static func refresh(node: DiskTreeNode, rootDev: dev_t, mode: IncrementalMode, counter: ProgressCounter,
                                onProgress: @escaping (Progress) -> Void, parallel: Bool) {
        if isCancelled { return }

        if mode == .structureOnly, node.filesFingerprint != 0,
           let m = directoryMTime(node.path), m == node.directoryModifiedAt {
            for child in node.children.values where child.isDirectory {
                refresh(node: child, rootDev: rootDev, mode: mode, counter: counter, onProgress: onProgress, parallel: false)
            }
            sumChildren(node)
            return
        }

        guard let listing = listDirectory(node.path, rootDev: rootDev) else {
            // Inaccesibil acum: păstrăm subarborele din cache (nu îl declarăm gol) și semnalăm eroarea.
            counter.noteAccessError(paths: [node.path])
            return
        }
        counter.noteAccessError(listing.errors, paths: listing.errorPaths)
        node.directoryModifiedAt = listing.dirMTime

        // Fișiere directe: amprentă diferită => reconstruim doar fișierele acestui folder.
        if fingerprint(of: listing.entries) != node.filesFingerprint {
            applyFiles(of: listing, to: node, collapse: true)
            reportFiles(listing, counter, onProgress)
        }

        // Subfoldere: scoatem ce a dispărut sau și-a schimbat tipul; reîmprospătăm ce există; scanăm ce e nou.
        let liveDirs = listing.entries.filter { $0.isDirectory }
        let liveNames = Set(liveDirs.map { $0.name })
        for (name, child) in node.children where child.isDirectory && !liveNames.contains(name) {
            node.children.removeValue(forKey: name)
        }
        var existing: [DiskTreeNode] = []
        var fresh: [DiskTreeNode] = []
        for e in liveDirs {
            if let c = node.children[e.name], c.isDirectory { existing.append(c) }
            else {
                node.children.removeValue(forKey: e.name)
                fresh.append(DiskTreeNode(name: e.name, path: node.path + (node.path.hasSuffix("/") ? "" : "/") + e.name, isDirectory: true))
            }
        }
        let total = existing.count + fresh.count
        let work: (Int) -> Void = { i in
            if i < existing.count {
                refresh(node: existing[i], rootDev: rootDev, mode: mode, counter: counter, onProgress: onProgress, parallel: false)
            } else {
                let n = fresh[i - existing.count]
                populate(node: n, rootDev: rootDev, counter: counter, onProgress: onProgress, parallel: false)
                _ = n.collapseSmallFiles()
            }
        }
        if parallel { DispatchQueue.concurrentPerform(iterations: total, execute: work) }
        else { for i in 0..<total { work(i) } }
        for n in fresh { node.children[n.name] = n }
        sumChildren(node)
    }

    // MARK: - Construcție / agregare

    /// Înlocuiește fișierele directe ale nodului cu cele din listare; fixează amprenta.
    private static func applyFiles(of listing: Listing, to node: DiskTreeNode, collapse: Bool) {
        for (name, child) in node.children where !child.isDirectory { node.children.removeValue(forKey: name) }
        let base = node.path.hasSuffix("/") ? node.path : node.path + "/"
        for e in listing.entries where !e.isDirectory {
            let f = DiskTreeNode(name: e.name, path: base + e.name, isDirectory: false)
            f.sizeBytes = e.size
            f.allocatedBytes = e.allocated
            f.modifiedAtNs = e.mtimeNs
            node.children[e.name] = f
        }
        node.filesFingerprint = fingerprint(of: listing.entries)
        if collapse { _ = node.collapseSmallFiles(recursive: false) }
    }

    private static func reportFiles(_ listing: Listing, _ counter: ProgressCounter, _ onProgress: @escaping (Progress) -> Void) {
        var n = 0; var bytes: Int64 = 0
        for e in listing.entries where !e.isDirectory { n += 1; bytes += e.allocated }
        if n > 0 { counter.add(files: n, bytes: bytes, onProgress: onProgress) }
    }

    private static func sumChildren(_ node: DiskTreeNode) {
        var s: Int64 = 0, a: Int64 = 0
        for c in node.children.values { s += c.sizeBytes; a += c.allocatedBytes }
        node.sizeBytes = s
        node.allocatedBytes = a
    }

    /// FNV-1a 64 peste fișierele sortate după nume (nume, mărime, alocat, mtime ns). Niciodată 0.
    private static func fingerprint(of entries: [Entry]) -> Int64 {
        var h: UInt64 = 0xcbf29ce484222325
        @inline(__always) func mix(_ v: UInt64) { h = (h ^ v) &* 0x100000001b3 }
        let files = entries.filter { !$0.isDirectory }.sorted { $0.name < $1.name }
        for f in files {
            for b in f.name.utf8 { mix(UInt64(b)) }
            mix(0xFF)
            mix(UInt64(bitPattern: f.size)); mix(UInt64(bitPattern: f.allocated)); mix(UInt64(bitPattern: f.mtimeNs))
        }
        mix(UInt64(files.count))
        let v = Int64(bitPattern: h)
        return v == 0 ? 1 : v
    }

    // MARK: - Ștergere (actualizează arborele fără rescanare)

    public static func remove(nodePath: String, from root: DiskTreeNode) {
        guard nodePath.hasPrefix(root.path) else { return }
        let rootPrefix = root.path.hasSuffix("/") ? root.path : root.path + "/"
        guard nodePath.hasPrefix(rootPrefix) else { return }
        let components = nodePath.dropFirst(rootPrefix.count).split(separator: "/").map(String.init)
        guard !components.isEmpty else { return }

        var chain: [DiskTreeNode] = [root]
        var current = root
        for component in components {
            guard let child = current.children[component] else { return }
            chain.append(child)
            current = child
        }
        let removedSize = current.sizeBytes
        let removedAllocated = current.allocatedBytes
        for ancestor in chain.dropLast() {
            ancestor.sizeBytes -= removedSize
            ancestor.allocatedBytes -= removedAllocated
        }
        if let parent = chain.dropLast().last, let last = components.last {
            parent.children.removeValue(forKey: last)
            // Amprenta fișierelor directe nu mai corespunde discului: la următoarea verificare folderul se recitește.
            parent.filesFingerprint = 0
        }
    }

    // MARK: - Helpers native

    private static func deviceID(_ path: String) -> dev_t? {
        var st = stat()
        guard stat(path, &st) == 0, (st.st_mode & S_IFMT) == S_IFDIR else { return nil }
        return st.st_dev
    }

    private static func directoryMTime(_ path: String) -> Double? {
        var st = stat()
        guard stat(path, &st) == 0 else { return nil }
        return Double(st.st_mtimespec.tv_sec) + Double(st.st_mtimespec.tv_nsec) / 1_000_000_000
    }

    /// Un nivel de director. `nil` doar dacă folderul nu poate fi deschis. Omite: legături simbolice,
    /// fișiere speciale, mount points (alt `st_dev`). Erorile pe intrări individuale se numără în `errors`.
    private static func listDirectory(_ path: String, rootDev: dev_t) -> Listing? {
        guard let dir = opendir(path) else { return nil }
        defer { closedir(dir) }
        let fd = dirfd(dir)
        var dst = stat()
        let dirMTime = fstat(fd, &dst) == 0
            ? Double(dst.st_mtimespec.tv_sec) + Double(dst.st_mtimespec.tv_nsec) / 1_000_000_000 : 0
        var entries: [Entry] = []
        var errors = 0
        var errorPaths: [String] = []
        while let ent = readdir(dir) {
            let name = withUnsafePointer(to: &ent.pointee.d_name) {
                $0.withMemoryRebound(to: CChar.self, capacity: Int(ent.pointee.d_namlen) + 1) { String(cString: $0) }
            }
            if name == "." || name == ".." { continue }
            var st = stat()
            guard fstatat(fd, name, &st, AT_SYMLINK_NOFOLLOW) == 0 else { errors += 1; if errorPaths.count < 20 { errorPaths.append(path + "/" + name) }; continue }
            let mode = st.st_mode & S_IFMT
            if mode == S_IFDIR {
                guard st.st_dev == rootDev else { continue }
                entries.append(Entry(name: name, isDirectory: true, size: 0, allocated: 0, mtimeNs: 0))
            } else if mode == S_IFREG {
                let ns = Int64(st.st_mtimespec.tv_sec) &* 1_000_000_000 &+ Int64(st.st_mtimespec.tv_nsec)
                entries.append(Entry(name: name, isDirectory: false, size: Int64(st.st_size),
                                     allocated: Int64(st.st_blocks) * 512, mtimeNs: ns))
            }
        }
        return Listing(entries: entries, dirMTime: dirMTime, errors: errors, errorPaths: errorPaths)
    }
}
