import SwiftUI
import AppKit
import MacMasterControlProCore

struct CloudManagerView: View {
    @StateObject private var service = CloudManagerService.shared
    @ObservedObject private var license = AccessCoordinator.shared
    @State private var showGate = false
    @State private var showAddSheet = false
    @State private var useChunker = false
    @State private var chunkSize = "18G"
    @State private var selected: Set<String> = []
    @State private var logLines: [String] = []
    @State private var mountFolder: String? = CloudMountSettings.customMountFolder
    @State private var rcloneTransfers = RclonePerformanceSettings.transfers
    @State private var rcloneCheckers = RclonePerformanceSettings.checkers
    @State private var rcloneChunkMB = RclonePerformanceSettings.driveChunkMB
    @State private var rcloneFastList = RclonePerformanceSettings.fastList

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Label("Cloud Manager (Multi-Provider)", systemImage: "cloud").font(.title2).bold()
                Spacer()
                Button(L.x("+ Adaugă cont", "+ Add account", "+ Añadir cuenta")) { showAddSheet = true }
                Button(L.x("Rescanează", "Rescan", "Volver a analizar")) { service.refreshRemotes() }
            }

            GroupBox(L.x("Locație montare", "Mount location", "Ubicación de montaje")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L.x("Implicit, conturile se montează pe Desktop. Poți alege în schimb un disc extern (Thunderbolt/USB-C), ca să nu ocupi spațiu pe SSD-ul intern.", "By default, accounts mount on the Desktop. You can pick an external drive (Thunderbolt/USB-C) instead, so you don’t use space on the internal SSD.", "De forma predeterminada, las cuentas se montan en el Escritorio. Puedes elegir un disco externo (Thunderbolt/USB-C) para no ocupar espacio en el SSD interno."))
                        .font(.caption).foregroundStyle(.secondary)
                    Text(mountFolder?.isEmpty == false ? L.x("Folder curent: \(mountFolder!)", "Current folder: \(mountFolder!)", "Carpeta actual: \(mountFolder!)") : "Implicit: ~/Desktop")
                        .font(.caption).foregroundStyle(mountFolder?.isEmpty == false ? .green : .secondary)
                    HStack {
                        Button(L.x("Alege folder…", "Choose folder…", "Elegir carpeta…")) { pickMountFolder() }
                        Button(L.x("Resetează (Desktop)", "Reset (Desktop)", "Restablecer (Escritorio)")) {
                            CloudMountSettings.customMountFolder = nil
                            mountFolder = nil
                        }
                    }
                }
                .padding(6)
            }

            GroupBox(L.x("Performanță rclone (Încărcare / Descărcare / Sincronizare)", "rclone performance (Upload / Download / Sync)", "Rendimiento de rclone (subida / descarga / sincronización)")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L.x("Se aplică la Încărcare, Descărcare și Sincronizare — nu la montare. Valori mai mari pot ajuta la multe fișiere mici SAU la fișiere mari, dar pot suprasolicita conexiunea/providerul; scade dacă apar erori de tip rate-limit.", "Applies to Upload, Download and Sync — not to mounting. Higher values can help with many small files OR large files, but may overload the connection/provider; lower them if you get rate-limit errors.", "Se aplica a subida, descarga y sincronización, no al montaje. Valores más altos pueden ayudar con muchos archivos pequeños O con archivos grandes, pero pueden saturar la conexión o el proveedor; bájalos si aparecen errores de límite de tasa."))
                        .font(.caption).foregroundStyle(.secondary)
                    Stepper("Transferuri paralele: \(rcloneTransfers)", value: $rcloneTransfers, in: RclonePerformanceSettings.transfersRange)
                        .onChange(of: rcloneTransfers) { _, newValue in RclonePerformanceSettings.transfers = newValue }
                    Stepper(L.x("Verificări paralele (checkers): \(rcloneCheckers)", "Parallel checks (checkers): \(rcloneCheckers)", "Comprobaciones en paralelo (checkers): \(rcloneCheckers)"), value: $rcloneCheckers, in: RclonePerformanceSettings.checkersRange)
                        .onChange(of: rcloneCheckers) { _, newValue in RclonePerformanceSettings.checkers = newValue }
                    Picker("Fragment upload (chunk size)", selection: $rcloneChunkMB) {
                        ForEach(RclonePerformanceSettings.chunkChoicesMB, id: \.self) { mb in
                            Text("\(mb) MB").tag(mb)
                        }
                    }
                    .frame(width: 260)
                    .onChange(of: rcloneChunkMB) { _, newValue in RclonePerformanceSettings.driveChunkMB = newValue }
                    Toggle(L.x("Listare rapidă (--fast-list)", "Fast listing (--fast-list)", "Listado rápido (--fast-list)"), isOn: $rcloneFastList)
                        .onChange(of: rcloneFastList) { _, newValue in RclonePerformanceSettings.fastList = newValue }
                }
                .padding(6)
            }

            GroupBox(L.x("Chunker (spargere fișiere mari)", "Chunker (split large files)", "Chunker (dividir archivos grandes)")) {
                HStack {
                    Toggle(L.x("Activ la montare", "Active when mounting", "Activo al montar"), isOn: $useChunker)
                    TextField("Dimensiune", text: $chunkSize).frame(width: 80)
                    Text("recomandat 15–18G").foregroundStyle(.secondary).font(.caption)
                }
                .padding(6)
            }

            GroupBox("Conturi configurate") {
                if service.remotes.isEmpty {
                    Text(L.x("Niciun cont adăugat încă.", "No account added yet.", "Aún no se ha añadido ninguna cuenta.")).foregroundStyle(.secondary).padding(6)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Button(selected.count == service.remotes.count ? L.x("Deselectează tot", "Deselect all", "Deseleccionar todo") : L.x("Selectează tot", "Select all", "Seleccionar todo")) {
                                selected = selected.count == service.remotes.count ? [] : Set(service.remotes.map(\.name))
                            }
                            .font(.caption)
                            Spacer()
                            Text(L.x("Selectate \(selected.count) din \(service.remotes.count)", "Selected \(selected.count) of \(service.remotes.count)", "Seleccionadas \(selected.count) de \(service.remotes.count)")).font(.caption).foregroundStyle(.secondary)
                        }
                        List(service.remotes) { remote in
                            CloudRemoteRow(service: service, remote: remote, selected: $selected)
                        }
                        .frame(minHeight: 220)

                        HStack {
                            Button(L.x("Montează selecția", "Mount selection", "Montar la selección")) {
                                runGated {
                                    logLines = []
                                    for name in selected where !service.mounted.contains(where: { $0.remoteName == name }) {
                                        service.mount(remoteName: name, useChunker: useChunker, chunkSize: chunkSize) { logLines.append($0) }
                                    }
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(selected.isEmpty)

                            Button(L.x("Demontează selecția", "Unmount selection", "Desmontar la selección")) {
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
        .sheet(isPresented: $showGate) { AccessGateSheet() }
    }

    private func pickMountFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.prompt = L.x("Alege", "Choose", "Elegir")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        CloudMountSettings.customMountFolder = url.path
        mountFolder = url.path
    }

    private func runGated(_ action: @escaping () -> Void) {
        if license.allowsFeatures { action() } else { showGate = true }
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
    @State private var useGDCClient = GDCOAuthClients.useGDCClientForNewRemotes

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L.x("Adaugă cont Cloud", "Add cloud account", "Añadir cuenta en la nube")).font(.title3).bold()

            TextField(L.x("Nume cont (ex: drive_personal)", "Account name (e.g. drive_personal)", "Nombre de la cuenta (p. ej. drive_personal)"), text: $name)
                .textFieldStyle(.roundedBorder)

            Picker("Provider", selection: $type) {
                ForEach(CloudProviderType.allCases) { Text($0.label).tag($0) }
            }

            if type.isOAuth {
                Text(L.x("Se va deschide browser-ul pentru autorizare — flux standard Rclone, o singură dată per cont.", "Your browser will open for authorisation — standard rclone flow, once per account.", "Se abrirá el navegador para autorizar: flujo estándar de rclone, una vez por cuenta."))
                    .font(.caption).foregroundStyle(.secondary)
                if type == .googleDrive {
                    Toggle(L.x("Folosește client Google rapid (GDC)", "Use the fast Google client (GDC)", "Usar el cliente rápido de Google (GDC)"), isOn: $useGDCClient)
                        .onChange(of: useGDCClient) { _, newValue in GDCOAuthClients.useGDCClientForNewRemotes = newValue }
                    Text(L.x("Activează DOAR pentru un cont pe care l-ai adăugat deja ca „test user” în Google Cloud Console — altfel contul rămâne blocat la conectare (mesaj „Access blocked”, fără opțiune de a continua). Vezi GHID_INTERN_ONBOARDING_GOOGLE_DRIVE.md.", "Enable ONLY for an account you have already added as a “test user” in Google Cloud Console — otherwise sign-in stays blocked (“Access blocked”, with no option to continue).", "Actívalo SOLO para una cuenta que ya hayas añadido como «usuario de prueba» en Google Cloud Console; si no, el inicio de sesión queda bloqueado («Access blocked», sin opción de continuar)."))
                        .font(.caption2).foregroundStyle(.secondary)
                }
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

            if let status { StatusBanner(text: status) }

            HStack {
                Button(L.x("Anulează", "Cancel", "Cancelar")) { dismiss() }
                Spacer()
                Button(isCreating ? L.x("Se creează…", "Creating…", "Creando…") : L.x("Adaugă", "Add", "Añadir")) { create() }
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
        status = type.isOAuth ? L.x("Verifică browser-ul pentru autorizare…", "Check your browser to authorise…", "Revisa el navegador para autorizar…") : nil
        service.createRemote(name: name, type: type, values: values) { success, message in
            isCreating = false
            if success {
                dismiss()
            } else {
                status = message.isEmpty ? L.x("Eroare la creare.", "Creation failed.", "Error al crear.") : message
            }
        }
    }
}
