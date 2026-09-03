import Foundation

/// Executie privilegiata pentru comenzile care necesita root
/// (sysctl, networksetup, purge, tmutil, pam.d).
///
/// [2026-09-03] FIX REAL, raportat de Cristi: promptul de administrator
/// nu mai apărea DELOC (nici fereastra de sistem) — eșec instant,
/// "Promptul de administrator a fost respins", fără ca userul să apuce
/// să vadă vreo fereastră. Fix-ul anterior (mutarea `NSAppleScript` pe
/// main thread) trata doar eșecurile INTERMITENTE — asta era un eșec
/// SISTEMATIC, cauza reală fiind alta: V1 folosea `NSAppleScript`
/// IN-PROCES (`.executeAndReturnError`), care sub Hardened Runtime (
/// obligatoriu pentru notarizare) poate fi refuzat de sistem înainte
/// să ajungă la Security Agent — fără entitlement-ul de Apple Events
/// (`com.apple.security.automation.apple-events`), absent intenționat
/// din `entitlements.plist` (șablon comun, ne-sandboxat) fiindcă nu era
/// clar că această cale chiar are nevoie de el.
///
/// Root-cauza reală, confirmată direct din `GDCVault/Sources/GDCVault/
/// SelfUpdater.swift` (deja funcțional în producție, confirmat de
/// Cristi): acolo `do shell script ... with administrator privileges`
/// rulează prin `/usr/bin/osascript` ca PROCES EXTERN separat
/// (`Process`), NU prin `NSAppleScript` in-proces. Un proces extern își
/// are propria identitate TCC/Hardened-Runtime — nu moștenește restricțiile
/// binarului nostru, deci promptul nativ de parolă/Touch ID apare mereu,
/// exact ca la Terminal. Rescris identic cu acel tipar dovedit, plus
/// citirea incrementală a pipe-ului (fix-ul de deadlock din Shell.swift,
/// aplicat și aici — o comandă privilegiată poate produce output mare,
/// ex. `rm -rf` verbose pe un folder mare).
public enum PrivilegedRunner {
    public struct Result {
        public let output: String
        public let success: Bool
    }

    /// [2026-09-03] `onOutput`, daca dat, primeste comanda exacta trimisa
    /// si FIECARE linie reala de output/eroare, plus statusul final — cerut
    /// explicit de Cristi dupa ce Touch ID a continuat sa esueze identic
    /// dupa fix-ul de root-cauza: "o fereastra tip terminal in care sa
    /// ramana comenzile ce s-au incercat si eroarea... sa nu dispara
    /// fereastra". Port 1:1 al parametrului `onOutput` deja existent pe
    /// Windows (`PrivilegedRunner.cs`) — asigura ca ORICE eșec, oricât de
    /// ciudat, e vizibil și copiabil direct de user, fără să mai depindă
    /// de un mesaj static presupus de noi dinainte.
    @discardableResult
    public static func run(_ command: String, onOutput: ((String) -> Void)? = nil) -> Result {
        let escaped = command.replacingOccurrences(of: "\"", with: "\\\"")
        let script = "do shell script \"\(escaped)\" with administrator privileges"
        onOutput?("$ \(command)")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        let outputData = NSMutableData()
        let lock = NSLock()
        pipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            lock.lock()
            outputData.append(chunk)
            lock.unlock()
        }

        do {
            try process.run()
        } catch {
            pipe.fileHandleForReading.readabilityHandler = nil
            return Result(output: "Nu s-a putut porni osascript: \(error.localizedDescription)", success: false)
        }
        process.waitUntilExit()
        let remaining = pipe.fileHandleForReading.readDataToEndOfFile()
        lock.lock()
        if !remaining.isEmpty { outputData.append(remaining) }
        let resultData = outputData as Data
        lock.unlock()
        pipe.fileHandleForReading.readabilityHandler = nil

        let text = String(data: resultData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        // osascript iese cu cod nenul atat la parola gresita/prompt respins
        // (mesaj tipic "User canceled." sau eroare de autorizare in text)
        // cat si la o comanda shell care ea insasi a esuat - in ambele
        // cazuri, `success` reflecta exact ce s-a intamplat, text-ul
        // exact al erorii ramane vizibil apelantului.
        if !text.isEmpty {
            for line in text.split(separator: "\n") { onOutput?(String(line)) }
        }
        let exitCode = process.terminationStatus
        onOutput?(exitCode == 0 ? "✔ osascript a ieșit cu codul 0" : "✘ osascript a ieșit cu codul \(exitCode)")
        return Result(output: text, success: exitCode == 0)
    }

    /// Rulare multi-comanda (o singura solicitare de parola pentru tot lantul).
    @discardableResult
    public static func run(_ commands: [String]) -> Result {
        run(commands.joined(separator: " && "))
    }
}
