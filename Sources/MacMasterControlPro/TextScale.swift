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

    private static let key = "MacMasterControlPro.textScale"

    // [2026-09-03] Persistenta reactivata — lockout-ul vechi (userul ramanea
    // blocat afara din Setari daca pornea deja pe "Mare") era cauzat de
    // implementarea GRESITA a scaleEffect-ului, nu de persistenta in sine
    // (vezi MacMasterControlProApp.swift, ScaledContentView). Cu tehnica
    // corecta (portata identic din GDC Plugin Manager), hit-testing-ul
    // ramane corect la orice scala, deci nu mai exista risc de blocare.
    @Published var current: TextScalePreference {
        didSet {
            guard current != oldValue else { return }
            UserDefaults.standard.set(current.rawValue, forKey: Self.key)
        }
    }

    private init() {
        let saved = UserDefaults.standard.string(forKey: Self.key)
        current = saved.flatMap(TextScalePreference.init(rawValue:)) ?? .normal
    }
}
