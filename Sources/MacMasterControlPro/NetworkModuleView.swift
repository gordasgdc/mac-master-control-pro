import SwiftUI
import MacMasterControlProCore

/// Primul modul: Retea & Cloud (mapare directa pe menu_network_cloud din script).
struct NetworkModuleView: View {
    @StateObject private var service = NetworkService()
    @ObservedObject private var license = LicenseStore.shared
    @State private var showGate = false
    @State private var selected: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("🌐 Rețea").font(.title2).bold()

            GroupBox("Plăci de rețea detectate") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Button(selected.count == service.adapters.count && !service.adapters.isEmpty ? "Deselectează tot" : "Selectează tot") {
                            selected = selected.count == service.adapters.count ? [] : Set(service.adapters.map(\.name))
                        }
                        .font(.caption)
                        Spacer()
                        Button("Rescanează") { service.scanAdapters() }
                    }
                    ForEach(service.adapters) { adapter in
                        Toggle(isOn: Binding(
                            get: { selected.contains(adapter.name) },
                            set: { checked in
                                if checked { selected.insert(adapter.name) } else { selected.remove(adapter.name) }
                            }
                        )) {
                            Text(adapter.name)
                        }
                    }
                    Text("Selectate \(selected.count) din \(service.adapters.count) plăci de rețea")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(6)
            }

            GroupBox("Tuning Gigabit & TCP Kernel") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Forțează 1 Gbps Full-Duplex, DNS Cloudflare/Google, buffere TCP 1MB pe plăcile bifate.")
                        .foregroundStyle(.secondary)
                    Button("Aplică Tuning pe selecție") { runGated { service.applyTuning(selectedAdapters: selected) } }
                        .buttonStyle(.borderedProminent)
                        .disabled(selected.isEmpty)
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
