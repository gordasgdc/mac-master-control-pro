import Foundation

/// Executie privilegiata pentru comenzile care necesita root
/// (sysctl, networksetup, purge, tmutil, pam.d).
///
/// V1: foloseste `osascript -e 'do shell script "..." with administrator
/// privileges'` - solutia sanctionata Apple pentru GUI fara helper separat,
/// arata promptul nativ de parola/Touch ID o singura data per apel.
/// V2 (planificat): Privileged Helper via SMAppService.daemon + XPC, pentru
/// zero prompturi repetate intr-o sesiune de lucru - necesita Developer ID
/// separat pt. helper si un al doilea target semnat/notarizat in build.
public enum PrivilegedRunner {
    public struct Result {
        public let output: String
        public let success: Bool
    }

    /// [2026-09-03] FIX REAL, raportat de Cristi: "permisiune negată",
    /// intermitent - Touch ID pentru sudo functiona uneori, alteori nu,
    /// fara motiv aparent. Cauza reala: `NSAppleScript.executeAndReturnError`
    /// e documentat explicit de Apple ca NEFIIND thread-safe si trebuie
    /// apelat DOAR de pe thread-ul principal - dar toate cele 15 apeluri
    /// `PrivilegedRunner.run(...)` din aplicatie vin din
    /// `DispatchQueue.global().async` (ca sa nu blocheze UI-ul cat asteapta
    /// parola). Executia de pe un thread de fundal poate produce erori
    /// intermitente de autorizare de la Security Server (promptul nativ de
    /// parola/Touch ID e legat de rularea pe main thread), exact tiparul
    /// "cateodata merge, cateodata nu" raportat.
    /// Fix: `run` forteaza executia efectiva a AppleScript-ului pe main
    /// thread (`DispatchQueue.main.sync`, cu verificare `Thread.isMainThread`
    /// ca sa nu ne blocam singuri daca apelantul e deja pe main) - apelantii
    /// existenti raman neschimbati (tot pot chema din fundal), doar
    /// AppleScript-ul insusi ruleaza mereu unde Apple cere.
    @discardableResult
    public static func run(_ command: String) -> Result {
        let escaped = command.replacingOccurrences(of: "\"", with: "\\\"")
        let script = "do shell script \"\(escaped)\" with administrator privileges"

        func execute() -> Result {
            var error: NSDictionary?
            guard let appleScript = NSAppleScript(source: script) else {
                return Result(output: "Nu s-a putut initializa AppleScript.", success: false)
            }
            let descriptor = appleScript.executeAndReturnError(&error)
            if let error {
                let message = (error[NSAppleScript.errorMessage] as? String) ?? "Eroare necunoscuta"
                return Result(output: message, success: false)
            }
            return Result(output: descriptor.stringValue ?? "", success: true)
        }

        if Thread.isMainThread {
            return execute()
        }
        return DispatchQueue.main.sync { execute() }
    }

    /// Rulare multi-comanda (o singura solicitare de parola pentru tot lantul).
    @discardableResult
    public static func run(_ commands: [String]) -> Result {
        run(commands.joined(separator: " && "))
    }
}
