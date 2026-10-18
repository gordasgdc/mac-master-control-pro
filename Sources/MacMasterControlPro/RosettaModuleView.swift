import SwiftUI
import MacMasterControlProCore

struct RosettaModuleView: View {
    @StateObject private var service = RosettaInspector.shared
    @ObservedObject private var license = AccessCoordinator.shared
    @State private var showGate = false
    @State private var showConfirmRemove = false
    @State private var showConfirmTrash = false
    @State private var selected: Set<IntelApp> = []
    @State private var status = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label("Rosetta 2 Inspector", systemImage: "cpu").font(.title2).bold()

            GroupBox("Stare Rosetta 2") {
                HStack {
                    Circle()
                        .fill(service.rosettaInstalled ? Color.orange : Color.green)
                        .frame(width: 10, height: 10)
                    Text(service.rosettaInstalled ? L.x("Instalată", "Installed", "Instalado") : L.x("Nu este instalată", "Not installed", "No instalado"))
                    Spacer()
                    Button(L.x("Rescanează", "Rescan", "Volver a analizar")) { service.scan(); selected = [] }
                }
                .padding(6)
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(L.x("Aplicații Intel (x86_64) găsite: \(service.intelApps.count)", "Intel (x86_64) apps found: \(service.intelApps.count)", "Apps Intel (x86_64) encontradas: \(service.intelApps.count)")).font(.headline)
                        Spacer()
                        if !service.intelApps.isEmpty {
                            Button(selected.count == service.intelApps.count ? L.x("Deselectează tot", "Deselect all", "Deseleccionar todo") : L.x("Selectează tot", "Select all", "Seleccionar todo")) {
                                selected = selected.count == service.intelApps.count ? [] : Set(service.intelApps)
                            }
                            .font(.caption)
                        }
                    }

                    if service.intelApps.isEmpty {
                        Text(L.x("Niciuna — sistemul e pregătit pentru macOS fără Rosetta.", "None — the system is ready for macOS without Rosetta.", "Ninguna: el sistema está listo para macOS sin Rosetta."))
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

                        Text(L.x("Selectat \(selected.count) din \(service.intelApps.count) aplicații", "Selected \(selected.count) of \(service.intelApps.count) apps", "Seleccionadas \(selected.count) de \(service.intelApps.count) apps"))
                            .font(.caption).foregroundStyle(.secondary)

                        Button(L.x("Trimite la Coș aplicațiile selectate", "Move selected apps to the Trash", "Mover las apps seleccionadas a la Papelera"), role: .destructive) {
                            if license.allowsFeatures { showConfirmTrash = true } else { showGate = true }
                        }
                        .disabled(selected.isEmpty)
                    }
                }
                .padding(6)
            }

            GroupBox(L.x("Curățare Rosetta", "Rosetta cleanup", "Limpieza de Rosetta")) {
                VStack(alignment: .leading, spacing: 8) {
                    if !service.intelApps.isEmpty {
                        Label(L.x("Ai \(service.intelApps.count) aplicații care încă necesită Rosetta. Elimin-o doar după ce le înlocuiești.", "You have \(service.intelApps.count) apps that still need Rosetta. Remove it only after replacing them.", "Tienes \(service.intelApps.count) apps que aún necesitan Rosetta. Elimínala solo después de sustituirlas."), systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange).font(.caption)
                    }
                    Button(L.x("Elimină Rosetta 2 din sistem…", "Remove Rosetta 2 from the system…", "Quitar Rosetta 2 del sistema…"), role: .destructive) {
                        if license.allowsFeatures { showConfirmRemove = true } else { showGate = true }
                    }
                }
                .padding(6)
            }

            if !status.isEmpty {
                StatusBanner(text: status)
            }
            Spacer()
        }
        .padding(24)
        .onAppear { service.scan() }
        .sheet(isPresented: $showGate) { AccessGateSheet() }
        .alert("Elimini Rosetta 2?", isPresented: $showConfirmRemove) {
            Button(L.x("Anulează", "Cancel", "Cancelar"), role: .cancel) {}
            Button(L.x("Elimină definitiv", "Remove permanently", "Quitar definitivamente"), role: .destructive) { service.removeRosetta() }
        } message: {
            Text(L.x("Operațiune nedocumentată oficial de Apple. Aplicațiile Intel rămase nu vor mai putea rula.", "Not officially documented by Apple. Remaining Intel apps will no longer run.", "Operación no documentada oficialmente por Apple. Las apps Intel restantes dejarán de ejecutarse."))
        }
        .alert(L.x("Trimiți \(selected.count) aplicații la Coș?", "Move \(selected.count) apps to the Trash?", "¿Mover \(selected.count) apps a la Papelera?"), isPresented: $showConfirmTrash) {
            Button(L.x("Anulează", "Cancel", "Cancelar"), role: .cancel) {}
            Button(L.x("Trimite la Coș", "Move to Trash", "Mover a la Papelera"), role: .destructive) {
                let moved = service.moveToTrash(selected)
                status = L.x("✔ \(moved) aplicații trimise la Coș.", "✔ \(moved) apps moved to the Trash.", "✔ \(moved) apps movidas a la Papelera.")
                selected = []
            }
        } message: {
            Text(L.x("Poți restaura din Coșul de gunoi dacă te răzgândești.", "You can restore from the Trash if you change your mind.", "Puedes restaurar desde la Papelera si cambias de opinión."))
        }
    }
}
