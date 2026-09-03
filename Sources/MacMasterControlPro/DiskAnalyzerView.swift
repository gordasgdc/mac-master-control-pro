import SwiftUI
import AppKit
import MacMasterControlProCore

/// Analiză de disc, gen DaisyDisk/GrandPerspective — indexare completă,
/// o singură dată, apoi navigare INSTANTĂ în arborele deja construit
/// (vezi `DiskScanEngine`/`DiskAnalyzerViewModel` pentru mecanism).
struct DiskAnalyzerView: View {
    @StateObject private var vm = DiskAnalyzerViewModel.shared
    @State private var toDelete: DiskTreeNode?
    @State private var confirmingReset = false

    private let palette: [Color] = [.orange, .cyan, .purple, .green, .pink, .yellow, .indigo, .mint, .teal, .brown]

    private static let lastScanFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMMM, HH:mm"
        f.locale = Locale(identifier: "ro_RO")
        return f
    }()

    private var totalBytes: Int64 { vm.currentChildren.reduce(0) { $0 + $1.sizeBytes } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Label("Analiză Disc", systemImage: "chart.pie").font(.title2).bold()
                Text("Indexare completă o singură dată — după aceea, navigarea în orice subfolder e instantă, chiar dacă navighezi în alt meniu între timp.")
                    .font(.callout).foregroundStyle(.secondary)

                if vm.isIndexing {
                    indexingProgress
                } else if vm.tree != nil {
                    if let lastScannedAt = vm.lastScannedAt {
                        cacheBanner(lastScannedAt)
                    }
                    breadcrumb
                    if vm.currentChildren.isEmpty {
                        Text("Folder gol.").font(.callout).foregroundStyle(.secondary)
                    } else {
                        proportionalBar
                        entryList
                    }
                } else {
                    rootPicker
                }

                if let deleteError = vm.deleteError {
                    Text("✘ \(deleteError)").font(.caption).foregroundStyle(.red)
                }
            }
            .padding(24)
        }
        .onAppear { vm.loadRootsIfNeeded() }
        .alert("Ștergi „\(toDelete?.name ?? "")”?", isPresented: Binding(get: { toDelete != nil }, set: { if !$0 { toDelete = nil } })) {
            Button("Anulează", role: .cancel) { toDelete = nil }
            Button("Șterge", role: .destructive) { if let n = toDelete { vm.delete(n) } }
        } message: {
            Text("Mută la Coșul de gunoi (\(toDelete?.sizeDescription ?? "")) — dacă permisiunile refuză, se cere automat parola de administrator.")
        }
        .alert("Resetezi cache-ul și rescanezi tot discul de la zero?", isPresented: $confirmingReset) {
            Button("Anulează", role: .cancel) {}
            Button("Resetează & Rescanează", role: .destructive) { vm.resetCacheAndFullRescan() }
        } message: {
            Text("Poate dura mult pe un disc mare — folosește-l doar dacă analiza pare vizibil greșită. „Re-scanează doar modificările” e suficient în mod normal.")
        }
    }

    // MARK: - Banner cache (ultima analiză + acțiuni de rescanare)

    private func cacheBanner(_ scannedAt: Date) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath").foregroundStyle(.secondary)
            Text("Afișez datele din analiza de la **\(Self.lastScanFormatter.string(from: scannedAt))**.")
                .font(.callout).foregroundStyle(.secondary)
            Spacer(minLength: 8)
            if vm.isRescanning {
                ProgressView().controlSize(.small)
                Text("Rescanez...").font(.caption).foregroundStyle(.secondary)
            } else {
                Button("Re-scanează doar modificările") { vm.rescanChangesOnly() }
                    .buttonStyle(.bordered)
                Button("Resetare Cache & Scanare Completă") { confirmingReset = true }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Progres indexare

    private var indexingProgress: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ProgressView().controlSize(.small)
                Text("Indexez... \(vm.filesIndexed) fișiere, \(vm.indexedBytesDescription) până acum.")
                    .font(.callout).foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }
            Text("O singură trecere completă — după ce se termină, orice subfolder se deschide instant, fără rescanare.")
                .font(.caption2).foregroundStyle(.tertiary)
        }
        .animation(.default, value: vm.filesIndexed)
    }

    // MARK: - Breadcrumb

    private var breadcrumb: some View {
        HStack(spacing: 6) {
            Button {
                vm.resetToRoots()
            } label: {
                Image(systemName: "internaldrive")
            }
            .buttonStyle(.plain)

            if !vm.pathStack.isEmpty {
                Button {
                    vm.pathStack.removeLast()
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.plain)
                .help("Înapoi")
            }

            ForEach(Array(vm.pathStack.enumerated()), id: \.element.id) { index, node in
                Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
                Button(node.name) {
                    vm.jumpTo(index: index)
                }
                .buttonStyle(.plain)
                .fontWeight(index == vm.pathStack.count - 1 ? .semibold : .regular)
            }
        }
        .font(.callout)
    }

    // MARK: - Root picker (volume disponibile)

    private var rootPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Alege ce vrei să analizezi:").font(.headline)
            ForEach(vm.roots) { root in
                Button {
                    vm.startIndexing(root: root)
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

    // MARK: - Bara proportionala (stil DaisyDisk simplificat)

    private var proportionalBar: some View {
        GeometryReader { geo in
            HStack(spacing: 1) {
                ForEach(Array(vm.currentChildren.prefix(30).enumerated()), id: \.element.id) { index, node in
                    let fraction = totalBytes > 0 ? CGFloat(node.sizeBytes) / CGFloat(totalBytes) : 0
                    Rectangle()
                        .fill(palette[index % palette.count].opacity(0.85))
                        .frame(width: max(2, geo.size.width * fraction))
                        .onTapGesture { vm.open(node) }
                        .help("\(node.name) — \(node.sizeDescription)")
                }
            }
        }
        .frame(height: 28)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Lista

    private var entryList: some View {
        VStack(spacing: 0) {
            ForEach(Array(vm.currentChildren.enumerated()), id: \.element.id) { index, node in
                HStack {
                    Circle().fill(palette[index % palette.count]).frame(width: 8, height: 8)
                    Image(systemName: node.isDirectory ? "folder.fill" : "doc")
                        .foregroundStyle(.secondary)
                    Text(node.name).lineLimit(1)
                    Spacer()
                    Text(node.sizeDescription).foregroundStyle(.secondary).font(.system(.callout, design: .monospaced))
                    Button {
                        // [2026-09-04] Cerință explicită: pentru un folder,
                        // "Arată în Finder" (selectFile) doar îl evidenția
                        // în fereastra PĂRINTELUI — userul voia să vadă
                        // efectiv CE E ÎNĂUNTRU. Pentru foldere, deschidem
                        // direct o fereastră Finder navigată ÎN el; pentru
                        // fișiere, comportamentul vechi (evidențiat în
                        // folderul care-l conține) rămâne corect — un
                        // fișier nu se "deschide" ca fereastră de Finder.
                        if node.isDirectory {
                            NSWorkspace.shared.open(URL(fileURLWithPath: node.path))
                        } else {
                            NSWorkspace.shared.selectFile(node.path, inFileViewerRootedAtPath: "")
                        }
                    } label: {
                        Image(systemName: node.isDirectory ? "folder" : "arrow.up.forward.app")
                    }
                    .buttonStyle(.plain)
                    .help(node.isDirectory ? "Deschide folderul în Finder" : "Arată în Finder")
                    Button(role: .destructive) {
                        toDelete = node
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.plain)
                }
                .contentShape(Rectangle())
                .padding(.vertical, 6)
                .onTapGesture(count: 1) { if node.isDirectory { vm.open(node) } }
                Divider()
            }
        }
    }
}
