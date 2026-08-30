import SwiftUI
import MacMasterControlProCore

struct CloudManagerView: View {
    @StateObject private var service = CloudManagerService()
    @ObservedObject private var license = LicenseStore.shared
    @State private var showGate = false
    @State private var showAddSheet = false
    @State private var useChunker = false
    @State private var chunkSize = "18G"

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("☁️ Cloud Manager (Multi-Provider)").font(.title2).bold()
                Spacer()
                Button("+ Adaugă cont") { showAddSheet = true }
                Button("Rescanează") { service.refreshRemotes() }
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
                    List(service.remotes) { remote in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(remote.name).bold()
                                Text(remote.type).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if service.mounted.contains(where: { $0.remoteName == remote.name }) {
                                Label("Montat", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                                Button("Demontează") { service.unmount(remoteName: remote.name) }
                            } else {
                                Button("Montează pe Desktop") { runGated { service.mount(remoteName: remote.name, useChunker: useChunker, chunkSize: chunkSize) } }
                            }
                            Button(role: .destructive) { service.deleteRemote(remote.name) } label: { Image(systemName: "trash") }
                        }
                    }
                    .frame(minHeight: 220)
                }
            }
            Spacer()
        }
        .padding(24)
        .onAppear { service.refreshRemotes() }
        .sheet(isPresented: $showAddSheet) { AddCloudRemoteSheet(service: service) }
        .sheet(isPresented: $showGate) { TrialGateModal() }
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
