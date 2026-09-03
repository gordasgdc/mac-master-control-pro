import Foundation

/// "Mod Randare" (2026-08-31, Nivel 1 #1 din lista de optimizări cerută de
/// Cristi) — un singur comutator care elimină cele mai frecvente surse de
/// contenție I/O în timpul unui export/randare lung: indexarea Spotlight
/// (scanează continuu discul, inclusiv fișierele media nou scrise), Time
/// Machine (poate porni un backup exact în mijlocul unui export) și
/// prioritatea implicită a procesului aplicației de editare. Revine automat
/// la starea normală la dezactivare — nu lasă sistemul "oprit" din greșeală.
///
/// [2026-09-03] GENERALIZARE, cerută explicit de Cristi: "l-am gândit doar
/// pentru DaVinci Resolve, dar sunt sigur că e valabil pentru orice
/// aplicație... Final Cut, Premiere, Media Encoder". Time Machine/Spotlight
/// erau deja oprite la nivel de SISTEM (nu specifice unei aplicații) — doar
/// pasul de `renice` (prioritate CPU) era hardcodat la un singur proces.
/// Acum verifică o listă de aplicații profesionale de video/audio cunoscute
/// și ridică prioritatea TUTUROR celor care rulează efectiv acum (nu doar
/// prima găsită) — un flux real poate avea Premiere Pro ȘI Media Encoder
/// pornite simultan (export în coadă din Premiere, randat de Encoder).
public final class RenderModeService: ObservableObject {
    @Published public var isActive = false

    public init() {}

    /// Nume de proces EXACTE (`pgrep -x`), nu bundle ID — Time Machine/
    /// Spotlight beneficiază oricum orice flux de export intensiv pe disc,
    /// chiar și fără niciuna din aceste aplicații pornite (ex. export
    /// direct din Compressor sau un batch de conversie prin Terminal).
    /// Listă extensibilă — orice altă aplicație de randare/export
    /// raportată de un client se adaugă aici, un singur loc.
    private static let knownRenderApps: [String] = [
        "DaVinci Resolve",
        "Final Cut Pro",
        "Compressor",
        "Motion",
        "Adobe Premiere Pro",
        "Adobe Media Encoder",
        "Adobe After Effects",
        "Logic Pro",
        "Blackmagic Fusion",
        "HandBrake",
    ]

    /// Activează Modul Randare — o SINGURĂ cerere de parolă admin pentru tot
    /// lanțul de comenzi (`PrivilegedRunner.run([...])`).
    public func activate(log: @escaping (String) -> Void) {
        var commands = ["tmutil disable", "mdutil -a -i off"]
        let runningApps = Self.runningRenderApps()
        for app in runningApps {
            commands.append("renice -n -15 -p \(app.pid)")
        }

        log("$ " + commands.joined(separator: " && "))
        let result = PrivilegedRunner.run(commands)
        if result.success {
            log("✔ Time Machine pus pe pauză.")
            log("✔ Indexare Spotlight oprită (tot sistemul).")
            if runningApps.isEmpty {
                log("ℹ Nicio aplicație de randare cunoscută nu rulează acum — prioritatea n-a fost atinsă (Time Machine/Spotlight tot ajută la orice export/copiere masivă).")
            } else {
                for app in runningApps {
                    log("✔ \(app.name) (PID \(app.pid)) ridicat la prioritate maximă.")
                }
            }
            isActive = true
            log("✔ Mod Randare ACTIV.")
        } else {
            log("✘ Eroare la activare — \(result.output)")
        }
    }

    /// Revine la starea normală — Time Machine + Spotlight reactivate.
    /// Prioritatea aplicațiilor de randare NU trebuie resetată manual:
    /// `renice` afectează doar procesul curent, dispare automat la
    /// restart/relansare, iar readucerea ei la "normal" (0) în timp ce
    /// aplicația încă randează n-are niciun beneficiu practic.
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

    private struct RunningApp { let name: String; let pid: Int32 }

    /// Toate aplicațiile din `knownRenderApps` care rulează ACUM — nu doar
    /// prima găsită, pentru fluxuri cu mai multe pornite simultan.
    private static func runningRenderApps() -> [RunningApp] {
        knownRenderApps.compactMap { name -> RunningApp? in
            guard let pid = pid(forProcessName: name) else { return nil }
            return RunningApp(name: name, pid: pid)
        }
    }

    private static func pid(forProcessName name: String) -> Int32? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        process.arguments = ["-x", name]
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
