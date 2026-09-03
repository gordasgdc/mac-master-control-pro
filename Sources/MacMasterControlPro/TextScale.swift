import SwiftUI

/// BUG REAL, gasit si reparat 2026-08-31: `dynamicTypeSize` nu producea
/// NICIO schimbare vizibila pe macOS in aceasta aplicatie (raportat direct
/// de Cristi: "la setari cand aleg text mic normal mare nu se intampla
/// nimica") — acelasi bug deja documentat si reparat in GDC Plugin Manager
/// (AppTheme.swift/TextScalePreference), doar ca fix-ul nu fusese propagat
/// si aici. Inlocuit cu aceeasi tehnica dovedita: scalare vizuala directa
/// (`.scaleEffect` + compensare de `frame`, vezi `ScaledContentView` din
/// `MacMasterControlProApp.swift`), port 1:1 al `ScaleTransform` de pe
/// Windows (`TextScalePreferenceExtensions.ScaleFactor`).
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
    /// Aceiasi factori ca pe Windows si ca in GDC Plugin Manager —
    /// paritate vizuala intre platforme/aplicatii.
    var scaleFactor: CGFloat {
        switch self {
        case .small: return 0.9
        case .normal: return 1.0
        case .large: return 1.15
        case .xlarge: return 1.3
        }
    }
}

final class TextScaleManager: ObservableObject {
    static let shared = TextScaleManager()

    // [2026-09-03] A 4-a incercare de scaleEffect (portata identic din GDC
    // Plugin Manager) a REPRODUS acelasi bug de hit-testing (Setari
    // neresponsive) - vezi MacMasterControlProApp.swift. Revenit definitiv
    // la varianta safe: NU persistam alegerea (porneste mereu Normal),
    // si scaleFactor ramane doar informativ - vezi nota la nivel de enum,
    // aplicarea vizuala e dezactivata pana la o solutie non-riscanta.
    @Published var current: TextScalePreference = .normal

    private init() {}
}
