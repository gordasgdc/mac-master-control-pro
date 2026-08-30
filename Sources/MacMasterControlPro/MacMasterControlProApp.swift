import SwiftUI
import AppKit

@main
struct MacMasterControlProApp: App {
    init() {
        ThemeManager.shared.applyNow()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("Despre Mac Master Control Pro") { showAboutPanel() }
            }
            CommandGroup(replacing: .help) {
                Button("Ghid de Utilizare (PDF)") { GuidePDF.open() }
            }
        }
    }

    private func showAboutPanel() {
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "Mac Master Control Pro",
            .credits: NSAttributedString(string: "© \(Calendar.current.component(.year, from: Date())) GDC. Toate drepturile rezervate."),
        ])
    }
}
