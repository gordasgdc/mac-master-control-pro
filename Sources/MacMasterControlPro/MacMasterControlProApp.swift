import SwiftUI
import AppKit

@main
struct MacMasterControlProApp: App {
    var body: some Scene {
        WindowGroup {
            ScaledContentView()
                .onAppear { ThemeManager.shared.applyNow() }
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("Despre Master Control Studio Pro") { showAboutPanel() }
            }
            CommandGroup(replacing: .help) {
                Button("Ghid de Utilizare (PDF)") { GuidePDF.open() }
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
    }
}
