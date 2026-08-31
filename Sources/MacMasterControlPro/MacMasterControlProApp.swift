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

/// Mărime text (2026-08-31) — vezi nota din `TextScalePreference`
/// (TextScale.swift) despre eșecul real al `dynamicTypeSize` pe această
/// aplicație. Randăm `ContentView` la dimensiunea "1/scale" din spațiul
/// disponibil, apoi îl mărim vizual cu `.scaleEffect` — port 1:1 al
/// tehnicii deja dovedite în GDC Plugin Manager/Windows (`ScaleTransform`).
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
        // BUG REAL, gasit 2026-08-31: minimul de fereastra (Regula 18)
        // trebuie aplicat AICI, pe containerul din AFARA scalarii — daca
        // era pus in interiorul `ContentView` (cum era inainte), acel
        // `.frame(minWidth:900, minHeight:600)` intern castiga mereu in
        // fata dimensiunii mai mici cerute de `geo.size.width / scale`
        // cand scale > 1, blocand complet efectul vizual (marimea textului
        // parea sa nu faca NIMIC, indiferent ce optiune alegeai in Setari).
        .frame(minWidth: 900, minHeight: 600)
    }
}
