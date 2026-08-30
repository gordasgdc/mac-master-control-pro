import SwiftUI
import AppKit
import MacMasterControlProCore

struct TweaksModuleView: View {
    @StateObject private var service = TweaksService()
    @ObservedObject private var license = LicenseStore.shared
    @State private var showGate = false
    @State private var spotlightStatus = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("🛠️ Tweak-uri Sistem").font(.title2).bold()

            GroupBox("Finder & Spotlight") {
                VStack(alignment: .leading, spacing: 10) {
                    Button("Activează vizualizare avansată Finder") {
                        runGated { service.enableFinderAdvancedView() }
                    }
                    Button("Blochează .DS_Store pe discuri externe / USB") {
                        runGated { service.blockDSStoreOnExternalVolumes() }
                    }
                    Divider()
                    Button("Protejează folder RAW de Spotlight…") { pickFolderAndProtect() }
                    if !spotlightStatus.isEmpty {
                        Text(spotlightStatus).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(6)
            }

            GroupBox("Touch ID") {
                Button("Activează Touch ID pentru comenzi sudo") {
                    runGated { service.enableTouchIDForSudo() }
                }
                .padding(6)
            }
            Spacer()
        }
        .padding(24)
        .sheet(isPresented: $showGate) { TrialGateModal() }
    }

    private func pickFolderAndProtect() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        runGated {
            let ok = service.protectFromSpotlight(folderPath: url.path)
            spotlightStatus = ok ? "✔ Protejat: \(url.lastPathComponent)" : "Eroare — cale invalidă."
        }
    }

    private func runGated(_ action: @escaping () -> Void) {
        if license.isActivated { action() } else { showGate = true }
    }
}
