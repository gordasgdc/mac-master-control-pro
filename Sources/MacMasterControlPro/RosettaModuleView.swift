import SwiftUI
import MacMasterControlProCore

struct RosettaModuleView: View {
    @StateObject private var service = RosettaInspector()
    @ObservedObject private var license = LicenseStore.shared
    @State private var showGate = false
    @State private var showConfirmRemove = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("🧭 Rosetta 2 Inspector").font(.title2).bold()

            GroupBox("Stare Rosetta 2") {
                HStack {
                    Circle()
                        .fill(service.rosettaInstalled ? Color.orange : Color.green)
                        .frame(width: 10, height: 10)
                    Text(service.rosettaInstalled ? "Instalată" : "Nu este instalată")
                    Spacer()
                    Button("Rescanează") { service.scan() }
                }
                .padding(6)
            }

            GroupBox("Aplicații Intel (x86_64) găsite: \(service.intelApps.count)") {
                if service.intelApps.isEmpty {
                    Text("Niciuna — sistemul e pregătit pentru macOS fără Rosetta.")
                        .foregroundStyle(.secondary).padding(6)
                } else {
                    List(service.intelApps) { app in
                        Text(app.name)
                    }
                    .frame(minHeight: 160)
                }
            }

            GroupBox("Curățare Rosetta") {
                VStack(alignment: .leading, spacing: 8) {
                    if !service.intelApps.isEmpty {
                        Label("Ai \(service.intelApps.count) aplicații care încă necesită Rosetta. Elimin-o doar după ce le înlocuiești.", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange).font(.caption)
                    }
                    Button("Elimină Rosetta 2 din sistem…", role: .destructive) {
                        if license.isActivated { showConfirmRemove = true } else { showGate = true }
                    }
                }
                .padding(6)
            }
            Spacer()
        }
        .padding(24)
        .onAppear { service.scan() }
        .sheet(isPresented: $showGate) { TrialGateModal() }
        .alert("Elimini Rosetta 2?", isPresented: $showConfirmRemove) {
            Button("Anulează", role: .cancel) {}
            Button("Elimină definitiv", role: .destructive) { service.removeRosetta() }
        } message: {
            Text("Operațiune nedocumentată oficial de Apple. Aplicațiile Intel rămase nu vor mai putea rula.")
        }
    }
}
