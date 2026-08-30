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
}

/// Manager Universal Multi-Cloud - inlocuieste implementarea legata strict
/// de Degoo. Orice remote Rclone (OAuth sau cu credentiale) e tratat identic.
public final class CloudManagerService: ObservableObject {
    public init() { loadMountedState() }

    @Published public var remotes: [CloudRemote] = []
    @Published public var mounted: [MountedDrive] = []
    @Published public var lastError: String?

    private static let mountedKey = "MacMasterControlPro.mountedDrives"

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

    public func mount(remoteName: String, useChunker: Bool, chunkSize: String) {
        let mountPath = NSHomeDirectory() + "/Desktop/Cloud_" + remoteName
        try? FileManager.default.createDirectory(atPath: mountPath, withIntermediateDirectories: true)

        var sourceRemote = "\(remoteName):"
        if useChunker {
            let chunkedName = remoteName + "-chunked"
            if !remotes.contains(where: { $0.name == chunkedName }) {
                Shell.run("rclone config create \"\(chunkedName)\" chunker remote=\(remoteName): chunk_size=\(chunkSize) 2>/dev/null")
            }
            sourceRemote = "\(chunkedName):"
        }

        Shell.run("nohup rclone mount \(sourceRemote) \"\(mountPath)\" --vfs-cache-mode off --bwlimit 0 > /tmp/mmc_\(remoteName).log 2>&1 &")

        let drive = MountedDrive(remoteName: remoteName, mountPath: mountPath, usesChunker: useChunker)
        mounted.removeAll { $0.remoteName == remoteName }
        mounted.append(drive)
        saveMountedState()
    }

    public func unmount(remoteName: String) {
        guard let drive = mounted.first(where: { $0.remoteName == remoteName }) else { return }
        Shell.run("diskutil unmount force \"\(drive.mountPath)\" 2>/dev/null || umount \"\(drive.mountPath)\" 2>/dev/null")
        mounted.removeAll { $0.remoteName == remoteName }
        saveMountedState()
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
