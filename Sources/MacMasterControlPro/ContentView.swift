import SwiftUI
import MacMasterControlProCore

enum SidebarItem: String, CaseIterable, Identifiable {
    case dashboard, network, cloud, cleanup, tweaks, rosetta, settings
    var id: String { rawValue }
    var label: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .network: return "Rețea"
        case .cloud: return "Cloud Manager"
        case .cleanup: return "Curățare & RAM"
        case .tweaks: return "Tweak-uri Sistem"
        case .rosetta: return "Rosetta Inspector"
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
        case .settings: return "gearshape"
        }
    }
}

struct ContentView: View {
    @State private var selection: SidebarItem? = .dashboard
    @ObservedObject private var textScale = TextScaleManager.shared

    var body: some View {
        NavigationSplitView {
            List(SidebarItem.allCases, selection: $selection) { item in
                Label(item.label, systemImage: item.icon).tag(item)
            }
            .navigationTitle("Mac Master Control Pro")
        } detail: {
            switch selection {
            case .network: NetworkModuleView()
            case .cloud: CloudManagerView()
            case .cleanup: CleanupModuleView()
            case .tweaks: TweaksModuleView()
            case .rosetta: RosettaModuleView()
            case .settings: SettingsView()
            default: DashboardView()
            }
        }
        .dynamicTypeSize(textScale.current.dynamicTypeSize)
        .frame(minWidth: 900, minHeight: 600)
    }
}

struct DashboardView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("📊 Dashboard").font(.largeTitle).bold()
            Text("Ultimate System Tuning, Cloud Mount, Media Cache & Future macOS Readiness Panel")
                .foregroundStyle(.secondary)
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
