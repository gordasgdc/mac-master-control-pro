import SwiftUI
import MacMasterControlProCore

/// Primul modul: Retea & Cloud (mapare directa pe menu_network_cloud din script).
struct NetworkModuleView: View {
    @StateObject private var service = NetworkService()
    @ObservedObject private var license = LicenseStore.shared
    @State private var showGate = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("🌐 Rețea").font(.title2).bold()

            GroupBox("Adaptor selectat") {
                HStack {
                    Text(service.selectedAdapter)
                    Spacer()
                    Button("Rescanează") { service.scanAdapters() }
                }
                .padding(6)
            }

            GroupBox("Tuning Gigabit & TCP Kernel") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Forțează 1 Gbps Full-Duplex, DNS Cloudflare/Google, buffere TCP 1MB.")
                        .foregroundStyle(.secondary)
                    Button("Aplică Tuning") { runGated { service.applyTuning() } }
                        .buttonStyle(.borderedProminent)
                }
                .padding(6)
            }

            GroupBox("Motor Cloud (Rclone / macFUSE)") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Configurarea conturilor Cloud s-a mutat în modulul „Cloud Manager” din bara laterală.")
                        .foregroundStyle(.secondary)
                    Button("Instalează Rclone + macFUSE") { service.installRcloneStack() }
                }
                .padding(6)
            }

            Spacer()
        }
        .padding(24)
        .onAppear { service.scanAdapters() }
        .sheet(isPresented: $showGate) { TrialGateModal() }
    }

    private func runGated(_ action: @escaping () -> Void) {
        if license.isActivated {
            action()
        } else {
            showGate = true
        }
    }
}
