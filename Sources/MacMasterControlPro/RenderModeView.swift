import SwiftUI
import MacMasterControlProCore

/// "Mod Randare" (2026-08-31, Nivel 1 #1) — un singur comutator care
/// elimină cele mai frecvente surse de încetinire în timpul unui export
/// lung (indexare Spotlight, Time Machine, prioritate proces). Vezi
/// RenderModeService.swift pentru mecanismul exact.
struct RenderModeView: View {
    @StateObject private var service = RenderModeService.shared
    @ObservedObject private var license = LicenseStore.shared
    @State private var showGate = false
    @State private var logLines: [String] = []
    /// Reîmprospătare periodică (nu doar la deschiderea paginii) — userul
    /// poate porni Premiere/Final Cut chiar cât se uită la acest ecran.
    private let refreshTimer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label("Mod Randare", systemImage: "bolt.circle").font(.title2).bold()

            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Pentru export-uri/randări lungi din orice aplicație — DaVinci Resolve, Final Cut Pro, Premiere Pro, Media Encoder, After Effects, Logic Pro, HandBrake și altele: pune pe pauză indexarea Spotlight și Time Machine (ambele pot concura pentru discul de proiect chiar în timpul randării), și ridică prioritatea aplicațiilor de mai sus care rulează acum.")
                        .font(.caption).foregroundStyle(.secondary)

                    HStack(spacing: 14) {
                        Circle()
                            .fill(service.isActive ? Color.green : Color.secondary.opacity(0.3))
                            .frame(width: 12, height: 12)
                        Text(service.isActive ? "Mod Randare ACTIV" : "Mod Randare inactiv")
                            .font(.headline)
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { service.isActive },
                            set: { newValue in
                                runGated {
                                    if newValue {
                                        logLines = []
                                        service.activate { logLines.append($0) }
                                    } else {
                                        service.deactivate { logLines.append($0) }
                                    }
                                }
                            }
                        ))
                        .toggleStyle(.switch)
                        .labelsHidden()
                    }

                    if service.isActive {
                        Label("Nu uita să dezactivezi Modul Randare după export — Time Machine și Spotlight rămân oprite cât timp comutatorul e ON.", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption).foregroundStyle(.orange)
                    }
                }
                .padding(6)
            }

            detectedAppsSection

            if !logLines.isEmpty {
                TerminalLogView(lines: logLines)
            }
            Spacer()
        }
        .padding(24)
        .onAppear { service.refreshDetectedApps() }
        .onReceive(refreshTimer) { _ in service.refreshDetectedApps() }
        .sheet(isPresented: $showGate) { TrialGateModal() }
    }

    /// [2026-09-03] Cerut explicit de Cristi: "iconița oficială de la
    /// Final Cut, iconița de la Premiere" — vizibil TOT timpul, nu doar în
    /// jurnalul de activare, ca userul să vadă dintr-o privire ce anume ar
    /// optimiza Modul Randare dacă l-ar porni chiar acum.
    @ViewBuilder
    private var detectedAppsSection: some View {
        GroupBox("Aplicații detectate acum") {
            if service.detectedApps.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "questionmark.circle").foregroundStyle(.secondary)
                    Text("Nicio aplicație de randare cunoscută nu rulează — Modul Randare tot ajută la orice export/copiere masivă, prin Time Machine/Spotlight.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(6)
            } else {
                HStack(spacing: 16) {
                    ForEach(service.detectedApps) { app in
                        VStack(spacing: 4) {
                            Image(nsImage: app.icon)
                                .resizable()
                                .frame(width: 32, height: 32)
                            Text(app.name)
                                .font(.caption2)
                                .lineLimit(1)
                                .frame(maxWidth: 84)
                        }
                    }
                    Spacer()
                }
                .padding(6)
            }
        }
    }

    private func runGated(_ action: @escaping () -> Void) {
        if license.isActivated { action() } else { showGate = true }
    }
}
