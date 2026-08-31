import SwiftUI
import AppKit

extension Notification.Name {
    static let mmcpOpenSettings = Notification.Name("mmcpOpenSettings")
}

@main
struct MacMasterControlProApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear { ThemeManager.shared.applyNow() }
        }
        // BUG REAL, gasit 2026-08-31: `.windowResizability(.contentSize)`
        // intra in conflict cu `ScaledContentView` (GeometryReader + scaleEffect,
        // vezi mai jos) — GeometryReader nu are o dimensiune "ideala" proprie,
        // deci macOS ramanea blocat pe dimensiunea initiala a ferestrei,
        // Mararea/Micsorarea textului nu se vedea NICIODATA, indiferent ce
        // optiune alegeai in Setari (confirmat: dimensiunea reala din
        // Accessibility ramanea identica intre "Normal" si "Foarte mare").
        // Eliminat complet — se aliniaza si cu Regula 18 (fereastra ramane
        // liber redimensionabila), care oricum interzicea implicit acest mod.
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("Despre Master Control Studio Pro") { showAboutPanel() }
            }
            CommandGroup(replacing: .help) {
                Button("Ghid de Utilizare (PDF)") { GuidePDF.open() }
            }
            // Plasă de siguranță (2026-08-31): ⌘, e scurtătura STANDARD
            // macOS pentru Preferences — deschide Setări indiferent de
            // orice problemă viitoare de click în sidebar (vezi bug-ul de
            // hit-testing de mai sus). Nu costă nimic sa existe, chiar daca
            // sidebar-ul functioneaza normal.
            CommandGroup(replacing: .appSettings) {
                Button("Setări…") { NotificationCenter.default.post(name: .mmcpOpenSettings, object: nil) }
                    .keyboardShortcut(",", modifiers: .command)
            }
        }
    }

    private func showAboutPanel() {
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "Master Control Studio Pro",
            .credits: NSAttributedString(string: "© \(Calendar.current.component(.year, from: Date())) GDC. Toate drepturile rezervate."),
        ])
    }
}

// BUG REAL FINAL, confirmat direct de Cristi (2026-08-31): tehnica
// `.scaleEffect` + `.position()` (fostul `ScaledContentView`, eliminat)
// nu doar ca nu producea o schimbare vizibila (v2.19.0), dar dupa fix-ul
// de layout (v2.20.0) a inceput sa rupa efectiv CLICK-urile — la orice
// scale diferit de 1.0, tot ecranul Setari devenea neresponsiv (niciun
// buton nu mai reactiona), blocand userul definitiv in acel ecran (nici
// macar revenirea la "Normal" nu mai era posibila din UI). Motiv tehnic
// probabil: NavigationSplitView e susdinut intern de NSSplitViewController
// (AppKit), iar geometria de hit-testing a coloanelor lui nu se resincronizeaza
// corect cu un `.scaleEffect` extern aplicat peste intreg continutul SwiftUI.
//
// Decizie: dupa 3 incercari esuate de reparare a acestei tehnici, o
// ELIMINAM COMPLET — un bug care poate bloca ireversibil userul e mai grav
// decat lipsa functiei. `TextScalePreference`/picker-ul din Setari raman
// (Windows chiar functioneaza corect, port 1:1 confirmat de Cristi), dar
// pe Mac raman DOAR cosmetic, fara efect vizual, pana la o implementare
// non-riscanta (scalare reala per-Text/Font, nu transform global) —
// de facut intr-o sesiune viitoare, dedicata, nu graba.
