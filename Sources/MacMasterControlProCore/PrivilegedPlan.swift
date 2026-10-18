import Foundation

/// Plan de operații privilegiate: toate pașii unei acțiuni (sau ai unei selecții) se prezintă împreună, se autorizează O SINGURĂ dată
/// (un singur apel `do shell script … with administrator privileges`, adică un singur dialog nativ de parolă/Touch ID) și se execută
/// într-un singur proces. Anularea oprește întregul plan: nu urmează alte ferestre. Parola nu este văzută, salvată sau transmisă de aplicație;
/// nu se folosește `sudo`, nu se prelungește autorizarea și nu rămâne niciun proces privilegiat după plan.
public enum PrivilegedPlan {
    public struct Step: Sendable {
        public let label: String
        /// Comandă construită de aplicație (niciodată din text liber al utilizatorului), cu argumente deja citate cu `shellQuote`.
        public let command: String
        public init(label: String, command: String) { self.label = label; self.command = command }
    }

    public struct Outcome: Sendable {
        /// Utilizatorul a refuzat planul sau dialogul de sistem a fost anulat: nimic nu s-a executat și nu se mai cere nimic.
        public let cancelled: Bool
        /// Eticheta pasului → `nil` la succes, altfel mesajul de eroare.
        public let results: [String: String?]
        public var failedLabels: [String] { results.compactMap { $0.value == nil ? nil : $0.key } }
    }

    /// Prezintă planul înainte de dialogul de sistem. Setat de aplicație (fereastră de confirmare). Fără aprobator (teste, mod fără interfață) planul se refuză.
    nonisolated(unsafe) public static var approver: (([String], String) -> Bool)?

    public static func shellQuote(_ s: String) -> String { "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'" }

    /// Căi pe care o ștergere privilegiată nu le atinge niciodată (directoare de sistem / rădăcini).
    public static func isSafeDeletePath(_ path: String) -> Bool {
        guard path.hasPrefix("/"), !path.contains("\n"), !path.contains("\0") else { return false }
        let comps = (path as NSString).standardizingPath.split(separator: "/")
        if comps.count < 2 || path.contains("/../") || path.hasSuffix("/..") { return false }
        let blocked: Set<String> = ["/System", "/Library", "/usr", "/bin", "/sbin", "/private", "/Users", "/Volumes", "/Applications", "/etc", "/var", "/opt", "/cores"]
        return !blocked.contains((path as NSString).standardizingPath)
    }

    @discardableResult
    public static func execute(title: String, steps: [Step]) -> Outcome {
        guard !steps.isEmpty else { return Outcome(cancelled: false, results: [:]) }
        let labels = steps.map(\.label)
        guard let approve = approver, approve(labels, title) else {
            DiagnosticLog.write(.info, tag: "privilege", event: "plan.declined", message: "\(steps.count)")
            return Outcome(cancelled: true, results: Dictionary(uniqueKeysWithValues: labels.map { ($0, "cancelled") }))
        }
        // Un singur script, un singur dialog. Fiecare pas își raportează singur rezultatul; un pas eșuat nu declanșează o nouă cerere.
        var script = ""
        for (i, s) in steps.enumerated() { script += "{ \(s.command) ; } >/dev/null 2>&1 && echo \"STEP\(i):OK\" || echo \"STEP\(i):FAIL\"\n" }
        let r = PrivilegedRunner.run(script, reason: title)
        if r.cancelled || (!r.success && !r.output.contains("STEP")) {
            DiagnosticLog.write(.info, tag: "privilege", event: "plan.cancelled", message: "\(steps.count)")
            return Outcome(cancelled: r.cancelled, results: Dictionary(uniqueKeysWithValues: labels.map { ($0, r.cancelled ? "cancelled" : (r.output.isEmpty ? "failed" : r.output)) }))
        }
        var results: [String: String?] = [:]
        for (i, s) in steps.enumerated() {
            results[s.label] = r.output.contains("STEP\(i):OK") ? nil : CoreL.x("pasul a eșuat chiar cu drepturi de administrator", "the step failed even with administrator rights", "el paso falló incluso con derechos de administrador")
        }
        return Outcome(cancelled: false, results: results)
    }
}
