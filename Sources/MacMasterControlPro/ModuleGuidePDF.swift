import AppKit

/// [2026-09-03] Ghiduri PDF detaliate PER MODUL, cerute explicit de Cristi
/// pentru meniul Help — separate de ghidul general de instalare/utilizare
/// (`GuidePDF.swift`). Port 1:1 al tiparului acelui fișier (deschide
/// versiunea din limba curentă, cu fallback RO) — doar parametrizat pe
/// numele de bază al ghidului, ca să nu repetăm aceeași logică de 4 ori.
/// Generate din `installer/generate_module_guides.py`.
enum ModuleGuidePDF {
    case renderMode
    case diskAnalyzer
    case systemTweaks
    case backupSecurity

    private var baseName: String {
        switch self {
        case .renderMode: return "Ghid_ModRandare"
        case .diskAnalyzer: return "Ghid_AnalizaDisc"
        case .systemTweaks: return "Ghid_TweaksSistem"
        case .backupSecurity: return "Ghid_BackupSecuritate"
        }
    }

    func open() {
        let suffix: String
        switch LanguageStore.shared.current {
        case .ro: suffix = "RO"
        case .en: suffix = "EN"
        case .es: suffix = "ES"
        }
        let name = "\(baseName)_\(suffix)"
        if let url = Bundle.main.url(forResource: name, withExtension: "pdf") {
            NSWorkspace.shared.open(url)
            return
        }
        if let fallback = Bundle.main.url(forResource: "\(baseName)_RO", withExtension: "pdf") {
            NSWorkspace.shared.open(fallback)
            return
        }
        NSSound.beep()
    }
}
