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
}
