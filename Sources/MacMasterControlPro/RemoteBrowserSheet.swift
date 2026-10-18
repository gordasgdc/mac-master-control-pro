import SwiftUI
import AppKit
import MacMasterControlProCore

/// Faza 3+4 - explorare rapida a unui remote FARA sa-l montezi, plus
/// operatiile reale de management de fisiere (upload/download/stergere) —
/// cerinta explicita 2026-08-30: "cum sa urc, sa cobor, sa sincronizez,
/// sa aranjez fisierele".
struct RemoteBrowserSheet: View {
    let service: CloudManagerService
    let remoteName: String
    @Environment(\.dismiss) private var dismiss

    @State private var path = ""
    @State private var entries: [RemoteEntry] = []
    @State private var isLoading = false
    @State private var selectedEntry: RemoteEntry?
    @State private var logLines: [String] = []
    @State private var isBusy = false
    @State private var confirmDelete = false
    @State private var showSyncSheet = false

    private var breadcrumb: String { path.isEmpty ? "\(remoteName):" : "\(remoteName):/\(path)" }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Explorare — \(remoteName)").font(.title3).bold()
                Spacer()
                Button(L.x("Închide", "Close", "Cerrar")) { dismiss() }
            }

            HStack {
                if !path.isEmpty {
                    Button(L.x("⬅︎ Înapoi", "⬅︎ Back", "⬅︎ Atrás")) { goUp() }
                }
                Text(breadcrumb).font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
                Spacer()
                if isLoading || isBusy { ProgressView().controlSize(.small) }
            }

            List(entries, selection: $selectedEntry) { entry in
                HStack {
                    Image(systemName: entry.isDir ? "folder.fill" : "doc")
                        .foregroundStyle(entry.isDir ? .yellow : .secondary)
                    Text(entry.name)
                    Spacer()
                    if !entry.isDir {
                        Text(formattedSize(entry.size)).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .tag(entry)
                .contentShape(Rectangle())
                .onTapGesture(count: 2) { if entry.isDir { open(entry) } }
                .onTapGesture(count: 1) { selectedEntry = entry }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Faza 4: actiuni reale de management de fisiere.
            HStack {
                Button(L.x("⬆︎ Încarcă fișiere aici…", "⬆︎ Upload files here…", "⬆︎ Subir archivos aquí…")) { pickAndUpload() }
                    .disabled(isBusy)
                Button(L.x("⬇︎ Descarcă selecția", "⬇︎ Download selection", "⬇︎ Descargar la selección")) { downloadSelected() }
                    .disabled(isBusy || selectedEntry == nil)
                Button(L.x("🔄 Sincronizare folder…", "🔄 Sync folder…", "🔄 Sincronizar carpeta…")) { showSyncSheet = true }
                    .disabled(isBusy)
                Spacer()
                Button(role: .destructive) { confirmDelete = true } label: { Label(L.x("Șterge selecția", "Delete selection", "Eliminar la selección"), systemImage: "trash") }
                    .disabled(isBusy || selectedEntry == nil)
            }
            .font(.caption)

            if !logLines.isEmpty {
                TerminalLogView(lines: logLines)
            }
        }
        .padding(20)
        // FIX REAL (2026-08-30): un .sheet pe macOS devine efectiv
        // redimensionabil DOAR daca frame-ul exterior specifica explicit
        // maxWidth/maxHeight ca .infinity - fara ele (asa cum era pana
        // acum, doar minWidth/idealWidth), SwiftUI trateaza ideal ca plafon
        // real si fereastra ramane blocata la acea dimensiune, oricat ai
        // trage de margine. Raportat de Cristi: "ramane tot la o dimensiune
        // asa ingusta".
        .frame(minWidth: 560, idealWidth: 780, maxWidth: .infinity,
               minHeight: 420, idealHeight: 560, maxHeight: .infinity)
        .onAppear { reload() }
        .alert(L.x("Ștergi „\(selectedEntry?.name ?? "")”?", "Delete “\(selectedEntry?.name ?? "")”?", "¿Eliminar «\(selectedEntry?.name ?? "")»?"), isPresented: $confirmDelete) {
            Button(L.x("Anulează", "Cancel", "Cancelar"), role: .cancel) {}
            Button(L.x("Șterge definitiv", "Delete permanently", "Eliminar definitivamente"), role: .destructive) { deleteSelected() }
        } message: {
            Text(L.x("Această acțiune e ireversibilă — fișierul/folderul se șterge direct de pe \(remoteName).", "This action is irreversible — the file/folder is deleted directly from \(remoteName).", "Esta acción es irreversible: el archivo o la carpeta se elimina directamente de \(remoteName)."))
        }
        .sheet(isPresented: $showSyncSheet) {
            SyncFolderSheet(service: service, remoteName: remoteName, remotePath: path) { logLines.append($0) }
        }
    }

    private func open(_ entry: RemoteEntry) {
        path = entry.path
        selectedEntry = nil
        reload()
    }

    private func goUp() {
        var parts = path.split(separator: "/").map(String.init)
        if !parts.isEmpty { parts.removeLast() }
        path = parts.joined(separator: "/")
        selectedEntry = nil
        reload()
    }

    private func reload() {
        isLoading = true
        let currentPath = path
        DispatchQueue.global(qos: .userInitiated).async {
            let result = service.listRemoteFolder(remoteName: remoteName, path: currentPath)
            DispatchQueue.main.async {
                entries = result
                isLoading = false
            }
        }
    }

    private func pickAndUpload() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        isBusy = true
        logLines = []
        service.upload(remoteName: remoteName, remotePath: path, localPaths: panel.urls.map(\.path), log: { logLines.append($0) }) { _ in
            isBusy = false
            reload()
        }
    }

    private func downloadSelected() {
        guard let entry = selectedEntry else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.prompt = L.x("Descarcă aici", "Download here", "Descargar aquí")
        guard panel.runModal() == .OK, let destURL = panel.url else { return }
        isBusy = true
        logLines = []
        service.download(remoteName: remoteName, remotePath: entry.path, isDir: entry.isDir, localDestFolder: destURL.path, log: { logLines.append($0) }) { _ in
            isBusy = false
        }
    }

    private func deleteSelected() {
        guard let entry = selectedEntry else { return }
        isBusy = true
        logLines = []
        DispatchQueue.global(qos: .userInitiated).async {
            service.deleteRemoteEntry(remoteName: remoteName, remotePath: entry.path, isDir: entry.isDir, log: { line in
                DispatchQueue.main.async { logLines.append(line) }
            })
            DispatchQueue.main.async {
                isBusy = false
                selectedEntry = nil
                reload()
            }
        }
    }

    private func formattedSize(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

/// Sincronizare folder local <-> remote (Faza 4) - implicit "copy" (nu
/// sterge nimic), cu optiune explicita de oglinda exacta.
private struct SyncFolderSheet: View {
    let service: CloudManagerService
    let remoteName: String
    let remotePath: String
    let onLog: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var localFolder: String = ""
    @State private var direction: SyncDirection = .upload
    @State private var mirror = false
    @State private var isRunning = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L.x("Sincronizare folder", "Folder sync", "Sincronización de carpeta")).font(.title3).bold()

            HStack {
                Text(localFolder.isEmpty ? L.x("Niciun folder local ales", "No local folder chosen", "No se ha elegido ninguna carpeta local") : localFolder)
                    .font(.caption).foregroundStyle(localFolder.isEmpty ? .secondary : .primary)
                Spacer()
                Button(L.x("Alege folder local…", "Choose local folder…", "Elegir carpeta local…")) { pickFolder() }
            }

            Picker(L.x("Direcție", "Direction", "Dirección"), selection: $direction) {
                Text(L.x("Local → Cloud (încarcă)", "Local → Cloud (upload)", "Local → Nube (subir)")).tag(SyncDirection.upload)
                Text(L.x("Cloud → Local (descarcă)", "Cloud → Local (download)", "Nube → Local (descargar)")).tag(SyncDirection.download)
            }
            .pickerStyle(.radioGroup)

            Toggle(L.x("Oglindă exactă (șterge la destinație ce lipsește la sursă)", "Exact mirror (deletes at the destination what is missing at the source)", "Espejo exacto (borra en el destino lo que falta en el origen)"), isOn: $mirror)
                .toggleStyle(.checkbox)
            if mirror {
                Label(L.x("Atenție: poate șterge fișiere ireversibil la destinație.", "Warning: may irreversibly delete files at the destination.", "Atención: puede borrar archivos de forma irreversible en el destino."), systemImage: "exclamationmark.triangle.fill")
                    .font(.caption).foregroundStyle(.orange)
            }

            HStack {
                Button(L.x("Anulează", "Cancel", "Cancelar")) { dismiss() }
                Spacer()
                Button(isRunning ? L.x("Se sincronizează…", "Syncing…", "Sincronizando…") : L.x("Pornește sincronizarea", "Start sync", "Iniciar sincronización")) { run() }
                    .buttonStyle(.borderedProminent)
                    .disabled(localFolder.isEmpty || isRunning)
            }
        }
        .padding(24)
        .frame(width: 460)
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        localFolder = url.path
    }

    private func run() {
        isRunning = true
        service.syncFolder(localFolder: localFolder, remoteName: remoteName, remotePath: remotePath, direction: direction, mirror: mirror, log: onLog) { _ in
            isRunning = false
            dismiss()
        }
    }
}
