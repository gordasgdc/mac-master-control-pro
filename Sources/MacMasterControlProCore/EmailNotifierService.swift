import Foundation

/// Setari SMTP pentru notificare automata pe email (2026-08-31, cerut
/// explicit de Cristi dupa notificarea nativa pe ecran - "nu vad sa pun nr
/// de telefon" - WhatsApp NU poate trimite automat fara click manual
/// (doar deschide o conversatie pre-completata, la fel ca la licentiere),
/// email e singura varianta cu adevarat automata catre telefon).
/// **Parola in Keychain** (nu in UserDefaults); UI recomanda "parola de
/// aplicatie" (App Password), NU parola reala a contului.
public struct EmailNotifierSettings: Codable {
    public var enabled: Bool = false
    public var smtpHost: String = "smtp.gmail.com"
    public var smtpPort: Int = 587
    public var username: String = ""
    public var appPassword: String = ""
    public var recipient: String = ""
}

public enum EmailNotifierService {
    private static let key = "MacMasterControlPro.emailNotifierSettings"

    private static let passwordAccount = "smtp.appPassword"

    /// Parola sta in Keychain (SecretStore); in UserDefaults se salveaza doar
    /// restul setarilor. Valorile vechi, in clar, se migreaza la prima citire
    /// si se sterg din UserDefaults (fara pierderea configuratiei).
    public static var settings: EmailNotifierSettings {
        get {
            guard let data = AppProfile.defaults.data(forKey: key),
                  var decoded = try? JSONDecoder().decode(EmailNotifierSettings.self, from: data)
            else {
                var s = EmailNotifierSettings()
                s.appPassword = SecretStore.get(account: passwordAccount) ?? ""
                return s
            }
            if !decoded.appPassword.isEmpty {
                // Migrare din stocarea veche (in clar).
                if SecretStore.set(decoded.appPassword, account: passwordAccount) {
                    var scrubbed = decoded
                    scrubbed.appPassword = ""
                    if let clean = try? JSONEncoder().encode(scrubbed) { AppProfile.defaults.set(clean, forKey: key) }
                    DiagnosticLog.write(.info, tag: "secrets", event: "smtp.migrated", result: "ok")
                } else {
                    DiagnosticLog.write(.error, tag: "secrets", event: "smtp.migrated", result: "keychain-failed")
                }
            } else {
                decoded.appPassword = SecretStore.get(account: passwordAccount) ?? ""
            }
            return decoded
        }
        set {
            SecretStore.set(newValue.appPassword, account: passwordAccount)
            var stored = newValue
            stored.appPassword = ""
            if let data = try? JSONEncoder().encode(stored) {
                AppProfile.defaults.set(data, forKey: key)
            }
        }
    }

    /// Trimite prin `curl` (preinstalat pe orice Mac) - evita implementarea
    /// manuala a protocolului SMTP (AUTH LOGIN, STARTTLS etc.), foloseste
    /// acelasi tipar "shell out la un tool de sistem" ca restul aplicatiei
    /// (rclone, brew). `--ssl-reqd` forteaza STARTTLS pe conexiunea plain
    /// (port 587, tipic Gmail/Outlook).
    @discardableResult
    public static func send(subject: String, body: String) -> (ok: Bool, error: String?) {
        let s = settings
        guard s.enabled else { return (false, "Notificarea pe email e dezactivată.") }
        guard !s.username.isEmpty, !s.appPassword.isEmpty, !s.recipient.isEmpty else {
            return (false, "Completează email, parolă de aplicație și destinatar în Setări.")
        }

        let message = "From: \(s.username)\r\nTo: \(s.recipient)\r\nSubject: \(subject)\r\n\r\n\(body)\r\n"
        let tmpFile = NSTemporaryDirectory() + "mmc_email_\(UUID().uuidString).eml"
        do {
            try message.write(toFile: tmpFile, atomically: true, encoding: .utf8)
        } catch {
            return (false, "Nu s-a putut scrie mesajul temporar: \(error.localizedDescription)")
        }
        defer { try? FileManager.default.removeItem(atPath: tmpFile) }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
        process.arguments = [
            "--silent", "--show-error",
            "smtp://\(s.smtpHost):\(s.smtpPort)",
            "--ssl-reqd",
            "--mail-from", s.username,
            "--mail-rcpt", s.recipient,
            "--upload-file", tmpFile,
            "--max-time", "60",
            "-K", "-",
        ]
        let stdin = Pipe()
        let pipe = Pipe()
        process.standardInput = stdin
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            // Credentialele merg pe stdin (nu in argv, vizibil in `ps`).
            let cfgUser = "\(s.username):\(s.appPassword)".replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
            stdin.fileHandleForWriting.write(Data("user = \"\(cfgUser)\"\n".utf8))
            try? stdin.fileHandleForWriting.close()
            let op = DiagnosticLog.begin("email", "send")
            process.waitUntilExit()
            op.end(process.terminationStatus == 0 ? "ok" : "fail", level: process.terminationStatus == 0 ? .info : .warning,
                   fields: ["exit": String(process.terminationStatus)])
            if process.terminationStatus == 0 { return (true, nil) }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return (false, String(data: data, encoding: .utf8) ?? "curl a eșuat (cod \(process.terminationStatus)).")
        } catch {
            return (false, "Nu s-a putut porni curl: \(error.localizedDescription)")
        }
    }
}
