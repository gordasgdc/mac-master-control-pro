import Foundation

/// [2026-09-03] REFACTORIZARE, cerută explicit de Cristi: "aplicația
/// declanșează o nouă scanare de la zero" la fiecare intrare într-un
/// subfolder — vechiul model (`DiskAnalyzerService.scanLevel`, ȘTERS)
/// rescana discul cu `du`/`find` LA FIECARE navigare, exact ca o pagină
/// web care se reîncarcă la fiecare click. Un explorator real (DaisyDisk/
/// GrandPerspective/TreeSize) indexează structura completă O SINGURĂ
/// DATĂ, ține totul într-un arbore în memorie, iar navigarea ulterioară
/// citește instant din acel arbore — ZERO acces nou la disc.
///
/// **O singură trecere recursivă real**: `find <root> -x -type f -exec
/// stat -f '%z\t%N' {} +` — un SINGUR proces, listează TOATE fișierele
/// din toată structura dintr-o dată (`-exec ... +`, nu `;`, grupează căile
/// în loturi mari — mult mai rapid decât un `stat` per fișier). `-x` nu
/// traversează în alte volume montate (ex. un folder de rețea legat
/// simbolic), la fel ca vechiul `du -x`.
///
/// **Streaming, nu un blob uriaș în memorie (Regula 21)**: output-ul
/// `find` pe un disc cu milioane de fișiere ar însemna sute de MB de text
/// brut — în loc să așteptăm tot output-ul (`Shell.run` obișnuit) și abia
/// apoi să-l tăiem pe linii, citim pipe-ul incremental (`readabilityHandler`,
/// același fix de deadlock din `Shell.swift`) și PROCESĂM fiecare linie
/// direct în arbore pe măsură ce sosește — bufferul brut de text nu
/// depășește niciodată câțiva KB (doar rândul/rândurile în curs), restul
/// devine imediat un nod compact în arbore (nume + mărime, nu tot rândul
/// de text păstrat).
public enum DiskScanEngine {
    public struct Progress {
        public let filesIndexed: Int
        public let bytesIndexed: Int64
    }

    /// Construiește arborele complet pentru `root`. `onProgress` e chemat
    /// periodic PE MAIN THREAD cât indexarea avansează (la fiecare 2000 de
    /// fișiere, plus o dată la final) — userul vede un numărător viu, nu
    /// doar un cronometru fără sens pe un disc cu milioane de fișiere.
    /// `completion` e chemat o singură dată, la final, tot pe main thread.
    public static func buildTree(root: String, onProgress: @escaping (Progress) -> Void, completion: @escaping (DiskTreeNode) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let rootNode = DiskTreeNode(name: (root as NSString).lastPathComponent, path: root, isDirectory: true)
            let rootPrefix = root.hasSuffix("/") ? root : root + "/"

            var filesIndexed = 0
            var bytesIndexed: Int64 = 0
            var lastReportedAt = Date()

            func ingest(_ line: Substring) {
                let parts = line.split(separator: "\t", maxSplits: 1)
                guard parts.count == 2, let bytes = Int64(parts[0]) else { return }
                let fullPath = String(parts[1])
                guard fullPath.hasPrefix(rootPrefix) else { return }
                let relative = fullPath.dropFirst(rootPrefix.count)
                let components = relative.split(separator: "/")
                guard !components.isEmpty else { return }

                var current = rootNode
                current.sizeBytes += bytes
                var pathSoFar = rootPrefix
                for (index, component) in components.enumerated() {
                    let isLastComponent = index == components.count - 1
                    let name = String(component)
                    pathSoFar += (index == 0 ? "" : "/") + name
                    if let existing = current.children[name] {
                        existing.sizeBytes += bytes
                        current = existing
                    } else {
                        let node = DiskTreeNode(name: name, path: pathSoFar, isDirectory: !isLastComponent)
                        node.sizeBytes = bytes
                        current.children[name] = node
                        current = node
                    }
                }
                filesIndexed += 1
                bytesIndexed += bytes

                // Progres la fiecare 2000 de fisiere SAU cel putin o data pe
                // secunda — pe un disc cu foarte multe fisiere mici, 2000 ar
                // veni prea des (zeci de update-uri UI/secunda); pe unul cu
                // putine fisiere foarte mari, ar putea sa nu vina niciodata
                // fara pragul de timp.
                let now = Date()
                if filesIndexed % 2000 == 0 || now.timeIntervalSince(lastReportedAt) >= 1 {
                    lastReportedAt = now
                    let snapshot = Progress(filesIndexed: filesIndexed, bytesIndexed: bytesIndexed)
                    DispatchQueue.main.async { onProgress(snapshot) }
                }
            }

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/find")
            // [2026-09-03] FIX REAL, gasit prin testare izolata directa pe
            // /usr/bin/find (verificarea initiala trecuse din greseala pe
            // un shim `find`/`bfs` din mediul de shell, care accepta `-x`
            // dupa cale — binarul REAL de sistem, cel apelat aici prin cale
            // absoluta, respinge asta cu "illegal option": `-x` e o OPTIUNE
            // globala, trebuie sa preceada calea, nu un primar de expresie
            // ca `-type` care poate veni oriunde dupa.
            process.arguments = ["-x", root, "-type", "f", "-exec", "/usr/bin/stat", "-f", "%z\t%N", "{}", "+"]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe() // erori (permisiuni etc.) ignorate, nu ne blocheaza indexarea

            // [2026-09-03] FIX REAL #1 (crash + date corupte la fisiere
            // putine): manipularea manuala de offset-uri `Data`
            // (`firstIndex(of:)` + `removeSubrange`) nu garanta indici
            // valizi dupa o stergere partiala.
            //
            // [2026-09-03] FIX REAL #2, mult mai serios, gasit prin testare
            // cu 500+ fisiere (SIGSEGV intermitent, sau pierdere silentioasa
            // a majoritatii fisierelor, in functie de timing): varianta cu
            // `readabilityHandler` proceseaza date pe un thread de fundal
            // AL DISPATCH SOURCE-ULUI, in timp ce codul de dupa
            // `waitUntilExit()` (pe alt thread) citea/scria ACEEASI
            // variabila capturata (`leftoverText`) fara nicio sincronizare
            // — o cursa reala de date, nu doar teoretica (confirmata cu
            // crash reproductibil). Fix: citire BLOCANTA, SECVENTIALA, pe
            // UN SINGUR thread (deja pe fundal, `DispatchQueue.global`,
            // deci blocarea aici nu afecteaza UI-ul) — `FileHandle.
            // availableData` asteapta date noi sau intoarce `Data()` goale
            // la EOF real; fara `readabilityHandler`, fara acces concurent,
            // fara cursa posibila.
            do {
                try process.run()
            } catch {
                DispatchQueue.main.async { completion(rootNode) }
                return
            }

            let handle = pipe.fileHandleForReading
            var leftoverText = ""
            while true {
                let chunk = handle.availableData
                if chunk.isEmpty { break } // EOF real - procesul a inchis capatul de scriere
                guard let text = String(data: chunk, encoding: .utf8) else { continue }
                leftoverText += text
                var lines = leftoverText.split(separator: "\n", omittingEmptySubsequences: false)
                // Ultima bucata poate fi o linie INCOMPLETA (chunk-ul s-a
                // taiat la mijlocul unui rand) — o pastram pentru
                // urmatorul chunk, NU o ingeram inca.
                leftoverText = lines.isEmpty ? "" : String(lines.removeLast())
                for line in lines { ingest(line) }
            }
            if !leftoverText.isEmpty {
                for line in leftoverText.split(separator: "\n", omittingEmptySubsequences: false) where !line.isEmpty {
                    ingest(line)
                }
            }
            process.waitUntilExit()

            let final = Progress(filesIndexed: filesIndexed, bytesIndexed: bytesIndexed)
            DispatchQueue.main.async {
                onProgress(final)
                completion(rootNode)
            }
        }
    }

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
}
