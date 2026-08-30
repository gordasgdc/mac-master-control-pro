import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case ro, en, es
    var id: String { rawValue }
    var label: String {
        switch self {
        case .ro: return "Română"
        case .en: return "English"
        case .es: return "Español"
        }
    }
}

final class LanguageStore: ObservableObject {
    static let shared = LanguageStore()
    private static let key = "MacMasterControlPro.language"

    @Published var current: AppLanguage {
        didSet { UserDefaults.standard.set(current.rawValue, forKey: Self.key) }
    }

    private init() {
        if let saved = UserDefaults.standard.string(forKey: Self.key), let lang = AppLanguage(rawValue: saved) {
            current = lang
        } else {
            // Detectie initiala din limba sistemului, cu fallback RO.
            let preferred = Locale.preferredLanguages.first ?? "ro"
            if preferred.hasPrefix("es") { current = .es }
            else if preferred.hasPrefix("en") { current = .en }
            else { current = .ro }
        }
    }
}

/// Dictionar minimal - acopera interfata principala (sidebar, dashboard,
/// setari, poarta de trial). Textele specifice fiecarui modul raman RO
/// in v1.0.0 - traducere completa urmarita pentru v1.1 (vezi CHANGELOG).
enum L {
    private static let strings: [String: [AppLanguage: String]] = [
        "sidebar.dashboard": [.ro: "Dashboard", .en: "Dashboard", .es: "Panel"],
        "sidebar.network": [.ro: "Rețea", .en: "Network", .es: "Red"],
        "sidebar.cloud": [.ro: "Cloud Manager", .en: "Cloud Manager", .es: "Gestor Cloud"],
        "sidebar.cleanup": [.ro: "Curățare & RAM", .en: "Cleanup & RAM", .es: "Limpieza y RAM"],
        "sidebar.tweaks": [.ro: "Tweak-uri Sistem", .en: "System Tweaks", .es: "Ajustes del Sistema"],
        "sidebar.rosetta": [.ro: "Rosetta Inspector", .en: "Rosetta Inspector", .es: "Inspector Rosetta"],
        "sidebar.dependencies": [.ro: "Dependențe", .en: "Dependencies", .es: "Dependencias"],
        "sidebar.settings": [.ro: "Setări", .en: "Settings", .es: "Ajustes"],

        "dashboard.title": [.ro: "📊 Dashboard", .en: "📊 Dashboard", .es: "📊 Panel"],
        "dashboard.tagline": [
            .ro: "Ultimate System Tuning, Cloud Mount, Media Cache & Future macOS Readiness Panel",
            .en: "Ultimate System Tuning, Cloud Mount, Media Cache & Future macOS Readiness Panel",
            .es: "Panel definitivo de optimización, montaje Cloud, caché multimedia y preparación para futuros macOS"
        ],
        "dashboard.depsWarning": [
            .ro: "Dependențe lipsă — apasă pentru a rezolva",
            .en: "Missing dependencies — tap to fix",
            .es: "Faltan dependencias — pulsa para resolver"
        ],

        "settings.appearance": [.ro: "Aspect", .en: "Appearance", .es: "Apariencia"],
        "settings.theme": [.ro: "Temă", .en: "Theme", .es: "Tema"],
        "settings.textSize": [.ro: "Mărime text", .en: "Text Size", .es: "Tamaño de texto"],
        "settings.language": [.ro: "Limbă", .en: "Language", .es: "Idioma"],
        "settings.profile": [.ro: "Profil", .en: "Profile", .es: "Perfil"],
        "settings.name": [.ro: "Nume", .en: "Name", .es: "Nombre"],
        "settings.email": [.ro: "Email", .en: "Email", .es: "Correo"],

        "trial.title": [.ro: "Analiza este 100% completă", .en: "Analysis is 100% complete", .es: "El análisis está 100% completo"],
        "trial.body": [
            .ro: "Susține dezvoltarea cu o donație (17€, o singură dată) pentru a debloca aplicarea modificărilor.",
            .en: "Support development with a one-time 17€ donation to unlock applying changes.",
            .es: "Apoya el desarrollo con una donación única de 17€ para desbloquear la aplicación de cambios."
        ],
        "trial.donate": [.ro: "Donează din GDC Plugin Manager", .en: "Donate via GDC Plugin Manager", .es: "Donar desde GDC Plugin Manager"],
        "trial.activate": [.ro: "Activează", .en: "Activate", .es: "Activar"],
        "trial.cancel": [.ro: "Anulează", .en: "Cancel", .es: "Cancelar"],
        "trial.key": [.ro: "Cheie de licență", .en: "License key", .es: "Clave de licencia"],
        "trial.whatsapp": [.ro: "Contact WhatsApp", .en: "Contact WhatsApp", .es: "Contacto WhatsApp"],
        "sidebar.trialBadge": [.ro: "Trial — Activează", .en: "Trial — Activate", .es: "Prueba — Activar"],
    ]

    static func t(_ key: String) -> String {
        let lang = LanguageStore.shared.current
        return strings[key]?[lang] ?? strings[key]?[.ro] ?? key
    }
}
