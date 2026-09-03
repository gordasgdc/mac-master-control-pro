import SwiftUI
import MacMasterControlProCore

/// Modul "Dezinstalator" — șterge complet o aplicație (ORICARE, nu doar
/// produse GDC): bundle-ul + Application Support/Caches/Preferences/
/// Saved State/Logs/HTTPStorages/WebKit/Containers/LaunchAgents/Daemons.
/// Cerință directă (2026-08-31): "să dezinstalezi tot ce ține legătură de
/// acea aplicație, să nu rămână nimica pe niciunde".
struct UninstallerModuleView: View {
    @ObservedObject private var license = LicenseStore.shared
    @State private var showGate = false

    @State private var apps: [InstalledApp] = []
    @State private var searchText = ""
    @State private var selectedApp: InstalledApp?
    @State private var categories: [UninstallCategory] = []
    @State private var selectedCategoryIDs: Set<String> = []
    @State private var deleteAppItselfToo = true
    @State private var logLines: [String] = []
    @State private var isBusy = false
    @State private var pendingConfirm = false

    /// Selecție separată de "aplicația deschisă în detaliu" — cerință
    /// directă (2026-09-01): "vreau sa pot selecta mai multe si sa le
    /// dezinstalez, nu una cate una". Bifa de pe fiecare rând adaugă
    /// aplicația la ștergerea în masă; click pe rând (în afara bifei) tot
    /// deschide detaliul ei individual, ca înainte — cele două acțiuni
    /// sunt independente.
    @State private var bulkSelectedIDs: Set<String> = []
    @State private var pendingBulkConfirm = false
    @State private var isBulkBusy = false

    private var filteredApps: [InstalledApp] {
        guard !searchText.isEmpty else { return apps }
        return apps.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        HSplitView {
            appListPane
            detailsPane
        }
        .padding(24)
        .onAppear { apps = UninstallerService.scanInstalledApps() }
        .sheet(isPresented: $showGate) { TrialGateModal() }
    }

    // MARK: - Lista de aplicații

    private var appListPane: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Dezinstalator", systemImage: "trash.slash").font(.title2).bold()
                Spacer()
                if !bulkSelectedIDs.isEmpty {
                    Button("Dezinstalează selectate (\(bulkSelectedIDs.count))", role: .destructive) {
                        pendingBulkConfirm = true
                    }
                    .disabled(isBulkBusy)
                    .help("Șterge complet toate aplicațiile bifate mai jos — bundle-ul + toate urmele lor (Application Support, Caches, Preferences etc.), într-un singur pas.")
                }
            }
            TextField("Caută aplicație…", text: $searchText).textFieldStyle(.roundedBorder)
            List(filteredApps, selection: $selectedApp) { app in
                HStack {
                    Toggle(isOn: Binding(
                        get: { bulkSelectedIDs.contains(app.id) },
                        set: { checked in
                            if checked { bulkSelectedIDs.insert(app.id) } else { bulkSelectedIDs.remove(app.id) }
                        }
                    )) { EmptyView() }
                    .toggleStyle(.checkbox)
                    .help("Bifează ca să incluzi \(app.name) la o ștergere în masă a mai multor aplicații deodată.")
                    Image(nsImage: app.icon).resizable().frame(width: 20, height: 20)
                    Text(app.name)
                }
                .tag(app)
                .onTapGesture { selectApp(app) }
            }
        }
        .frame(minWidth: 260, idealWidth: 300)
        .confirmationDialog(
            "Ștergi definitiv \(bulkSelectedIDs.count) aplicații?",
            isPresented: $pendingBulkConfirm, titleVisibility: .visible
        ) {
            Button("Șterge definitiv toate", role: .destructive) { runGated { performBulkDelete() } }
            Button("Anulează", role: .cancel) {}
        } message: {
            Text("Fiecare aplicație bifată va fi ștearsă complet, împreună cu toate urmele ei găsite pe disc.")
        }
    }

    // MARK: - Detalii + scanare urme

    private var detailsPane: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let app = selectedApp {
                HStack {
                    Image(nsImage: app.icon).resizable().frame(width: 32, height: 32)
                    Text(app.name).font(.title3).bold()
                    Spacer()
                    Toggle("Șterge și aplicația", isOn: $deleteAppItselfToo)
                }

                if categories.isEmpty {
                    Text("Nicio urmă găsită în afara aplicației înseși (deja curat).")
                        .foregroundStyle(.secondary)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(categories) { category in
                                HStack {
                                    Toggle(isOn: Binding(
                                        get: { selectedCategoryIDs.contains(category.id) },
                                        set: { checked in
                                            if checked { selectedCategoryIDs.insert(category.id) }
                                            else { selectedCategoryIDs.remove(category.id) }
                                        }
                                    )) {
                                        HStack {
                                            Text(category.title)
                                            if category.requiresPrivilege {
                                                Image(systemName: "lock.fill").font(.caption2).foregroundStyle(.orange)
                                            }
                                        }
                                    }
                                    Spacer()
                                    Text(category.sizeDescription).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 260)

                    Text("Total selectat: \(selectedSizeDescription)")
                        .font(.caption).foregroundStyle(.secondary)
                }

                if !logLines.isEmpty {
                    TerminalLogView(lines: logLines)
                }

                HStack {
                    if isBusy { ProgressView().controlSize(.small) }
                    Button("Șterge selectate", role: .destructive) { pendingConfirm = true }
                        .disabled(isBusy || (selectedCategoryIDs.isEmpty && !deleteAppItselfToo))
                        .help("Șterge doar categoriile bifate mai sus pentru \(app.name) — folosește asta ca să păstrezi ceva anume (ex. Preferences).")
                    Button("Rescanează") { selectApp(app) }
                        .help("Rulează din nou scanarea de urme pentru \(app.name) — util dacă tocmai ai șters ceva manual sau ai deschis aplicația între timp.")
                }
            } else {
                Text("Alege o aplicație din listă.").foregroundStyle(.secondary)
            }
            Spacer()
        }
        .frame(minWidth: 380)
        .confirmationDialog(
            "Ștergi definitiv \(selectedApp?.name ?? "")?",
            isPresented: $pendingConfirm, titleVisibility: .visible
        ) {
            Button("Șterge definitiv", role: .destructive) { runGated { performDelete() } }
            Button("Anulează", role: .cancel) {}
        } message: {
            Text("Total: \(selectedSizeDescription)\(deleteAppItselfToo ? " + aplicația însăși" : "")")
        }
    }

    private var selectedSizeDescription: String {
        let bytes = categories.filter { selectedCategoryIDs.contains($0.id) }.reduce(Int64(0)) { $0 + $1.totalBytes }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    /// `keepLog: true` pastreaza `logLines` neatinse - folosit dupa o
    /// stergere esuata, ca sa NU se piarda mesajul de diagnostic chiar
    /// inainte ca userul sa apuce sa-l citeasca (BUG REAL, 2026-09-03,
    /// gasit dintr-o inregistrare video trimisa de Cristi: "il sterg, tot
    /// apare" - mesajul real de eroare/diagnostic era calculat corect, dar
    /// `selectApp` reseta `logLines = []` IMEDIAT dupa ce era adaugat,
    /// inainte ca userul sa-l vada - panoul revenea instant la placeholder-ul
    /// "Nicio urma gasita", ascunzand complet cauza reala).
    private func selectApp(_ app: InstalledApp, keepLog: Bool = false) {
        selectedApp = app
        categories = UninstallerService.scanRelatedFiles(for: app)
        selectedCategoryIDs = Set(categories.map(\.id))
        if !keepLog { logLines = [] }
    }

    private func performDelete() {
        guard let app = selectedApp else { return }
        isBusy = true
        logLines = ["Încep ștergerea pentru \(app.name)…"]
        let toDelete = categories.filter { selectedCategoryIDs.contains($0.id) }
        DispatchQueue.global(qos: .userInitiated).async {
            UninstallerService.terminateIfRunning(app)
            UninstallerService.delete(categories: toDelete) { line in
                DispatchQueue.main.async { logLines.append(line) }
            }
            if deleteAppItselfToo {
                let result = UninstallerService.deleteAppBundle(app)
                DispatchQueue.main.async { logLines.append(result) }
            }
            DispatchQueue.main.async {
                logLines.append("Gata. Reverific…")
                apps = UninstallerService.scanInstalledApps()
                if selectedApp != nil && !apps.contains(where: { $0.id == app.id }) {
                    selectedApp = nil
                    categories = []
                    logLines.append("✓ Confirmat: \(app.name) nu mai apare în /Applications.")
                } else if let stillThere = apps.first(where: { $0.id == app.id }) {
                    logLines.append("⚠ \(app.name) tot apare în /Applications — vezi mesajul de eroare de mai sus (probabil aplicația era deschisă).")
                    selectApp(stillThere, keepLog: true)
                }
                isBusy = false
            }
        }
    }

    /// Ștergere în masă — cerință directă (2026-09-01): "vreau sa pot
    /// selecta mai multe si sa le dezinstalez, nu una cate una". Fiecare
    /// aplicație bifată e scanată din nou chiar înainte de ștergere (nu
    /// refolosim un scan vechi/parțial) și ștearsă COMPLET — toate
    /// categoriile de urme găsite, plus bundle-ul însuși — la fel de
    /// riguros ca fluxul individual, doar fără personalizare per-categorie
    /// (o ștergere în masă înseamnă "curăț tot", nu "păstrează doar X").
    private func performBulkDelete() {
        let targets = apps.filter { bulkSelectedIDs.contains($0.id) }
        guard !targets.isEmpty else { return }
        isBulkBusy = true
        logLines = ["Încep ștergerea în masă pentru \(targets.count) aplicații…"]
        DispatchQueue.global(qos: .userInitiated).async {
            for app in targets {
                DispatchQueue.main.async { logLines.append("— \(app.name) —") }
                UninstallerService.terminateIfRunning(app)
                let foundCategories = UninstallerService.scanRelatedFiles(for: app)
                UninstallerService.delete(categories: foundCategories) { line in
                    DispatchQueue.main.async { logLines.append(line) }
                }
                let result = UninstallerService.deleteAppBundle(app)
                DispatchQueue.main.async { logLines.append(result) }
            }
            DispatchQueue.main.async {
                logLines.append("Gata. Reverific…")
                apps = UninstallerService.scanInstalledApps()
                bulkSelectedIDs.removeAll()
                if let selectedApp, !apps.contains(where: { $0.id == selectedApp.id }) {
                    self.selectedApp = nil
                    categories = []
                }
                isBulkBusy = false
            }
        }
    }

    private func runGated(_ action: @escaping () -> Void) {
        if license.isActivated {
            action()
        } else {
            showGate = true
        }
    }
}
