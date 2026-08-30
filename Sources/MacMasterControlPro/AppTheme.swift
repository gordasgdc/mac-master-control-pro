import SwiftUI
import AppKit

/// Identic cu ThemeManager din GDCVault (Regula 18).
enum AppTheme: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var label: String {
        switch self {
        case .system: return "Sistem"
        case .light: return "Luminos"
        case .dark: return "Întunecat"
        }
    }
}

final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    private static let key = "MacMasterControlPro.appTheme"

    @Published var current: AppTheme {
        didSet {
            UserDefaults.standard.set(current.rawValue, forKey: Self.key)
            applyNow()
        }
    }

    private init() {
        let raw = UserDefaults.standard.string(forKey: Self.key) ?? AppTheme.system.rawValue
        current = AppTheme(rawValue: raw) ?? .system
    }

    func applyNow() {
        switch current {
        case .system: NSApp.appearance = nil
        case .light: NSApp.appearance = NSAppearance(named: .aqua)
        case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }
}
