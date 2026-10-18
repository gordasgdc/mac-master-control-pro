import Foundation

/// Starea sistemului ÎNAINTE de Modul Randare. Se salvează pe disc înainte de orice modificare,
/// ca dezactivarea să readucă exact ce era (nu să activeze forțat ce utilizatorul avea oprit)
/// și ca o închidere forțată să nu lase sistemul modificat fără urmă.
public struct RenderModeSnapshot: Codable, Equatable {
    public var createdAt: Date
    /// nil = necunoscut (nu se modifică).
    public var timeMachineAutoBackup: Bool?
    /// punct de montare -> indexarea Spotlight era activă
    public var spotlight: [String: Bool]
    /// pid -> valoarea `nice` de dinainte
    public var nice: [Int32: Int]
    public init(createdAt: Date = Date(), timeMachineAutoBackup: Bool?, spotlight: [String: Bool], nice: [Int32: Int]) {
        self.createdAt = createdAt; self.timeMachineAutoBackup = timeMachineAutoBackup
        self.spotlight = spotlight; self.nice = nice
    }
}

public enum RenderModeState {
    /// Parsează `mdutil -a -s`: "/path:\n\tIndexing enabled." — doar "enabled"/"disabled" clare;
    /// orice altă stare ("Error", "No index") se omite (necunoscut => nu se atinge).
    public static func parseMdutil(_ output: String) -> [String: Bool] {
        var result: [String: Bool] = [:]
        var current: String?
        for raw in output.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = String(raw)
            if !line.hasPrefix("\t") && !line.hasPrefix(" ") && line.hasSuffix(":") {
                current = String(line.dropLast())
            } else if let c = current {
                let t = line.trimmingCharacters(in: .whitespaces).lowercased()
                if t.hasPrefix("indexing enabled") { result[c] = true }
                else if t.hasPrefix("indexing disabled") || t.hasPrefix("indexing and searching disabled") { result[c] = false }
            }
        }
        return result
    }

    public static func parseAutoBackup(_ output: String) -> Bool? {
        switch output.trimmingCharacters(in: .whitespacesAndNewlines) {
        case "1": return true
        case "0": return false
        default: return nil
        }
    }

    /// Comenzile de activare: doar pentru ce era ACTIV acum.
    public static func activationCommands(_ s: RenderModeSnapshot) -> [String] {
        var c: [String] = []
        if s.timeMachineAutoBackup == true { c.append("tmutil disable") }
        for (vol, on) in s.spotlight.sorted(by: { $0.key < $1.key }) where on { c.append("mdutil -i off \(shellQuote(vol))") }
        for pid in s.nice.keys.sorted() { c.append("renice -n -15 -p \(pid)") }
        return c
    }

    /// Comenzile de restaurare: exact ce a fost schimbat.
    public static func restoreCommands(_ s: RenderModeSnapshot) -> [String] {
        var c: [String] = []
        if s.timeMachineAutoBackup == true { c.append("tmutil enable") }
        for (vol, on) in s.spotlight.sorted(by: { $0.key < $1.key }) where on { c.append("mdutil -i on \(shellQuote(vol))") }
        for (pid, nice) in s.nice.sorted(by: { $0.key < $1.key }) { c.append("renice -n \(nice) -p \(pid) 2>/dev/null || true") }
        return c
    }

    /// Rezumat pentru previzualizare, înainte de activare.
    public static func changeSummary(_ s: RenderModeSnapshot) -> [String] {
        var l: [String] = []
        switch s.timeMachineAutoBackup {
        case true?: l.append("Time Machine: copiile automate se opresc (se repornesc la dezactivare).")
        case false?: l.append("Time Machine: deja oprit, rămâne neschimbat.")
        case nil: l.append("Time Machine: stare necunoscută, nu se modifică.")
        }
        let on = s.spotlight.filter { $0.value }.keys.sorted()
        l.append(on.isEmpty ? "Spotlight: nicio indexare activă de oprit." : "Spotlight: indexarea se oprește pe \(on.count) volum(e): \(on.joined(separator: ", ")).")
        l.append(s.nice.isEmpty ? "Prioritate: nicio aplicație de randare cunoscută nu rulează." : "Prioritate: \(s.nice.count) proces(e) trec la prioritate mare; valorile vechi se restaurează.")
        return l
    }

    static func shellQuote(_ s: String) -> String { "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'" }

    // MARK: - Persistență (atomic, în Application Support)
    public static var snapshotURL: URL {
        AppProfile.supportDirectory.appendingPathComponent("RenderModeSnapshot.json")
    }
    public static func saveSnapshot(_ s: RenderModeSnapshot, to url: URL = snapshotURL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(s).write(to: url, options: .atomic)
    }
    public static func loadSnapshot(from url: URL = snapshotURL) -> RenderModeSnapshot? {
        guard let d = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(RenderModeSnapshot.self, from: d)
    }
    public static func clearSnapshot(at url: URL = snapshotURL) { try? FileManager.default.removeItem(at: url) }
}
