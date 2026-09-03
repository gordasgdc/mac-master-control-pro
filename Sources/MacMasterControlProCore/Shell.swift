import Foundation

/// Executie shell fara privilegii (scanari, citiri, brew).
public enum Shell {
    /// PATH augmentat cu locatiile standard Homebrew (Apple Silicon +
    /// Intel) - un `.app` lansat din Finder/Dock mosteneste un PATH minimal
    /// (`/usr/bin:/bin:/usr/sbin:/sbin`), FARA `/opt/homebrew/bin` sau
    /// `/usr/local/bin`, unde Homebrew instaleaza rclone/macFUSE. BUG REAL,
    /// gasit 2026-08-30 din raportul lui Cristi: "Adauga cont Cloud" esua cu
    /// "env: rclone: No such file or directory" desi rclone era instalat -
    /// `DependencyChecker` il gasea (verifica direct `brew list`, cale
    /// absoluta), dar `CloudManagerService` invoca "rclone" ca nume simplu,
    /// negasibil pe PATH-ul minimal al unui .app lansat din Finder.
    public static let augmentedPath: String = {
        let existing = ProcessInfo.processInfo.environment["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
        return "/opt/homebrew/bin:/usr/local/bin:" + existing
    }()

    @discardableResult
    public static func run(_ command: String) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command]
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = augmentedPath
        process.environment = env
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return "Eroare executie: \(error.localizedDescription)"
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    /// [2026-09-03] FIX REAL, raportat de Cristi: instalarea `macFUSE` prin
    /// `brew install --cask macfuse` esua constant cu "sudo: a terminal is
    /// required to read the password; either use the -S option ... or
    /// configure an askpass helper" — pachetele Homebrew de tip cask care
    /// scriu in afara Homebrew-ului insusi (macFUSE instaleaza o extensie
    /// de sistem via `installer -pkg ... -target /`) folosesc intern
    /// `sudo`, care nu are NICIUN terminal disponibil cand e lansat dintr-un
    /// `Process` pornit de o aplicatie GUI (fara TTY, fara `stdin` interactiv)
    /// — nu un bug in codul nostru, ci o limitare reala a `sudo` fara
    /// configurare suplimentara.
    ///
    /// Fix corect, NU un ocol: `man sudoers` — `sudo` foloseste automat
    /// helper-ul din `SUDO_ASKPASS` (variabila de mediu) atunci cand
    /// NICIUN terminal nu e accesibil, chiar si FARA flag-ul `-A` explicit
    /// (brew nu adauga `-A` la `sudo`-ul lui intern, deci n-am cum sa-l
    /// schimbam pe el — dar `sudo` insusi cade pe askpass in acest caz).
    /// `askpassScriptPath` scrie un mic script care deschide un dialog
    /// NATIV macOS (`osascript`/System Events) cerand parola de admin —
    /// exact acelasi tip de prompt vizual ca `osascript ... with
    /// administrator privileges` folosit de Self-Updater (Regula 20), doar
    /// ca aici trebuie sa fie un PROGRAM separat (nu un simplu apel), fiindca
    /// asta cere `sudo`/`SUDO_ASKPASS`.
    private static var askpassScriptPath: String = {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/MacMasterControlPro", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let scriptURL = dir.appendingPathComponent("askpass.sh")
        let script = """
        #!/bin/zsh
        osascript -e 'Tell application "System Events" to display dialog "Master Control Studio Pro are nevoie de parola de administrator ca sa continue instalarea." with title "Parolă necesară" default answer "" with hidden answer with icon caution' -e 'text returned of result' 2>/dev/null
        """
        try? script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: scriptURL.path)
        return scriptURL.path
    }()

    /// Identic cu `run(_:)`, dar cu `SUDO_ASKPASS` setat — pentru orice
    /// comanda care poate declansa intern `sudo` FARA terminal disponibil
    /// (ex. `brew install --cask macfuse`). Formulele obisnuite (rclone,
    /// ffmpeg) nu au nevoie de asta — doar cask-urile care ating sistemul.
    @discardableResult
    public static func runElevated(_ command: String) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command]
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = augmentedPath
        env["SUDO_ASKPASS"] = askpassScriptPath
        process.environment = env
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return "Eroare executie: \(error.localizedDescription)"
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}
