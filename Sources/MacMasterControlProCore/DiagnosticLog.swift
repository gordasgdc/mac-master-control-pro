import Foundation
import OSLog

/// Jurnal de diagnostic local (OBSERVABILITY_STANDARD, Regulile 25/39).
/// - os_log (subsystem = bundle ID) + fisier rotativ in `~/Library/Logs/MasterControlStudioPro/`.
/// - Linie = un obiect JSON: timestamp cu fus, nivel, subsistem, event, sesiune, operatie, faza, durata, rezultat.
/// - Redactare INAINTE de scriere: parole, tokenuri, chei de licenta, emailuri, calea home.
/// - Loggerul nu arunca niciodata si nu blocheaza apelantul (coada seriala proprie).
public enum DiagnosticLog {
    public enum Level: String, Comparable {
        case trace, debug, info, warning, error, critical
        private var rank: Int { [Level.trace, .debug, .info, .warning, .error, .critical].firstIndex(of: self)! }
        public static func < (a: Level, b: Level) -> Bool { a.rank < b.rank }
    }

    public static let subsystem = "com.gordasgdc.macmastercontrolpro"
    public static let sessionID = String(UUID().uuidString.prefix(8)).lowercased()
    /// Rotire: fisier activ + `.1` ... `.3`, maxim ~5 MB fiecare (~20 MB total).
    static let maxFileBytes = 5_000_000
    static let keepArchives = 3

    nonisolated(unsafe) static var directoryOverride: URL?
    nonisolated(unsafe) public static var minimumLevel: Level = .info
    private static let queue = DispatchQueue(label: "com.gordasgdc.macmastercontrolpro.diaglog", qos: .utility)
    private static let osLogger = Logger(subsystem: subsystem, category: "app")

    public static var directory: URL {
        directoryOverride ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/MasterControlStudioPro", isDirectory: true)
    }
    public static var activeFile: URL { directory.appendingPathComponent("mcsp.log") }

    public static var appVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "dev"
    }

    // MARK: - Scriere

    public static func write(_ level: Level = .info, tag: String, event: String, message: String = "",
                             op: String? = nil, phase: String? = nil, durationMs: Int? = nil,
                             result: String? = nil, fields: [String: String] = [:]) {
        guard level >= minimumLevel else { return }
        var obj: [String: Any] = [
            "ts": isoFormatter.string(from: Date()), "lvl": level.rawValue, "sub": tag, "evt": event,
            "ses": sessionID, "ver": appVersion, "plat": "macos",
        ]
        if !message.isEmpty { obj["msg"] = redact(message) }
        if let op { obj["op"] = op }
        if let phase { obj["phase"] = phase }
        if let durationMs { obj["ms"] = durationMs }
        if let result { obj["res"] = result }
        for (k, v) in fields { obj["f_" + k] = redact(v) }
        osLogger.log(level: osLevel(level), "[\(tag, privacy: .public)] \(event, privacy: .public)")
        queue.async { append(obj) }
    }

    /// Asteapta golirea cozii (teste, inchiderea aplicatiei, export).
    public static func flush() { queue.sync {} }

    private static func append(_ obj: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: obj, options: [.sortedKeys]) else { return }
        let fm = FileManager.default
        do {
            try fm.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = activeFile
            if let attrs = try? fm.attributesOfItem(atPath: url.path),
               let size = attrs[.size] as? Int, size + data.count > maxFileBytes {
                rotate()
            }
            if !fm.fileExists(atPath: url.path) { fm.createFile(atPath: url.path, contents: nil, attributes: [.posixPermissions: 0o600]) }
            let h = try FileHandle(forWritingTo: url)
            defer { try? h.close() }
            try h.seekToEnd()
            try h.write(contentsOf: data + Data([0x0A]))
        } catch {
            // Fallback sigur: eroarea loggerului nu afecteaza operatia principala.
            osLogger.error("diaglog write failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func rotate() {
        let fm = FileManager.default
        let base = activeFile
        try? fm.removeItem(at: base.appendingPathExtension("\(keepArchives)"))
        for i in stride(from: keepArchives - 1, through: 1, by: -1) {
            try? fm.moveItem(at: base.appendingPathExtension("\(i)"), to: base.appendingPathExtension("\(i + 1)"))
        }
        try? fm.moveItem(at: base, to: base.appendingPathExtension("1"))
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds, .withTimeZone]
        f.timeZone = .current
        return f
    }()

    private static func osLevel(_ l: Level) -> OSLogType {
        switch l {
        case .trace, .debug: return .debug
        case .info: return .info
        case .warning: return .default
        case .error: return .error
        case .critical: return .fault
        }
    }

    // MARK: - Redactare

    /// Redacteaza secrete si date personale. `paths: true` (implicit pentru
    /// pachetul de suport) inlocuieste si numele de utilizator din cai.
    public static func redact(_ text: String, paths: Bool = true) -> String {
        var s = text
        for (pattern, repl) in redactionRules {
            s = s.replacingOccurrences(of: pattern, with: repl, options: .regularExpression)
        }
        if paths {
            s = s.replacingOccurrences(of: NSHomeDirectory(), with: "~")
            s = s.replacingOccurrences(of: "/Users/[^/\\s\"]+", with: "/Users/<user>", options: .regularExpression)
        }
        return s
    }

    private static let redactionRules: [(String, String)] = [
        ("(?i)(password|passwd|pass|secret|token|apikey|api_key|client_secret|authorization)([\"']?\\s*[:=]\\s*[\"']?)[^\\s\"',;&]+", "$1$2<redacted>"),
        ("(?i)--user[ =]\\S+", "--user <redacted>"),
        ("(?i)bearer\\s+[A-Za-z0-9._\\-]+", "Bearer <redacted>"),
        ("[A-Za-z0-9._%+\\-]+@[A-Za-z0-9.\\-]+\\.[A-Za-z]{2,}", "<email>"),
        // serial de licenta GDC (blocuri lungi base32/hex/base64url) si orice sir opac >= 32 caractere
        ("[A-Za-z0-9_\\-]{32,}", "<opaque>"),
        ("[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}", "<uuid>"),
    ]

    // MARK: - Operatii

    /// Operatie corelata: id scurt, faze, durata, rezultat.
    public final class Operation {
        public let id = String(UUID().uuidString.prefix(8)).lowercased()
        public let tag: String
        public let name: String
        private let start = Date()
        private let lock = NSLock()
        private var ended = false

        init(tag: String, name: String, fields: [String: String]) {
            self.tag = tag; self.name = name
            DiagnosticLog.write(.info, tag: tag, event: "\(name).start", op: id, phase: "start", fields: fields)
        }
        public func phase(_ phase: String, message: String = "", fields: [String: String] = [:]) {
            DiagnosticLog.write(.info, tag: tag, event: "\(name).phase", message: message, op: id, phase: phase,
                                durationMs: elapsedMs, fields: fields)
        }
        public func progress(items: Int, bytes: Int64? = nil, errors: Int = 0) {
            var f = ["items": String(items), "errors": String(errors)]
            if let bytes { f["bytes"] = String(bytes) }
            DiagnosticLog.write(.debug, tag: tag, event: "\(name).progress", op: id, phase: "run", durationMs: elapsedMs, fields: f)
        }
        public func end(_ result: String, level: Level = .info, message: String = "", fields: [String: String] = [:]) {
            lock.lock(); let already = ended; ended = true; lock.unlock()
            guard !already else { return }
            DiagnosticLog.write(level, tag: tag, event: "\(name).end", message: message, op: id, phase: "end",
                                durationMs: elapsedMs, result: result, fields: fields)
        }
        private var elapsedMs: Int { Int(Date().timeIntervalSince(start) * 1000) }
    }

    public static func begin(_ tag: String, _ name: String, fields: [String: String] = [:]) -> Operation {
        Operation(tag: tag, name: name, fields: fields)
    }
}
