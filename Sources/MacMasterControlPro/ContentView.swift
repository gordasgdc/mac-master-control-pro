import SwiftUI
import AppKit
import MacMasterControlProCore

enum SidebarItem: String, CaseIterable, Identifiable {
    case dashboard, renderMode, loginItems, processMonitor, diskHealth, resolveTools, windowLayouts, network, cloud, cleanup, uninstaller, security, tweaks, rosetta, dependencies, settings
    var id: String { rawValue }
    var labelKey: String {
        switch self {
        case .dashboard: return "sidebar.dashboard"
        case .renderMode: return "sidebar.renderMode"
        case .loginItems: return "sidebar.loginItems"
        case .processMonitor: return "sidebar.processMonitor"
        case .diskHealth: return "sidebar.diskHealth"
        case .resolveTools: return "sidebar.resolveTools"
        case .windowLayouts: return "sidebar.windowLayouts"
        case .network: return "sidebar.network"
        case .cloud: return "sidebar.cloud"
        case .cleanup: return "sidebar.cleanup"
        case .uninstaller: return "sidebar.uninstaller"
        case .security: return "sidebar.security"
        case .tweaks: return "sidebar.tweaks"
        case .rosetta: return "sidebar.rosetta"
        case .dependencies: return "sidebar.dependencies"
        case .settings: return "sidebar.settings"
        }
    }
    var icon: String {
        switch self {
        case .dashboard: return "gauge.with.dots.needle.67percent"
        case .renderMode: return "bolt.circle"
        case .loginItems: return "power.circle"
        case .processMonitor: return "speedometer"
        case .diskHealth: return "internaldrive"
        case .resolveTools: return "film"
        case .windowLayouts: return "macwindow.on.rectangle"
        case .network: return "network"
        case .cloud: return "cloud"
        case .cleanup: return "trash.circle"
        case .uninstaller: return "trash.slash"
        case .security: return "checkmark.shield"
        case .tweaks: return "wrench.and.screwdriver"
        case .rosetta: return "cpu"
        case .dependencies: return "puzzlepiece.extension"
        case .settings: return "gearshape"
        }
    }

    /// Descriere scurtă, afișată la hover pe rândul din sidebar — cerință
    /// directă (2026-09-01): "cand te duci cu mouse-ul peste un buton,
    /// sa-ti apara o descriere de ce face".
    var tooltip: String {
        switch self {
        case .dashboard: return "Privire de ansamblu — starea generală a Mac-ului dintr-o privire."
        case .renderMode: return "Oprește temporar Spotlight/Time Machine/alte procese de fundal cât randezi în DaVinci Resolve."
        case .loginItems: return "Vezi și oprești aplicațiile care pornesc automat odată cu Mac-ul."
        case .processMonitor: return "Procesele active acum, sortabile după CPU sau RAM — închide ce consumă prea mult."
        case .diskHealth: return "Spațiu liber, status SMART și test de viteză pentru discurile montate."
        case .resolveTools: return "Notificare la final de randare, verificare Media Pool, sincronizare LUT-uri, backup bază de date."
        case .windowLayouts: return "Salvează și restaurează aranjamentul ferestrelor pe ecran."
        case .network: return "Configurare și optimizare rețea, persistentă la repornire."
        case .cloud: return "Conectează și gestionează conturi Cloud (Drive, Dropbox, S3 și altele)."
        case .cleanup: return "Șterge cache-uri recuperabile, fișiere mari uitate, eliberează RAM."
        case .uninstaller: return "Dezinstalează complet una sau mai multe aplicații, cu toate urmele lor."
        case .security: return "Verifică setările de securitate ale Mac-ului, cu ghid pas-cu-pas pentru ce lipsește."
        case .tweaks: return "Ajustări rapide de sistem și accesibilitate."
        case .rosetta: return "Verifică ce aplicații rulează prin Rosetta (emulare Intel) pe un Mac Apple Silicon."
        case .dependencies: return "Componentele externe de care aplicația are nevoie — instalare cu un click."
        case .settings: return "Temă, limbă, licență și alte preferințe ale aplicației."
        }
    }
}

struct ContentView: View {
    @State private var selection: SidebarItem? = .dashboard
    @ObservedObject private var language = LanguageStore.shared
    @StateObject private var dependencyChecker = DependencyChecker()

    var body: some View {
        NavigationSplitView {
            // Frati intr-un VStack, NICIODATA .safeAreaInset direct pe List
            // (Regula 24 — bug de suprapunere la resize rapid al ferestrei).
            VStack(spacing: 0) {
                List(SidebarItem.allCases, selection: $selection) { item in
                    HStack {
                        Label(L.t(item.labelKey), systemImage: item.icon)
                        if item == .dependencies, !dependencyChecker.allInstalled, !dependencyChecker.items.isEmpty {
                            Spacer()
                            Circle().fill(Color.red).frame(width: 8, height: 8)
                        }
                    }
                    .tag(item)
                    .help(item.tooltip)
                }
                SidebarFooterView()
            }
            .navigationTitle("Master Control Studio Pro")
        } detail: {
            switch selection {
            case .renderMode: RenderModeView()
            case .loginItems: LoginItemsView()
            case .processMonitor: ProcessMonitorView()
            case .diskHealth: DiskHealthView()
            case .resolveTools: ResolveToolsView()
            case .windowLayouts: WindowLayoutsView()
            case .network: NetworkModuleView()
            case .cloud: CloudManagerView()
            case .cleanup: CleanupModuleView()
            case .uninstaller: UninstallerModuleView()
            case .security: SecurityModuleView()
            case .tweaks: TweaksModuleView()
            case .rosetta: RosettaModuleView()
            case .dependencies: DependenciesModuleView(checker: dependencyChecker)
            case .settings: SettingsView()
            default: DashboardView(checker: dependencyChecker, navigate: { selection = $0 })
            }
        }
        .id(language.current) // forteaza refresh la schimbarea limbii
        .frame(minWidth: 900, minHeight: 600)
        .onReceive(NotificationCenter.default.publisher(for: .mmcpOpenSettings)) { _ in
            selection = .settings
        }
        .onAppear {
            dependencyChecker.checkAll()
            UpdateChecker.checkSilentlyOnLaunch { version, pkgURL in
                let alert = NSAlert()
                alert.messageText = "Este disponibilă o versiune nouă"
                alert.informativeText = "Master Control Studio Pro \(version) este disponibil (tu ai \(UpdateChecker.currentVersion))."
                alert.addButton(withTitle: "Actualizează acum")
                alert.addButton(withTitle: "Mai târziu")
                let response = alert.runModal()
                UpdateChecker.markDismissed(version)
                if response == .alertFirstButtonReturn {
                    Task { await SelfUpdater.downloadAndInstall(pkgURL: pkgURL, version: version) }
                }
            }
        }
    }
}

/// Un modul + starea lui reala (verde/rosu), fara sa intri in el —
/// cerinta directa (2026-08-31): "sa apara verde/rosu la orice tip de
/// configurare, direct pe dashboard".
private struct DashboardCard: View {
    let icon: String
    let title: String
    let isGood: Bool?  // nil = inca se verifica
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: icon).font(.title2)
                    Spacer()
                    if let isGood {
                        Circle().fill(isGood ? Color.green : Color.red).frame(width: 10, height: 10)
                    } else {
                        ProgressView().controlSize(.mini)
                    }
                }
                Text(title).font(.headline).multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(height: 90, alignment: .topLeading)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(nsColor: .separatorColor), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

struct DashboardView: View {
    @ObservedObject var checker: DependencyChecker
    let navigate: (SidebarItem) -> Void

    @State private var securityGood: Bool?
    @State private var networkTuningActive: Bool?

    private static let columns = [GridItem(.adaptive(minimum: 220), spacing: 14)]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L.t("dashboard.title")).font(.largeTitle).bold()
            Text(L.t("dashboard.tagline"))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: Self.columns, spacing: 14) {
                DashboardCard(icon: "checkmark.shield", title: "Securitate", isGood: securityGood) { navigate(.security) }
                DashboardCard(icon: "network", title: "Tuning rețea persistent", isGood: networkTuningActive) { navigate(.network) }
                DashboardCard(icon: "puzzlepiece.extension", title: "Dependențe",
                              isGood: checker.items.isEmpty ? nil : checker.allInstalled) { navigate(.dependencies) }
                DashboardCard(icon: "power.circle", title: "Aplicații de fundal", isGood: nil) { navigate(.loginItems) }
            }

            if !checker.items.isEmpty, !checker.allInstalled {
                Button {
                    navigate(.dependencies)
                } label: {
                    Label(L.t("dashboard.depsWarning"), systemImage: "exclamationmark.triangle.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
            Spacer()
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task { await refreshStatuses() }
    }

    private func refreshStatuses() async {
        let net = NetworkService()
        net.refreshPersistentTuningStatus()
        let security = SecurityService.runAllChecks()
        await MainActor.run {
            networkTuningActive = net.persistentTuningActive
            securityGood = security.allSatisfy(\.isGood)
        }
    }
}

struct SettingsView: View {
    @ObservedObject private var theme = ThemeManager.shared
    @ObservedObject private var textScale = TextScaleManager.shared
    @ObservedObject private var profile = UserProfileStore.shared
    @ObservedObject private var language = LanguageStore.shared

    var body: some View {
        Form {
            Section(L.t("settings.appearance")) {
                Picker(L.t("settings.theme"), selection: $theme.current) {
                    ForEach(AppTheme.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)

                Picker(L.t("settings.textSize"), selection: $textScale.current) {
                    ForEach(TextScalePreference.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)

                Picker(L.t("settings.language"), selection: $language.current) {
                    ForEach(AppLanguage.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            Section(L.t("settings.profile")) {
                TextField(L.t("settings.name"), text: $profile.name)
                TextField(L.t("settings.email"), text: $profile.email)
            }
        }
        .padding(32)
    }
}
