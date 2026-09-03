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
    @Published public var filesIndexed = 0
    @Published public var bytesIndexed: Int64 = 0
    @Published public var deleteError: String?
    @Published public var roots: [DiskEntry] = []

    public var currentNode: DiskTreeNode? { pathStack.last ?? tree }
    public var currentChildren: [DiskTreeNode] { currentNode?.sortedChildren ?? [] }
    public var indexedBytesDescription: String { ByteCountFormatter.string(fromByteCount: bytesIndexed, countStyle: .file) }

    public func loadRootsIfNeeded() {
        guard tree == nil, roots.isEmpty else { return }
        roots = DiskAnalyzerService.availableRoots()
    }

    /// Întoarcere completă la ecranul de alegere disc/folder — abandonează
    /// arborele curent (o reindexare adevărată e singura cale de a-l
    /// reface, dacă userul alege din nou aceeași rădăcină; oricum
    /// conținutul discului se poate fi schimbat între timp).
    public func resetToRoots() {
        tree = nil
        pathStack = []
        isIndexing = false
        roots = DiskAnalyzerService.availableRoots()
    }

    public func startIndexing(root: DiskEntry) {
        tree = nil
        pathStack = []
        isIndexing = true
        filesIndexed = 0
        bytesIndexed = 0
        DiskScanEngine.buildTree(
            root: root.path,
            onProgress: { [weak self] progress in
                guard let self else { return }
                self.filesIndexed = progress.filesIndexed
                self.bytesIndexed = progress.bytesIndexed
            },
            completion: { [weak self] node in
                guard let self else { return }
                self.tree = node
                self.isIndexing = false
            }
        )
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
                } else if let tree = self.tree {
                    DiskScanEngine.remove(nodePath: nodePath, from: tree)
                    // Forteaza SwiftUI sa re-citeasca `currentChildren` —
                    // mutatiile in interiorul claselor `DiskTreeNode` nu
                    // sunt @Published, deci nu declanseaza singure un update.
                    self.objectWillChange.send()
                }
            }
        }
    }
}
