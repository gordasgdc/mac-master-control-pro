import Foundation

/// Stare licentiere - trial permite scanare completa, blocheaza doar
/// actiunile care scriu pe disc/sistem (teasing, per cerinta produsului).
public enum LicenseState: String {
    case trial
    case activated
}

public final class LicenseStore: ObservableObject {
    public static let shared = LicenseStore()
    private static let key = "MacMasterControlPro.licenseState"

    @Published public var state: LicenseState {
        didSet { UserDefaults.standard.set(state.rawValue, forKey: Self.key) }
    }

    private init() {
        let raw = UserDefaults.standard.string(forKey: Self.key) ?? LicenseState.trial.rawValue
        state = LicenseState(rawValue: raw) ?? .trial
    }

    public var isActivated: Bool { state == .activated }

    /// TODO: inlocuit cu verificare reala fata de GDC Plugin Manager
    /// (acelasi Machine UUID + cheie publica ca GDCVault/GDCPluginManager).
    public func activate(withKey key: String) -> Bool {
        guard !key.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        state = .activated
        return true
    }
}
