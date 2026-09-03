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

// BUG ISTORIC (2026-08-31): 3 incercari anterioare de `.scaleEffect` +
// `.position()` au rupt hit-testing-ul (click-uri moarte in Setari la
// scale != 1.0), motiv pentru care tehnica fusese ELIMINATA complet aici.
//
// [2026-09-03] A 4-A INCERCARE, cu tehnica EXACTA din GDC Plugin Manager
// (`geo.size / scale` + `.scaleEffect` + `.position`) — REPRODUS ACELASI
// BUG, confirmat direct de Cristi ("apas pe meniul setari dar nu se
// deschide"). Deci NU e o diferenta de implementare intre cele doua
// aplicatii (ambele folosesc NavigationSplitView identic) — e specific
// combinatiei GeometryReader+scaleEffect cu NSSplitViewController-ul din
// spatele NavigationSplitView-ului ACESTEI aplicatii macOS, indiferent
// cat de exact copiem reteta care functioneaza in GDC Plugin Manager.
// RE-ELIMINAT. Nu mai incerca aceasta tehnica aici fara un mediu de
// testare interactiv real (nu doar `swift build`) — 4 incercari esuate
// identic e suficient sa marcheze asta ca ne-viabil pentru acest layout,
// nu doar "inca nereparat".
