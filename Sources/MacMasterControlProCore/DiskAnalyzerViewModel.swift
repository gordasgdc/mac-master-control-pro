import Foundation

/// [2026-09-03] FIX REAL #1, raportat de Cristi: "dacă dau să ruleze o
/// analiză pe disc și mă uit în celelalte meniuri, s-a oprit" — scanarea
/// (proces de sistem real) NU se oprea niciodată, dar starea care AFIȘA
/// progresul trăia doar în `@State`-ul local al `DiskAnalyzerView` — o
/// simplă struct, distrusă de SwiftUI de fiecare dată când `ContentView`
/// schimbă `selection` la alt meniu. Fix, identic ca principiu cu toate
/// serviciile din acest repo (`RenderModeService` etc.): toată starea
/// trăiește într-un `ObservableObject` SINGLETON (`.shared`).
///
/// [2026-09-03] FIX REAL #2, raportat imediat după: "când dai dublu-click
/// să intri într-un subfolder, aplicația declanșează o nouă scanare de la
/// zero". Rescris complet de la model "o scanare per nivel, la fiecare
/// navigare" (`DiskAnalyzerService.scanLevel`, ȘTERS) la model "o singură
/// indexare completă, recursivă, apoi navigare instantă în arborele deja
/// construit" (`DiskScanEngine.buildTree`) — exact cum funcționează
/// DaisyDisk/GrandPerspective/TreeSize. `pathStack` navighează acum prin
/// NODURI deja indexate, ZERO acces nou la disc.
///
/// [2026-09-04] Cache persistent + scanare incrementală, cerință explicită
/// de la Cristi: la 624.000 de fișiere, o oră de scanare care se reia de
/// la zero la fiecare deschidere a aplicației e inacceptabil. Alegerea
/// unei rădăcini încarcă acum INSTANT ultimul cache salvat
/// (`DiskCacheStore`), dacă există — nicio scanare nouă. `rescanChangesOnly()`
/// și `resetCacheAndFullRescan()` sunt cele două acțiuni explicite din UI.
@MainActor
public final class DiskAnalyzerViewModel: ObservableObject {
    public static let shared = DiskAnalyzerViewModel()
    private init() {}

    /// Rădăcina arborelui indexat complet — `nil` cât timp nu s-a ales
    /// încă un disc/folder, sau indexarea tocmai a pornit.
    @Published public var tree: DiskTreeNode?
    /// Lanțul de noduri parcurs — `pathStack.last` e folderul curent
    /// afișat; gol înseamnă "rădăcina arborelui" (`tree`).
    @Published public var pathStack: [DiskTreeNode] = []
    @Published public var isIndexing = false
    /// Rescanare incrementală în curs — distinctă de `isIndexing` (scanare
    /// completă): UI-ul arată un indicator mai discret, arborele deja
    /// afișat rămâne navigabil normal cât timp rulează.
    @Published public var isRescanning = false
    @Published public var filesIndexed = 0
    /// Discul aflat în curs de indexare — folosit pentru iconița NATIVĂ din
    /// panoul de progres (2026-09-11).
    @Published public private(set) var currentScanRootPath: String?
    /// Distinge „încarc analiza salvată" de „scanez discul" — sunt două
    /// așteptări diferite și userul trebuie să știe pe care o vede.
    @Published public private(set) var isLoadingCache = false
    @Published public var bytesIndexed: Int64 = 0
    @Published public var deleteError: String?
    /// Rădăcina aleasă nu există sau nu poate fi citită: se arată un banner, nu se revine mut la selector.
    @Published public var scanError: String?
    @Published public var roots: [DiskEntry] = []
    /// Data ultimei analize (completă SAU incrementală) — `nil` doar cât
    /// timp arborele curent n-a fost încă salvat/încărcat niciodată.
    @Published public var lastScannedAt: Date?
    /// Ultima verificare la nivel de fisier (nil = cache vechi, nereconciliat).
    @Published public var lastVerifiedAt: Date?
    /// Elemente ce n-au putut fi citite la ultima scanare; rezultatul e partial in acele zone.
    @Published public var accessErrors = 0
    /// Primele căi neanalizate (eșantion) — arătate în detalii; rezultatul nu e complet cât timp contorul > 0.
    @Published public var accessSamples: [String] = []
    /// Mesaj de stare pentru utilizator (volum deconectat, anulat etc.); null daca nimic de spus.
    @Published public var scanNotice: String?

    private var currentRootPath: String?

    // MARK: - Selecție și revizuire (Studio Glass)
    /// Selecția supraviețuiește navigării. Un părinte selectat înlocuiește copiii selectați (fără dublă numărare).
    @Published public private(set) var selection: [UUID: DiskTreeNode] = [:]
    @Published public var focusID: UUID?
    @Published public var hoverID: UUID?
    /// Rezultatul ultimei mutări în Coș, per element (nil = nicio operație sau încă în revizuire).
    @Published public private(set) var trashResults: [UUID: TrashService.Outcome]?
    @Published public private(set) var isTrashing = false
    /// Elementele operației curente, păstrate pentru afișarea rezultatului (după mutare dispar din selecție).
    @Published public private(set) var resultItems: [UUID: DiskTreeNode] = [:]
    @Published public var includeUnverified = false

    public var duplicateSurplus: Set<String> { SpaceClassifier.duplicateSurplus(groups: DuplicateFinderViewModel.shared.groups) }

    public func flags(_ n: DiskTreeNode) -> Set<SpaceFlag> {
        SpaceClassifier.flags(path: n.path, isDirectory: n.isDirectory, isAggregate: n.isAggregate, duplicateSurplus: duplicateSurplus)
    }

    public var summary: SpaceSelectionSummary { SpaceMath.summarize(nodes: Array(selection.values), duplicateSurplus: duplicateSurplus) }

    public func isSelected(_ n: DiskTreeNode) -> Bool { selection[n.id] != nil }
    public func hasSelectedDescendant(_ n: DiskTreeNode) -> Bool { n.children.values.contains { selection[$0.id] != nil || hasSelectedDescendant($0) } }

    /// false dacă elementul e protejat (nu se poate selecta).
    @discardableResult
    public func toggleSelection(_ n: DiskTreeNode) -> Bool {
        if selection[n.id] != nil { selection[n.id] = nil; return true }
        if flags(n).contains(.protected) { return false }
        // părinte vs. copii: păstrăm doar nivelul cel mai de sus
        func drop(_ x: DiskTreeNode) { for c in x.children.values { selection[c.id] = nil; drop(c) } }
        drop(n)
        var p: DiskTreeNode? = parentOf(n)
        while let a = p { selection[a.id] = nil; p = parentOf(a) }
        selection[n.id] = n
        return true
    }

    private func parentOf(_ n: DiskTreeNode) -> DiskTreeNode? {
        guard let tree else { return nil }
        let parentPath = (n.path as NSString).deletingLastPathComponent
        if parentPath == tree.path { return tree }
        var cur = tree
        let rel = parentPath.dropFirst(tree.path.hasSuffix("/") ? tree.path.count : tree.path.count + 1)
        guard parentPath.hasPrefix(tree.path) else { return nil }
        for comp in rel.split(separator: "/") { guard let next = cur.children[String(comp)] else { return nil }; cur = next }
        return cur
    }

    public func clearSelection() { selection = [:]; trashResults = nil }

    /// Mută la Coș elementele recuperabile (+ cele neverificate doar dacă `includeUnverified`). Per element, rezultat explicit.
    public func moveSelectionToTrash() {
        guard !isTrashing else { return }
        let sum = summary
        let wanted = Set(sum.recoverable + (includeUnverified ? sum.unverified : []))
        let items = selection.values.filter { wanted.contains($0.path) }
        guard !items.isEmpty else { return }
        isTrashing = true; trashResults = nil
        resultItems = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        let op = DiagnosticLog.begin("trash", "move", fields: ["items": String(items.count)])
        let pairs = items.map { ($0.id, $0.path) }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var out: [UUID: TrashService.Outcome] = [:]
            for (id, path) in pairs { out[id] = TrashService.moveToTrash(path: path) }
            DispatchQueue.main.async {
                guard let self else { return }
                let failed = out.values.filter { if case .failed = $0 { return true } else { return false } }.count
                op.end(failed == 0 ? "ok" : "partial", level: failed == 0 ? .info : .warning, fields: ["failed": String(failed)])
                if let tree = self.tree, let rootPath = self.currentRootPath {
                    for (id, o) in out where o == .moved {
                        if let n = self.selection[id] { DiskScanEngine.remove(nodePath: n.path, from: tree) }
                        self.selection[id] = nil
                    }
                    self.filesIndexed = tree.totalFileCount; self.bytesIndexed = tree.usedBytes
                    DiskCacheStore.save(.init(rootPath: rootPath, scannedAt: self.lastScannedAt ?? Date(), root: tree,
                                              accessErrors: self.accessErrors, verifiedAt: self.lastVerifiedAt, accessSamples: self.accessSamples))
                }
                self.trashResults = out
                self.isTrashing = false
                self.objectWillChange.send()
            }
        }
    }

    /// Căile din rezultat care erau „fără regulă verificată” (pentru gruparea rezultatului).
    public var unverifiedPathsForResult: Set<String> { Set(resultItems.values.filter { !(flags($0).contains(.regenerable) || flags($0).contains(.duplicate)) }.map(\.path)) }

    public func dismissTrashResults() { trashResults = nil }

    public var currentNode: DiskTreeNode? { pathStack.last ?? tree }
    public var currentChildren: [DiskTreeNode] { currentNode?.sortedChildren ?? [] }
    public var indexedBytesDescription: String { ByteCountFormatter.string(fromByteCount: bytesIndexed, countStyle: .file) }

    public func loadRootsIfNeeded() {
        guard tree == nil, roots.isEmpty else { return }
        roots = DiskAnalyzerService.availableRoots()
    }

    /// Întoarcere completă la ecranul de alegere disc/folder. NU șterge
    /// niciun cache — alegerea din nou a aceleiași rădăcini îl încarcă
    /// instant, la fel ca prima dată.
    public func resetToRoots() {
        tree = nil
        pathStack = []
        isIndexing = false
        isRescanning = false
        lastScannedAt = nil
        currentRootPath = nil
        roots = DiskAnalyzerService.availableRoots()
    }

    /// Alege o rădăcină — încarcă INSTANT cache-ul salvat, dacă există
    /// (0 acces la disc dincolo de citirea unui singur fișier local mic),
    /// altfel pornește o scanare completă (prima dată pentru acea rădăcină).
    public func startIndexing(root: DiskEntry) {
        scanError = nil
        var isDir: ObjCBool = false
        if !FileManager.default.fileExists(atPath: root.path, isDirectory: &isDir) {
            scanError = String(format: CoreL.x("✘ „%@” nu există sau volumul nu mai este montat.", "✘ “%@” does not exist or the volume is no longer mounted.", "✘ «%@» no existe o el volumen ya no está montado."), root.path)
            return
        }
        if !FileManager.default.isReadableFile(atPath: root.path) {
            scanError = String(format: CoreL.x("✘ „%@” nu poate fi citit. Verifică permisiunile (Acces complet la disc).", "✘ “%@” cannot be read. Check the permissions (Full Disk Access).", "✘ «%@» no se puede leer. Revisa los permisos (Acceso total al disco)."), root.path)
            return
        }
        currentRootPath = root.path
        pathStack = []
        deleteError = nil

        // [FIX 2026-09-11] CAUZA ROTIȚEI DE AȘTEPTARE, găsită cu `sample` pe
        // procesul blocat: `DiskCacheStore.load` rula SINCRON, pe main thread,
        // direct din acțiunea butonului. Comentariul de deasupra promitea „un
        // singur fișier local mic" — în realitate, cache-ul unui volum de 4 TB
        // ajunsese la **2,4 GB**, iar decodarea lui ca plist ținea main
        // thread-ul ocupat la 99,9% CPU zeci de secunde. Presupunerea „mic"
        // n-a fost niciodată verificată pe date reale.
        //
        // Acum: citire + decodare pe un thread de fundal, cu ecran de progres
        // și buton de anulare între timp.
        isIndexing = true
        currentScanRootPath = root.path
        filesIndexed = 0
        bytesIndexed = 0
        isLoadingCache = true

        let path = root.path
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let snapshot = DiskCacheStore.load(rootPath: path)
            DispatchQueue.main.async {
                guard let self else { return }
                // Userul a apăsat Stop cât se încărca — nu suprascriem ce a ales.
                guard self.isLoadingCache else { return }
                self.isLoadingCache = false

                if let snapshot {
                    // Cache-urile scrise ÎNAINTE de 2026-09-11 conțin arbori
                    // NEagregați (un nod per fișier). Agregăm la încărcare, ca
                    // userul să beneficieze imediat de memoria redusă, fără să
                    // fie nevoit să rescaneze discul de la zero.
                    snapshot.root.collapseSmallFiles()
                    self.tree = snapshot.root
                    self.lastScannedAt = snapshot.scannedAt
                    self.lastVerifiedAt = snapshot.verifiedAt
                    self.accessErrors = snapshot.accessErrors; self.accessSamples = snapshot.accessSamples
                    self.filesIndexed = snapshot.root.totalFileCount
                    self.bytesIndexed = snapshot.root.usedBytes
                    self.isIndexing = false
                } else {
                    self.performFullScan(rootPath: path)
                }
            }
        }
    }

    /// [2026-09-11] Oprește indexarea și revine la lista de discuri.
    /// Lipsea complet: odată pornită pe un volum de 4 TB, userul rămânea
    /// blocat pe ecranul de progres — fără buton înapoi, fără să poată alege
    /// alt disc între timp (exact ce lipsea față de DaisyDisk).
    public func cancelIndexing() {
        isLoadingCache = false
        DiskScanEngine.requestCancel()
        isIndexing = false
        tree = nil
        pathStack = []
    }

    private func performFullScan(rootPath: String) {
        tree = nil
        currentScanRootPath = rootPath
        isIndexing = true
        filesIndexed = 0
        bytesIndexed = 0
        DiskScanEngine.buildTree(
            root: rootPath,
            onProgress: { [weak self] progress in
                guard let self else { return }
                self.filesIndexed = progress.filesIndexed
                self.bytesIndexed = progress.bytesIndexed
            },
            completion: { [weak self] node, outcome in
                guard let self else { return }
                // Anulat sau radacina a disparut (volum deconectat): arborele e PARTIAL. Nu il afisam si,
                // mai ales, nu il salvam in cache - ar parea complet la urmatoarea deschidere.
                guard outcome.status == .complete else {
                    self.isIndexing = false
                    if outcome.status == .rootUnavailable { self.scanNotice = "Volumul nu mai este disponibil. Nu am salvat nimic." }
                    return
                }
                node.collapseSmallFiles()
                self.tree = node
                self.isIndexing = false
                let now = Date()
                self.lastScannedAt = now
                self.lastVerifiedAt = now
                self.accessErrors = outcome.accessErrors; self.accessSamples = outcome.accessSamples
                self.filesIndexed = node.totalFileCount
                DiskCacheStore.save(.init(rootPath: rootPath, scannedAt: now, root: node,
                                          accessErrors: outcome.accessErrors, verifiedAt: now, accessSamples: outcome.accessSamples))
            }
        )
    }

    /// „Re-scanează doar modificările" — compară cache-ul cu discul,
    /// atinge doar ce s-a schimbat (vezi `DiskScanEngine.incrementalUpdate`).
    /// Arborele existent rămâne navigabil normal cât timp rulează.
    public func rescanChangesOnly() {
        guard let tree, let rootPath = currentRootPath, !isRescanning, !isIndexing else { return }
        isRescanning = true
        scanNotice = nil
        DiskScanEngine.incrementalUpdate(
            cachedRoot: tree,
            onProgress: { _ in },
            completion: { [weak self] node, outcome in
                guard let self else { return }
                self.isRescanning = false
                switch outcome.status {
                case .complete:
                    self.tree = node
                    let now = Date()
                    self.lastScannedAt = now
                    self.lastVerifiedAt = now
                    self.accessErrors = outcome.accessErrors; self.accessSamples = outcome.accessSamples
                    self.filesIndexed = node.totalFileCount
                    self.bytesIndexed = node.usedBytes
                    self.objectWillChange.send()
                    DiskCacheStore.save(.init(rootPath: rootPath, scannedAt: now, root: node,
                                              accessErrors: outcome.accessErrors, verifiedAt: now, accessSamples: outcome.accessSamples))
                case .rootUnavailable:
                    // Volum deconectat: pastram arborele si cache-ul neatinse.
                    self.scanNotice = "Volumul nu mai este disponibil. Datele afisate sunt din ultima analiza salvata."
                case .cancelled:
                    // Arborele din memorie poate fi partial actualizat; cache-ul de pe disc e intact - reincarcam din el.
                    self.scanNotice = "Verificare anulata. S-a pastrat ultima analiza salvata."
                    self.reloadFromCache(rootPath: rootPath)
                }
            }
        )
    }

    /// Opreste o verificare incrementala in curs.
    public func cancelRescan() {
        guard isRescanning else { return }
        DiskScanEngine.requestCancel()
    }

    private func reloadFromCache(rootPath: String) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let snap = DiskCacheStore.load(rootPath: rootPath)
            DispatchQueue.main.async {
                guard let self, let snap else { return }
                snap.root.collapseSmallFiles()
                self.tree = snap.root
                self.pathStack = []
                self.lastScannedAt = snap.scannedAt
                self.lastVerifiedAt = snap.verifiedAt
                self.accessErrors = snap.accessErrors; self.accessSamples = snap.accessSamples
                self.filesIndexed = snap.root.totalFileCount
                self.bytesIndexed = snap.root.usedBytes
            }
        }
    }

    /// „Resetează cache & scanare completă" — cerut explicit doar pentru
    /// cazurile rare (Cristi): șterge cache-ul salvat și reindexează totul
    /// de la zero, ca prima dată.
    public func resetCacheAndFullRescan() {
        guard let rootPath = currentRootPath else { return }
        DiskCacheStore.clear(rootPath: rootPath)
        pathStack = []
        lastScannedAt = nil
        performFullScan(rootPath: rootPath)
    }

    public func open(_ node: DiskTreeNode) {
        guard node.isDirectory else { return }
        pathStack.append(node)
    }

    public func jumpTo(index: Int) {
        pathStack = Array(pathStack.prefix(index + 1))
    }

    /// Șterge efectiv de pe disc, apoi actualizează arborele IN-MEMORIE
    /// (`DiskScanEngine.remove`) — nicio rescanare, mărimile ancestorilor
    /// scad instant, exact ca-ntr-un explorator real.
    public func delete(_ node: DiskTreeNode) {
        deleteError = nil
        let nodePath = node.path // String e Sendable, DiskTreeNode nu — evitam capturarea clasei pe alt thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let error = PrivilegedFileOps.delete(nodePath)
            DispatchQueue.main.async {
                guard let self else { return }
                if let error {
                    self.deleteError = "✘ " + error
                } else if let tree = self.tree, let rootPath = self.currentRootPath {
                    DiskScanEngine.remove(nodePath: nodePath, from: tree)
                    // Forteaza SwiftUI sa re-citeasca `currentChildren` —
                    // mutatiile in interiorul claselor `DiskTreeNode` nu
                    // sunt @Published, deci nu declanseaza singure un update.
                    self.objectWillChange.send()
                    // [2026-09-04] Salveaza cache-ul actualizat — altfel,
                    // la urmatoarea deschidere a aplicatiei, cache-ul VECHI
                    // ar arata din nou fisierul/folderul deja sters.
                    self.filesIndexed = tree.totalFileCount
                    self.bytesIndexed = tree.usedBytes
                    DiskCacheStore.save(.init(rootPath: rootPath, scannedAt: self.lastScannedAt ?? Date(), root: tree))
                }
            }
        }
    }
}
