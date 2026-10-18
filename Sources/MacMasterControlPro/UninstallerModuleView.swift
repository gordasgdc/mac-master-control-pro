import SwiftUI
import MacMasterControlProCore

/// Modul "Dezinstalator" — șterge complet o aplicație (ORICARE, nu doar
/// produse GDC): bundle-ul + Application Support/Caches/Preferences/
/// Saved State/Logs/HTTPStorages/WebKit/Containers/LaunchAgents/Daemons.
/// Cerință directă (2026-08-31): "să dezinstalezi tot ce ține legătură de
/// acea aplicație, să nu rămână nimica pe niciunde".
struct UninstallerModuleView: View {
    @ObservedObject private var license = AccessCoordinator.shared
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
        .sheet(isPresented: $showGate) { AccessGateSheet() }
    }

    // MARK: - Lista de aplicații

    private var appListPane: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Dezinstalator", systemImage: "trash.slash").font(.title2).bold()
                Spacer()
                if !bulkSelectedIDs.isEmpty {
                    Button(L.x("Dezinstalează selectate (\(bulkSelectedIDs.count))", "Uninstall selected (\(bulkSelectedIDs.count))", "Desinstalar seleccionadas (\(bulkSelectedIDs.count))"), role: .destructive) {
                        pendingBulkConfirm = true
                    }
                    .disabled(isBulkBusy)
                    .help(L.x("Șterge complet toate aplicațiile bifate mai jos — bundle-ul + toate urmele lor (Application Support, Caches, Preferences etc.), într-un singur pas.", "Fully remove every app ticked below — the bundle plus all their leftovers (Application Support, Caches, Preferences, etc.) in one step.", "Elimina por completo todas las apps marcadas abajo: el paquete y todos sus restos (Application Support, Caches, Preferences, etc.) en un solo paso."))
                }
            }
            TextField(L.x("Caută aplicație…", "Search app…", "Buscar app…"), text: $searchText).textFieldStyle(.roundedBorder)
            List(filteredApps, selection: $selectedApp) { app in
                HStack {
                    Toggle(isOn: Binding(
                        get: { bulkSelectedIDs.contains(app.id) },
                        set: { checked in
                            if checked { bulkSelectedIDs.insert(app.id) } else { bulkSelectedIDs.remove(app.id) }
                        }
                    )) { EmptyView() }
                    .toggleStyle(.checkbox)
                    .help(L.x("Bifează ca să incluzi \(app.name) la o ștergere în masă a mai multor aplicații deodată.", "Tick to include \(app.name) in a bulk removal of several apps at once.", "Marca para incluir \(app.name) en una eliminación múltiple de varias apps a la vez."))
                    Image(nsImage: app.icon).resizable().frame(width: 20, height: 20)
                    Text(app.name)
                }
                .tag(app)
                .onTapGesture { selectApp(app) }
            }
        }
        .frame(minWidth: 260, idealWidth: 300)
        .confirmationDialog(
            L.x("Ștergi definitiv \(bulkSelectedIDs.count) aplicații?", "Permanently delete \(bulkSelectedIDs.count) apps?", "¿Eliminar definitivamente \(bulkSelectedIDs.count) apps?"),
            isPresented: $pendingBulkConfirm, titleVisibility: .visible
        ) {
            Button(L.x("Șterge definitiv toate", "Delete all permanently", "Eliminar todas definitivamente"), role: .destructive) { runGated { performBulkDelete() } }
            Button(L.x("Anulează", "Cancel", "Cancelar"), role: .cancel) {}
        } message: {
            Text(L.x("Fiecare aplicație bifată va fi ștearsă complet, împreună cu toate urmele ei găsite pe disc.", "Each ticked app will be removed completely, along with all its leftovers found on disk.", "Cada app marcada se eliminará por completo, junto con todos sus restos encontrados en el disco."))
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
                    Toggle(L.x("Șterge și aplicația", "Also delete the app", "Eliminar también la app"), isOn: $deleteAppItselfToo)
                }

                if categories.isEmpty {
                    Text(L.x("Nicio urmă găsită în afara aplicației înseși (deja curat).", "No leftovers found outside the app itself (already clean).", "No se encontraron restos fuera de la propia app (ya está limpio)."))
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
                    Button(L.x("Șterge selectate", "Delete selected", "Eliminar seleccionados"), role: .destructive) { pendingConfirm = true }
                        .disabled(isBusy || (selectedCategoryIDs.isEmpty && !deleteAppItselfToo))
                        .help(L.x("Șterge doar categoriile bifate mai sus pentru \(app.name) — folosește asta ca să păstrezi ceva anume (ex. Preferences).", "Deletes only the categories ticked above for \(app.name) — use this to keep something specific (e.g. Preferences).", "Elimina solo las categorías marcadas arriba para \(app.name); úsalo para conservar algo concreto (p. ej. Preferences)."))
                    Button(L.x("Rescanează", "Rescan", "Volver a analizar")) { selectApp(app) }
                        .help(L.x("Rulează din nou scanarea de urme pentru \(app.name) — util dacă tocmai ai șters ceva manual sau ai deschis aplicația între timp.", "Runs the leftover scan again for \(app.name) — useful if you just deleted something manually or opened the app meanwhile.", "Vuelve a buscar restos de \(app.name); útil si acabas de borrar algo a mano o has abierto la app entretanto."))
                }
            } else {
                Text(L.x("Alege o aplicație din listă.", "Choose an app from the list.", "Elige una app de la lista.")).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .frame(minWidth: 380)
        .confirmationDialog(
            L.x("Ștergi definitiv \(selectedApp?.name ?? "")?", "Permanently delete \(selectedApp?.name ?? "")?", "¿Eliminar definitivamente \(selectedApp?.name ?? "")?"),
            isPresented: $pendingConfirm, titleVisibility: .visible
        ) {
            Button(L.x("Șterge definitiv", "Delete permanently", "Eliminar definitivamente"), role: .destructive) { runGated { performDelete() } }
            Button(L.x("Anulează", "Cancel", "Cancelar"), role: .cancel) {}
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
        logLines = [L.x("Încep ștergerea pentru \(app.name)…", "Starting removal of \(app.name)…", "Iniciando la eliminación de \(app.name)…")]
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
                    logLines.append(L.x("✓ Confirmat: \(app.name) nu mai apare în /Applications.", "✓ Confirmed: \(app.name) no longer appears in /Applications.", "✓ Confirmado: \(app.name) ya no aparece en /Applications."))
                } else if let stillThere = apps.first(where: { $0.id == app.id }) {
                    logLines.append(L.x("⚠ \(app.name) tot apare în /Applications — vezi mesajul de eroare de mai sus (probabil aplicația era deschisă).", "⚠ \(app.name) still appears in /Applications — see the error message above (the app was probably open).", "⚠ \(app.name) sigue apareciendo en /Applications; mira el mensaje de error de arriba (probablemente la app estaba abierta)."))
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
        logLines = [L.x("Încep ștergerea în masă pentru \(targets.count) aplicații…", "Starting bulk removal of \(targets.count) apps…", "Iniciando la eliminación múltiple de \(targets.count) apps…")]
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
        if license.allowsFeatures {
            action()
        } else {
            showGate = true
        }
    }
}
