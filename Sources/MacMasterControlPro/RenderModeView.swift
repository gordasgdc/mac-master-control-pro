import SwiftUI
import MacMasterControlProCore

/// "Mod Randare" (2026-08-31, Nivel 1 #1) — un singur comutator care
/// elimină cele mai frecvente surse de încetinire în timpul unui export
/// lung (indexare Spotlight, Time Machine, prioritate proces). Vezi
/// RenderModeService.swift pentru mecanismul exact.
struct RenderModeView: View {
    @StateObject private var service = RenderModeService()
    @ObservedObject private var license = LicenseStore.shared
    @State private var showGate = false
    @State private var logLines: [String] = []

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

            if !logLines.isEmpty {
                TerminalLogView(lines: logLines)
            }
            Spacer()
        }
        .padding(24)
        .sheet(isPresented: $showGate) { TrialGateModal() }
    }

    private func runGated(_ action: @escaping () -> Void) {
        if license.isActivated { action() } else { showGate = true }
    }
}
