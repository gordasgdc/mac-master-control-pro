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

    private static var lastScanFormatter: DateFormatter {
        let f = DateFormatter(); f.dateFormat = "d MMMM, HH:mm"; f.locale = L.locale; return f
    }

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
        .alert(L.x("Resetezi cache-ul și rescanezi tot discul?", "Reset the cache and rescan the whole disk?", "¿Restablecer la caché y volver a escanear todo el disco?"), isPresented: $confirmingReset) {
            Button(L.x("Anulează", "Cancel", "Cancelar"), role: .cancel) {}
            Button(L.x("Resetează și rescanează", "Reset and rescan", "Restablecer y volver a escanear"), role: .destructive) { vm.resetCacheAndFullRescan() }
        } message: { Text(L.x("Poate dura mult pe un disc mare. „Verifică modificările” e suficient în mod normal.", "This can take long on a large disk. “Check for changes” is normally enough.", "Puede tardar en un disco grande. Normalmente basta con «Comprobar cambios».")) }
    }

    // MARK: - Antet și volume

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L.x("Ce ocupă spațiul", "What takes up space", "Qué ocupa el espacio")).font(.system(size: 30, weight: .bold, design: .rounded))
                    Text(L.x("Alege un volum, intră în foldere, bifează ce vrei să revizuiești.", "Pick a volume, step into folders, tick what you want to review.", "Elige un volumen, entra en carpetas y marca lo que quieras revisar.")).foregroundStyle(Studio.textMuted)
                }
                Spacer()
                if vm.tree != nil {
                    Picker("", selection: $advanced) { Text(L.x("Hartă", "Map", "Mapa")).tag(false); Text(L.x("Tabel avansat", "Advanced table", "Tabla avanzada")).tag(true) }
                        .pickerStyle(.segmented).frame(width: 190).labelsHidden()
                }
            }
            if !vm.roots.isEmpty || vm.tree != nil {
                HStack(spacing: 6) {
                    Button { chooseFolder() } label: {
                        VStack(spacing: 3) {
                            Image(systemName: "folder.badge.plus").font(.system(size: 30)).foregroundStyle(Studio.accent).frame(width: 52, height: 52)
                            Text(L.x("Alege un folder", "Choose a folder", "Elegir una carpeta")).font(.callout.weight(.medium))
                            Text(L.x("orice folder sau volum", "any folder or volume", "cualquier carpeta o volumen")).font(.caption).foregroundStyle(Studio.textMuted)
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
                        .accessibilityLabel(String(format: L.x("Volum %@","Volume %@","Volumen %@"), r.name))
                    }
                }
            }
        }
        .padding(.horizontal, 30).padding(.top, 22)
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.allowsMultipleSelection = false
        panel.prompt = L.x("Analizează", "Analyse", "Analizar"); panel.message = L.x("Alege folderul sau volumul de analizat", "Choose the folder or volume to analyse", "Elige la carpeta o el volumen a analizar")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        vm.startIndexing(root: DiskEntry(id: url.path, name: url.lastPathComponent, path: url.path, sizeBytes: 0, isDirectory: true))
    }

    private func isCurrent(_ r: DiskEntry) -> Bool { vm.tree?.path == URL(fileURLWithPath: r.path).resolvingSymlinksInPath().path || (vm.currentScanRootPath == r.path) }

    private var volumePicker: some View {
        Text(L.x("Alege un volum de mai sus ca să-l analizezi. Rezultatul rămâne salvat; la următoarea deschidere nu se reia scanarea.", "Pick a volume above to analyse it. The result is saved; the next time you open it, no rescan is needed.", "Elige un volumen arriba para analizarlo. El resultado se guarda; la próxima vez no se vuelve a escanear."))
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
                ProgressView().controlSize(.small); Text(L.x("Verific fișierele…", "Checking files…", "Comprobando archivos…")).font(.caption).foregroundStyle(Studio.textMuted)
                Button(L.x("Oprește", "Stop", "Detener")) { vm.cancelRescan() }.controlSize(.small)
            } else {
                if let d = vm.lastScannedAt {
                    Text(vm.lastVerifiedAt != nil ? String(format: L.x("Verificat %@","Checked %@","Comprobado %@"), Self.lastScanFormatter.string(from: d)) : String(format: L.x("Din analiza de %@, neverificată","From the analysis of %@, unchecked","Del análisis de %@, sin comprobar"), Self.lastScanFormatter.string(from: d)))
                        .font(.caption).foregroundStyle(Studio.textMuted)
                }
                if vm.accessErrors > 0 { Label(String(format: L.x("%d inaccesibile","%d inaccessible","%d inaccesibles"), vm.accessErrors), systemImage: "exclamationmark.circle").font(.caption).foregroundStyle(.orange) }
                Menu {
                    Button(L.x("Verifică modificările", "Check for changes", "Comprobar cambios")) { vm.rescanChangesOnly() }
                    Button(L.x("Resetează cache și rescanează…", "Reset cache and rescan…", "Restablecer caché y volver a escanear…")) { confirmingReset = true }
                } label: { Image(systemName: "arrow.clockwise") }
                    .menuStyle(.borderlessButton).fixedSize().help(L.x("Verifică modificările / rescanează", "Check for changes / rescan", "Comprobar cambios / volver a escanear"))
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
            if kids.isEmpty { Text(L.x("Folder gol.", "Empty folder.", "Carpeta vacía.")).foregroundStyle(Studio.textMuted) }
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(shown) { row($0) }
                    if kids.count > 5 {
                        Button(showAll ? L.x("Arată mai puține", "Show fewer", "Mostrar menos") : String(format: L.x("Alte %d elemente","%d more items","%d elementos más"), kids.count - 5)) { showAll.toggle() }
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
                .accessibilityLabel(String(format: selected ? L.x("Deselectează %@","Deselect %@","Deseleccionar %@") : L.x("Selectează %@","Select %@","Seleccionar %@"), n.name))
                SystemIconView(path: n.isAggregate ? (vm.currentNode?.path ?? "/") : n.path, size: 34)
                VStack(alignment: .leading, spacing: 1) {
                    Text(n.name).fontWeight(.semibold).lineLimit(1).truncationMode(.middle)
                    Text("\(Studio.gb(n.sizeBytes)) · \(percent(n))").font(.caption).foregroundStyle(Studio.textMuted)
                }
                Spacer(minLength: 6)
                ForEach(Array(f).sorted { $0.rawValue < $1.rawValue }, id: \.self) { FlagChip(flag: $0) }
                Button { openDetail = openDetail == n.id ? nil : n.id; vm.focusID = n.id } label: { Image(systemName: "info.circle") }
                    .buttonStyle(.plain).foregroundStyle(Studio.textMuted).help(L.x("Detalii","Details","Detalles")).accessibilityLabel(String(format: L.x("Detalii %@","Details %@","Detalles %@"), n.name))
                if n.isDirectory && !n.isAggregate {
                    Button { drill(n) } label: { Image(systemName: "chevron.right") }.buttonStyle(.plain).foregroundStyle(Studio.textMuted)
                        .accessibilityLabel(String(format: L.x("Deschide %@","Open %@","Abrir %@"), n.name))
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
                labeled("Cale", n.isAggregate ? L.x("(grup de fișiere mici din folderul curent)", "(group of small files in this folder)", "(grupo de archivos pequeños de esta carpeta)") : n.path)
                labeled(L.x("Mărime logică", "Logical size", "Tamaño lógico"), Studio.gb(n.sizeBytes))
                if n.allocatedBytes > 0 { labeled(L.x("Spațiu alocat", "Allocated space", "Espacio asignado"), Studio.gb(n.allocatedBytes)) }
                labeled(L.x("De ce această stare", "Why this state", "Por qué este estado"), SpaceClassifier.explanation(path: n.path, isDirectory: n.isDirectory, flags: flags))
            }
            if !n.isAggregate {
                HStack {
                    Button(n.isDirectory ? L.x("Arată în Finder", "Show in Finder", "Mostrar en el Finder") : L.x("Arată în Finder", "Show in Finder", "Mostrar en el Finder")) {
                        if n.isDirectory { NSWorkspace.shared.open(URL(fileURLWithPath: n.path)) }
                        else { NSWorkspace.shared.selectFile(n.path, inFileViewerRootedAtPath: "") }
                    }
                    if !n.isDirectory { Button(L.x("Previzualizează", "Preview", "Previsualizar")) { QuickLook.preview(path: n.path) } }
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
                Text(L.x("Recuperabil verificat în volum: ", "Verified recoverable in volume: ", "Recuperable verificado en el volumen: ")).foregroundStyle(Studio.textMuted)
                Text(Studio.gb(t.recoverable)).fontWeight(.semibold)
                Button(L.x("Cum se calculează", "How it is calculated", "Cómo se calcula")) { showCalc.toggle() }.buttonStyle(.plain).foregroundStyle(Studio.accent).fontWeight(.semibold)
                    .popover(isPresented: $showCalc) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(L.x("Calcul fără dublă numărare", "Calculation without double counting", "Cálculo sin doble recuento")).font(.headline)
                            Text(String(format: L.x("Regenerabil: %@","Regenerable: %@","Regenerable: %@"), Studio.gb(t.regenerable)))
                            Text(String(format: L.x("Surplus de duplicate verificate: %@","Surplus of verified duplicates: %@","Excedente de duplicados verificados: %@"), Studio.gb(t.duplicateSurplus)))
                            Text(String(format: L.x("Duplicate din interiorul unui element regenerabil, numărate o singură dată: %@","Duplicates inside a regenerable item, counted once: %@","Duplicados dentro de un elemento regenerable, contados una vez: %@"), Studio.gb(t.overlap))).foregroundStyle(Studio.textMuted)
                            Divider()
                            Text(String(format: L.x("Total: %@","Total: %@","Total: %@"), Studio.gb(t.recoverable))).fontWeight(.semibold)
                            Text(L.x("Elementele fără regulă verificată nu intră în total.", "Items without a verified rule are not part of the total.", "Los elementos sin regla verificada no cuentan en el total.")).font(.caption).foregroundStyle(Studio.textMuted)
                        }.padding(14).frame(width: 330)
                    }
            } else { ProgressView().controlSize(.small); Text(L.x("Calculez ce se poate recupera…", "Working out what can be recovered…", "Calculando lo recuperable…")).foregroundStyle(Studio.textMuted) }
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
                Text(String(format: (s.recoverable.count + s.unverified.count == 1) ? L.x("%d element selectat · %@","%d item selected · %@","%d elemento seleccionado · %@") : L.x("%d elemente selectate · %@","%d items selected · %@","%d elementos seleccionados · %@"), s.recoverable.count + s.unverified.count, Studio.gb(total))).fontWeight(.semibold)
                Text(String(format: L.x("%@ recuperabili verificat","%@ verified recoverable","%@ recuperables verificados"), Studio.gb(s.recoverableBytes)) + (s.unverifiedBytes > 0 ? String(format: L.x(" · %@ fără regulă verificată, nu intră în total"," · %@ without a verified rule, not in the total"," · %@ sin regla verificada, no entra en el total"), Studio.gb(s.unverifiedBytes)) : ""))
                    .font(.caption).foregroundStyle(Studio.textMuted)
            }
            Spacer()
            Button(L.x("Deselectează", "Deselect", "Deseleccionar")) { vm.clearSelection() }.buttonStyle(.plain).foregroundStyle(Studio.textMuted)
            Button { showReview = true } label: { Text(L.x("Revizuiește selecția", "Review selection", "Revisar selección")).fontWeight(.semibold).padding(.horizontal, 10) }
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
                title: vm.isLoadingCache ? L.x("Încarc analiza salvată…", "Loading the saved analysis…", "Cargando el análisis guardado…") : L.x("Indexez discul…", "Indexing the disk…", "Indexando el disco…"),
                detailPath: vm.currentScanRootPath ?? "",
                itemsLabel: "\(vm.filesIndexed) " + L.x("fișiere", "files", "archivos"),
                totalLabel: vm.indexedBytesDescription,
                fraction: nil, tint: Studio.accent, iconPath: vm.currentScanRootPath
            ) { vm.cancelIndexing() }
            Text(vm.isLoadingCache ? L.x("Citesc rezultatul scanării anterioare, nu se recitește discul.", "Reading the previous scan result; the disk is not re-read.", "Leyendo el resultado del escaneo anterior; no se vuelve a leer el disco.")
                 : L.x("O singură trecere completă. După ce se termină, orice subfolder se deschide instant.", "One full pass. Afterwards every subfolder opens instantly.", "Una sola pasada completa. Después, cada subcarpeta se abre al instante."))
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
                Text(res == nil ? L.x("Revizuiește înainte de a muta în Coș", "Review before moving to the Trash", "Revisa antes de mover a la Papelera") : resultTitle(res!)).font(.system(size: 22, weight: .bold, design: .rounded))
                Text(res == nil ? L.x("Nimic nu se șterge definitiv. Poți restaura din Coș.", "Nothing is deleted permanently. You can restore from the Trash.", "No se borra nada de forma definitiva. Puedes restaurar desde la Papelera.") : L.x("Elementele eșuate nu au fost modificate. Cele mutate se pot restaura din Coș.", "Items that failed were not changed. Moved items can be restored from the Trash.", "Los elementos fallidos no se modificaron. Los movidos se pueden restaurar desde la Papelera."))
                    .foregroundStyle(Studio.textMuted)
            }.padding(24)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if !s.recoverable.isEmpty || res != nil { group(L.x("Recuperabile verificat", "Verified recoverable", "Recuperable verificado"), icon: "checkmark.seal", paths: s.recoverable, bytes: s.recoverableBytes, res: res) }
                    if !s.unverified.isEmpty || (res != nil && !vm.unverifiedPathsForResult.isEmpty) {
                        VStack(alignment: .leading, spacing: 8) {
                            group(L.x("Fără regulă verificată", "No verified rule", "Sin regla verificada"), icon: "questionmark.shield", paths: s.unverified, bytes: s.unverifiedBytes, res: res, risk: true)
                            if res == nil {
                                Toggle(isOn: $vm.includeUnverified) {
                                    Text(L.x("Include și elementele fără regulă verificată. Nu știm dacă au o copie de rezervă; nu intră în totalul recuperabil.", "Also include items without a verified rule. We cannot tell whether they have a backup; they do not count toward the recoverable total.", "Incluir también los elementos sin regla verificada. No sabemos si tienen copia de seguridad; no cuentan en el total recuperable.")).font(.callout)
                                }.padding(.horizontal, 6)
                            }
                        }
                    }
                    HStack(spacing: 8) { Image(systemName: "lock"); Text(L.x("Excluse automat: backup-uri de dispozitiv, biblioteci Foto/Mail, aplicații și foldere personale întregi.", "Automatically excluded: device backups, Photos/Mail libraries, applications and whole personal folders.", "Excluidos automáticamente: copias de dispositivos, bibliotecas de Fotos/Mail, aplicaciones y carpetas personales completas.")) }
                        .font(.caption).foregroundStyle(Studio.textMuted).padding(.horizontal, 6)
                }.padding(.horizontal, 24)
            }
            Divider()
            HStack {
                let move = s.recoverableBytes + (vm.includeUnverified ? s.unverifiedBytes : 0)
                Text(String(format: L.x("Total de mutat: %@","Total to move: %@","Total a mover: %@"), Studio.gb(move))).foregroundStyle(Studio.textMuted)
                Spacer()
                Button(res == nil ? L.x("Înapoi", "Back", "Atrás") : L.x("Închide", "Close", "Cerrar")) { if res != nil { vm.dismissTrashResults() }; dismiss() }.keyboardShortcut(.cancelAction)
                if res == nil {
                    Button { vm.moveSelectionToTrash() } label: { Label(String(format: L.x("Mută %@ în Coș","Move %@ to the Trash","Mover %@ a la Papelera"), Studio.gb(move)), systemImage: "trash").fontWeight(.semibold) }
                        .buttonStyle(.borderedProminent).tint(Studio.accent).keyboardShortcut(.defaultAction)
                        .disabled(vm.isTrashing || (s.recoverable.isEmpty && !(vm.includeUnverified && !s.unverified.isEmpty)))
                }
            }.padding(18)
        }
        .frame(width: 560, height: 560)
        .background(Studio.canvasTop)
        .overlay { if vm.isTrashing { ProgressView(L.x("Mut în Coș…", "Moving to Trash…", "Moviendo a la Papelera…")).padding(20).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12)) } }
    }

    private func resultTitle(_ r: [UUID: TrashService.Outcome]) -> String {
        let ok = r.values.filter { $0 == .moved }.count
        return String(format: L.x("Rezultat: %d din %d mutate în Coș","Result: %d of %d moved to the Trash","Resultado: %d de %d movidos a la Papelera"), ok, r.count)
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
                    if let o = res?[n.id] { if case .failed(let why) = o { Text(String(format: L.x("eșuat: %@","failed: %@","falló: %@"), why)).font(.caption).foregroundStyle(Studio.caution) } else { Text(L.x("mutat","moved","movido")).font(.caption).foregroundStyle(Studio.good) } }
                    Text(Studio.gb(n.sizeBytes)).foregroundStyle(Studio.textMuted)
                }.padding(.horizontal, 12).padding(.vertical, 8)
            }
        }
        .background(Studio.card, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(risk ? Studio.caution.opacity(0.6) : Studio.line, lineWidth: risk ? 1.5 : 1))
    }
}
