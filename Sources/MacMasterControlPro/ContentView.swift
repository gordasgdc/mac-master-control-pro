import SwiftUI
import AppKit
import MacMasterControlProCore

enum SidebarItem: String, CaseIterable, Identifiable {
    case dashboard, network, cloud, cleanup, tweaks, rosetta, dependencies, settings
    var id: String { rawValue }
    var labelKey: String {
        switch self {
        case .dashboard: return "sidebar.dashboard"
        case .network: return "sidebar.network"
        case .cloud: return "sidebar.cloud"
        case .cleanup: return "sidebar.cleanup"
        case .tweaks: return "sidebar.tweaks"
        case .rosetta: return "sidebar.rosetta"
        case .dependencies: return "sidebar.dependencies"
        case .settings: return "sidebar.settings"
        }
    }
    var icon: String {
        switch self {
        case .dashboard: return "gauge.with.dots.needle.67percent"
        case .network: return "network"
        case .cloud: return "cloud"
        case .cleanup: return "trash.circle"
        case .tweaks: return "wrench.and.screwdriver"
        case .rosetta: return "cpu"
        case .dependencies: return "puzzlepiece.extension"
        case .settings: return "gearshape"
        }
    }
}

struct ContentView: View {
    @State private var selection: SidebarItem? = .dashboard
    @ObservedObject private var textScale = TextScaleManager.shared
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
                }
                SidebarFooterView()
            }
            .navigationTitle("Master Control Studio Pro")
        } detail: {
            switch selection {
            case .network: NetworkModuleView()
            case .cloud: CloudManagerView()
            case .cleanup: CleanupModuleView()
            case .tweaks: TweaksModuleView()
            case .rosetta: RosettaModuleView()
            case .dependencies: DependenciesModuleView(checker: dependencyChecker)
            case .settings: SettingsView()
            default: DashboardView(checker: dependencyChecker, goToDependencies: { selection = .dependencies })
            }
        }
        .id(language.current) // forteaza refresh la schimbarea limbii
        .dynamicTypeSize(textScale.current.dynamicTypeSize)
        .frame(minWidth: 900, minHeight: 600)
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

struct DashboardView: View {
    @ObservedObject var checker: DependencyChecker
    let goToDependencies: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L.t("dashboard.title")).font(.largeTitle).bold()
            Text(L.t("dashboard.tagline"))
                .foregroundStyle(.secondary)

            if !checker.items.isEmpty, !checker.allInstalled {
                Button {
                    goToDependencies()
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
