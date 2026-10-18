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
            detail: on ? CoreL.x("Activ", "On", "Activo") : CoreL.x("Dezactivat", "Off", "Desactivado"),
            manualSteps: on ? [] : [
                CoreL.x("Apasă „Deschide System Settings” mai jos — se deschide direct panoul corect.", "Press “Open System Settings” below — it opens the right pane directly.", "Pulsa «Abrir Ajustes del Sistema» abajo: abre directamente el panel correcto."),
                CoreL.x("Apasă butonul „Turn On…” din dreptul FileVault.", "Press the “Turn On…” button next to FileVault.", "Pulsa el botón «Turn On…» junto a FileVault."),
                CoreL.x("Mac-ul îți arată o cheie de recuperare (un cod lung) — NOTEAZ-O undeva sigur (ex. un manager de parole) sau alege să o salvezi în contul Apple. Fără ea, dacă uiți parola de Mac, datele devin irecuperabile.", "Your Mac shows a recovery key (a long code) — WRITE IT DOWN somewhere safe (e.g. a password manager) or choose to save it to your Apple account. Without it, if you forget your Mac password, the data becomes unrecoverable.", "El Mac muestra una clave de recuperación (un código largo): ANÓTALA en un lugar seguro (p. ej. un gestor de contraseñas) o elige guardarla en tu cuenta de Apple. Sin ella, si olvidas la contraseña del Mac, los datos serán irrecuperables."),
                CoreL.x("Confirmă și repornește Mac-ul când ți se cere — criptarea continuă în fundal, poți folosi Mac-ul normal cât timp se face.", "Confirm and restart your Mac when asked — encryption continues in the background, and you can use your Mac normally meanwhile.", "Confirma y reinicia el Mac cuando se te pida: el cifrado continúa en segundo plano y puedes usar el Mac con normalidad mientras tanto."),
            ],
            settingsPane: "com.apple.preference.security?Privacy_FDE"
        )
    }

    public static func sipCheck() -> SecurityCheck {
        let output = Shell.run("csrutil status")
        let on = output.contains("enabled")
        return SecurityCheck(
            id: "sip", title: "System Integrity Protection", isGood: on,
            detail: on ? CoreL.x("Activ", "On", "Activo") : CoreL.x("Dezactivat", "Off", "Desactivado"),
            manualSteps: on ? [] : [
                CoreL.x("Nu se poate reactiva din System Settings — necesită Recovery Mode.", "It cannot be re-enabled from System Settings — it needs Recovery Mode.", "No se puede reactivar desde Ajustes del Sistema: requiere el modo de recuperación."),
                CoreL.x("Repornește Mac-ul ținând apăsat butonul de pornire (Apple Silicon) până apare „Loading startup options”, apoi alege Options → Continue.", "Restart your Mac holding the power button (Apple silicon) until “Loading startup options” appears, then choose Options → Continue.", "Reinicia el Mac manteniendo pulsado el botón de encendido (Apple silicon) hasta que aparezca «Loading startup options»; luego elige Options → Continue."),
                CoreL.x("Din meniul de sus, deschide Terminal (Utilities → Terminal).", "From the top menu, open Terminal (Utilities → Terminal).", "En el menú superior, abre Terminal (Utilities → Terminal)."),
                "Scrie exact: csrutil enable — apoi Enter.",
                CoreL.x("Repornește normal (meniul Apple → Restart).", "Restart normally (Apple menu → Restart).", "Reinicia con normalidad (menú Apple → Restart)."),
            ],
            settingsPane: nil
        )
    }

    public static func gatekeeperCheck() -> SecurityCheck {
        let output = Shell.run("spctl --status")
        let on = output.contains("assessments enabled")
        return SecurityCheck(
            id: "gatekeeper", title: "Gatekeeper", isGood: on,
            detail: on ? CoreL.x("Activ", "On", "Activo") : CoreL.x("Dezactivat", "Off", "Desactivado"),
            manualSteps: on ? [] : [
                CoreL.x("Apasă „Deschide System Settings” mai jos.", "Press “Open System Settings” below.", "Pulsa «Abrir Ajustes del Sistema» abajo."),
                CoreL.x("La secțiunea „Allow applications from”, alege „App Store and identified developers”.", "In the “Allow applications from” section, choose “App Store and identified developers”.", "En la sección «Allow applications from», elige «App Store and identified developers»."),
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
            detail: on ? CoreL.x("Activ", "On", "Activo") : CoreL.x("Dezactivat — sau folosește butonul „Activează Firewall + Stealth Mode” din Acțiuni rapide, mai jos, pentru activare automată dintr-un click", "Off — or use the “Enable Firewall + Stealth Mode” button in Quick actions below to turn it on with one click", "Desactivado; o usa el botón «Activar el cortafuegos + modo sigilo» de Acciones rápidas, abajo, para activarlo con un clic"),
            manualSteps: on ? [] : [
                CoreL.x("Cel mai simplu: butonul „Activează Firewall + Stealth Mode” din secțiunea Acțiuni rapide de mai jos — un singur click, un singur prompt de parolă.", "Simplest: the “Enable Firewall + Stealth Mode” button in the Quick actions section below — one click, one password prompt.", "Lo más sencillo: el botón «Activar el cortafuegos + modo sigilo» de la sección Acciones rápidas de abajo; un clic y una sola petición de contraseña."),
                CoreL.x("Manual: „Deschide System Settings” → activează switch-ul Firewall.", "Manual: “Open System Settings” → turn on the Firewall switch.", "Manual: «Abrir Ajustes del Sistema» → activa el interruptor del cortafuegos."),
            ],
            settingsPane: "com.apple.preference.security?Firewall"
        )
    }

    public static func xprotectCheck() -> SecurityCheck {
        let output = Shell.run("system_profiler SPInstallHistoryDataType 2>/dev/null | grep -A2 XProtect | grep 'Install Date' | tail -1")
        let hasRecent = !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return SecurityCheck(
            id: "xprotect", title: CoreL.x("XProtect (semnături malware)", "XProtect (malware signatures)", "XProtect (firmas de malware)"), isGood: hasRecent,
            detail: hasRecent ? output.trimmingCharacters(in: .whitespacesAndNewlines) : CoreL.x("Nu s-a putut determina ultima actualizare", "Could not determine the last update", "No se pudo determinar la última actualización"),
            manualSteps: hasRecent ? [] : [
                CoreL.x("XProtect se actualizează automat de macOS, în fundal — nu ai nimic de apăsat.", "XProtect is updated automatically by macOS in the background — there is nothing to press.", "macOS actualiza XProtect automáticamente en segundo plano; no tienes que pulsar nada."),
                CoreL.x("Dacă vrei să forțezi o verificare: Apple menu → System Settings → General → Software Update → apasă „i” lângă „Automatic Updates” și asigură-te că toate switch-urile sunt activate.", "To force a check: Apple menu → System Settings → General → Software Update → press “i” next to “Automatic Updates” and make sure all switches are on.", "Para forzar una comprobación: menú Apple → System Settings → General → Software Update → pulsa «i» junto a «Automatic Updates» y asegúrate de que todos los interruptores estén activados."),
            ],
            settingsPane: "com.apple.preference.softwareupdate"
        )
    }

    public static func screensaverPasswordCheck() -> SecurityCheck {
        let output = Shell.run("defaults read com.apple.screensaver askForPassword 2>/dev/null")
        let on = output.trimmingCharacters(in: .whitespacesAndNewlines) == "1"
        return SecurityCheck(
            id: "screensaver", title: CoreL.x("Parolă imediată la screensaver", "Immediate password after screensaver", "Contraseña inmediata tras el salvapantallas"), isGood: on,
            detail: on ? CoreL.x("Activ", "On", "Activo") : CoreL.x("Dezactivat — sau folosește butonul „Cere parolă imediat la screensaver” din Acțiuni rapide, mai jos, pentru activare automată dintr-un click", "Off — or use the “Require password immediately after screensaver” button in Quick actions below to turn it on with one click", "Desactivado; o usa el botón «Pedir contraseña inmediatamente tras el salvapantallas» de Acciones rápidas, abajo, para activarlo con un clic"),
            manualSteps: on ? [] : [
                CoreL.x("Cel mai simplu: butonul „Cere parolă imediat la screensaver” din secțiunea Acțiuni rapide de mai jos — un singur click.", "Simplest: the “Require password immediately after screensaver” button in the Quick actions section below — one click.", "Lo más sencillo: el botón «Pedir contraseña inmediatamente tras el salvapantallas» de la sección Acciones rápidas de abajo; un solo clic."),
                CoreL.x("Manual: „Deschide System Settings” → Lock Screen → „Require password after screen saver begins or display is turned off” → alege „Immediately”.", "Manual: “Open System Settings” → Lock Screen → “Require password after screen saver begins or display is turned off” → choose “Immediately”.", "Manual: «Abrir Ajustes del Sistema» → Lock Screen → «Require password after screen saver begins or display is turned off» → elige «Immediately»."),
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
