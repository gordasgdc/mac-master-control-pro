import SwiftUI

/// Identic cu TextScale din GDCVault (Regula 24).
enum TextScalePreference: String, CaseIterable, Identifiable {
    case small, normal, large, xlarge
    var id: String { rawValue }
    var label: String {
        switch self {
        case .small: return "Mic"
        case .normal: return "Normal"
        case .large: return "Mare"
        case .xlarge: return "Foarte mare"
        }
    }
    var dynamicTypeSize: DynamicTypeSize {
        switch self {
        case .small: return .small
        case .normal: return .medium
        case .large: return .large
        case .xlarge: return .xLarge
        }
    }
}

final class TextScaleManager: ObservableObject {
    static let shared = TextScaleManager()
    private static let key = "MacMasterControlPro.textScale"

    @Published var current: TextScalePreference {
        didSet { UserDefaults.standard.set(current.rawValue, forKey: Self.key) }
    }

    private init() {
        let raw = UserDefaults.standard.string(forKey: Self.key) ?? TextScalePreference.normal.rawValue
        current = TextScalePreference(rawValue: raw) ?? .normal
    }
}
