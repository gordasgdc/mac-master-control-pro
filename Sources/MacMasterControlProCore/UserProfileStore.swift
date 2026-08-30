import Foundation

/// Profil optional in sidebar (Regula 12) - Nume/Email afisate, "Anonim"
/// daca nu sunt completate, plus Machine ID (folosit la licentiere).
public final class UserProfileStore: ObservableObject {
    public static let shared = UserProfileStore()

    private static let nameKey = "MacMasterControlPro.profile.name"
    private static let emailKey = "MacMasterControlPro.profile.email"

    @Published public var name: String {
        didSet { UserDefaults.standard.set(name, forKey: Self.nameKey) }
    }
    @Published public var email: String {
        didSet { UserDefaults.standard.set(email, forKey: Self.emailKey) }
    }

    public var displayName: String { name.trimmingCharacters(in: .whitespaces).isEmpty ? "Anonim" : name }

    private init() {
        name = UserDefaults.standard.string(forKey: Self.nameKey) ?? ""
        email = UserDefaults.standard.string(forKey: Self.emailKey) ?? ""
    }
}
