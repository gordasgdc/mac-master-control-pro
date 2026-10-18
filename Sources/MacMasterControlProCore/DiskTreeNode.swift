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
    /// Dimensiunea LOGICA (st_size), suma pe subarbore la foldere.
    public var sizeBytes: Int64 = 0
    /// Spatiul ALOCAT pe disc (st_blocks * 512): fisierele sparse, comprimate APFS sau
    /// "doar in cloud" (dataless) ocupa mult mai putin decat dimensiunea logica. Clonele APFS
    /// partajate nu pot fi distinse prin st_blocks (raportate la fel ca fisierele normale).
    /// 0 si pentru cache-urile vechi pana la prima reconciliere verificata.
    public var allocatedBytes: Int64 = 0
    /// Doar fisiere: mtime in nanosecunde (0 = necunoscut).
    public var modifiedAtNs: Int64 = 0
    /// Doar foldere: amprenta (nume, mărime, alocat, mtime) a fisierelor DIRECTE ale folderului,
    /// calculata la scanare, inainte de agregarea fisierelor mici. 0 = necunoscuta.
    /// Permite scanarii verificate sa detecteze modificari in-loc, inclusiv pentru fisierele agregate.
    public var filesFingerprint: Int64 = 0
    /// Doar pentru foldere — 0 pentru fișiere (nefolosit acolo).
    public var directoryModifiedAt: Double = 0
    public var children: [String: DiskTreeNode] = [:]

    /// [2026-09-11] Nod AGREGAT: reprezintă N fișiere mici dintr-un folder,
    /// nu un fișier real de pe disc. Vezi `DiskTreeNode.collapseSmallFiles`.
    /// Nu are cale reală, deci nu poate fi șters și nu se poate intra în el.
    public var aggregatedFileCount: Int = 0
    public var isAggregate: Bool { aggregatedFileCount > 0 }

    public init(name: String, path: String, isDirectory: Bool, id: UUID = UUID()) {
        self.id = id
        self.name = name
        self.path = path
        self.isDirectory = isDirectory
    }

    // Codable manual: cache-urile vechi nu contin campurile noi (decodeIfPresent), deci raman valide.
    private enum CodingKeys: String, CodingKey {
        case id, name, path, isDirectory, sizeBytes, allocatedBytes, modifiedAtNs, filesFingerprint
        case directoryModifiedAt, children, aggregatedFileCount
    }

    public required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        path = try c.decode(String.self, forKey: .path)
        isDirectory = try c.decode(Bool.self, forKey: .isDirectory)
        sizeBytes = try c.decodeIfPresent(Int64.self, forKey: .sizeBytes) ?? 0
        allocatedBytes = try c.decodeIfPresent(Int64.self, forKey: .allocatedBytes) ?? 0
        modifiedAtNs = try c.decodeIfPresent(Int64.self, forKey: .modifiedAtNs) ?? 0
        filesFingerprint = try c.decodeIfPresent(Int64.self, forKey: .filesFingerprint) ?? 0
        directoryModifiedAt = try c.decodeIfPresent(Double.self, forKey: .directoryModifiedAt) ?? 0
        children = try c.decodeIfPresent([String: DiskTreeNode].self, forKey: .children) ?? [:]
        aggregatedFileCount = try c.decodeIfPresent(Int.self, forKey: .aggregatedFileCount) ?? 0
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id); try c.encode(name, forKey: .name); try c.encode(path, forKey: .path)
        try c.encode(isDirectory, forKey: .isDirectory); try c.encode(sizeBytes, forKey: .sizeBytes)
        try c.encode(allocatedBytes, forKey: .allocatedBytes)
        if modifiedAtNs != 0 { try c.encode(modifiedAtNs, forKey: .modifiedAtNs) }
        if filesFingerprint != 0 { try c.encode(filesFingerprint, forKey: .filesFingerprint) }
        try c.encode(directoryModifiedAt, forKey: .directoryModifiedAt)
        try c.encode(children, forKey: .children)
        try c.encode(aggregatedFileCount, forKey: .aggregatedFileCount)
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
        // Un nod agregat reprezintă mai multe fișiere reale — numărul lor
        // trebuie păstrat, altfel totalul afișat userului ar scădea brusc
        // după agregare și ar părea că au dispărut fișiere.
        if isAggregate { return aggregatedFileCount }
        return isDirectory ? children.values.reduce(0) { $0 + $1.totalFileCount } : 1
    }
}

// MARK: - Agregarea fișierelor mici (2026-09-11)

public extension DiskTreeNode {
    /// Pragul sub care un fișier nu mai e păstrat individual în arbore.
    /// 1 MB: pe un volum de lucru video, un fișier sub 1 MB nu contează
    /// practic niciodată într-o analiză de spațiu — dar ASEMENEA fișiere sunt
    /// marea majoritate ca NUMĂR, deci ele umflau arborele.
    static let smallFileThreshold: Int64 = 1_048_576

    /// Înlocuiește, în fiecare folder, fișierele sub prag cu UN SINGUR nod
    /// „Alte fișiere mici (N)".
    ///
    /// De ce era nevoie (măsurat, nu presupus): cache-ul unui volum de 4 TB
    /// ajunsese la 2,4 GB, fiindcă se reținea fiecare fișier ca nod separat.
    /// Compresia a redus fișierul de pe disc, dar la încărcare arborele tot
    /// ajungea întreg în RAM. Aici se reduce numărul de noduri la sursă.
    ///
    /// Garanții — ce NU se schimbă pentru user:
    ///   - `sizeBytes` al fiecărui folder rămâne EXACT același (nodul agregat
    ///     poartă suma fișierelor pe care le înlocuiește);
    ///   - `totalFileCount` rămâne exact același (vezi `aggregatedFileCount`);
    ///   - structura de FOLDERE e neatinsă — se agregă doar fișiere;
    ///   - un folder cu un singur fișier mic nu câștigă nimic din agregare,
    ///     deci acela rămâne vizibil ca atare (evită „Alte fișiere mici (1)",
    ///     care ar fi doar mai puțin informativ decât numele real).
    @discardableResult
    func collapseSmallFiles(threshold: Int64 = DiskTreeNode.smallFileThreshold, recursive: Bool = true) -> Int {
        guard isDirectory else { return 0 }

        var removedNodes = 0
        var smallTotalBytes: Int64 = 0
        var smallAllocated: Int64 = 0
        var smallCount = 0
        var keys: [String] = []

        for (key, child) in children where !child.isDirectory && !child.isAggregate {
            if child.sizeBytes < threshold {
                smallTotalBytes += child.sizeBytes
                smallAllocated += child.allocatedBytes
                smallCount += 1
                keys.append(key)
            }
        }

        // Sub 2 fișiere nu are rost: n-am câștiga niciun nod, doar am ascunde
        // un nume real în spatele unei etichete generice.
        if smallCount >= 2 {
            for key in keys { children.removeValue(forKey: key) }
            let label = "Alte fișiere mici (\(smallCount))"
            let node = DiskTreeNode(name: label, path: path, isDirectory: false)
            node.sizeBytes = smallTotalBytes
            node.allocatedBytes = smallAllocated
            node.aggregatedFileCount = smallCount
            children[label] = node
            removedNodes += smallCount - 1
        }

        if recursive {
            for child in children.values where child.isDirectory {
                removedNodes += child.collapseSmallFiles(threshold: threshold)
            }
        }
        return removedNodes
    }
}
