import Foundation

/// Un agent de fundal (LaunchAgent) instalat de o aplicatie tert-parte -
/// NU agentii Apple (`com.apple.*`), excluși intenționat din listă, ca
/// niciun client sa nu dezactiveze din greseala ceva critic de sistem.
public struct LoginItem: Identifiable, Hashable {
    public var id: String { path }
    public let label: String
    public let path: String
    public let isLoaded: Bool
    public let isUserLevel: Bool // ~/Library vs /Library (necesita admin)
}

/// Auditor de aplicatii la pornire (2026-08-31, Nivel 1 #4) - multe
/// aplicatii de fundal (sincronizari, update checkere, agenti de
/// telemetrie) concureaza pentru CPU/RAM exact cand editezi/randezi.
/// Scaneaza LaunchAgents (user + sistem), nu foloseste API-uri private -
/// macOS nu expune public o lista COMPLETA a Login Items moderne
/// (SMAppService, Ventura+), dar marea majoritate a agentilor de fundal
/// tert-parte tot instaleaza un `.plist` clasic in LaunchAgents.
public enum LoginItemsService {
    private static let userAgentsDir = NSHomeDirectory() + "/Library/LaunchAgents"
    private static let systemAgentsDir = "/Library/LaunchAgents"
    /// Folder de "carantina" pentru plist-urile dezactivate - reversibil,
    /// niciodata stergere definitiva (userul poate reactiva oricand).
    private static let disabledHoldingDir = NSHomeDirectory() + "/Library/Application Support/MacMasterControlPro/DisabledLoginItems"

    public static func scan() -> [LoginItem] {
        var items: [LoginItem] = []
        items.append(contentsOf: scanDirectory(userAgentsDir, isUserLevel: true))
        items.append(contentsOf: scanDirectory(systemAgentsDir, isUserLevel: false))
        return items.sorted { $0.label < $1.label }
    }

    private static func scanDirectory(_ dir: String, isUserLevel: Bool) -> [LoginItem] {
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: dir) else { return [] }
        let loaded = Set(loadedLabels())
        return files.filter { $0.hasSuffix(".plist") }.compactMap { file -> LoginItem? in
            let label = String(file.dropLast(6))
            // Exclude agentii Apple - nu incurajam dezactivarea a ceva
            // critic de sistem doar pentru ca a fost gasit intr-un scan.
            if label.hasPrefix("com.apple.") { return nil }
            let path = dir + "/" + file
            return LoginItem(label: label, path: path, isLoaded: loaded.contains(label), isUserLevel: isUserLevel)
        }
    }

    private static func loadedLabels() -> [String] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["list"]
        let pipe = Pipe()
        process.standardOutput = pipe
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let text = String(data: data, encoding: .utf8) ?? ""
            return text.split(separator: "\n").compactMap { line in
                let cols = line.split(separator: "\t")
                return cols.count >= 3 ? String(cols[2]) : nil
            }
        } catch {
            return []
        }
    }

    /// Dezactiveaza (bootout + muta plist-ul in carantina) - agentii de
    /// sistem (`/Library`) cer privilegii admin, cei de user nu.
    public static func disable(_ item: LoginItem, log: @escaping (String) -> Void) {
        let domain = item.isUserLevel ? "gui/\(getuid())" : "system"
        let bootoutCmd = "launchctl bootout \(domain) \"\(item.path)\" 2>&1 || true"
        try? FileManager.default.createDirectory(atPath: disabledHoldingDir, withIntermediateDirectories: true)
        let destination = disabledHoldingDir + "/" + (item.path as NSString).lastPathComponent
        let moveCmd = "mv \"\(item.path)\" \"\(destination)\""
        log("$ \(bootoutCmd)")
        log("$ \(moveCmd)")
        if item.isUserLevel {
            _ = Shell.run(bootoutCmd)
            _ = Shell.run(moveCmd)
        } else {
            let result = PrivilegedRunner.run([bootoutCmd, moveCmd])
            if !result.success { log("✘ \(result.output)") }
        }
        log("✔ \(item.label) dezactivat — mutat în carantină, reversibil din „Reactivează”.")
    }

    /// Reversul lui `disable` - muta plist-ul inapoi si-l reincarca.
    public static func enable(_ item: LoginItem, log: @escaping (String) -> Void) {
        let quarantined = disabledHoldingDir + "/" + (item.path as NSString).lastPathComponent
        let moveCmd = "mv \"\(quarantined)\" \"\(item.path)\""
        let loadCmd = "launchctl bootstrap gui/\(getuid()) \"\(item.path)\" 2>&1 || true"
        log("$ \(moveCmd)")
        log("$ \(loadCmd)")
        if item.isUserLevel {
            _ = Shell.run(moveCmd)
            _ = Shell.run(loadCmd)
        } else {
            let result = PrivilegedRunner.run([moveCmd, "launchctl bootstrap system \"\(item.path)\" 2>&1 || true"])
            if !result.success { log("✘ \(result.output)") }
        }
        log("✔ \(item.label) reactivat.")
    }

    /// Itemii aflati in carantina (dezactivati anterior) - pentru butonul
    /// "Reactiveaza", separat de lista scanata din LaunchAgents.
    public static func disabledItems() -> [String] {
        (try? FileManager.default.contentsOfDirectory(atPath: disabledHoldingDir))?
            .filter { $0.hasSuffix(".plist") }.map { String($0.dropLast(6)) } ?? []
    }
}
