import Foundation

/// Un nod din arborele de fișiere/foldere indexat complet — vezi
/// `DiskScanEngine`. Foldere: `sizeBytes` e SUMA tuturor descendenților
/// (actualizată live pe măsură ce indexarea avansează, sau la ștergere);
/// fișiere: `sizeBytes` e mărimea proprie, `children` mereu gol.
public final class DiskTreeNode: Identifiable {
    public let id = UUID()
    public let name: String
    public let path: String
    public let isDirectory: Bool
    public var sizeBytes: Int64 = 0
    public var children: [String: DiskTreeNode] = [:]

    public init(name: String, path: String, isDirectory: Bool) {
        self.name = name
        self.path = path
        self.isDirectory = isDirectory
    }

    public var sizeDescription: String { ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file) }

    /// Copiii sortați descrescător după mărime — ordinea pe care o vede
    /// userul mereu, exact ca DaisyDisk/GrandPerspective/TreeSize.
    public var sortedChildren: [DiskTreeNode] {
        children.values.sorted { $0.sizeBytes > $1.sizeBytes }
    }
}
