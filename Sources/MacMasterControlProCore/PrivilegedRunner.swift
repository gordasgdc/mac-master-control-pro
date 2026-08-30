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

    @discardableResult
    public static func run(_ command: String) -> Result {
        let escaped = command.replacingOccurrences(of: "\"", with: "\\\"")
        let script = "do shell script \"\(escaped)\" with administrator privileges"
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

    /// Rulare multi-comanda (o singura solicitare de parola pentru tot lantul).
    @discardableResult
    public static func run(_ commands: [String]) -> Result {
        run(commands.joined(separator: " && "))
    }
}
