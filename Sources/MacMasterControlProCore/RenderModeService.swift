import Foundation

/// "Mod Randare" (2026-08-31, Nivel 1 #1 din lista de optimizări cerută de
/// Cristi) — un singur comutator care elimină cele mai frecvente surse de
/// contenție I/O în timpul unui export/randare lung: indexarea Spotlight
/// (scanează continuu discul, inclusiv fișierele media nou scrise), Time
/// Machine (poate porni un backup exact în mijlocul unui export) și
/// prioritatea implicită a procesului DaVinci Resolve. Revine automat la
/// starea normală la dezactivare — nu lasă sistemul "oprit" din greșeală.
public final class RenderModeService: ObservableObject {
    @Published public var isActive = false

    public init() {}

    /// Activează Modul Randare — o SINGURĂ cerere de parolă admin pentru tot
    /// lanțul de comenzi (`PrivilegedRunner.run([...])`).
    public func activate(log: @escaping (String) -> Void) {
        var commands = ["tmutil disable", "mdutil -a -i off"]
        var renicedPID: Int32?
        if let pid = Self.resolvePID() {
            commands.append("renice -n -15 -p \(pid)")
            renicedPID = pid
        }

        log("$ " + commands.joined(separator: " && "))
        let result = PrivilegedRunner.run(commands)
        if result.success {
            log("✔ Time Machine pus pe pauză.")
            log("✔ Indexare Spotlight oprită (tot sistemul).")
            if let renicedPID {
                log("✔ DaVinci Resolve (PID \(renicedPID)) ridicat la prioritate maximă.")
            } else {
                log("ℹ DaVinci Resolve nu rulează — prioritatea nu a fost atinsă.")
            }
            isActive = true
            log("✔ Mod Randare ACTIV.")
        } else {
            log("✘ Eroare la activare — \(result.output)")
        }
    }

    /// Revine la starea normală — Time Machine + Spotlight reactivate.
    /// Prioritatea DaVinci Resolve NU trebuie resetată manual: `renice`
    /// afectează doar procesul curent, dispare automat la restart/relansare,
    /// iar readucerea ei la "normal" (0) în timp ce Resolve încă randează
    /// nu are niciun beneficiu practic.
    public func deactivate(log: @escaping (String) -> Void) {
        let commands = ["tmutil enable", "mdutil -a -i on"]
        log("$ " + commands.joined(separator: " && "))
        let result = PrivilegedRunner.run(commands)
        if result.success {
            log("✔ Time Machine reactivat.")
            log("✔ Indexare Spotlight reactivată.")
            isActive = false
            log("✔ Mod Randare dezactivat — revenit la normal.")
        } else {
            log("✘ Eroare la dezactivare — \(result.output)")
        }
    }

    /// PID-ul procesului DaVinci Resolve, dacă rulează - `nil` altfel (Modul
    /// Randare rămâne util și fără Resolve pornit, doar pentru Time
    /// Machine/Spotlight, ex. randare prin alt tool sau export masiv de
    /// fișiere din Finder).
    private static func resolvePID() -> Int32? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        process.arguments = ["-x", "DaVinci Resolve"]
        let pipe = Pipe()
        process.standardOutput = pipe
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let text = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "\n").first
            else { return nil }
            return Int32(text)
        } catch {
            return nil
        }
    }
}
