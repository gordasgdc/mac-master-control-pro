import SwiftUI
import AppKit
import MacMasterControlProCore

struct CleanupModuleView: View {
    @StateObject private var service = CleanupService.shared
    @ObservedObject private var license = AccessCoordinator.shared
    @State private var showGate = false
    @State private var selectedItems: Set<CleanableItem> = []
    @State private var selectedSnapshots: Set<String> = []
    @State private var status = ""
    @State private var logLines: [String] = []
    @StateObject private var scanFolders = BigFileScanFolders.shared
    @State private var bigFiles: [BigFile] = []
    @State private var selectedBigFiles: Set<BigFile> = []
    @State private var isScanningBigFiles = false

    private var selectedBytes: Int64 { selectedItems.reduce(0) { $0 + $1.sizeBytes } }
    private var totalBytes: Int64 { service.items.reduce(0) { $0 + $1.sizeBytes } }

    var body: some View {
        // BUG REAL (raportat de Cristi, 2026-08-31: "imi apare o lista de
        // bifat, dar nu vad butonul de sters sau sa ma intorc") — pagina
        // intreaga era un VStack fara ScrollView; cu pana la 100 de
        // fisiere mari listate, continutul depasea usor inaltimea
        // ferestrei, iar tot ce era dedesubt (butonul "Sterge fisierele
        // selectate", sectiunea RAM & DNS) devenea inaccesibil, in afara
        // ecranului, fara nicio bara de scroll care sa arate ca mai
        // exista continut. Fix: intreaga pagina scroleaza acum.
        ScrollView {
        VStack(alignment: .leading, spacing: 20) {
            Label(L.x("Curățare & RAM", "Cleanup & RAM", "Limpieza y RAM"), systemImage: "trash.circle").font(.title2).bold()

            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(L.x("Cache-uri recuperabile", "Recoverable caches", "Cachés recuperables")).font(.headline)
                        Spacer()
                        Button(selectedItems.count == service.items.count ? L.x("Deselectează tot", "Deselect all", "Deseleccionar todo") : L.x("Selectează tot", "Select all", "Seleccionar todo")) {
                            selectedItems = selectedItems.count == service.items.count ? [] : Set(service.items)
                        }
                        .font(.caption)
                        Button(L.x("Rescanează", "Rescan", "Volver a analizar")) { service.scanReclaimable() }
                    }

                    ForEach(service.items) { item in
                        HStack {
                            Toggle(isOn: Binding(
                                get: { selectedItems.contains(item) },
                                set: { checked in
                                    if checked { selectedItems.insert(item) } else { selectedItems.remove(item) }
                                }
                            )) {
                                Text(item.name)
                            }
                            Spacer()
                            Text(String(format: "%.2f GB", item.sizeGB))
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Divider()
                    Text(String(format: L.x("Selectat %.2f GB din %.2f GB", "Selected %.2f GB of %.2f GB", "Seleccionados %.2f GB de %.2f GB"), Double(selectedBytes) / 1_073_741_824, Double(totalBytes) / 1_073_741_824))
                        .font(.caption).foregroundStyle(.secondary)

                    Button(L.x("Șterge cache-urile selectate", "Delete selected caches", "Eliminar las cachés seleccionadas")) {
                        runGated {
                            logLines = []
                            service.deleteSelected(selectedItems) { logLines.append($0) }
                            selectedItems = []
                            status = L.x("✔ Gata — vezi detaliile mai jos.", "✔ Done — see the details below.", "✔ Listo: mira los detalles abajo.")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedItems.isEmpty)
                }
                .padding(6)
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(L.x("Time Machine — Snapshots locale", "Time Machine — local snapshots", "Time Machine — instantáneas locales")).font(.headline)
                        Spacer()
                        Button(selectedSnapshots.count == service.snapshotDates.count && !service.snapshotDates.isEmpty ? L.x("Deselectează tot", "Deselect all", "Deseleccionar todo") : L.x("Selectează tot", "Select all", "Seleccionar todo")) {
                            selectedSnapshots = selectedSnapshots.count == service.snapshotDates.count ? [] : Set(service.snapshotDates)
                        }
                        .font(.caption)
                        Button(L.x("Rescanează", "Rescan", "Volver a analizar")) { service.scanSnapshots() }
                    }
                    if service.snapshotDates.isEmpty {
                        Text(L.x("Niciun snapshot local găsit.", "No local snapshot found.", "No se encontró ninguna instantánea local.")).font(.caption).foregroundStyle(.secondary)
                    } else {
                        ForEach(service.snapshotDates, id: \.self) { date in
                            Toggle(isOn: Binding(
                                get: { selectedSnapshots.contains(date) },
                                set: { checked in
                                    if checked { selectedSnapshots.insert(date) } else { selectedSnapshots.remove(date) }
                                }
                            )) {
                                Text(date).font(.system(.caption, design: .monospaced))
                            }
                        }
                    }
                    Text(L.x("Selectat \(selectedSnapshots.count) din \(service.snapshotDates.count) snapshots", "Selected \(selectedSnapshots.count) of \(service.snapshotDates.count) snapshots", "Seleccionadas \(selectedSnapshots.count) de \(service.snapshotDates.count) instantáneas"))
                        .font(.caption).foregroundStyle(.secondary)
                    Button(L.x("Șterge snapshot-urile selectate", "Delete selected snapshots", "Eliminar las instantáneas seleccionadas")) {
                        runGated { service.deleteSelectedSnapshots(selectedSnapshots); selectedSnapshots = []; status = L.x("✔ Snapshots șterse.", "✔ Snapshots deleted.", "✔ Instantáneas eliminadas.") }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedSnapshots.isEmpty)
                }
                .padding(6)
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(L.x("Fișiere mari", "Large files", "Archivos grandes")).font(.headline)
                        Spacer()
                        if isScanningBigFiles { ProgressView().controlSize(.small) }
                        Button(L.x("Scanează (> 200 MB)", "Scan (> 200 MB)", "Analizar (> 200 MB)")) { scanBigFiles() }
                            .disabled(scanFolders.activeRoots.isEmpty)
                    }
                    Text(L.x("Foldere de scanat — alege ce vrei, adaugă orice folder propriu:", "Folders to scan — pick what you want, add any folder of your own:", "Carpetas que analizar: elige las que quieras y añade cualquiera propia:"))
                        .font(.caption).foregroundStyle(.secondary)
                    ForEach(BigFileFinderService.defaultRoots, id: \.self) { path in
                        Toggle(isOn: Binding(
                            get: { scanFolders.enabledDefaults.contains(path) },
                            set: { _ in scanFolders.toggleDefault(path) }
                        )) {
                            Text((path as NSString).lastPathComponent)
                        }
                        .toggleStyle(.checkbox)
                    }
                    ForEach(scanFolders.customFolders, id: \.self) { path in
                        HStack {
                            Toggle(isOn: .constant(true)) {
                                Text(path).lineLimit(1).truncationMode(.middle)
                            }
                            .toggleStyle(.checkbox)
                            .disabled(true)
                            Spacer()
                            Button {
                                scanFolders.removeCustomFolder(path)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                        }
                    }
                    Button(L.x("+ Adaugă folder…", "+ Add folder…", "+ Añadir carpeta…")) { addCustomFolder() }
                        .controlSize(.small)
                    if scanFolders.activeRoots.isEmpty {
                        Text(L.x("Bifează cel puțin un folder mai sus ca să poți scana.", "Tick at least one folder above to be able to scan.", "Marca al menos una carpeta arriba para poder analizar."))
                            .font(.caption).foregroundStyle(.orange)
                    }
                    Divider()
                    if bigFiles.isEmpty && !isScanningBigFiles {
                        Text(L.x("Apasă „Scanează” — arată cele mai mari 100 de fișiere din folderele unde se acumulează uitate.", "Press “Scan” — it shows the 100 largest files in the folders where forgotten ones pile up.", "Pulsa «Analizar»: muestra los 100 archivos más grandes de las carpetas donde se acumulan los olvidados."))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    ForEach(bigFiles) { file in
                        HStack {
                            Toggle(isOn: Binding(
                                get: { selectedBigFiles.contains(file) },
                                set: { checked in
                                    if checked { selectedBigFiles.insert(file) } else { selectedBigFiles.remove(file) }
                                }
                            )) {
                                Text(file.name).lineLimit(1).truncationMode(.middle)
                            }
                            Spacer()
                            Text(file.sizeDescription).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    if !bigFiles.isEmpty {
                        Button(L.x("Șterge fișierele selectate", "Delete selected files", "Eliminar los archivos seleccionados"), role: .destructive) {
                            runGated {
                                let toDelete = bigFiles.filter { selectedBigFiles.contains($0) }
                                BigFileFinderService.delete(toDelete) { logLines.append($0) }
                                selectedBigFiles = []
                                scanBigFiles()
                            }
                        }
                        .disabled(selectedBigFiles.isEmpty)
                    }
                }
                .padding(6)
            }

            GroupBox(L.x("RAM & DNS", "RAM & DNS", "RAM y DNS")) {
                Button(L.x("Purjare RAM + Flush DNS", "Purge RAM + flush DNS", "Purgar RAM + vaciar DNS")) {
                    runGated { service.purgeRAMAndFlushDNS(); status = "✔ RAM eliberat, DNS golit." }
                }
                .padding(6)
            }

            if !status.isEmpty {
                if !status.isEmpty { StatusBanner(text: status) }
            }
            if !logLines.isEmpty {
                TerminalLogView(lines: logLines)
            }
        }
        .padding(24)
        }
        .onAppear { service.scanReclaimable(); service.scanSnapshots() }
        .sheet(isPresented: $showGate) { AccessGateSheet() }
    }

    private func runGated(_ action: @escaping () -> Void) {
        if license.allowsFeatures { action() } else { showGate = true }
    }

    private func scanBigFiles() {
        let roots = scanFolders.activeRoots
        guard !roots.isEmpty else { return }
        isScanningBigFiles = true
        DispatchQueue.global(qos: .userInitiated).async {
            let result = BigFileFinderService.scan(roots: roots)
            DispatchQueue.main.async {
                bigFiles = result
                isScanningBigFiles = false
            }
        }
    }

    private func addCustomFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = L.x("Adaugă", "Add", "Añadir")
        if panel.runModal() == .OK, let url = panel.url {
            scanFolders.addCustomFolder(url.path)
        }
    }
}
