import SwiftUI
import MacMasterControlProCore

struct RosettaModuleView: View {
    @StateObject private var service = RosettaInspector()
    @ObservedObject private var license = LicenseStore.shared
    @State private var showGate = false
    @State private var showConfirmRemove = false
    @State private var showConfirmTrash = false
    @State private var selected: Set<IntelApp> = []
    @State private var status = ""

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
                    Button("Rescanează") { service.scan(); selected = [] }
                }
                .padding(6)
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Aplicații Intel (x86_64) găsite: \(service.intelApps.count)").font(.headline)
                        Spacer()
                        if !service.intelApps.isEmpty {
                            Button(selected.count == service.intelApps.count ? "Deselectează tot" : "Selectează tot") {
                                selected = selected.count == service.intelApps.count ? [] : Set(service.intelApps)
                            }
                            .font(.caption)
                        }
                    }

                    if service.intelApps.isEmpty {
                        Text("Niciuna — sistemul e pregătit pentru macOS fără Rosetta.")
                            .foregroundStyle(.secondary)
                    } else {
                        List(service.intelApps) { app in
                            Toggle(isOn: Binding(
                                get: { selected.contains(app) },
                                set: { checked in
                                    if checked { selected.insert(app) } else { selected.remove(app) }
                                }
                            )) {
                                Text(app.name)
                            }
                        }
                        .frame(minHeight: 200)

                        Text("Selectat \(selected.count) din \(service.intelApps.count) aplicații")
                            .font(.caption).foregroundStyle(.secondary)

                        Button("Trimite la Coș aplicațiile selectate", role: .destructive) {
                            if license.isActivated { showConfirmTrash = true } else { showGate = true }
                        }
                        .disabled(selected.isEmpty)
                    }
                }
                .padding(6)
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

            if !status.isEmpty {
                Text(status).font(.caption).foregroundStyle(.secondary)
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
        .alert("Trimiți \(selected.count) aplicații la Coș?", isPresented: $showConfirmTrash) {
            Button("Anulează", role: .cancel) {}
            Button("Trimite la Coș", role: .destructive) {
                let moved = service.moveToTrash(selected)
                status = "✔ \(moved) aplicații trimise la Coș."
                selected = []
            }
        } message: {
            Text("Poți restaura din Coșul de gunoi dacă te răzgândești.")
        }
    }
}
