import Foundation

/// O verificare de securitate — stare + descriere scurta, afisata ca
/// punct rosu/verde in UI (standardul vizual stabilit 2026-08-31).
///
/// BUG REAL (raportat de Cristi, 2026-08-31: "doar imi arata rosu/verde,
/// nu ma ajuta cu nimic sa rezolv, pare ca aplicatia nu functioneaza") —
/// `manualSteps`/`settingsPane` adaugate ca sa fiecare verificare care nu
/// se poate rezolva automat (FileVault, SIP) sa arate explicit CE sa faca
/// userul, pas cu pas, plus un buton care deschide direct panoul corect
/// din System Settings — nu doar un status fara nicio actiune posibila.
public struct SecurityCheck: Identifiable {
    public let id: String
    public let title: String
    public let isGood: Bool
    public let detail: String
    /// Pasi explicativi, in ordine, pentru rezolvarea manuala — gol daca
    /// verificarea e deja OK sau se rezolva printr-un buton din "Actiuni
    /// rapide" (Firewall, Screensaver).
    public let manualSteps: [String]
    /// Identificatorul panoului System Settings de deschis (ex.
    /// "com.apple.preference.security?Privacy_FDE" pentru FileVault) —
    /// `nil` daca nu exista un pane direct (ex. SIP, care necesita
    /// Recovery Mode, nu System Settings).
    public let settingsPane: String?

    public init(id: String, title: String, isGood: Bool, detail: String, manualSteps: [String] = [], settingsPane: String? = nil) {
        self.id = id
        self.title = title
        self.isGood = isGood
        self.detail = detail
        self.manualSteps = manualSteps
        self.settingsPane = settingsPane
    }
}

/// Verificari + actiuni de securitate, bazate pe recomandarile din
/// drduh/macOS-Security-and-Privacy-Guide — DOAR verificarile/actiunile
/// automatizabile cu un buton, fara risc de blocare a Mac-ului (FileVault
/// ON, Full Security firmware, DNS/VPN/Tor raman decizii personale ale
/// userului, niciodata actiune automata dintr-un buton).
public enum SecurityService {
    public static func runAllChecks() -> [SecurityCheck] {
        [fileVaultCheck(), sipCheck(), gatekeeperCheck(), firewallCheck(), xprotectCheck(), screensaverPasswordCheck()]
    }

    public static func fileVaultCheck() -> SecurityCheck {
        let output = Shell.run("fdesetup status")
        let on = output.contains("FileVault is On")
        return SecurityCheck(
            id: "filevault", title: "FileVault (criptare disc)", isGood: on,
            detail: on ? "Activ" : "Dezactivat",
            manualSteps: on ? [] : [
                "Apasă „Deschide System Settings” mai jos — se deschide direct panoul corect.",
                "Apasă butonul „Turn On…” din dreptul FileVault.",
                "Mac-ul îți arată o cheie de recuperare (un cod lung) — NOTEAZ-O undeva sigur (ex. un manager de parole) sau alege să o salvezi în contul Apple. Fără ea, dacă uiți parola de Mac, datele devin irecuperabile.",
                "Confirmă și repornește Mac-ul când ți se cere — criptarea continuă în fundal, poți folosi Mac-ul normal cât timp se face.",
            ],
            settingsPane: "com.apple.preference.security?Privacy_FDE"
        )
    }

    public static func sipCheck() -> SecurityCheck {
        let output = Shell.run("csrutil status")
        let on = output.contains("enabled")
        return SecurityCheck(
            id: "sip", title: "System Integrity Protection", isGood: on,
            detail: on ? "Activ" : "Dezactivat",
            manualSteps: on ? [] : [
                "Nu se poate reactiva din System Settings — necesită Recovery Mode.",
                "Repornește Mac-ul ținând apăsat butonul de pornire (Apple Silicon) până apare „Loading startup options”, apoi alege Options → Continue.",
                "Din meniul de sus, deschide Terminal (Utilities → Terminal).",
                "Scrie exact: csrutil enable — apoi Enter.",
                "Repornește normal (meniul Apple → Restart).",
            ],
            settingsPane: nil
        )
    }

    public static func gatekeeperCheck() -> SecurityCheck {
        let output = Shell.run("spctl --status")
        let on = output.contains("assessments enabled")
        return SecurityCheck(
            id: "gatekeeper", title: "Gatekeeper", isGood: on,
            detail: on ? "Activ" : "Dezactivat",
            manualSteps: on ? [] : [
                "Apasă „Deschide System Settings” mai jos.",
                "La secțiunea „Allow applications from”, alege „App Store and identified developers”.",
            ],
            settingsPane: "com.apple.preference.security?General"
        )
    }

    public static func firewallCheck() -> SecurityCheck {
        let output = Shell.run("defaults read /Library/Preferences/com.apple.alf globalstate 2>/dev/null")
        let state = Int(output.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        let on = state > 0
        return SecurityCheck(
            id: "firewall", title: "Firewall", isGood: on,
            detail: on ? "Activ" : "Dezactivat — sau folosește butonul „Activează Firewall + Stealth Mode” din Acțiuni rapide, mai jos, pentru activare automată dintr-un click",
            manualSteps: on ? [] : [
                "Cel mai simplu: butonul „Activează Firewall + Stealth Mode” din secțiunea Acțiuni rapide de mai jos — un singur click, un singur prompt de parolă.",
                "Manual: „Deschide System Settings” → activează switch-ul Firewall.",
            ],
            settingsPane: "com.apple.preference.security?Firewall"
        )
    }

    public static func xprotectCheck() -> SecurityCheck {
        let output = Shell.run("system_profiler SPInstallHistoryDataType 2>/dev/null | grep -A2 XProtect | grep 'Install Date' | tail -1")
        let hasRecent = !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return SecurityCheck(
            id: "xprotect", title: "XProtect (semnături malware)", isGood: hasRecent,
            detail: hasRecent ? output.trimmingCharacters(in: .whitespacesAndNewlines) : "Nu s-a putut determina ultima actualizare",
            manualSteps: hasRecent ? [] : [
                "XProtect se actualizează automat de macOS, în fundal — nu ai nimic de apăsat.",
                "Dacă vrei să forțezi o verificare: Apple menu → System Settings → General → Software Update → apasă „i” lângă „Automatic Updates” și asigură-te că toate switch-urile sunt activate.",
            ],
            settingsPane: "com.apple.preference.softwareupdate"
        )
    }

    public static func screensaverPasswordCheck() -> SecurityCheck {
        let output = Shell.run("defaults read com.apple.screensaver askForPassword 2>/dev/null")
        let on = output.trimmingCharacters(in: .whitespacesAndNewlines) == "1"
        return SecurityCheck(
            id: "screensaver", title: "Parolă imediată la screensaver", isGood: on,
            detail: on ? "Activ" : "Dezactivat — sau folosește butonul „Cere parolă imediat la screensaver” din Acțiuni rapide, mai jos, pentru activare automată dintr-un click",
            manualSteps: on ? [] : [
                "Cel mai simplu: butonul „Cere parolă imediat la screensaver” din secțiunea Acțiuni rapide de mai jos — un singur click.",
                "Manual: „Deschide System Settings” → Lock Screen → „Require password after screen saver begins or display is turned off” → alege „Immediately”.",
            ],
            settingsPane: "com.apple.preference.security?General"
        )
    }

    // MARK: - Actiuni (un singur prompt de parola pentru toate comenzile)

    public static func enableFirewallWithStealth() {
        PrivilegedRunner.run([
            "/usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on",
            "/usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on",
            "/usr/libexec/ApplicationFirewall/socketfilterfw --setallowsigned off",
        ])
    }

    public static func requirePasswordImmediatelyAtScreensaver() {
        Shell.run("defaults write com.apple.screensaver askForPassword -int 1; defaults write com.apple.screensaver askForPasswordDelay -int 0")
    }
}
