import Foundation

/// O verificare de securitate — stare + descriere scurta, afisata ca
/// punct rosu/verde in UI (standardul vizual stabilit 2026-08-31).
public struct SecurityCheck: Identifiable {
    public let id: String
    public let title: String
    public let isGood: Bool
    public let detail: String
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
        return SecurityCheck(id: "filevault", title: "FileVault (criptare disc)", isGood: on,
                              detail: on ? "Activ" : "Dezactivat — activează-l manual din System Settings ▸ Privacy & Security (cere cheie de recuperare, nu se poate automatiza sigur)")
    }

    public static func sipCheck() -> SecurityCheck {
        let output = Shell.run("csrutil status")
        let on = output.contains("enabled")
        return SecurityCheck(id: "sip", title: "System Integrity Protection", isGood: on,
                              detail: on ? "Activ" : "Dezactivat — reactivare necesită Recovery Mode, nu se poate face din aplicație")
    }

    public static func gatekeeperCheck() -> SecurityCheck {
        let output = Shell.run("spctl --status")
        let on = output.contains("assessments enabled")
        return SecurityCheck(id: "gatekeeper", title: "Gatekeeper", isGood: on,
                              detail: on ? "Activ" : "Dezactivat")
    }

    public static func firewallCheck() -> SecurityCheck {
        let output = Shell.run("defaults read /Library/Preferences/com.apple.alf globalstate 2>/dev/null")
        let state = Int(output.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        let on = state > 0
        return SecurityCheck(id: "firewall", title: "Firewall", isGood: on,
                              detail: on ? "Activ" : "Dezactivat")
    }

    public static func xprotectCheck() -> SecurityCheck {
        let output = Shell.run("system_profiler SPInstallHistoryDataType 2>/dev/null | grep -A2 XProtect | grep 'Install Date' | tail -1")
        let hasRecent = !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return SecurityCheck(id: "xprotect", title: "XProtect (semnături malware)", isGood: hasRecent,
                              detail: hasRecent ? output.trimmingCharacters(in: .whitespacesAndNewlines) : "Nu s-a putut determina ultima actualizare")
    }

    public static func screensaverPasswordCheck() -> SecurityCheck {
        let output = Shell.run("defaults read com.apple.screensaver askForPassword 2>/dev/null")
        let on = output.trimmingCharacters(in: .whitespacesAndNewlines) == "1"
        return SecurityCheck(id: "screensaver", title: "Parolă imediată la screensaver", isGood: on,
                              detail: on ? "Activ" : "Dezactivat")
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
