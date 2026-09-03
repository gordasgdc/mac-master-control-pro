import Foundation

/// Un nod din arborele de fișiere/foldere indexat complet — vezi
/// `DiskScanEngine`. Foldere: `sizeBytes` e SUMA tuturor descendenților
/// (actualizată live pe măsură ce indexarea avansează, sau la ștergere);
/// fișiere: `sizeBytes` e mărimea proprie, `children` mereu gol.
///
/// [2026-09-04] `Codable` + `directoryModifiedAt` (nou) — arborele
/// trebuie acum să poată fi salvat pe disc (`DiskCacheStore`) și
/// reîncărcat instant la o redeschidere a aplicației, în loc să reia
/// indexarea de la zero de fiecare dată. `directoryModifiedAt` (mtime-ul
/// directorului, doar pentru foldere) e cheia scanării incrementale
/// (`DiskScanEngine.incrementalUpdate`) — un folder al cărui mtime nu s-a
/// schimbat de la ultima scanare nu are nevoie să fie recitit de pe disc,
/// subarborele lui cache-uit rămâne valabil ca atare.
public final class DiskTreeNode: Identifiable, Codable {
    public let id: UUID
    public let name: String
    public let path: String
    public let isDirectory: Bool
    public var sizeBytes: Int64 = 0
    /// Doar pentru foldere — 0 pentru fișiere (nefolosit acolo).
    public var directoryModifiedAt: Double = 0
    public var children: [String: DiskTreeNode] = [:]

    public init(name: String, path: String, isDirectory: Bool, id: UUID = UUID()) {
        self.id = id
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

    /// Numărul total de fișiere din acest subarbore — folosit doar pentru
    /// metadata cache-ului (afișat userului), calculat o singură dată la
    /// final de scanare/rescanare, niciodată pe un traseu fierbinte.
    public var totalFileCount: Int {
        isDirectory ? children.values.reduce(0) { $0 + $1.totalFileCount } : 1
    }
}
