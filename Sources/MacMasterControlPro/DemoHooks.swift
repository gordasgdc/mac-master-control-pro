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
}
