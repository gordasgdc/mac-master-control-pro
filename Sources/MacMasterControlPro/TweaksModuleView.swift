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
    @StateObject private var service = TweaksService.shared
    @ObservedObject private var license = LicenseStore.shared
    @State private var showGate = false
    @State private var selected: Set<TweakID> = []
    @State private var status = ""
    /// [2026-09-03] Panou „Terminal Live" (Regula 26), cerut explicit de
    /// Cristi pentru Touch ID — comanda EXACTĂ trimisă la osascript +
    /// fiecare linie de output/eroare reală, NU doar un mesaj static
    /// presupus de noi. Rămâne pe ecran după eșec (nu se golește automat)
    /// ca userul să poată citi/copia exact ce s-a întâmplat.
    @State private var touchIDLog: [String] = []
    /// Eroare de scriere/ștergere marker Spotlight — banda verde
    /// "Protejat" de lângă fiecare toggle e deja indicatorul de succes;
    /// asta apare doar la eșec (permisiuni etc.), ca userul să nu rămână
    /// cu impresia falsă că toggle-ul a funcționat.
    @State private var spotlightStatus: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label("Tweak-uri Sistem", systemImage: "wrench.and.screwdriver").font(.title2).bold()

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

                }
                .padding(6)
            }

            GroupBox("Spotlight Shield — Discuri & Foldere") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Bifează un disc/folder pentru a-l proteja de indexarea Spotlight (`.metadata_never_index`); debifează pentru a elimina protecția.")
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button("+ Adaugă foldere…") { pickFolders() }
                    }
                    HStack {
                        Button(service.protectedPaths.count == service.spotlightTargets.count && !service.spotlightTargets.isEmpty
                               ? "Deselectează tot" : "Selectează tot") {
                            runGated {
                                let all = service.protectedPaths.count == service.spotlightTargets.count
                                service.applyProtection(selected: all ? [] : Set(service.spotlightTargets.map(\.path)))
                            }
                        }
                        .font(.caption)
                        Spacer()
                        Button("Rescanează") { service.scanSpotlightTargets() }
                    }
                    if service.spotlightTargets.isEmpty {
                        Text("Niciun disc extern conectat și niciun folder adăugat.").font(.caption).foregroundStyle(.secondary)
                    } else {
                        ForEach(service.spotlightTargets) { target in
                            let isProtected = service.protectedPaths.contains(target.path)
                            HStack {
                                Toggle(isOn: Binding(
                                    get: { isProtected },
                                    set: { checked in
                                        runGated {
                                            let ok = service.setProtected(target.path, checked)
                                            spotlightStatus = ok
                                                ? nil // starea e deja evidentă din eticheta „Protejat" de mai jos
                                                : "✘ Nu am putut \(checked ? "proteja" : "elimina protecția pentru") „\(target.name)” — verifică permisiunile discului."
                                        }
                                    }
                                )) {
                                    Label(target.name, systemImage: target.isVolume ? "externaldrive" : "folder")
                                }
                                if isProtected {
                                    Label("Protejat", systemImage: "checkmark.shield.fill")
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(.green)
                                        .padding(.horizontal, 8).padding(.vertical, 3)
                                        .background(Color.green.opacity(0.12), in: Capsule())
                                }
                                Spacer()
                                if !target.isVolume {
                                    Button(role: .destructive) { service.removeCustomFolder(target.path) } label: {
                                        Image(systemName: "xmark.circle")
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    if let spotlightStatus {
                        StatusBanner(text: spotlightStatus)
                    }
                    Label("Protejate \(service.protectedPaths.count) din \(service.spotlightTargets.count)", systemImage: "checkmark.shield")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(6)
            }

            GroupBox("Touch ID") {
                VStack(alignment: .leading, spacing: 8) {
                    Button("Activează Touch ID pentru comenzi sudo") {
                        runGated {
                            status = "Se activează…"
                            touchIDLog = []
                            service.enableTouchIDForSudo(
                                onOutput: { line in touchIDLog.append(line) },
                                completion: { _, message in status = message }
                            )
                        }
                    }
                    if !touchIDLog.isEmpty {
                        TerminalLogView(lines: touchIDLog)
                        HStack {
                            Spacer()
                            Button("Copiază tot") {
                                let pb = NSPasteboard.general
                                pb.clearContents()
                                pb.setString(touchIDLog.joined(separator: "\n"), forType: .string)
                            }
                            .font(.caption)
                        }
                    }
                }
                .padding(6)
            }

            if !status.isEmpty {
                StatusBanner(text: status)
            }
            Spacer()
        }
        .padding(24)
        .onAppear { service.scanSpotlightTargets() }
        .sheet(isPresented: $showGate) { TrialGateModal() }
    }

    private func applySelected() {
        if selected.contains(.finderAdvanced) { service.enableFinderAdvancedView() }
        if selected.contains(.blockDSStore) { service.blockDSStoreOnExternalVolumes() }
        status = "✔ \(selected.count) tweak-uri aplicate."
        selected = []
    }

    private func pickFolders() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        service.addCustomFolders(panel.urls.map(\.path))
    }

    private func runGated(_ action: @escaping () -> Void) {
        if license.isActivated { action() } else { showGate = true }
    }
}
