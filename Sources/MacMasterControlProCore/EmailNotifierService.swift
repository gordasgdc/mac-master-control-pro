import Foundation

/// Setari SMTP pentru notificare automata pe email (2026-08-31, cerut
/// explicit de Cristi dupa notificarea nativa pe ecran - "nu vad sa pun nr
/// de telefon" - WhatsApp NU poate trimite automat fara click manual
/// (doar deschide o conversatie pre-completata, la fel ca la licentiere),
/// email e singura varianta cu adevarat automata catre telefon).
/// **Stocare LOCALA, in clar** (UserDefaults) - la fel ca parola dintr-un
/// `rclone.conf` sau alt config local din acest ecosistem; recomanda
/// explicit in UI o "parola de aplicatie" (App Password), NU parola reala
/// a contului, exact pentru cazul in care acest fisier ar fi vreodata citit.
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

    public static var settings: EmailNotifierSettings {
        get {
            guard let data = UserDefaults.standard.data(forKey: key),
                  let decoded = try? JSONDecoder().decode(EmailNotifierSettings.self, from: data)
            else { return EmailNotifierSettings() }
            return decoded
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: key)
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
            "--user", "\(s.username):\(s.appPassword)",
        ]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 { return (true, nil) }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return (false, String(data: data, encoding: .utf8) ?? "curl a eșuat (cod \(process.terminationStatus)).")
        } catch {
            return (false, "Nu s-a putut porni curl: \(error.localizedDescription)")
        }
    }
}
