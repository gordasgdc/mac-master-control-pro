import SwiftUI
import AppKit
import MacMasterControlProCore

struct DuplicateFinderView: View {
    @ObservedObject private var license = LicenseStore.shared
    @StateObject private var scanFolders = DuplicateScanFolders.shared
    @State private var showGate = false
    /// [2026-09-11] Starea scanarii traieste in ViewModel-ul SINGLETON, nu in
    /// `@State` pe view. La schimbarea tab-ului SwiftUI distruge view-ul si,
    /// odata cu el, orice `@State` — rezultatele se pierdeau si scanarea
    /// continua sa scrie intr-un view mort. Acelasi tipar ca
    /// DiskAnalyzerViewModel.shared, care functioneaza deja corect aici.
    @StateObject private var model = DuplicateFinderViewModel.shared
    @State private var logLines: [String] = []

    private var groups: [DuplicateGroup] { model.groups }
    private var isScanning: Bool { model.isScanning }
    private var scanStatus: String { model.statusText }
    private var markedForDeletion: Set<String> { model.markedForDeletion }

    private var totalReclaimable: Int64 { model.totalReclaimable }
    private var markedBytes: Int64 {
        groups.flatMap(\.files).filter { markedForDeletion.contains($0.path) }
            .reduce(0) { $0 + $1.sizeBytes }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Label("Duplicate", systemImage: "doc.on.doc").font(.title2).bold()
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
                            Button("Caută duplicate") { scan() }
                                .buttonStyle(.borderedProminent)
                                .disabled(scanFolders.folders.isEmpty || isScanning)
                                .help("Scanează folderele alese și grupează fișierele identice ca și conținut.")
                            // [2026-09-11] Pana acum scanarea nu putea fi
                            // oprita deloc — odata pornita pe 1,4 TB, ramaneai
                            // blocat pana se termina sau crapa aplicatia.
                            if isScanning {
                                Button("Stop") { model.cancel() }
                                    .help("Oprește scanarea acum.")
                            }
                        }
                        if isScanning, let progress = model.progress {
                            ScanProgressView(
                                title: progress.phase.label,
                                detailPath: progress.currentPath,
                                itemsLabel: "\(progress.filesSeen) fișiere",
                                totalLabel: ByteCountFormatter.string(fromByteCount: progress.bytesFound, countStyle: .file),
                                fraction: progress.fraction,
                                tint: .blue,
                                iconPath: scanFolders.folders.first
                            ) { model.cancel() }
                        } else if !scanStatus.isEmpty {
                            Text(scanStatus).font(.caption).foregroundStyle(.secondary)
                        }
                        if let error = model.errorMessage {
                            Label(error, systemImage: "exclamationmark.triangle.fill")
                                .font(.caption).foregroundStyle(.red)
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
                        DuplicateGroupCard(group: group, marked: $model.markedForDeletion)
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
        model.start(roots: scanFolders.folders)
    }

    private func deleteMarked() {
        logLines = []
        // [2026-09-11] Nu mai rescanam tot dupa stergere: ViewModel-ul scoate
        // direct fisierele sterse din grupuri si elimina grupurile ramase cu
        // un singur exemplar. O rescanare completa a 1,4 TB doar ca sa afli
        // ce tocmai ai sters tu insuti era timp aruncat.
        model.deleteMarked { logLines.append($0) }
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
