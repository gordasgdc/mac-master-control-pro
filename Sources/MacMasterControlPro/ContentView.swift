import SwiftUI
import MacMasterControlProCore

enum SidebarItem: String, CaseIterable, Identifiable {
    case dashboard, network, cloud, cleanup, tweaks, rosetta, dependencies, settings
    var id: String { rawValue }
    var label: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .network: return "Rețea"
        case .cloud: return "Cloud Manager"
        case .cleanup: return "Curățare & RAM"
        case .tweaks: return "Tweak-uri Sistem"
        case .rosetta: return "Rosetta Inspector"
        case .dependencies: return "Dependențe"
        case .settings: return "Setări"
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
    @StateObject private var dependencyChecker = DependencyChecker()

    var body: some View {
        NavigationSplitView {
            List(SidebarItem.allCases, selection: $selection) { item in
                HStack {
                    Label(item.label, systemImage: item.icon)
                    if item == .dependencies, !dependencyChecker.allInstalled, !dependencyChecker.items.isEmpty {
                        Spacer()
                        Circle().fill(Color.red).frame(width: 8, height: 8)
                    }
                }
                .tag(item)
            }
            .navigationTitle("Mac Master Control Pro")
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
        .dynamicTypeSize(textScale.current.dynamicTypeSize)
        .frame(minWidth: 900, minHeight: 600)
        .onAppear { dependencyChecker.checkAll() }
    }
}

struct DashboardView: View {
    @ObservedObject var checker: DependencyChecker
    let goToDependencies: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("📊 Dashboard").font(.largeTitle).bold()
            Text("Ultimate System Tuning, Cloud Mount, Media Cache & Future macOS Readiness Panel")
                .foregroundStyle(.secondary)

            if !checker.items.isEmpty, !checker.allInstalled {
                Button {
                    goToDependencies()
                } label: {
                    Label("Dependențe lipsă — apasă pentru a rezolva", systemImage: "exclamationmark.triangle.fill")
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

    var body: some View {
        Form {
            Picker("Temă", selection: $theme.current) {
                ForEach(AppTheme.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)

            Picker("Mărime text", selection: $textScale.current) {
                ForEach(TextScalePreference.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
        }
        .padding(32)
    }
}
