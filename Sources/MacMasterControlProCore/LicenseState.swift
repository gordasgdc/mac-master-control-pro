import Foundation

public enum LicenseState: String {
    case trial
    case activated
}

/// productID inregistrat in gdcStandaloneProducts (Furnizor) - trebuie sa
/// coincida EXACT cu id-ul folosit la generarea serialului in GenerateSerialView.
public let macMasterControlProProductID = "mac-master-control-pro"

public final class LicenseStore: ObservableObject {
    public static let shared = LicenseStore()
    private static let stateKey = "MacMasterControlPro.licenseState"
    private static let serialKey = "MacMasterControlPro.licenseSerial"

    @Published public var state: LicenseState {
        didSet { UserDefaults.standard.set(state.rawValue, forKey: Self.stateKey) }
    }
    @Published public var lastError: String?

    private init() {
        let raw = UserDefaults.standard.string(forKey: Self.stateKey) ?? LicenseState.trial.rawValue
        state = LicenseState(rawValue: raw) ?? .trial
        // Re-validare la lansare (ex. update la un serial expirat local),
        // in caz ca un serial fusese salvat dar starea "activated" nu.
        if let saved = UserDefaults.standard.string(forKey: Self.serialKey), state == .trial {
            _ = activate(withKey: saved)
        }
    }

    public var isActivated: Bool { state == .activated }

    /// Verificare Ed25519 reala (LicenseCore, cheie publica GDC) - acelasi
    /// format de serial generat de GenerateSerialView.swift (Furnizor).
    @discardableResult
    public func activate(withKey key: String) -> Bool {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            lastError = "Cheie goală."
            return false
        }
        switch LicenseCore.validate(serial: trimmed, expectedProductID: macMasterControlProProductID) {
        case .success:
            state = .activated
            lastError = nil
            UserDefaults.standard.set(trimmed, forKey: Self.serialKey)
            return true
        case .failure(let error):
            lastError = Self.message(for: error)
            return false
        }
    }

    private static func message(for error: LicenseCore.ValidationError) -> String {
        switch error {
        case .malformedCode: return "Cod invalid."
        case .badSignature: return "Semnătură invalidă."
        case .wrongProduct: return "Cod pentru alt produs."
        case .wrongMachine: return "Cod legat de alt Mac."
        case .expired: return "Cod expirat."
        }
    }
}
