import SwiftUI
import MacMasterControlProCore

/// Primul modul: Retea & Cloud (mapare directa pe menu_network_cloud din script).
struct NetworkModuleView: View {
    @StateObject private var service = NetworkService.shared
    @ObservedObject private var license = LicenseStore.shared
    @State private var showGate = false
    @State private var selected: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label("Rețea", systemImage: "network").font(.title2).bold()

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
                    Button("Aplică Tuning pe selecție (acum, o dată)") { runGated { service.applyTuning(selectedAdapters: selected) } }
                        .disabled(selected.isEmpty)

                    Divider()

                    HStack(spacing: 6) {
                        Circle()
                            .fill(service.persistentTuningActive ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        Text(service.persistentTuningActive
                             ? "Tuning persistent ACTIV — se reaplică automat la fiecare pornire"
                             : "Tuning persistent INACTIV — dispare la restart")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Button("Activează la pornire (persistent)") {
                            runGated { service.installPersistentTuning(selectedAdapters: selected) }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(selected.isEmpty)

                        if service.persistentTuningActive {
                            Button("Dezactivează", role: .destructive) { runGated { service.removePersistentTuning() } }
                        }
                    }
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
        .onAppear {
            service.scanAdapters()
            service.refreshPersistentTuningStatus()
        }
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
