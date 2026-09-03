import SwiftUI
import AppKit

extension Notification.Name {
    static let mmcpOpenSettings = Notification.Name("mmcpOpenSettings")
}

@main
struct MacMasterControlProApp: App {
    var body: some Scene {
        WindowGroup {
            ScaledContentView()
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
// [2026-09-03] REPUS, cu tehnica EXACTA (nu doar similara) care functioneaza
// deja confirmat in GDC Plugin Manager — acelasi NavigationSplitView, acelasi
// SwiftUI/macOS. Diferenta reala fata de incercarile anterioare de-aici:
// randam ContentView() la `geo.size / scale` (compensare de frame INAINTE
// de scaleEffect, nu dupa) intr-un GeometryReader care ii da mereu
// dimensiunea REALA curenta a ferestrei — asta pastreaza layout-ul si
// hit-testing-ul sincronizate cu ce se vede vizual, indiferent de
// NavigationSplitView/NSSplitViewController dedesubt. Daca acest fix
// reproduce vreodata bug-ul vechi (click-uri moarte), revino la varianta
// eliminata mai sus, dar cu diagnostic real (nu presupunere) inainte.
private struct ScaledContentView: View {
    @ObservedObject private var textScale = TextScaleManager.shared

    var body: some View {
        GeometryReader { geo in
            let scale = textScale.current.scaleFactor
            ContentView()
                .frame(width: geo.size.width / scale, height: geo.size.height / scale)
                .scaleEffect(scale)
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
    }
}
