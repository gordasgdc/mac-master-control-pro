import Foundation

/// Un folder de configurare Resolve/Fusion portabil intre statii (2026-08-31,
/// Nivel 3 #9) - EXCLUSIV foldere de fisiere simple (LUT-uri, macro-uri,
/// sabloane, script-uri Fusion). PowerGrade-urile NU sunt incluse aici -
/// traiesc in baza de date interna Resolve (Gallery), nu ca fisiere pe
/// disc; sincronizarea lor ar necesita export/import prin Scripting API
/// (`gallery.ExportStills`/`ImportStills`, acelasi tipar ca
/// `PowerGradeImporter.swift` din gdc-plugin-manager) - ramane TODO real,
/// nemenetionat ca "gata" pana nu se implementeaza explicit.
public struct ResolveConfigFolder: Identifiable {
    public var id: String { path }
    public let label: String
    public let path: String
    public var exists: Bool { FileManager.default.fileExists(atPath: path) }
}

public enum ResolveConfigSyncService {
    private static let base = NSHomeDirectory() + "/Library/Application Support/Blackmagic Design/DaVinci Resolve"

    public static var folders: [ResolveConfigFolder] {
        [
            ResolveConfigFolder(label: "LUT-uri (.LUT)", path: base + "/.LUT"),
            ResolveConfigFolder(label: "Fusion — Macro-uri", path: base + "/Fusion/Macros"),
            ResolveConfigFolder(label: "Fusion — Șabloane", path: base + "/Fusion/Templates"),
            ResolveConfigFolder(label: "Fusion — Script-uri", path: base + "/Fusion/Scripts"),
        ]
    }
}
