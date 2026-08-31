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
            Text("🗑️ Dezinstalator").font(.title2).bold()
            TextField("Caută aplicație…", text: $searchText).textFieldStyle(.roundedBorder)
            List(filteredApps, selection: $selectedApp) { app in
                HStack {
                    Image(nsImage: app.icon).resizable().frame(width: 20, height: 20)
                    Text(app.name)
                }
                .tag(app)
                .onTapGesture { selectApp(app) }
            }
        }
        .frame(minWidth: 260, idealWidth: 300)
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
                    Button("Rescanează") { selectApp(app) }
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

    private func selectApp(_ app: InstalledApp) {
        selectedApp = app
        categories = UninstallerService.scanRelatedFiles(for: app)
        selectedCategoryIDs = Set(categories.map(\.id))
        logLines = []
    }

    private func performDelete() {
        guard let app = selectedApp else { return }
        isBusy = true
        logLines = ["Încep ștergerea pentru \(app.name)…"]
        let toDelete = categories.filter { selectedCategoryIDs.contains($0.id) }
        DispatchQueue.global(qos: .userInitiated).async {
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
                    selectApp(stillThere)
                }
                isBusy = false
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
