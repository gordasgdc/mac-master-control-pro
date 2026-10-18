import Foundation

/// Pachet de diagnostic local (OBSERVABILITY_STANDARD): ZIP inspectabil, redactat,
/// creat doar la cererea utilizatorului. Nu se incarca nimic automat.
public enum DiagnosticExport {
    public struct Item: Identifiable {
        public let id = UUID()
        public let name: String
        public let bytes: Int
        public let note: String
    }

    /// Continutul exact al pachetului (pentru previzualizare), fara a scrie nimic.
    public static func preview() -> [Item] {
        DiagnosticLog.flush()
        var items = [Item(name: "manifest.json", bytes: manifest().count, note: "versiune, platforma, sesiune, ora")]
        for url in logFiles() {
            let size = (try? Data(contentsOf: url).count) ?? 0
            items.append(Item(name: "logs/" + url.lastPathComponent, bytes: size, note: "redactat (parole, emailuri, calea home)"))
        }
        return items
    }

    /// Construieste ZIP-ul in `destinationFolder`; intoarce calea. Redactarea se aplica din nou la export.
    public static func export(to destinationFolder: URL) throws -> URL {
        DiagnosticLog.flush()
        let fm = FileManager.default
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let name = "MasterControlStudioPro-diagnostic-\(DiagnosticLog.appVersion)-\(stamp)"
        let staging = fm.temporaryDirectory.appendingPathComponent(name, isDirectory: true)
        try? fm.removeItem(at: staging)
        try fm.createDirectory(at: staging.appendingPathComponent("logs"), withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: staging) }

        try manifest().write(to: staging.appendingPathComponent("manifest.json"))
        for url in logFiles() {
            let raw = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            try DiagnosticLog.redact(raw).write(to: staging.appendingPathComponent("logs/" + url.lastPathComponent),
                                                atomically: true, encoding: .utf8)
        }
        let zip = destinationFolder.appendingPathComponent(name + ".zip")
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        p.arguments = ["-c", "-k", "--keepParent", staging.path, zip.path]
        try p.run(); p.waitUntilExit()
        guard p.terminationStatus == 0 else {
            throw NSError(domain: "DiagnosticExport", code: Int(p.terminationStatus),
                          userInfo: [NSLocalizedDescriptionKey: "ditto a esuat"])
        }
        DiagnosticLog.write(.info, tag: "diag", event: "export.done", result: "ok")
        return zip
    }

    static func logFiles() -> [URL] {
        let fm = FileManager.default
        let names = (try? fm.contentsOfDirectory(atPath: DiagnosticLog.directory.path)) ?? []
        return names.filter { $0.hasPrefix("mcsp.log") }.sorted().map { DiagnosticLog.directory.appendingPathComponent($0) }
    }

    static func manifest() -> Data {
        let info = ProcessInfo.processInfo
        let obj: [String: Any] = [
            "app": "Master Control Studio Pro", "version": DiagnosticLog.appVersion, "platform": "macos",
            "os": info.operatingSystemVersionString, "session": DiagnosticLog.sessionID,
            "generated": ISO8601DateFormatter().string(from: Date()),
            "contents": "log-uri redactate; fara continutul fisierelor, fara chei de licenta, fara parole",
        ]
        return (try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys])) ?? Data()
    }
}
