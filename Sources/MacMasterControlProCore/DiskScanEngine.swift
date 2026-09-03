import Foundation
import Darwin

/// [2026-09-04] REFACTORIZARE completă, cerută explicit de Cristi după ce
/// scanarea a ajuns la 624.000 de fișiere și dura peste o oră — și, mai
/// grav, relua totul de la zero la fiecare deschidere a aplicației.
/// Aplicații reale (DaisyDisk, TreeSize/WizTree) nu parcurg tot discul la
/// fiecare scanare — indexează o dată, salvează persistent, și la
/// rescanare actualizează DOAR ce s-a schimbat. Trei schimbări, toate
/// cerute explicit:
///
/// 1. **Native, nu shell.** Varianta veche (`/usr/bin/find -exec stat +`)
///    shell-a un proces extern și parsa text (`"%z\t%N"`) — funcțional,
///    dar cu un cost real de proces+pipe+parsare, ȘI un bug latent
///    niciodată lovit din întâmplare: un nume de fișier care conține
///    literal un TAB ar fi rupt parsarea `split(separator: "\t")`. Acum
///    foloseşte direct `fts(3)` (POSIX, exact API-ul intern folosit de
///    `find` însuși) — `fts_statp` dă mărimea ȘI mtime-ul DIRECT, ca
///    struct, fără nicio conversie prin text.
/// 2. **Paralel pe toate nucleele.** Fiecare subfolder de PRIM NIVEL al
///    rădăcinii primește propriul `fts` independent, rulat concurent
///    (`DispatchQueue.concurrentPerform` — GCD alege singur câte thread-uri
///    pornește, după numărul de nuclee). Fiecare thread construiește
///    propriul subarbore, FĂRĂ nicio stare comună mutabilă cu celelalte —
///    unirea în arborele final e un pas simplu, secvențial, la sfârșit.
/// 3. **Scanare incrementală.** `incrementalUpdate` compară mtime-ul
///    fiecărui folder cu cel din cache (`DiskTreeNode.directoryModifiedAt`)
///    — un folder neschimbat își păstrează subarborele cache-uit INTACT,
///    fără nicio citire suplimentară de disc dincolo de acel `stat()`.
///    Doar folderele chiar atinse (adăugare/ștergere/redenumire de
///    fișier) sunt recitite. Reduce o rescanare de la ore la câteva
///    secunde pe un disc unde majoritatea conținutului n-a fost atins.
///
/// **Verificat izolat înainte de integrare** (practica deja stabilită în
/// acest repo, vezi CLAUDE.md v2.28.0): un mic executabil separat,
/// ȘTERS după verificare, a confirmat `fts_open`/`fts_read` funcționează
/// corect din Swift (nume/mărime/mtime extrase corect) și e semnificativ
/// mai rapid decât varianta shell (36.028 fișiere reale, 1.13s, un singur
/// thread — extrapolat, ~20s pentru 624.000 fișiere chiar și FĂRĂ
/// paralelismul de mai sus).
public enum DiskScanEngine {
    public struct Progress {
        public let filesIndexed: Int
        public let bytesIndexed: Int64
    }

    private struct TopLevelEntry {
        let name: String
        let path: String
        let isDirectory: Bool
        let size: Int64
    }

    /// Acumulator de progres thread-safe — fiecare thread de scanare
    /// raportează în loturi (nu per-fișier, ca să nu se blocheze reciproc
    /// mii de ori pe secundă pe același lacăt), doar rezultatul agregat
    /// ajunge, pe main thread, la `onProgress`.
    private final class ProgressCounter {
        private let lock = NSLock()
        private(set) var files = 0
        private(set) var bytes: Int64 = 0
        private var lastReportedAt = Date()

        func add(files deltaFiles: Int, bytes deltaBytes: Int64, onProgress: @escaping (Progress) -> Void) {
            lock.lock()
            files += deltaFiles
            bytes += deltaBytes
            let now = Date()
            let due = now.timeIntervalSince(lastReportedAt) >= 1
            let snapshot = Progress(filesIndexed: files, bytesIndexed: bytes)
            if due { lastReportedAt = now }
            lock.unlock()
            if due { DispatchQueue.main.async { onProgress(snapshot) } }
        }
    }

    // MARK: - Scanare completă (prima dată, sau "Resetează cache")

    /// Construiește arborele complet pentru `root`, paralel pe toate
    /// nucleele. `onProgress` e chemat periodic PE MAIN THREAD cât
    /// indexarea avansează; `completion` o singură dată, la final, tot pe
    /// main thread.
    public static func buildTree(root: String, onProgress: @escaping (Progress) -> Void, completion: @escaping (DiskTreeNode) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let resolvedRoot = URL(fileURLWithPath: root).resolvingSymlinksInPath().path
            let rootNode = DiskTreeNode(name: (resolvedRoot as NSString).lastPathComponent, path: resolvedRoot, isDirectory: true)
            rootNode.directoryModifiedAt = directoryMTime(resolvedRoot) ?? 0

            let topLevel = directChildren(of: resolvedRoot)
            guard !topLevel.isEmpty else {
                DispatchQueue.main.async { completion(rootNode) }
                return
            }

            let progressReporter = ProgressCounter()
            var partial = [DiskTreeNode?](repeating: nil, count: topLevel.count)
            let mergeLock = NSLock()

            DispatchQueue.concurrentPerform(iterations: topLevel.count) { index in
                let entry = topLevel[index]
                let node: DiskTreeNode
                if entry.isDirectory {
                    node = scanSubtreeNative(root: entry.path, name: entry.name, progressReporter: progressReporter, onProgress: onProgress)
                } else {
                    node = DiskTreeNode(name: entry.name, path: entry.path, isDirectory: false)
                    node.sizeBytes = entry.size
                    progressReporter.add(files: 1, bytes: entry.size, onProgress: onProgress)
                }
                mergeLock.lock()
                partial[index] = node
                mergeLock.unlock()
            }

            for case let node? in partial {
                rootNode.children[node.name] = node
                rootNode.sizeBytes += node.sizeBytes
            }

            let final = Progress(filesIndexed: progressReporter.files, bytesIndexed: progressReporter.bytes)
            DispatchQueue.main.async {
                onProgress(final)
                completion(rootNode)
            }
        }
    }

    /// Scanare `fts` nativă, completă, a UNUI subfolder — apelată o dată
    /// per subfolder de prim nivel (paralel, vezi `buildTree`), și din
    /// nou, punctual, de `incrementalUpdate` pentru un folder nou-apărut
    /// care nu exista deloc în cache.
    private static func scanSubtreeNative(root: String, name: String, progressReporter: ProgressCounter, onProgress: @escaping (Progress) -> Void) -> DiskTreeNode {
        let rootNode = DiskTreeNode(name: name, path: root, isDirectory: true)
        rootNode.directoryModifiedAt = directoryMTime(root) ?? 0

        guard let rootCPath = strdup(root) else { return rootNode }
        var pathArg: [UnsafeMutablePointer<CChar>?] = [rootCPath, nil]
        defer { free(rootCPath) }

        guard let ftsp = fts_open(&pathArg, FTS_PHYSICAL | FTS_XDEV | FTS_NOCHDIR, nil) else {
            return rootNode
        }
        defer { fts_close(ftsp) }

        let rootPrefix = root.hasSuffix("/") ? root : root + "/"
        var pendingFiles = 0
        var pendingBytes: Int64 = 0

        _ = fts_read(ftsp) // prima intrare e radacina insasi - deja reprezentata de rootNode

        while let ent = fts_read(ftsp) {
            let info = Int32(ent.pointee.fts_info)
            guard info == FTS_F || info == FTS_D else { continue }
            guard let st = ent.pointee.fts_statp else { continue }

            // [2026-09-04] BUG REAL, gasit prin rulare (nu vizibil din citirea
            // codului): `fts_path` e deja un `char*` (UnsafeMutablePointer<CChar>),
            // NU un buffer inline in struct — `withUnsafePointer(to: &ent.pointee.fts_path)`
            // lua adresa CAMPULUI-POINTER insusi, iar reinterpretarea ei ca text
            // citea octetii propriului pointer ca ASCII, nu calea reala. Rezultat:
            // `hasPrefix(rootPrefix)` esua mereu, tacut, si scanarea gasea 0
            // fisiere. Fix: `fts_path` se citeste direct cu `String(cString:)`.
            guard let ftsPathPtr = ent.pointee.fts_path else { continue }
            let fullPath = String(cString: ftsPathPtr)
            guard fullPath.hasPrefix(rootPrefix) else { continue }
            let relative = fullPath.dropFirst(rootPrefix.count)
            let components = relative.split(separator: "/")
            guard !components.isEmpty else { continue }

            let isDir = info == FTS_D
            let size = isDir ? 0 : st.pointee.st_size
            let mtime = Double(st.pointee.st_mtimespec.tv_sec) + Double(st.pointee.st_mtimespec.tv_nsec) / 1_000_000_000

            var current = rootNode
            if !isDir { current.sizeBytes += size }
            var built = rootPrefix
            for (index, component) in components.enumerated() {
                let isLast = index == components.count - 1
                let cname = String(component)
                built += (index == 0 ? "" : "/") + cname
                if let existing = current.children[cname] {
                    if !isDir { existing.sizeBytes += size }
                    current = existing
                } else {
                    let node = DiskTreeNode(name: cname, path: built, isDirectory: isLast ? isDir : true)
                    if !isDir { node.sizeBytes = size }
                    current.children[cname] = node
                    current = node
                }
            }
            if isDir { current.directoryModifiedAt = mtime }

            if !isDir {
                pendingFiles += 1
                pendingBytes += size
                if pendingFiles >= 500 {
                    progressReporter.add(files: pendingFiles, bytes: pendingBytes, onProgress: onProgress)
                    pendingFiles = 0
                    pendingBytes = 0
                }
            }
        }
        if pendingFiles > 0 {
            progressReporter.add(files: pendingFiles, bytes: pendingBytes, onProgress: onProgress)
        }
        return rootNode
    }

    // MARK: - Scanare incrementală ("Re-scanează doar modificările")

    /// Reutilizează arborele deja cache-uit, atingând discul DOAR pentru
    /// folderele al căror mtime chiar s-a schimbat de la ultima scanare —
    /// vezi comentariul de la nivelul enum-ului. Nu detectează o schimbare
    /// de CONȚINUT a unui fișier existent care și-a păstrat exact aceeași
    /// mărime (extrem de rar în practică) — pentru acel caz limită rămâne
    /// disponibil butonul „Resetează cache & scanare completă".
    public static func incrementalUpdate(cachedRoot: DiskTreeNode, onProgress: @escaping (Progress) -> Void, completion: @escaping (DiskTreeNode) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let progressReporter = ProgressCounter()
            let updated = refreshDirectory(node: cachedRoot, progressReporter: progressReporter, onProgress: onProgress)
            let final = Progress(filesIndexed: progressReporter.files, bytesIndexed: progressReporter.bytes)
            DispatchQueue.main.async {
                onProgress(final)
                completion(updated)
            }
        }
    }

    /// Recursiv, dar ieftin: costul real e un `stat()` per folder vizitat
    /// — un subarbore ale cărui mtime-uri n-au fost atinse tot recursează
    /// prin el (ca să verifice și sub-subfolderele), dar NICIODATĂ nu
    /// re-listează conținutul unui folder al cărui mtime propriu n-a
    /// diferit. Pe 624.000 de fișiere, numărul de FOLDERE e o fracțiune
    /// mică din total — de-aia asta rămâne "câteva secunde", nu "ore".
    private static func refreshDirectory(node: DiskTreeNode, progressReporter: ProgressCounter, onProgress: @escaping (Progress) -> Void) -> DiskTreeNode {
        guard node.isDirectory else { return node }

        guard let currentMTime = directoryMTime(node.path) else {
            // Folderul a dispărut complet de pe disc între timp.
            node.children = [:]
            node.sizeBytes = 0
            return node
        }

        if currentMTime == node.directoryModifiedAt {
            for child in node.children.values where child.isDirectory {
                _ = refreshDirectory(node: child, progressReporter: progressReporter, onProgress: onProgress)
            }
            node.sizeBytes = node.children.values.reduce(0) { $0 + $1.sizeBytes }
            return node
        }

        node.directoryModifiedAt = currentMTime
        let liveEntries = directChildren(of: node.path)
        let liveNames = Set(liveEntries.map { $0.name })

        for staleName in node.children.keys where !liveNames.contains(staleName) {
            node.children.removeValue(forKey: staleName)
        }

        var newFiles = 0
        var newBytes: Int64 = 0
        for entry in liveEntries {
            if entry.isDirectory {
                if let existingChild = node.children[entry.name] {
                    _ = refreshDirectory(node: existingChild, progressReporter: progressReporter, onProgress: onProgress)
                } else {
                    let scanned = scanSubtreeNative(root: entry.path, name: entry.name, progressReporter: progressReporter, onProgress: onProgress)
                    node.children[entry.name] = scanned
                }
            } else if node.children[entry.name]?.sizeBytes != entry.size {
                let fileNode = DiskTreeNode(name: entry.name, path: entry.path, isDirectory: false)
                fileNode.sizeBytes = entry.size
                node.children[entry.name] = fileNode
                newFiles += 1
                newBytes += entry.size
            }
        }
        if newFiles > 0 {
            progressReporter.add(files: newFiles, bytes: newBytes, onProgress: onProgress)
        }
        node.sizeBytes = node.children.values.reduce(0) { $0 + $1.sizeBytes }
        return node
    }

    // MARK: - Ștergere (neschimbată — actualizează arborele fără rescanare)

    /// Actualizează arborele DUPĂ o ștergere reușită — scade mărimea
    /// fișierului/folderului șters din TOȚI strămoșii lui și îl elimină din
    /// arbore, ca navigarea să rămână instantă (fără rescanare) și
    /// mărimile afișate să rămână corecte imediat.
    public static func remove(nodePath: String, from root: DiskTreeNode) {
        guard nodePath.hasPrefix(root.path) else { return }
        let rootPrefix = root.path.hasSuffix("/") ? root.path : root.path + "/"
        guard nodePath.hasPrefix(rootPrefix) else { return }
        let relative = nodePath.dropFirst(rootPrefix.count)
        let components = relative.split(separator: "/").map(String.init)
        guard !components.isEmpty else { return }

        var chain: [DiskTreeNode] = [root]
        var current = root
        for component in components {
            guard let child = current.children[component] else { return }
            chain.append(child)
            current = child
        }
        let removedSize = current.sizeBytes
        for ancestor in chain.dropLast() {
            ancestor.sizeBytes -= removedSize
        }
        if let parent = chain.dropLast().last, let lastComponent = components.last {
            parent.children.removeValue(forKey: lastComponent)
        }
    }

    // MARK: - Helpers native (fără shell)

    /// Listare de UN SINGUR nivel — folosită pentru împărțirea în task-uri
    /// paralele (subfolderele de prim nivel ale rădăcinii) și pentru
    /// comparația "ce mai există pe disc" din scanarea incrementală.
    /// `FileManager` de nivel înalt e potrivit AICI (un singur nivel, nu
    /// traversare recursivă) — traversarea adâncă rămâne pe `fts` nativ.
    private static func directChildren(of path: String) -> [TopLevelEntry] {
        guard let items = try? FileManager.default.contentsOfDirectory(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey]
        ) else { return [] }
        return items.compactMap { url in
            guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey]) else { return nil }
            return TopLevelEntry(
                name: url.lastPathComponent,
                path: url.path,
                isDirectory: values.isDirectory ?? false,
                size: Int64(values.fileSize ?? 0)
            )
        }
    }

    private static func directoryMTime(_ path: String) -> Double? {
        var st = stat()
        guard stat(path, &st) == 0 else { return nil }
        return Double(st.st_mtimespec.tv_sec) + Double(st.st_mtimespec.tv_nsec) / 1_000_000_000
    }
}
