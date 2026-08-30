import Foundation

/// Camp de configurare cerut de un provider Rclone (ex: host, user, parola).
public struct CloudField: Identifiable {
    public let id = UUID()
    public let key: String       // cheia folosita de `rclone config create`
    public let label: String
    public let isSecure: Bool
    public init(key: String, label: String, isSecure: Bool = false) {
        self.key = key; self.label = label; self.isSecure = isSecure
    }
}

/// Providerii suportati - "type" e valoarea reala acceptata de rclone.
/// OAuth (drive/dropbox/onedrive/pcloud) nu cere campuri: rclone deschide
/// singur browser-ul si asteapta callback local (flux standard rclone).
public enum CloudProviderType: String, CaseIterable, Identifiable {
    case googleDrive = "drive"
    case dropbox = "dropbox"
    case oneDrive = "onedrive"
    case pcloud = "pcloud"
    case degoo = "degoo"       // necesita build/plugin rclone cu backend Degoo
    case mega = "mega"
    case s3 = "s3"
    case webdav = "webdav"
    case sftpNAS = "sftp"
    case ftp = "ftp"

    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .googleDrive: return "Google Drive"
        case .dropbox: return "Dropbox"
        case .oneDrive: return "OneDrive"
        case .pcloud: return "pCloud"
        case .degoo: return "Degoo"
        case .mega: return "Mega"
        case .s3: return "AWS S3 / compatibil"
        case .webdav: return "WebDAV"
        case .sftpNAS: return "SFTP / NAS"
        case .ftp: return "FTP"
        }
    }
    public var isOAuth: Bool {
        switch self {
        case .googleDrive, .dropbox, .oneDrive, .pcloud: return true
        default: return false
        }
    }
    public var fields: [CloudField] {
        switch self {
        case .googleDrive, .dropbox, .oneDrive, .pcloud:
            return []
        case .degoo, .mega:
            return [CloudField(key: "user", label: "Email"), CloudField(key: "pass", label: "Parolă", isSecure: true)]
        case .s3:
            return [
                CloudField(key: "provider", label: "Provider (ex: AWS, Wasabi, Minio)"),
                CloudField(key: "access_key_id", label: "Access Key ID"),
                CloudField(key: "secret_access_key", label: "Secret Access Key", isSecure: true),
                CloudField(key: "region", label: "Regiune (ex: eu-central-1)")
            ]
        case .webdav:
            return [
                CloudField(key: "url", label: "URL server (ex: https://exemplu.ro/remote.php/dav)"),
                CloudField(key: "vendor", label: "Vendor (nextcloud/owncloud/other)"),
                CloudField(key: "user", label: "Utilizator"),
                CloudField(key: "pass", label: "Parolă", isSecure: true)
            ]
        case .sftpNAS:
            return [
                CloudField(key: "host", label: "IP / Host NAS"),
                CloudField(key: "user", label: "Utilizator"),
                CloudField(key: "pass", label: "Parolă", isSecure: true),
                CloudField(key: "port", label: "Port (implicit 22)")
            ]
        case .ftp:
            return [
                CloudField(key: "host", label: "Host"),
                CloudField(key: "user", label: "Utilizator"),
                CloudField(key: "pass", label: "Parolă", isSecure: true)
            ]
        }
    }
}

public struct CloudRemote: Identifiable, Equatable {
    public var id: String { name }
    public let name: String
    public let type: String
}

public struct MountedDrive: Codable, Identifiable {
    public var id: String { remoteName }
    public let remoteName: String
    public let mountPath: String
    public let usesChunker: Bool
    /// Port RC unic (Faza 2 - statistici live), `nil` pentru montari facute
    /// inainte de aceasta versiune (fara `--rc`, fara statistici disponibile
    /// pana la o remontare).
    public var rcPort: Int? = nil
}

/// Statistici live de transfer (Faza 2), citite din `rclone rc core/stats`.
public struct CloudTransferStats {
    public let speedBytesPerSec: Double
    public let bytesTransferred: Int64
    public let activeTransfers: Int
}

/// Directia unei sincronizari folder local <-> remote (Faza 4).
public enum SyncDirection { case upload, download }

/// O intrare intr-un folder de pe remote (Faza 3 - explorare fara montare).
public struct RemoteEntry: Identifiable, Hashable {
    public var id: String { path }
    public let name: String
    public let path: String
    public let isDir: Bool
    public let size: Int64
}

/// Folder custom (posibil pe disc extern) unde se monteaza remote-urile, in
/// loc de `~/Desktop` implicit - cerinta explicita 2026-08-30 (SSD-uri
/// interne mici, se lucreaza de pe discuri externe Thunderbolt/USB-C).
/// `nil` = comportament vechi (`~/Desktop`).
public enum CloudMountSettings {
    private static let key = "MacMasterControlPro.customMountFolder"

    public static var customMountFolder: String? {
        get { UserDefaults.standard.string(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}

/// Manager Universal Multi-Cloud - inlocuieste implementarea legata strict
/// de Degoo. Orice remote Rclone (OAuth sau cu credentiale) e tratat identic.
public final class CloudManagerService: ObservableObject {
    public init() { loadMountedState() }

    @Published public var remotes: [CloudRemote] = []
    @Published public var mounted: [MountedDrive] = []
    @Published public var lastError: String?

    private static let mountedKey = "MacMasterControlPro.mountedDrives"
    private static let rcBasePort = 5572
    private var nextRcPort: Int { Self.rcBasePort + mounted.count }

    // MARK: - Remote list

    public func refreshRemotes() {
        let raw = Shell.run("rclone listremotes --long 2>/dev/null")
        remotes = raw.split(separator: "\n").compactMap { line -> CloudRemote? in
            // format: "nume:  tip"
            let parts = line.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count == 2 else { return nil }
            let type = parts[1].trimmingCharacters(in: .whitespaces)
            return CloudRemote(name: parts[0], type: type)
        }
    }

    // MARK: - Creare remote (wizard vizual, fara `rclone config` in Terminal)

    /// Pentru provideri OAuth, rclone deschide singur browser-ul si asteapta
    /// callback local - de aceea rulam async, fara sa blocam UI-ul.
    public func createRemote(name: String, type: CloudProviderType, values: [String: String], completion: @escaping (Bool, String) -> Void) {
        var args = ["config", "create", name, type.rawValue]
        for field in type.fields {
            guard let value = values[field.key], !value.isEmpty else { continue }
            if field.isSecure {
                let obscured = Shell.run("rclone obscure \"\(escapeForShell(value))\"")
                args.append("\(field.key)=\(obscured)")
            } else {
                args.append("\(field.key)=\(value)")
            }
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["rclone"] + args
        // Vezi Shell.augmentedPath - Process() separat de Shell.run() nu
        // mostenea PATH-ul augmentat cu Homebrew, deci "rclone" era negasibil
        // de /usr/bin/env desi era instalat (bug real 2026-08-30).
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = Shell.augmentedPath
        process.environment = env
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        process.terminationHandler = { [weak self] proc in
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            DispatchQueue.main.async {
                self?.refreshRemotes()
                completion(proc.terminationStatus == 0, output)
            }
        }
        do {
            try process.run()
        } catch {
            completion(false, "Nu s-a putut porni rclone: \(error.localizedDescription)")
        }
    }

    public func deleteRemote(_ name: String) {
        Shell.run("rclone config delete \"\(escapeForShell(name))\"")
        refreshRemotes()
    }

    // MARK: - Mount / Unmount (actiune reala - poarta de Trial in UI)

    /// `log` primeste linia de comanda + orice avertisment (panou Terminal
    /// Live) - ex. daca folderul custom configurat nu mai exista (disc
    /// extern deconectat), cadem pe Desktop in loc sa esuam silentios.
    public func mount(remoteName: String, useChunker: Bool, chunkSize: String, log: ((String) -> Void)? = nil) {
        var baseFolder = NSHomeDirectory() + "/Desktop"
        if let custom = CloudMountSettings.customMountFolder, !custom.isEmpty {
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: custom, isDirectory: &isDir), isDir.boolValue {
                baseFolder = custom
            } else {
                log?("⚠ Folderul de mount configurat (\(custom)) nu există (disc extern deconectat?) — folosesc Desktop în loc.")
            }
        }
        let mountPath = baseFolder + "/Cloud_" + remoteName
        try? FileManager.default.createDirectory(atPath: mountPath, withIntermediateDirectories: true)

        var sourceRemote = "\(remoteName):"
        if useChunker {
            let chunkedName = remoteName + "-chunked"
            if !remotes.contains(where: { $0.name == chunkedName }) {
                Shell.run("rclone config create \"\(chunkedName)\" chunker remote=\(remoteName): chunk_size=\(chunkSize) 2>/dev/null")
            }
            sourceRemote = "\(chunkedName):"
        }

        // --rc: activeaza API-ul local de statistici (Faza 2, "progres live
        // la transfer") - port UNIC per montare, nu unul fix comun (aceeasi
        // clasa de bug reparata pe Windows: doua montari simultane pe
        // acelasi port s-ar interfera la citirea statisticilor).
        let port = nextRcPort
        log?("$ rclone mount \(sourceRemote) \"\(mountPath)\" --rc-addr 127.0.0.1:\(port)")
        Shell.run("nohup rclone mount \(sourceRemote) \"\(mountPath)\" --vfs-cache-mode off --bwlimit 0 --rc --rc-addr 127.0.0.1:\(port) --rc-no-auth > /tmp/mmc_\(remoteName).log 2>&1 &")

        let drive = MountedDrive(remoteName: remoteName, mountPath: mountPath, usesChunker: useChunker, rcPort: port)
        mounted.removeAll { $0.remoteName == remoteName }
        mounted.append(drive)
        saveMountedState()
        log?("✔ \(remoteName): montat pe \(mountPath)")
    }

    public func unmount(remoteName: String, log: ((String) -> Void)? = nil) {
        guard let drive = mounted.first(where: { $0.remoteName == remoteName }) else { return }
        if let port = drive.rcPort {
            log?("$ rclone rc core/quit --rc-addr 127.0.0.1:\(port)")
            Shell.run("rclone rc core/quit --rc-addr 127.0.0.1:\(port) 2>/dev/null")
        }
        log?("$ diskutil unmount force \"\(drive.mountPath)\"")
        Shell.run("diskutil unmount force \"\(drive.mountPath)\" 2>/dev/null || umount \"\(drive.mountPath)\" 2>/dev/null")
        mounted.removeAll { $0.remoteName == remoteName }
        saveMountedState()
        log?("✔ \(remoteName): demontat.")
    }

    // MARK: - Faza 2: Statistici live de transfer

    /// Citeste `core/stats` din API-ul local al montarii - `nil` daca
    /// remote-ul nu e montat sau montarea a fost facuta cu o versiune veche
    /// (fara `--rc`, `rcPort == nil`).
    public func fetchStats(remoteName: String) -> CloudTransferStats? {
        guard let drive = mounted.first(where: { $0.remoteName == remoteName }), let port = drive.rcPort else { return nil }
        let output = Shell.run("rclone rc core/stats --rc-addr 127.0.0.1:\(port) 2>/dev/null")
        guard let data = output.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        let speed = json["speed"] as? Double ?? 0
        let bytes = (json["bytes"] as? NSNumber)?.int64Value ?? 0
        let transfers = (json["transfers"] as? NSNumber)?.intValue ?? 0
        return CloudTransferStats(speedBytesPerSec: speed, bytesTransferred: bytes, activeTransfers: transfers)
    }

    // MARK: - Faza 4: Upload / Download / Sincronizare / Stergere

    /// Urca fisiere/foldere locale intr-un folder de pe remote - functioneaza
    /// FIE ca remote-ul e montat, FIE nu (rclone lucreaza direct pe API-ul
    /// providerului, nu are nevoie de mount pentru copy).
    public func upload(remoteName: String, remotePath: String, localPaths: [String], log: @escaping (String) -> Void, completion: @escaping (Bool) -> Void) {
        let target = remotePath.isEmpty ? "\(remoteName):" : "\(remoteName):\(remotePath)"
        DispatchQueue.global(qos: .userInitiated).async {
            for path in localPaths {
                log("$ rclone copy \"\(path)\" \"\(target)\" --progress")
                let output = Shell.run("rclone copy \"\(path)\" \"\(target)\" -P 2>&1 | tail -n 8")
                if !output.isEmpty { DispatchQueue.main.async { log(output) } }
            }
            DispatchQueue.main.async { log("✔ Încărcare terminată."); completion(true) }
        }
    }

    /// Descarca un fisier/folder de pe remote intr-un folder local.
    public func download(remoteName: String, remotePath: String, isDir: Bool, localDestFolder: String, log: @escaping (String) -> Void, completion: @escaping (Bool) -> Void) {
        let source = "\(remoteName):\(remotePath)"
        DispatchQueue.global(qos: .userInitiated).async {
            log("$ rclone copy \"\(source)\" \"\(localDestFolder)\" --progress")
            let output = Shell.run("rclone copy \"\(source)\" \"\(localDestFolder)\" -P 2>&1 | tail -n 8")
            if !output.isEmpty { DispatchQueue.main.async { log(output) } }
            DispatchQueue.main.async { log("✔ Descărcare terminată în \(localDestFolder)."); completion(true) }
        }
    }

    /// Sterge un fisier sau un folder (recursiv) de pe remote - IREVERSIBIL,
    /// UI-ul trebuie sa ceara confirmare explicita inainte de a apela asta.
    public func deleteRemoteEntry(remoteName: String, remotePath: String, isDir: Bool, log: @escaping (String) -> Void) {
        let target = "\(remoteName):\(remotePath)"
        let command = isDir ? "rclone purge \"\(target)\"" : "rclone deletefile \"\(target)\""
        log("$ \(command)")
        let output = Shell.run("\(command) 2>&1")
        if !output.isEmpty { log(output) }
        log("✔ Șters: \(remotePath)")
    }

    /// Sincronizare folder local <-> remote. `mirror: true` = oglinda EXACTA
    /// (sterge la destinatie ce nu mai exista la sursa, `rclone sync`) -
    /// implicit FALSE (`rclone copy`, doar adauga/actualizeaza, niciodata
    /// nu sterge) - standardul GDC de "niciodata distructiv fara bifa
    /// explicita" (Regula 26/multi-selectie).
    public func syncFolder(localFolder: String, remoteName: String, remotePath: String, direction: SyncDirection, mirror: Bool, log: @escaping (String) -> Void, completion: @escaping (Bool) -> Void) {
        let remoteTarget = remotePath.isEmpty ? "\(remoteName):" : "\(remoteName):\(remotePath)"
        let (source, dest) = direction == .upload ? (localFolder, remoteTarget) : (remoteTarget, localFolder)
        let verb = mirror ? "sync" : "copy"
        DispatchQueue.global(qos: .userInitiated).async {
            log("$ rclone \(verb) \"\(source)\" \"\(dest)\" --progress" + (mirror ? "  (oglindă - șterge ce lipsește la sursă)" : ""))
            let output = Shell.run("rclone \(verb) \"\(source)\" \"\(dest)\" -P 2>&1 | tail -n 12")
            DispatchQueue.main.async {
                if !output.isEmpty { log(output) }
                log("✔ Sincronizare terminată.")
                completion(true)
            }
        }
    }

    // MARK: - Faza 3: Explorare remote fara montare

    /// Listeaza un folder de pe remote prin `rclone lsjson`, FARA sa
    /// monteze nimic - util pentru un preview rapid inainte de a decide
    /// daca montezi remote-ul intreg.
    public func listRemoteFolder(remoteName: String, path: String) -> [RemoteEntry] {
        let target = path.isEmpty ? "\(remoteName):" : "\(remoteName):\(path)"
        let output = Shell.run("rclone lsjson \"\(target)\" 2>/dev/null")
        guard let data = output.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
        return array.compactMap { item in
            guard let name = item["Name"] as? String else { return nil }
            let isDir = item["IsDir"] as? Bool ?? false
            let size = (item["Size"] as? NSNumber)?.int64Value ?? 0
            let childPath = path.isEmpty ? name : "\(path)/\(name)"
            return RemoteEntry(name: name, path: childPath, isDir: isDir, size: size)
        }.sorted { $0.isDir && !$1.isDir || ($0.isDir == $1.isDir && $0.name.lowercased() < $1.name.lowercased()) }
    }

    private func escapeForShell(_ value: String) -> String {
        value.replacingOccurrences(of: "\"", with: "\\\"")
    }

    private func saveMountedState() {
        if let data = try? JSONEncoder().encode(mounted) {
            UserDefaults.standard.set(data, forKey: Self.mountedKey)
        }
    }

    private func loadMountedState() {
        guard let data = UserDefaults.standard.data(forKey: Self.mountedKey),
              let saved = try? JSONDecoder().decode([MountedDrive].self, from: data) else { return }
        // Nu remontam automat la lansare - doar afisam ce era montat anterior.
        mounted = saved
    }
}
