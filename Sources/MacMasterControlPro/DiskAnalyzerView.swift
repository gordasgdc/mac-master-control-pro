import SwiftUI
import AppKit
import MacMasterControlProCore

/// Analiză de disc, direcția „Studio Glass”: hartă radială mare, listă scurtă, detalii la cerere, selecție vizibilă și o acțiune principală.
/// Datele sunt reale (arborele indexat); fiecare sector e proporțional cu mărimea lui; selecția e comună între hartă și listă.
struct DiskAnalyzerView: View {
    @StateObject private var vm = DiskAnalyzerViewModel.shared
    @ObservedObject private var dupes = DuplicateFinderViewModel.shared
    @State private var confirmingReset = false
    @State private var showAll = false
    @State private var openDetail: UUID?
    @State private var advanced = false
    @State private var showReview = false
    @State private var totals: (regenerable: Int64, duplicateSurplus: Int64, overlap: Int64, recoverable: Int64)?
    @State private var showCalc = false

    private static let lastScanFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "d MMMM, HH:mm"; f.locale = Locale(identifier: "ro_RO"); return f
    }()

    var body: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(colors: [Studio.canvasTop, Studio.canvasBottom], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                header
                if vm.isIndexing { indexingProgress.padding(.horizontal, 30).padding(.top, 20); Spacer() }
                else if vm.tree != nil { content }
                else { volumePicker.padding(.top, 8); Spacer() }
            }
            if vm.tree != nil, !vm.selection.isEmpty { tray.padding(.horizontal, 24).padding(.bottom, 18).transition(.move(edge: .bottom).combined(with: .opacity)) }
        }
        .animation(.easeOut(duration: 0.22), value: vm.selection.isEmpty)
        .onAppear { vm.loadRootsIfNeeded() }
        .task(id: vm.lastScannedAt) { await refreshTotals() }
        .task(id: dupes.groups.count) { await refreshTotals() }
        .sheet(isPresented: $showReview) { ReviewSheet(vm: vm, dismiss: { showReview = false }) }
        .alert("Resetezi cache-ul și rescanezi tot discul?", isPresented: $confirmingReset) {
            Button("Anulează", role: .cancel) {}
            Button("Resetează și rescanează", role: .destructive) { vm.resetCacheAndFullRescan() }
        } message: { Text("Poate dura mult pe un disc mare. „Verifică modificările” e suficient în mod normal.") }
    }

    // MARK: - Antet și volume

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ce ocupă spațiul").font(.system(size: 30, weight: .bold, design: .rounded))
                    Text("Alege un volum, intră în foldere, bifează ce vrei să revizuiești.").foregroundStyle(Studio.textMuted)
                }
                Spacer()
                if vm.tree != nil {
                    Picker("", selection: $advanced) { Text("Hartă").tag(false); Text("Tabel avansat").tag(true) }
                        .pickerStyle(.segmented).frame(width: 190).labelsHidden()
                }
            }
            if !vm.roots.isEmpty || vm.tree != nil {
                HStack(spacing: 6) {
                    Button { chooseFolder() } label: {
                        VStack(spacing: 3) {
                            Image(systemName: "folder.badge.plus").font(.system(size: 30)).foregroundStyle(Studio.accent).frame(width: 52, height: 52)
                            Text("Alege un folder").font(.callout.weight(.medium))
                            Text("orice folder sau volum").font(.caption).foregroundStyle(Studio.textMuted)
                        }
                        .frame(minWidth: 108).padding(.horizontal, 10).padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    ForEach(vm.roots) { r in
                        Button { vm.startIndexing(root: r) } label: {
                            VStack(spacing: 3) {
                                SystemIconView(path: r.path, size: 52)
                                Text(r.name.replacingOccurrences(of: " (volum principal)", with: "")).font(.callout.weight(.medium)).lineLimit(1)
                                if r.sizeBytes > 0 { Text(r.sizeDescription).font(.caption).foregroundStyle(Studio.textMuted) }
                            }
                            .frame(minWidth: 108).padding(.horizontal, 10).padding(.vertical, 8)
                            .background(isCurrent(r) ? Studio.card : .clear, in: RoundedRectangle(cornerRadius: 12))
                            .overlay(alignment: .bottom) { if isCurrent(r) { Capsule().fill(Studio.accent).frame(width: 40, height: 3).offset(y: -2) } }
                            .shadow(color: .black.opacity(isCurrent(r) ? 0.10 : 0), radius: 8, y: 3)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Volum \(r.name)")
                    }
                }
            }
        }
        .padding(.horizontal, 30).padding(.top, 22)
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.allowsMultipleSelection = false
        panel.prompt = "Analizează"; panel.message = "Alege folderul sau volumul de analizat"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        vm.startIndexing(root: DiskEntry(id: url.path, name: url.lastPathComponent, path: url.path, sizeBytes: 0, isDirectory: true))
    }

    private func isCurrent(_ r: DiskEntry) -> Bool { vm.tree?.path == URL(fileURLWithPath: r.path).resolvingSymlinksInPath().path || (vm.currentScanRootPath == r.path) }

    private var volumePicker: some View {
        Text("Alege un volum de mai sus ca să-l analizezi. Rezultatul rămâne salvat; la următoarea deschidere nu se reia scanarea.")
            .foregroundStyle(Studio.textMuted).padding(.horizontal, 30).padding(.top, 20)
    }

    // MARK: - Conținut

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            breadcrumb.padding(.horizontal, 30).padding(.top, 8)
            if let n = vm.scanNotice { Label(n, systemImage: "exclamationmark.triangle").font(.callout).foregroundStyle(.orange).padding(.horizontal, 30).padding(.top, 4) }
            if advanced { advancedTable.padding(.horizontal, 30).padding(.bottom, 96) }
            else {
                HStack(alignment: .top, spacing: 28) {
                    if let node = vm.currentNode {
                        SunburstView(root: node, selection: vm.selection, hover: $vm.hoverID,
                                     onTap: { vm.focusID = $0.id; if !vm.toggleSelection($0) { NSSound.beep() } },
                                     onDrill: { drill($0) })
                            .id(node.id)
                            .transition(.opacity)
                            .frame(minWidth: 320, maxWidth: .infinity, minHeight: 360)
                            .padding(.vertical, 6)
                    }
                    panel.frame(minWidth: 330, idealWidth: 420, maxWidth: 470)
                }
                .padding(.horizontal, 30).padding(.bottom, 96)
            }
        }
    }

    private var breadcrumb: some View {
        HStack(spacing: 6) {
            Button { vm.resetToRoots() } label: { Text(vm.tree?.name ?? "Volume") }.buttonStyle(.plain).foregroundStyle(vm.pathStack.isEmpty ? .primary : Studio.textMuted)
            ForEach(Array(vm.pathStack.enumerated()), id: \.element.id) { i, n in
                Image(systemName: "chevron.right").font(.caption2).foregroundStyle(Studio.textMuted)
                Button(n.name) { vm.jumpTo(index: i) }.buttonStyle(.plain)
                    .fontWeight(i == vm.pathStack.count - 1 ? .semibold : .regular)
                    .foregroundStyle(i == vm.pathStack.count - 1 ? Color.primary : Studio.textMuted)
            }
            Spacer()
            freshness
        }
        .font(.callout)
    }

    private var freshness: some View {
        HStack(spacing: 8) {
            if vm.isRescanning {
                ProgressView().controlSize(.small); Text("Verific fișierele…").font(.caption).foregroundStyle(Studio.textMuted)
                Button("Oprește") { vm.cancelRescan() }.controlSize(.small)
            } else {
                if let d = vm.lastScannedAt {
                    Text(vm.lastVerifiedAt != nil ? "Verificat \(Self.lastScanFormatter.string(from: d))" : "Din analiza de \(Self.lastScanFormatter.string(from: d)), neverificată")
                        .font(.caption).foregroundStyle(Studio.textMuted)
                }
                if vm.accessErrors > 0 { Label("\(vm.accessErrors) inaccesibile", systemImage: "exclamationmark.circle").font(.caption).foregroundStyle(.orange) }
                Menu {
                    Button("Verifică modificările") { vm.rescanChangesOnly() }
                    Button("Resetează cache și rescanează…") { confirmingReset = true }
                } label: { Image(systemName: "arrow.clockwise") }
                    .menuStyle(.borderlessButton).fixedSize().help("Verifică modificările / rescanează")
            }
        }
    }

    // MARK: - Panou dreapta

    private var focusNode: DiskTreeNode? { vm.focusID.flatMap { id in vm.currentChildren.first { $0.id == id } } ?? vm.currentNode }

    private var panel: some View {
        let kids = vm.currentChildren
        let shown = showAll ? kids : Array(kids.prefix(5))
        return VStack(alignment: .leading, spacing: 10) {
            if let f = focusNode {
                HStack(spacing: 14) {
                    SystemIconView(path: f.isAggregate ? (vm.currentNode?.path ?? "/") : f.path, size: 64)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(f.name).font(.system(size: 22, weight: .bold, design: .rounded)).lineLimit(2)
                        Text(Studio.gb(f.sizeBytes)).font(.title3).foregroundStyle(Studio.textMuted)
                    }
                    Spacer()
                    if f.isDirectory, f !== vm.currentNode, !f.isAggregate { Button { drill(f) } label: { Label("Deschide", systemImage: "chevron.right") }.buttonStyle(.bordered) }
                }
                Divider()
            }
            if kids.isEmpty { Text("Folder gol.").foregroundStyle(Studio.textMuted) }
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(shown) { row($0) }
                    if kids.count > 5 {
                        Button(showAll ? "Arată mai puține" : "Alte \(kids.count - 5) elemente") { showAll.toggle() }
                            .buttonStyle(.plain).foregroundStyle(Studio.accent).fontWeight(.semibold).padding(.vertical, 10)
                    }
                }
            }
            recoverableLine
        }
    }

    private func row(_ n: DiskTreeNode) -> some View {
        let f = vm.flags(n)
        let selected = vm.isSelected(n)
        let protectedItem = f.contains(.protected)
        return VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button { if !vm.toggleSelection(n) { NSSound.beep() } } label: {
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle").font(.title3)
                        .foregroundStyle(selected ? Studio.accent : (protectedItem ? Studio.line : Studio.textMuted))
                }
                .buttonStyle(.plain).disabled(protectedItem && !selected)
                .accessibilityLabel(selected ? "Deselectează \(n.name)" : "Selectează \(n.name)")
                SystemIconView(path: n.isAggregate ? (vm.currentNode?.path ?? "/") : n.path, size: 34)
                VStack(alignment: .leading, spacing: 1) {
                    Text(n.name).fontWeight(.semibold).lineLimit(1).truncationMode(.middle)
                    Text("\(Studio.gb(n.sizeBytes)) · \(percent(n))").font(.caption).foregroundStyle(Studio.textMuted)
                }
                Spacer(minLength: 6)
                ForEach(Array(f).sorted { $0.rawValue < $1.rawValue }, id: \.self) { FlagChip(flag: $0) }
                Button { openDetail = openDetail == n.id ? nil : n.id; vm.focusID = n.id } label: { Image(systemName: "info.circle") }
                    .buttonStyle(.plain).foregroundStyle(Studio.textMuted).help("Detalii").accessibilityLabel("Detalii \(n.name)")
                if n.isDirectory && !n.isAggregate {
                    Button { drill(n) } label: { Image(systemName: "chevron.right") }.buttonStyle(.plain).foregroundStyle(Studio.textMuted)
                        .accessibilityLabel("Deschide \(n.name)")
                }
            }
            .padding(.vertical, 8).padding(.horizontal, 6)
            .background(rowBackground(n, selected: selected), in: RoundedRectangle(cornerRadius: 10))
            .contentShape(Rectangle())
            .onTapGesture { vm.focusID = n.id }
            .onHover { vm.hoverID = $0 ? n.id : (vm.hoverID == n.id ? nil : vm.hoverID) }
            if openDetail == n.id { detail(n, flags: f).padding(.leading, 52).padding(.vertical, 6) }
            Divider().opacity(0.6)
        }
    }

    private func rowBackground(_ n: DiskTreeNode, selected: Bool) -> Color {
        selected ? Studio.accent.opacity(0.13) : (vm.hoverID == n.id ? Studio.accent.opacity(0.06) : .clear)
    }

    private func detail(_ n: DiskTreeNode, flags: Set<SpaceFlag>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Group {
                labeled("Cale", n.isAggregate ? "(grup de fișiere mici din folderul curent)" : n.path)
                labeled("Mărime logică", Studio.gb(n.sizeBytes))
                if n.allocatedBytes > 0 { labeled("Spațiu alocat", Studio.gb(n.allocatedBytes)) }
                labeled("De ce această stare", SpaceClassifier.explanation(path: n.path, isDirectory: n.isDirectory, flags: flags))
            }
            if !n.isAggregate {
                HStack {
                    Button(n.isDirectory ? "Arată în Finder" : "Arată în Finder") {
                        if n.isDirectory { NSWorkspace.shared.open(URL(fileURLWithPath: n.path)) }
                        else { NSWorkspace.shared.selectFile(n.path, inFileViewerRootedAtPath: "") }
                    }
                    if !n.isDirectory { Button("Previzualizează") { QuickLook.preview(path: n.path) } }
                }.controlSize(.small)
            }
        }
        .font(.caption).padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Studio.card, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Studio.line))
    }
    private func labeled(_ k: String, _ v: String) -> some View {
        HStack(alignment: .top, spacing: 8) { Text(k).foregroundStyle(Studio.textMuted).frame(width: 110, alignment: .leading); Text(v).textSelection(.enabled) }
    }

    private var recoverableLine: some View {
        HStack(spacing: 4) {
            if let t = totals {
                Text("Recuperabil verificat în volum: ").foregroundStyle(Studio.textMuted)
                Text(Studio.gb(t.recoverable)).fontWeight(.semibold)
                Button("Cum se calculează") { showCalc.toggle() }.buttonStyle(.plain).foregroundStyle(Studio.accent).fontWeight(.semibold)
                    .popover(isPresented: $showCalc) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Calcul fără dublă numărare").font(.headline)
                            Text("Regenerabil: \(Studio.gb(t.regenerable))")
                            Text("Surplus de duplicate verificate: \(Studio.gb(t.duplicateSurplus))")
                            Text("Duplicate din interiorul unui element regenerabil, numărate o singură dată: \(Studio.gb(t.overlap))").foregroundStyle(Studio.textMuted)
                            Divider()
                            Text("Total: \(Studio.gb(t.recoverable))").fontWeight(.semibold)
                            Text("Elementele fără regulă verificată nu intră în total.").font(.caption).foregroundStyle(Studio.textMuted)
                        }.padding(14).frame(width: 330)
                    }
            } else { ProgressView().controlSize(.small); Text("Calculez ce se poate recupera…").foregroundStyle(Studio.textMuted) }
        }
        .font(.caption).padding(.top, 4)
    }

    // MARK: - Tabel avansat

    private struct TRow: Identifiable { let id: UUID; let node: DiskTreeNode; let depth: Int }
    private var tableRows: [TRow] {
        var out: [TRow] = []
        for k in vm.currentChildren { out.append(TRow(id: k.id, node: k, depth: 0)); for c in k.sortedChildren.prefix(50) { out.append(TRow(id: c.id, node: c, depth: 1)) } }
        return out
    }
    private var advancedTable: some View {
        Table(tableRows) {
            TableColumn("") { r in
                Button { _ = vm.toggleSelection(r.node) } label: { Image(systemName: vm.isSelected(r.node) ? "checkmark.circle.fill" : "circle") }.buttonStyle(.plain)
            }.width(28)
            TableColumn("Nume") { r in Text(r.node.name).padding(.leading, CGFloat(r.depth) * 16).lineLimit(1) }
            TableColumn("Stare") { r in HStack { ForEach(Array(vm.flags(r.node)).sorted { $0.rawValue < $1.rawValue }, id: \.self) { FlagChip(flag: $0) } } }
            TableColumn("Logic") { r in Text(Studio.gb(r.node.sizeBytes)).monospacedDigit() }.width(90)
            TableColumn("Alocat") { r in Text(r.node.allocatedBytes > 0 ? Studio.gb(r.node.allocatedBytes) : "—").monospacedDigit() }.width(90)
            TableColumn("%") { r in Text(percent(r.node)).monospacedDigit() }.width(60)
        }
    }

    // MARK: - Tava de selecție

    private var tray: some View {
        let s = vm.summary
        let total = s.moveBytes
        return HStack(spacing: 14) {
            ZStack { ForEach(Array(vm.selection.values.prefix(2).enumerated()), id: \.element.id) { i, n in
                SystemIconView(path: n.isAggregate ? "/" : n.path, size: 34).offset(x: CGFloat(i) * 9, y: CGFloat(i) * -5) } }
                .frame(width: 52, height: 40)
            VStack(alignment: .leading, spacing: 1) {
                Text("\(s.recoverable.count + s.unverified.count) \(s.recoverable.count + s.unverified.count == 1 ? "element selectat" : "elemente selectate") · \(Studio.gb(total))").fontWeight(.semibold)
                Text("\(Studio.gb(s.recoverableBytes)) recuperabili verificat" + (s.unverifiedBytes > 0 ? " · \(Studio.gb(s.unverifiedBytes)) fără regulă verificată, nu intră în total" : ""))
                    .font(.caption).foregroundStyle(Studio.textMuted)
            }
            Spacer()
            Button("Deselectează") { vm.clearSelection() }.buttonStyle(.plain).foregroundStyle(Studio.textMuted)
            Button { showReview = true } label: { Text("Revizuiește selecția").fontWeight(.semibold).padding(.horizontal, 10) }
                .buttonStyle(.borderedProminent).tint(Studio.accent).controlSize(.large)
        }
        .padding(.vertical, 12).padding(.horizontal, 16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Studio.line))
        .shadow(color: .black.opacity(0.14), radius: 16, y: 6)
    }

    // MARK: - Helpers

    private func percent(_ n: DiskTreeNode) -> String {
        let t = Double(max(vm.currentNode?.sizeBytes ?? 1, 1)); let p = Double(n.sizeBytes) / t * 100
        return String(format: p < 10 ? "%.1f%%" : "%.0f%%", p).replacingOccurrences(of: ".", with: ",")
    }
    private func drill(_ n: DiskTreeNode) { guard n.isDirectory, !n.isAggregate else { return }; withAnimation(.easeOut(duration: 0.2)) { vm.open(n); vm.focusID = nil; showAll = false; openDetail = nil } }

    private func refreshTotals() async {
        guard let tree = vm.tree else { totals = nil; return }
        let surplus = vm.duplicateSurplus
        totals = nil
        let result = await Task.detached(priority: .utility) { SpaceMath.volumeTotals(root: tree, duplicateSurplus: surplus) }.value
        totals = result
    }

    // MARK: - Progres indexare

    private var indexingProgress: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScanProgressView(
                title: vm.isLoadingCache ? "Încarc analiza salvată…" : "Indexez discul…",
                detailPath: vm.currentScanRootPath ?? "",
                itemsLabel: "\(vm.filesIndexed) fișiere",
                totalLabel: vm.indexedBytesDescription,
                fraction: nil, tint: Studio.accent, iconPath: vm.currentScanRootPath
            ) { vm.cancelIndexing() }
            Text(vm.isLoadingCache ? "Citesc rezultatul scanării anterioare, nu se recitește discul."
                 : "O singură trecere completă. După ce se termină, orice subfolder se deschide instant.")
                .font(.caption2).foregroundStyle(.tertiary)
        }
    }
}

/// Previzualizare prin Quick Look (fișiere).
enum QuickLook {
    static func preview(path: String) {
        let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/qlmanage"); p.arguments = ["-p", path]
        p.standardOutput = Pipe(); p.standardError = Pipe(); try? p.run()
    }
}

// MARK: - Revizuire

struct ReviewSheet: View {
    @ObservedObject var vm: DiskAnalyzerViewModel
    let dismiss: () -> Void

    var body: some View {
        let s = vm.summary
        let res = vm.trashResults
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(res == nil ? "Revizuiește înainte de a muta în Coș" : resultTitle(res!)).font(.system(size: 22, weight: .bold, design: .rounded))
                Text(res == nil ? "Nimic nu se șterge definitiv. Poți restaura din Coș." : "Elementele eșuate nu au fost modificate. Cele mutate se pot restaura din Coș.")
                    .foregroundStyle(Studio.textMuted)
            }.padding(24)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if !s.recoverable.isEmpty || res != nil { group("Recuperabile verificat", icon: "checkmark.seal", paths: s.recoverable, bytes: s.recoverableBytes, res: res) }
                    if !s.unverified.isEmpty || (res != nil && !vm.unverifiedPathsForResult.isEmpty) {
                        VStack(alignment: .leading, spacing: 8) {
                            group("Fără regulă verificată", icon: "questionmark.shield", paths: s.unverified, bytes: s.unverifiedBytes, res: res, risk: true)
                            if res == nil {
                                Toggle(isOn: $vm.includeUnverified) {
                                    Text("Include și elementele fără regulă verificată. Nu știm dacă au o copie de rezervă; nu intră în totalul recuperabil.").font(.callout)
                                }.padding(.horizontal, 6)
                            }
                        }
                    }
                    HStack(spacing: 8) { Image(systemName: "lock"); Text("Excluse automat: backup-uri de dispozitiv, biblioteci Foto/Mail, aplicații și foldere personale întregi.") }
                        .font(.caption).foregroundStyle(Studio.textMuted).padding(.horizontal, 6)
                }.padding(.horizontal, 24)
            }
            Divider()
            HStack {
                let move = s.recoverableBytes + (vm.includeUnverified ? s.unverifiedBytes : 0)
                Text("Total de mutat: \(Studio.gb(move))").foregroundStyle(Studio.textMuted)
                Spacer()
                Button(res == nil ? "Înapoi" : "Închide") { if res != nil { vm.dismissTrashResults() }; dismiss() }.keyboardShortcut(.cancelAction)
                if res == nil {
                    Button { vm.moveSelectionToTrash() } label: { Label("Mută \(Studio.gb(move)) în Coș", systemImage: "trash").fontWeight(.semibold) }
                        .buttonStyle(.borderedProminent).tint(Studio.accent).keyboardShortcut(.defaultAction)
                        .disabled(vm.isTrashing || (s.recoverable.isEmpty && !(vm.includeUnverified && !s.unverified.isEmpty)))
                }
            }.padding(18)
        }
        .frame(width: 560, height: 560)
        .background(Studio.canvasTop)
        .overlay { if vm.isTrashing { ProgressView("Mut în Coș…").padding(20).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12)) } }
    }

    private func resultTitle(_ r: [UUID: TrashService.Outcome]) -> String {
        let ok = r.values.filter { $0 == .moved }.count
        return "Rezultat: \(ok) din \(r.count) mutate în Coș"
    }

    private func group(_ title: String, icon: String, paths: [String], bytes: Int64, res: [UUID: TrashService.Outcome]?, risk: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack { Label(title, systemImage: icon).fontWeight(.semibold); Spacer(); Text(Studio.gb(bytes)).foregroundStyle(Studio.textMuted) }.padding(12)
            ForEach(Array((res == nil ? Array(vm.selection.values) : Array(vm.resultItems.values)).filter { n in res == nil ? paths.contains(n.path) : (risk ? vm.unverifiedPathsForResult.contains(n.path) : !vm.unverifiedPathsForResult.contains(n.path)) }), id: \.id) { n in
                Divider()
                HStack(spacing: 10) {
                    SystemIconView(path: n.path, size: 28)
                    VStack(alignment: .leading) { Text(n.name).fontWeight(.medium); Text((n.path as NSString).deletingLastPathComponent).font(.caption).foregroundStyle(Studio.textMuted).lineLimit(1).truncationMode(.head) }
                    Spacer()
                    if let o = res?[n.id] { if case .failed(let why) = o { Text("eșuat: \(why)").font(.caption).foregroundStyle(Studio.caution) } else { Text("mutat").font(.caption).foregroundStyle(Studio.good) } }
                    Text(Studio.gb(n.sizeBytes)).foregroundStyle(Studio.textMuted)
                }.padding(.horizontal, 12).padding(.vertical, 8)
            }
        }
        .background(Studio.card, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(risk ? Studio.caution.opacity(0.6) : Studio.line, lineWidth: risk ? 1.5 : 1))
    }
}
