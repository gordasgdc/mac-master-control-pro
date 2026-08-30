import AppKit

/// Identic cu GuidePDF din DataMover/GDCVault (Regula "help = PDF mare") -
/// deschide ghidul in limba curenta (LanguageStore), cu fallback RO.
enum GuidePDF {
    static func open() {
        let suffix: String
        switch LanguageStore.shared.current {
        case .ro: suffix = "RO"
        case .en: suffix = "EN"
        case .es: suffix = "ES"
        }
        let name = "Instructiuni_Utilizare_\(suffix)"
        if let url = Bundle.main.url(forResource: name, withExtension: "pdf") {
            NSWorkspace.shared.open(url)
            return
        }
        if let fallback = Bundle.main.url(forResource: "Instructiuni_Utilizare_RO", withExtension: "pdf") {
            NSWorkspace.shared.open(fallback)
            return
        }
        NSSound.beep()
    }
}
