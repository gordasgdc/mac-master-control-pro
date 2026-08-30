import AppKit

/// Identic cu GuidePDF din DataMover/GDCVault (Regula "help = PDF mare").
enum GuidePDF {
    static func open() {
        guard let url = Bundle.main.url(forResource: "MacMasterControlPro_Ghid_RO", withExtension: "pdf") else {
            NSSound.beep()
            return
        }
        NSWorkspace.shared.open(url)
    }
}
