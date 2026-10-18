import SwiftUI
import AppKit
import MacMasterControlProCore

private enum TweakID: String, CaseIterable, Identifiable {
    case finderAdvanced, blockDSStore
    var id: String { rawValue }
    var label: String {
        switch self {
        case .finderAdvanced: return L.x("Activează vizualizare avansată Finder", "Enable advanced Finder view", "Activar la vista avanzada del Finder")
        case .blockDSStore: return L.x("Blochează .DS_Store pe discuri externe / USB", "Block .DS_Store on external / USB drives", "Bloquear .DS_Store en discos externos / USB")
        }
    }
}

struct TweaksModuleView: View {
    @StateObject private var service = TweaksService.shared
    @ObservedObject private var license = AccessCoordinator.shared
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
                        Button(selected.count == TweakID.allCases.count ? L.x("Deselectează tot", "Deselect all", "Deseleccionar todo") : L.x("Selectează tot", "Select all", "Seleccionar todo")) {
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
                    Text(L.x("Selectat \(selected.count) din \(TweakID.allCases.count)", "Selected \(selected.count) of \(TweakID.allCases.count)", "Seleccionados \(selected.count) de \(TweakID.allCases.count)"))
                        .font(.caption).foregroundStyle(.secondary)
                    Button(L.x("Aplică tweak-urile selectate", "Apply selected tweaks", "Aplicar los ajustes seleccionados")) {
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
                        Text(L.x("Bifează un disc/folder pentru a-l proteja de indexarea Spotlight (`.metadata_never_index`); debifează pentru a elimina protecția.", "Tick a drive/folder to protect it from Spotlight indexing (`.metadata_never_index`); untick to remove the protection.", "Marca un disco o carpeta para protegerlo de la indexación de Spotlight (`.metadata_never_index`); desmárcalo para quitar la protección."))
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button(L.x("+ Adaugă foldere…", "+ Add folders…", "+ Añadir carpetas…")) { pickFolders() }
                    }
                    HStack {
                        Button(service.protectedPaths.count == service.spotlightTargets.count && !service.spotlightTargets.isEmpty
                               ? L.x("Deselectează tot", "Deselect all", "Deseleccionar todo") : L.x("Selectează tot", "Select all", "Seleccionar todo")) {
                            runGated {
                                let all = service.protectedPaths.count == service.spotlightTargets.count
                                service.applyProtection(selected: all ? [] : Set(service.spotlightTargets.map(\.path)))
                            }
                        }
                        .font(.caption)
                        Spacer()
                        Button(L.x("Rescanează", "Rescan", "Volver a analizar")) { service.scanSpotlightTargets() }
                    }
                    if service.spotlightTargets.isEmpty {
                        Text(L.x("Niciun disc extern conectat și niciun folder adăugat.", "No external drive connected and no folder added.", "Ningún disco externo conectado ni carpeta añadida.")).font(.caption).foregroundStyle(.secondary)
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
                                                : L.x("✘ Nu am putut \(checked ? "proteja" : "elimina protecția pentru") „\(target.name)” — verifică permisiunile discului.", "✘ Could not \(checked ? "protect" : "remove protection for") “\(target.name)” — check the drive permissions.", "✘ No se pudo \(checked ? "proteger" : "quitar la protección de") «\(target.name)»; revisa los permisos del disco.")
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
                    Label(L.x("Protejate \(service.protectedPaths.count) din \(service.spotlightTargets.count)", "Protected \(service.protectedPaths.count) of \(service.spotlightTargets.count)", "Protegidos \(service.protectedPaths.count) de \(service.spotlightTargets.count)"), systemImage: "checkmark.shield")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(6)
            }

            GroupBox("Touch ID") {
                VStack(alignment: .leading, spacing: 8) {
                    Button(L.x("Activează Touch ID pentru comenzi sudo", "Enable Touch ID for sudo commands", "Activar Touch ID para los comandos sudo")) {
                        runGated {
                            status = L.x("Se activează…", "Enabling…", "Activando…")
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
                            Button(L.x("Copiază tot", "Copy all", "Copiar todo")) {
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
        .sheet(isPresented: $showGate) { AccessGateSheet() }
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
        if license.allowsFeatures { action() } else { showGate = true }
    }
}
