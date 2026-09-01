import SwiftUI
import AppKit
import MacMasterControlProCore

struct DuplicateFinderView: View {
    @ObservedObject private var license = LicenseStore.shared
    @StateObject private var scanFolders = DuplicateScanFolders.shared
    @State private var showGate = false
    @State private var groups: [DuplicateGroup] = []
    @State private var isScanning = false
    @State private var scanStatus = ""
    /// Cheie: path fisier -> bifat pentru stergere. Sugestie implicita
    /// (bifate toate MAI PUTIN cel mai vechi, "originalul") aplicata la
    /// fiecare scanare, dar userul o poate schimba liber pe orice fisier.
    @State private var markedForDeletion: Set<String> = []
    @State private var logLines: [String] = []

    private var totalReclaimable: Int64 { groups.reduce(0) { $0 + $1.reclaimableBytes } }
    private var markedBytes: Int64 {
        groups.flatMap(\.files).filter { markedForDeletion.contains($0.path) }
            .reduce(0) { $0 + $1.sizeBytes }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("🧬 Duplicate").font(.title2).bold()
                Text("Comparație REALĂ pe conținut (hash SHA256), nu doar nume/dată — două fișiere apar ca duplicate doar dacă sunt identice byte-cu-byte.")
                    .font(.caption).foregroundStyle(.secondary)

                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Foldere de căutat").font(.headline)
                        if scanFolders.folders.isEmpty {
                            Text("Niciun folder ales — adaugă cel puțin unul.")
                                .font(.caption).foregroundStyle(.orange)
                        }
                        ForEach(scanFolders.folders, id: \.self) { path in
                            HStack {
                                Image(systemName: "folder")
                                Text(path).lineLimit(1).truncationMode(.middle)
                                Spacer()
                                Button {
                                    scanFolders.removeFolder(path)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.secondary)
                            }
                        }
                        Button("+ Adaugă folder…") { addFolder() }
                            .controlSize(.small)

                        HStack {
                            if isScanning { ProgressView().controlSize(.small) }
                            Button("Caută duplicate") { scan() }
                                .buttonStyle(.borderedProminent)
                                .disabled(scanFolders.folders.isEmpty || isScanning)
                                .help("Scanează folderele alese și grupează fișierele identice ca și conținut.")
                        }
                        if !scanStatus.isEmpty {
                            Text(scanStatus).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(6)
                }

                if !groups.isEmpty {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(groups.count) grupuri de duplicate găsite.")
                                .font(.subheadline)
                            Text("Potențial recuperabil: \(ByteCountFormatter.string(fromByteCount: totalReclaimable, countStyle: .file))")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(6)
                    }

                    ForEach(groups) { group in
                        DuplicateGroupCard(group: group, marked: $markedForDeletion)
                    }

                    GroupBox {
                        HStack {
                            Text("Bifate spre ștergere: \(ByteCountFormatter.string(fromByteCount: markedBytes, countStyle: .file))")
                                .font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Button("Șterge fișierele bifate (\(markedForDeletion.count))", role: .destructive) {
                                runGated { deleteMarked() }
                            }
                            .disabled(markedForDeletion.isEmpty)
                        }
                        .padding(6)
                    }
                } else if !isScanning {
                    Text("Apasă „Caută duplicate” — comparăm conținutul fișierelor din folderele alese mai sus.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                if !logLines.isEmpty {
                    TerminalLogView(lines: logLines)
                }
            }
            .padding(24)
        }
        .sheet(isPresented: $showGate) { TrialGateModal() }
    }

    private func runGated(_ action: @escaping () -> Void) {
        if license.isActivated { action() } else { showGate = true }
    }

    private func addFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Adaugă"
        if panel.runModal() == .OK, let url = panel.url {
            scanFolders.addFolder(url.path)
        }
    }

    private func scan() {
        let roots = scanFolders.folders
        guard !roots.isEmpty else { return }
        isScanning = true
        groups = []
        markedForDeletion = []
        scanStatus = "Se scanează…"
        DispatchQueue.global(qos: .userInitiated).async {
            let result = DuplicateFinderService.scan(roots: roots) { line in
                DispatchQueue.main.async { scanStatus = line }
            }
            DispatchQueue.main.async {
                groups = result
                isScanning = false
                scanStatus = result.isEmpty ? "Niciun duplicat găsit." : ""
                // Sugestie implicita: pastreaza cel mai vechi (originalul
                // probabil), bifeaza restul spre stergere — userul poate
                // debifa/rebifa oricare inainte de a apasa Sterge.
                var defaults: Set<String> = []
                for group in result {
                    let sorted = group.files.sorted { ($0.modifiedDate ?? .distantFuture) < ($1.modifiedDate ?? .distantFuture) }
                    defaults.formUnion(sorted.dropFirst().map(\.path))
                }
                markedForDeletion = defaults
            }
        }
    }

    private func deleteMarked() {
        logLines = []
        let toDelete = groups.flatMap(\.files).filter { markedForDeletion.contains($0.path) }
        DuplicateFinderService.delete(toDelete) { logLines.append($0) }
        markedForDeletion = []
        scan()
    }
}

private struct DuplicateGroupCard: View {
    let group: DuplicateGroup
    @Binding var marked: Set<String>

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(group.files.count) copii identice · \(ByteCountFormatter.string(fromByteCount: group.sizeBytes, countStyle: .file)) fiecare")
                    .font(.caption).bold()
                ForEach(group.files) { file in
                    HStack {
                        Toggle(isOn: Binding(
                            get: { marked.contains(file.path) },
                            set: { checked in
                                if checked { marked.insert(file.path) } else { marked.remove(file.path) }
                            }
                        )) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(file.path).font(.caption).lineLimit(1).truncationMode(.middle)
                                if let date = file.modifiedDate {
                                    Text(date.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                        }
                        Spacer()
                        Button {
                            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: file.path)])
                        } label: {
                            Image(systemName: "folder")
                        }
                        .buttonStyle(.plain)
                        .help("Deschide în Finder — verifică fișierul înainte de a-l șterge.")
                    }
                }
            }
            .padding(6)
        }
    }
}
