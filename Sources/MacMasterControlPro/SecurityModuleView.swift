import SwiftUI
import MacMasterControlProCore

/// Modul "Securitate & Confidențialitate" — verificări 🔴/🟢 pe baza
/// recomandărilor din drduh/macOS-Security-and-Privacy-Guide, plus
/// acțiuni SIGURE (fără risc de blocare a Mac-ului sau necesitatea unui
/// recovery key manual) cu un singur click.
struct SecurityModuleView: View {
    @ObservedObject private var license = LicenseStore.shared
    @State private var showGate = false
    @State private var checks: [SecurityCheck] = []
    @State private var isBusy = false
    @State private var lastActionMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("🛡️ Securitate & Confidențialitate").font(.title2).bold()
                Spacer()
                if isBusy { ProgressView().controlSize(.small) }
                Button("Rescanează") { refresh() }
            }

            GroupBox("Verificări sistem") {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(checks) { check in
                        HStack {
                            Circle()
                                .fill(check.isGood ? Color.green : Color.red)
                                .frame(width: 8, height: 8)
                            Text(check.title)
                            Spacer()
                            Text(check.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                    if checks.isEmpty {
                        Text("Se scanează…").foregroundStyle(.secondary)
                    }
                }
                .padding(6)
            }

            GroupBox("Acțiuni rapide") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Button("Activează Firewall + Stealth Mode") {
                            runGated {
                                SecurityService.enableFirewallWithStealth()
                                refresh(message: "Firewall activat (stealth mode + fără excepții automate pentru aplicații semnate).")
                            }
                        }
                    }
                    HStack {
                        Button("Cere parolă imediat la screensaver") {
                            runGated {
                                SecurityService.requirePasswordImmediatelyAtScreensaver()
                                refresh(message: "Parola va fi cerută imediat la ieșirea din screensaver.")
                            }
                        }
                    }
                    if let lastActionMessage {
                        Label(lastActionMessage, systemImage: "checkmark.circle.fill")
                            .font(.caption).foregroundStyle(.green)
                    }
                }
                .padding(6)
            }

            GroupBox("Ce NU se face automat, și de ce") {
                Text("FileVault (cere cheie de recuperare confirmată manual), dezactivarea System Integrity Protection (necesită Recovery Mode), și configurarea DNS/VPN/Tor (alegere personală) rămân decizii luate direct din System Settings, niciodată dintr-un buton — riscul de a bloca sau expune Mac-ul fără să-ți dai seama e prea mare.")
                    .font(.caption).foregroundStyle(.secondary)
                    .padding(6)
            }

            Spacer()
        }
        .padding(24)
        .onAppear { refresh() }
        .sheet(isPresented: $showGate) { TrialGateModal() }
    }

    private func refresh(message: String? = nil) {
        isBusy = true
        lastActionMessage = message
        DispatchQueue.global(qos: .userInitiated).async {
            let result = SecurityService.runAllChecks()
            DispatchQueue.main.async {
                checks = result
                isBusy = false
            }
        }
    }

    private func runGated(_ action: @escaping () -> Void) {
        if license.isActivated {
            action()
        } else {
            showGate = true
        }
    }
}
