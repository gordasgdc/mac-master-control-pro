import Foundation
import MacMasterControlProCore

/// Ganci pentru materiale demonstrative (capturi): limba, tema și pagina de pornire din variabile de mediu.
/// Active NUMAI într-un profil izolat (`MCSP_PROFILE_DIR` sau alt bundle ID); în instalarea oficială nu au niciun efect.
enum DemoHooks {
    private static func env(_ name: String) -> String? {
        guard AppProfile.isIsolated, let v = ProcessInfo.processInfo.environment[name], !v.isEmpty else { return nil }
        return v
    }
    static var language: String? { env("MCSP_DEMO_LANG") }
    static var theme: String? { env("MCSP_DEMO_THEME") }
    static var page: String? { env("MCSP_DEMO_PAGE") }
    /// Verificare automată (profil izolat): în loc să deschidă WhatsApp, adresa conversației se scrie în acest fișier; nu se trimite nimic.
    static var whatsAppSink: String? { env("MCSP_DEMO_WA_SINK") }
    /// Machine ID sintetic în materialele demonstrative: capturile publice nu conțin identificatorul real al calculatorului.
    static var machineID: String? { language != nil ? "DEMO-0000-0000" : nil }
    /// Scenariu de captură pentru Analiză Disc (profil izolat): volum de scanat, cale de scanat (progres/eroare), foldere de deschis, elemente de bifat, foaia de revizuire, tabel avansat.
    static var scanVolume: String? { env("MCSP_DEMO_SCAN") }
    static var scanPath: String? { env("MCSP_DEMO_SCAN_PATH") }
    static var openPath: String? { env("MCSP_DEMO_OPEN") }
    static var select: String? { env("MCSP_DEMO_SELECT") }
    static var review: Bool { env("MCSP_DEMO_REVIEW") != nil }
    static var advanced: Bool { env("MCSP_DEMO_ADVANCED") != nil }
}
