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
    @Published public var bytesIndexed: Int64 = 0
    @Published public var deleteError: String?
    @Published public var roots: [DiskEntry] = []
    /// Data ultimei analize (completă SAU incrementală) — `nil` doar cât
    /// timp arborele curent n-a fost încă salvat/încărcat niciodată.
    @Published public var lastScannedAt: Date?

    private var currentRootPath: String?

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
        currentRootPath = root.path
        pathStack = []
        deleteError = nil

        if let snapshot = DiskCacheStore.load(rootPath: root.path) {
            tree = snapshot.root
            lastScannedAt = snapshot.scannedAt
            filesIndexed = snapshot.root.totalFileCount
            bytesIndexed = snapshot.root.sizeBytes
            isIndexing = false
            return
        }
        performFullScan(rootPath: root.path)
    }

    private func performFullScan(rootPath: String) {
        tree = nil
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
            completion: { [weak self] node in
                guard let self else { return }
                self.tree = node
                self.isIndexing = false
                let now = Date()
                self.lastScannedAt = now
                self.filesIndexed = node.totalFileCount
                DiskCacheStore.save(.init(rootPath: rootPath, scannedAt: now, root: node))
            }
        )
    }

    /// „Re-scanează doar modificările" — compară cache-ul cu discul,
    /// atinge doar ce s-a schimbat (vezi `DiskScanEngine.incrementalUpdate`).
    /// Arborele existent rămâne navigabil normal cât timp rulează.
    public func rescanChangesOnly() {
        guard let tree, let rootPath = currentRootPath, !isRescanning, !isIndexing else { return }
        isRescanning = true
        DiskScanEngine.incrementalUpdate(
            cachedRoot: tree,
            onProgress: { _ in }, // progres per-fisier nu are sens aici - de regula dureaza cateva secunde
            completion: { [weak self] node in
                guard let self else { return }
                self.tree = node
                self.isRescanning = false
                let now = Date()
                self.lastScannedAt = now
                self.filesIndexed = node.totalFileCount
                self.bytesIndexed = node.sizeBytes
                DiskCacheStore.save(.init(rootPath: rootPath, scannedAt: now, root: node))
            }
        )
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
                    self.deleteError = error
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
                    self.bytesIndexed = tree.sizeBytes
                    DiskCacheStore.save(.init(rootPath: rootPath, scannedAt: self.lastScannedAt ?? Date(), root: tree))
                }
            }
        }
    }
}
