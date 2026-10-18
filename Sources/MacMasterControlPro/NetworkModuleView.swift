import SwiftUI
import MacMasterControlProCore

/// Primul modul: Retea & Cloud (mapare directa pe menu_network_cloud din script).
struct NetworkModuleView: View {
    @StateObject private var service = NetworkService.shared
    @ObservedObject private var license = AccessCoordinator.shared
    @State private var showGate = false
    @State private var selected: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label(L.x("Rețea", "Network", "Red"), systemImage: "network").font(.title2).bold()

            GroupBox(L.x("Plăci de rețea detectate", "Network adapters detected", "Adaptadores de red detectados")) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Button(selected.count == service.adapters.count && !service.adapters.isEmpty ? L.x("Deselectează tot", "Deselect all", "Deseleccionar todo") : L.x("Selectează tot", "Select all", "Seleccionar todo")) {
                            selected = selected.count == service.adapters.count ? [] : Set(service.adapters.map(\.name))
                        }
                        .font(.caption)
                        Spacer()
                        Button(L.x("Rescanează", "Rescan", "Volver a analizar")) { service.scanAdapters() }
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
                    Text(L.x("Selectate \(selected.count) din \(service.adapters.count) plăci de rețea", "Selected \(selected.count) of \(service.adapters.count) network adapters", "Seleccionados \(selected.count) de \(service.adapters.count) adaptadores de red"))
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(6)
            }

            GroupBox("Tuning Gigabit & TCP Kernel") {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L.x("Forțează 1 Gbps Full-Duplex, DNS Cloudflare/Google, buffere TCP 1MB pe plăcile bifate.", "Forces 1 Gbps full duplex, Cloudflare/Google DNS and 1 MB TCP buffers on the ticked adapters.", "Fuerza 1 Gbps full dúplex, DNS de Cloudflare/Google y búferes TCP de 1 MB en los adaptadores marcados."))
                        .foregroundStyle(.secondary)
                    Button(L.x("Aplică Tuning pe selecție (acum, o dată)", "Apply tuning to the selection (now, once)", "Aplicar el ajuste a la selección (ahora, una vez)")) { runGated { service.applyTuning(selectedAdapters: selected) } }
                        .disabled(selected.isEmpty)

                    Divider()

                    HStack(spacing: 6) {
                        Circle()
                            .fill(service.persistentTuningActive ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        Text(service.persistentTuningActive
                             ? L.x("Tuning persistent ACTIV — se reaplică automat la fiecare pornire", "Persistent tuning ON — reapplied automatically at every startup", "Ajuste persistente ACTIVO: se vuelve a aplicar en cada inicio")
                             : L.x("Tuning persistent INACTIV — dispare la restart", "Persistent tuning OFF — disappears on restart", "Ajuste persistente INACTIVO: desaparece al reiniciar"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Button(L.x("Activează la pornire (persistent)", "Enable at startup (persistent)", "Activar al iniciar (persistente)")) {
                            runGated { service.installPersistentTuning(selectedAdapters: selected) }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(selected.isEmpty)

                        if service.persistentTuningActive {
                            Button(L.x("Dezactivează", "Disable", "Desactivar"), role: .destructive) { runGated { service.removePersistentTuning() } }
                        }
                    }
                }
                .padding(6)
            }

            GroupBox("Motor Cloud (Rclone / macFUSE)") {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L.x("Configurarea conturilor Cloud s-a mutat în modulul „Cloud Manager” din bara laterală.", "Cloud account setup has moved to the “Cloud Manager” module in the sidebar.", "La configuración de cuentas en la nube se ha movido al módulo «Cloud Manager» de la barra lateral."))
                        .foregroundStyle(.secondary)
                    Button(L.x("Instalează Rclone + macFUSE", "Install rclone + macFUSE", "Instalar rclone + macFUSE")) { service.installRcloneStack() }
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
        .sheet(isPresented: $showGate) { AccessGateSheet() }
    }

    private func runGated(_ action: @escaping () -> Void) {
        if license.allowsFeatures {
            action()
        } else {
            showGate = true
        }
    }
}
