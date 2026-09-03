import SwiftUI
import AppKit
import MacMasterControlProCore

/// Analiză de disc, gen DaisyDisk — drill-down pe niveluri cu bară
/// proporțională + listă sortată descrescător după mărime.
struct DiskAnalyzerView: View {
    @State private var pathStack: [DiskEntry] = []
    @State private var entries: [DiskEntry] = []
    @State private var isScanning = false
    @State private var toDelete: DiskEntry?
    @State private var deleteError: String?
    /// Previne o cursă intre scanari: daca userul schimbă folderul (sau se
    /// întoarce la rădăcină) în timp ce o scanare veche, lentă, tot rulează
    /// pe fundal, rezultatul ei întârziat NU mai trebuie să suprascrie
    /// entries-urile folderului nou deschis — fiecare scanare își poartă
    /// propriul număr, doar cea mai recentă are voie să scrie rezultatul.
    @State private var scanGeneration = 0

    private let palette: [Color] = [.orange, .cyan, .purple, .green, .pink, .yellow, .indigo, .mint, .teal, .brown]

    private var currentPath: String? { pathStack.last?.path }
    private var totalBytes: Int64 { entries.reduce(0) { $0 + $1.sizeBytes } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("💽 Analiză Disc").font(.title2).bold()
                Text("Vezi ce ocupă spațiul, folder cu folder — apasă pe orice segment sau rând ca să intri în el.")
                    .font(.callout).foregroundStyle(.secondary)

                breadcrumb

                if isScanning {
                    HStack(spacing: 10) {
                        ProgressView().controlSize(.small)
                        Text("Scanez\(currentPath.map { " „\(($0 as NSString).lastPathComponent)”" } ?? "")… poate dura la un disc mare.")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                } else if !entries.isEmpty {
                    proportionalBar
                    entryList
                } else if pathStack.isEmpty {
                    rootPicker
                } else {
                    Text("Folder gol.").font(.callout).foregroundStyle(.secondary)
                }

                if let deleteError {
                    Text("✘ \(deleteError)").font(.caption).foregroundStyle(.red)
                }
            }
            .padding(24)
        }
        .onAppear { if pathStack.isEmpty { loadRoots() } }
        .alert("Ștergi „\(toDelete?.name ?? "")”?", isPresented: Binding(get: { toDelete != nil }, set: { if !$0 { toDelete = nil } })) {
            Button("Anulează", role: .cancel) { toDelete = nil }
            Button("Șterge", role: .destructive) { if let e = toDelete { delete(e) } }
        } message: {
            Text("Mută la Coșul de gunoi (\(toDelete?.sizeDescription ?? "")) — dacă permisiunile refuză, se cere automat parola de administrator.")
        }
    }

    // MARK: - Breadcrumb

    private var breadcrumb: some View {
        HStack(spacing: 6) {
            Button {
                resetToRoots()
            } label: {
                Image(systemName: "internaldrive")
            }
            .buttonStyle(.plain)

            ForEach(Array(pathStack.enumerated()), id: \.element.id) { index, entry in
                Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
                Button(entry.name) {
                    pathStack = Array(pathStack.prefix(index + 1))
                    scan(pathStack.last!.path)
                }
                .buttonStyle(.plain)
                .fontWeight(index == pathStack.count - 1 ? .semibold : .regular)
            }
        }
        .font(.callout)
    }

    // MARK: - Root picker (volume disponibile)

    @State private var roots: [DiskEntry] = []

    private var rootPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Alege ce vrei să analizezi:").font(.headline)
            ForEach(roots) { root in
                Button {
                    pathStack = [root]
                    scan(root.path)
                } label: {
                    HStack {
                        Image(systemName: root.path == "/" ? "internaldrive" : "externaldrive")
                        Text(root.name)
                        Spacer()
                        if root.sizeBytes > 0 {
                            Text(root.sizeDescription).foregroundStyle(.secondary)
                        }
                    }
                    .padding(10)
                    .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func loadRoots() {
        roots = DiskAnalyzerService.availableRoots()
    }

    /// Anulează efectiv orice scanare veche in zbor (incrementând
    /// generația — vezi comentariul de la `scanGeneration`) inainte de a
    /// goli starea, ca un rezultat intarziat sa nu mai poata "reaparea"
    /// peste ecranul de root dupa ce userul s-a intors deja acolo.
    private func resetToRoots() {
        scanGeneration += 1
        isScanning = false
        entries = []
        pathStack = []
        loadRoots()
    }

    // MARK: - Bara proportionala (stil DaisyDisk simplificat)

    private var proportionalBar: some View {
        GeometryReader { geo in
            HStack(spacing: 1) {
                ForEach(Array(entries.prefix(30).enumerated()), id: \.element.id) { index, entry in
                    let fraction = totalBytes > 0 ? CGFloat(entry.sizeBytes) / CGFloat(totalBytes) : 0
                    Rectangle()
                        .fill(palette[index % palette.count].opacity(0.85))
                        .frame(width: max(2, geo.size.width * fraction))
                        .onTapGesture { open(entry) }
                        .help("\(entry.name) — \(entry.sizeDescription)")
                }
            }
        }
        .frame(height: 28)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Lista

    private var entryList: some View {
        VStack(spacing: 0) {
            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                HStack {
                    Circle().fill(palette[index % palette.count]).frame(width: 8, height: 8)
                    Image(systemName: entry.isDirectory ? "folder.fill" : "doc")
                        .foregroundStyle(.secondary)
                    Text(entry.name).lineLimit(1)
                    Spacer()
                    Text(entry.sizeDescription).foregroundStyle(.secondary).font(.system(.callout, design: .monospaced))
                    Button {
                        NSWorkspace.shared.selectFile(entry.path, inFileViewerRootedAtPath: "")
                    } label: {
                        Image(systemName: "arrow.up.forward.app")
                    }
                    .buttonStyle(.plain)
                    .help("Arată în Finder")
                    Button(role: .destructive) {
                        toDelete = entry
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.plain)
                }
                .contentShape(Rectangle())
                .padding(.vertical, 6)
                .onTapGesture(count: 1) { if entry.isDirectory { open(entry) } }
                Divider()
            }
        }
    }

    // MARK: - Actiuni

    private func open(_ entry: DiskEntry) {
        guard entry.isDirectory else { return }
        pathStack.append(entry)
        scan(entry.path)
    }

    private func scan(_ path: String) {
        isScanning = true
        entries = []
        scanGeneration += 1
        let generation = scanGeneration
        DispatchQueue.global(qos: .userInitiated).async {
            let result = DiskAnalyzerService.scanLevel(path)
            DispatchQueue.main.async {
                // O scanare mai veche, terminată abia acum — irelevantă,
                // userul a navigat deja altundeva intre timp.
                guard generation == scanGeneration else { return }
                entries = result
                isScanning = false
            }
        }
    }

    private func delete(_ entry: DiskEntry) {
        toDelete = nil
        deleteError = nil
        DispatchQueue.global(qos: .userInitiated).async {
            let error = PrivilegedFileOps.delete(entry.path)
            DispatchQueue.main.async {
                if let error {
                    deleteError = error
                } else if let current = currentPath {
                    scan(current)
                }
            }
        }
    }
}
