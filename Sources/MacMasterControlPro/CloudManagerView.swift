import SwiftUI
import AppKit
import MacMasterControlProCore

struct CloudManagerView: View {
    @StateObject private var service = CloudManagerService()
    @ObservedObject private var license = LicenseStore.shared
    @State private var showGate = false
    @State private var showAddSheet = false
    @State private var useChunker = false
    @State private var chunkSize = "18G"
    @State private var selected: Set<String> = []
    @State private var logLines: [String] = []
    @State private var mountFolder: String? = CloudMountSettings.customMountFolder

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("☁️ Cloud Manager (Multi-Provider)").font(.title2).bold()
                Spacer()
                Button("+ Adaugă cont") { showAddSheet = true }
                Button("Rescanează") { service.refreshRemotes() }
            }

            GroupBox("Locație montare") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Implicit, conturile se montează pe Desktop. Poți alege în schimb un disc extern (Thunderbolt/USB-C), ca să nu ocupi spațiu pe SSD-ul intern.")
                        .font(.caption).foregroundStyle(.secondary)
                    Text(mountFolder?.isEmpty == false ? "Folder curent: \(mountFolder!)" : "Implicit: ~/Desktop")
                        .font(.caption).foregroundStyle(mountFolder?.isEmpty == false ? .green : .secondary)
                    HStack {
                        Button("Alege folder…") { pickMountFolder() }
                        Button("Resetează (Desktop)") {
                            CloudMountSettings.customMountFolder = nil
                            mountFolder = nil
                        }
                    }
                }
                .padding(6)
            }

            GroupBox("Chunker (spargere fișiere mari)") {
                HStack {
                    Toggle("Activ la montare", isOn: $useChunker)
                    TextField("Dimensiune", text: $chunkSize).frame(width: 80)
                    Text("recomandat 15–18G").foregroundStyle(.secondary).font(.caption)
                }
                .padding(6)
            }

            GroupBox("Conturi configurate") {
                if service.remotes.isEmpty {
                    Text("Niciun cont adăugat încă.").foregroundStyle(.secondary).padding(6)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Button(selected.count == service.remotes.count ? "Deselectează tot" : "Selectează tot") {
                                selected = selected.count == service.remotes.count ? [] : Set(service.remotes.map(\.name))
                            }
                            .font(.caption)
                            Spacer()
                            Text("Selectate \(selected.count) din \(service.remotes.count)").font(.caption).foregroundStyle(.secondary)
                        }
                        List(service.remotes) { remote in
                            HStack {
                                Toggle(isOn: Binding(
                                    get: { selected.contains(remote.name) },
                                    set: { checked in
                                        if checked { selected.insert(remote.name) } else { selected.remove(remote.name) }
                                    }
                                )) {
                                    VStack(alignment: .leading) {
                                        Text(remote.name).bold()
                                        Text(remote.type).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                if service.mounted.contains(where: { $0.remoteName == remote.name }) {
                                    Label("Montat", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                                } else {
                                    Text("Demontat").font(.caption).foregroundStyle(.secondary)
                                }
                                Button(role: .destructive) { service.deleteRemote(remote.name) } label: { Image(systemName: "trash") }
                                    .buttonStyle(.plain)
                            }
                        }
                        .frame(minHeight: 220)

                        HStack {
                            Button("Montează selecția") {
                                runGated {
                                    logLines = []
                                    for name in selected where !service.mounted.contains(where: { $0.remoteName == name }) {
                                        service.mount(remoteName: name, useChunker: useChunker, chunkSize: chunkSize) { logLines.append($0) }
                                    }
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(selected.isEmpty)

                            Button("Demontează selecția") {
                                logLines = []
                                for name in selected { service.unmount(remoteName: name) { logLines.append($0) } }
                            }
                            .disabled(selected.isEmpty)
                        }
                    }
                }
            }

            if !logLines.isEmpty {
                TerminalLogView(lines: logLines)
            }
            Spacer()
        }
        .padding(24)
        .onAppear { service.refreshRemotes() }
        .sheet(isPresented: $showAddSheet) { AddCloudRemoteSheet(service: service) }
        .sheet(isPresented: $showGate) { TrialGateModal() }
    }

    private func pickMountFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.prompt = "Alege"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        CloudMountSettings.customMountFolder = url.path
        mountFolder = url.path
    }

    private func runGated(_ action: @escaping () -> Void) {
        if license.isActivated { action() } else { showGate = true }
    }
}

struct AddCloudRemoteSheet: View {
    @ObservedObject var service: CloudManagerService
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var type: CloudProviderType = .googleDrive
    @State private var values: [String: String] = [:]
    @State private var status: String?
    @State private var isCreating = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Adaugă cont Cloud").font(.title3).bold()

            TextField("Nume cont (ex: drive_personal)", text: $name)
                .textFieldStyle(.roundedBorder)

            Picker("Provider", selection: $type) {
                ForEach(CloudProviderType.allCases) { Text($0.label).tag($0) }
            }

            if type.isOAuth {
                Text("Se va deschide browser-ul pentru autorizare — flux standard Rclone, o singură dată per cont.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(type.fields) { field in
                    if field.isSecure {
                        SecureField(field.label, text: binding(for: field.key))
                    } else {
                        TextField(field.label, text: binding(for: field.key))
                    }
                }
                .textFieldStyle(.roundedBorder)
            }

            if let status { Text(status).font(.caption).foregroundStyle(.secondary) }

            HStack {
                Button("Anulează") { dismiss() }
                Spacer()
                Button(isCreating ? "Se creează…" : "Adaugă") { create() }
                    .buttonStyle(.borderedProminent)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isCreating)
            }
        }
        .padding(28)
        .frame(width: 420)
    }

    private func binding(for key: String) -> Binding<String> {
        Binding(get: { values[key] ?? "" }, set: { values[key] = $0 })
    }

    private func create() {
        isCreating = true
        status = type.isOAuth ? "Verifică browser-ul pentru autorizare…" : nil
        service.createRemote(name: name, type: type, values: values) { success, message in
            isCreating = false
            if success {
                dismiss()
            } else {
                status = message.isEmpty ? "Eroare la creare." : message
            }
        }
    }
}
