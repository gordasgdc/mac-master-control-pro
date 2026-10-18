import Foundation

/// Limba pentru textele produse de nucleu (mesaje de serviciu, explicații). Aplicația o setează la pornire și la schimbarea limbii.
public enum CoreL {
    nonisolated(unsafe) public static var code = "ro"
    public static func x(_ ro: String, _ en: String, _ es: String) -> String {
        switch code { case "en": return en; case "es": return es; default: return ro }
    }
}
