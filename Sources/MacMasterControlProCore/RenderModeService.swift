import Foundation
import AppKit

/// O aplicație de randare/export cunoscută, detectată efectiv rulând acum
/// — cu iconița ei REALĂ (nu un simbol generic), citită direct din
/// bundle-ul instalat prin `NSRunningApplication.icon`, exact tiparul deja
/// folosit de `InstalledApp.icon` (`UninstallerService.swift`).
public struct DetectedRenderApp: Identifiable, Hashable {
    public var id: Int32 { pid }
    public let name: String
    public let pid: Int32
    public let icon: NSImage

    public static func == (lhs: DetectedRenderApp, rhs: DetectedRenderApp) -> Bool { lhs.pid == rhs.pid }
    public func hash(into hasher: inout Hasher) { hasher.combine(pid) }
}

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
/// pasul de prioritate CPU era hardcodat la un singur proces.
///
/// [2026-09-03] A DOUA TRECERE: rescris de la `pgrep -x` (potrivire EXACTĂ
/// de nume de proces — fragil, un "Adobe Premiere Pro 2025" cu anul în nume
/// n-ar mai fi găsit niciodată) la `NSWorkspace.shared.runningApplications`
/// + potrivire prin SUBSTRING pe `localizedName` — robust la variații de
/// nume între versiuni, ȘI oferă gratuit iconița REALĂ a aplicației
/// (`NSRunningApplication.icon`), cerută explicit de Cristi ("iconița
/// oficială de la Final Cut, iconița de la Premiere"), fără nicio
/// dependință nouă — API nativ AppKit, deja disponibil.
public final class RenderModeService: ObservableObject {
    /// [2026-09-03] FIX REAL, raportat de Cristi: navigarea la alt meniu
    /// și înapoi "oprea" acțiunea în curs — de fapt starea nu se oprea,
    /// dar SwiftUI distrugea instanța `@StateObject` locală view-ului
    /// părăsit (fiecare pagină crea propriul serviciu, `= RenderModeService()`),
    /// iar la revenire userul vedea o instanță NOUĂ, complet resetată,
    /// deși procesul de sistem real (dacă exista unul) continua neschimbat
    /// pe fundal. Fix: un singur `.shared` per serviciu, referit din orice
    /// View — starea (isActive, detectedApps, jurnalul) supraviețuiește
    /// navigării, exact ca un tab de browser care rulează în fundal.
    public static let shared = RenderModeService()
    @Published public var isActive = false
    /// Aplicațiile cunoscute găsite rulând ACUM, cu iconița lor reală —
    /// afișate live în UI (nu doar în jurnalul de activare), ca userul să
    /// vadă tot timpul ce ar optimiza Modul Randare dacă l-ar porni acum.
    @Published public private(set) var detectedApps: [DetectedRenderApp] = []

    public init() {
        refreshDetectedApps()
        if RenderModeState.loadSnapshot() != nil { isActive = true; recoveredFromPreviousSession = true }
    }

    /// Cuvinte-cheie, NU nume exacte — se potrivesc prin substring,
    /// insensibil la majuscule, pe `localizedName`-ul aplicației rulate
    /// (ex. "Adobe Premiere Pro 2026" conține "Premiere Pro"). Listă
    /// extensibilă — orice altă aplicație de randare/export raportată de
    /// un client se adaugă aici, un singur loc.
    private static let knownRenderAppKeywords: [String] = [
        "DaVinci Resolve",
        "Final Cut Pro",
        "Compressor",
        "Motion",
        "Premiere Pro",
        "Media Encoder",
        "After Effects",
        "Logic Pro",
        "Fusion",
        "HandBrake",
    ]

    /// Rescanează aplicațiile rulate acum — apelat la creare + oricând UI-ul
    /// vrea o stare proaspătă (ex. la deschiderea paginii).
    public func refreshDetectedApps() {
        detectedApps = NSWorkspace.shared.runningApplications.compactMap { app -> DetectedRenderApp? in
            guard let name = app.localizedName,
                  Self.knownRenderAppKeywords.contains(where: { name.localizedCaseInsensitiveContains($0) }),
                  let icon = app.icon
            else { return nil }
            return DetectedRenderApp(name: name, pid: app.processIdentifier, icon: icon)
        }
    }

    /// Activează Modul Randare — o SINGURĂ cerere de parolă admin pentru tot
    /// lanțul de comenzi (`PrivilegedRunner.run([...])`).
    /// Mod Randare rămas activ de la o sesiune anterioară (închidere forțată / repornire): sistemul poate fi încă modificat.
    @Published public private(set) var recoveredFromPreviousSession = false

    private func readCurrentState() -> RenderModeSnapshot {
        let tm = RenderModeState.parseAutoBackup(Shell.run("/usr/bin/defaults read /Library/Preferences/com.apple.TimeMachine AutoBackup 2>/dev/null", timeout: 10))
        let spot = RenderModeState.parseMdutil(Shell.run("/usr/bin/mdutil -a -s 2>/dev/null", timeout: 20))
        var nice: [Int32: Int] = [:]
        for app in detectedApps {
            if let n = Int(Shell.run("/bin/ps -o nice= -p \(app.pid)", timeout: 5).trimmingCharacters(in: .whitespaces)) { nice[app.pid] = n }
        }
        return RenderModeSnapshot(timeMachineAutoBackup: tm, spotlight: spot, nice: nice)
    }

    /// Ce ar schimba activarea ACUM (fără să schimbe nimic): pentru previzualizare în interfață.
    public func previewChanges() -> [String] {
        refreshDetectedApps()
        return RenderModeState.changeSummary(readCurrentState())
    }

    public func activate(log: @escaping (String) -> Void) {
        refreshDetectedApps()
        let snapshot = readCurrentState()
        let commands = RenderModeState.activationCommands(snapshot)
        let op = DiagnosticLog.begin("render", "activate", fields: ["commands": String(commands.count)])
        for line in RenderModeState.changeSummary(snapshot) { log("• " + line) }
        guard !commands.isEmpty else {
            log("ℹ Nimic de schimbat: tot ce poate face Modul Randare este deja oprit.")
            op.end("noop"); return
        }
        // Starea veche se salvează ÎNAINTE de modificare; fără ea nu se continuă.
        do { try RenderModeState.saveSnapshot(snapshot) } catch {
            log("✘ Nu am putut salva starea curentă, nu modific nimic: \(error.localizedDescription)")
            op.end("snapshot-failed", level: .error); return
        }
        log("$ " + commands.joined(separator: " && "))
        let result = PrivilegedRunner.run(commands)
        if result.success {
            isActive = true
            log("✔ Mod Randare ACTIV. Starea anterioară e salvată; dezactivarea o restaurează exact.")
            op.end("ok")
        } else {
            log("✘ Eroare la activare — \(result.output)")
            log("ℹ Starea veche rămâne salvată; apasă Dezactivează pentru a readuce ce s-a schimbat parțial.")
            isActive = true   // posibil parțial aplicat: permite restaurarea
            op.end("failed", level: .error)
        }
    }

    public func deactivate(log: @escaping (String) -> Void) {
        guard let snapshot = RenderModeState.loadSnapshot() else {
            log("ℹ Nu există o stare salvată de restaurat. Nu modific Time Machine sau Spotlight.")
            isActive = false; recoveredFromPreviousSession = false; return
        }
        let commands = RenderModeState.restoreCommands(snapshot)
        let op = DiagnosticLog.begin("render", "deactivate", fields: ["commands": String(commands.count)])
        if commands.isEmpty { RenderModeState.clearSnapshot(); isActive = false; recoveredFromPreviousSession = false; log("✔ Nimic de restaurat."); op.end("noop"); return }
        log("$ " + commands.joined(separator: " && "))
        let result = PrivilegedRunner.run(commands)
        if result.success {
            RenderModeState.clearSnapshot()
            isActive = false; recoveredFromPreviousSession = false
            log("✔ Mod Randare dezactivat: s-a restaurat exact starea de dinainte.")
            op.end("ok")
        } else {
            log("✘ Eroare la restaurare — \(result.output). Starea salvată a fost păstrată; reîncearcă.")
            op.end("failed", level: .error)
        }
    }
}
