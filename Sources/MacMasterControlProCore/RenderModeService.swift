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

    public init() { refreshDetectedApps() }

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
    public func activate(log: @escaping (String) -> Void) {
        refreshDetectedApps()
        var commands = ["tmutil disable", "mdutil -a -i off"]
        for app in detectedApps {
            commands.append("renice -n -15 -p \(app.pid)")
        }

        log("$ " + commands.joined(separator: " && "))
        let result = PrivilegedRunner.run(commands)
        if result.success {
            log("✔ Time Machine pus pe pauză.")
            log("✔ Indexare Spotlight oprită (tot sistemul).")
            if detectedApps.isEmpty {
                log("ℹ Nicio aplicație de randare cunoscută nu rulează acum — prioritatea n-a fost atinsă (Time Machine/Spotlight tot ajută la orice export/copiere masivă).")
            } else {
                for app in detectedApps {
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
}
