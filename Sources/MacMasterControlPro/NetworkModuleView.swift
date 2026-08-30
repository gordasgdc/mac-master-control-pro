import SwiftUI
import MacMasterControlProCore

/// Primul modul: Retea & Cloud (mapare directa pe menu_network_cloud din script).
struct NetworkModuleView: View {
    @StateObject private var service = NetworkService()
    @ObservedObject private var license = LicenseStore.shared
    @State private var showGate = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("🌐 Rețea & Cloud").font(.title2).bold()

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

            GroupBox("Cloud Mount (Rclone / Degoo)") {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Folder de montare", text: $service.cloudMountDir)
                        .textFieldStyle(.roundedBorder)
                    HStack {
                        Button("Instalează Rclone + macFUSE") { service.installRcloneStack() }
                        Button("Montează Cloud") { runGated { service.mountCloud() } }
                    }
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
