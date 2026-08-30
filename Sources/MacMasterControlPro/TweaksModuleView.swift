import SwiftUI
import AppKit
import MacMasterControlProCore

private enum TweakID: String, CaseIterable, Identifiable {
    case finderAdvanced, blockDSStore
    var id: String { rawValue }
    var label: String {
        switch self {
        case .finderAdvanced: return "Activează vizualizare avansată Finder"
        case .blockDSStore: return "Blochează .DS_Store pe discuri externe / USB"
        }
    }
}

struct TweaksModuleView: View {
    @StateObject private var service = TweaksService()
    @ObservedObject private var license = LicenseStore.shared
    @State private var showGate = false
    @State private var spotlightStatus = ""
    @State private var selected: Set<TweakID> = []
    @State private var status = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("🛠️ Tweak-uri Sistem").font(.title2).bold()

            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Finder").font(.headline)
                        Spacer()
                        Button(selected.count == TweakID.allCases.count ? "Deselectează tot" : "Selectează tot") {
                            selected = selected.count == TweakID.allCases.count ? [] : Set(TweakID.allCases)
                        }
                        .font(.caption)
                    }
                    ForEach(TweakID.allCases) { tweak in
                        Toggle(isOn: Binding(
                            get: { selected.contains(tweak) },
                            set: { checked in
                                if checked { selected.insert(tweak) } else { selected.remove(tweak) }
                            }
                        )) {
                            Text(tweak.label)
                        }
                    }
                    Text("Selectat \(selected.count) din \(TweakID.allCases.count)")
                        .font(.caption).foregroundStyle(.secondary)
                    Button("Aplică tweak-urile selectate") {
                        runGated { applySelected() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selected.isEmpty)

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

            if !status.isEmpty {
                Text(status).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(24)
        .sheet(isPresented: $showGate) { TrialGateModal() }
    }

    private func applySelected() {
        if selected.contains(.finderAdvanced) { service.enableFinderAdvancedView() }
        if selected.contains(.blockDSStore) { service.blockDSStoreOnExternalVolumes() }
        status = "✔ \(selected.count) tweak-uri aplicate."
        selected = []
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
