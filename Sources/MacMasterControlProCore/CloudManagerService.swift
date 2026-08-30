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

/// Client OAuth propriu GDC (Google Cloud Console, proiect al lui Cristi),
/// disponibil ca OPTIUNE in aplicatie (2026-08-30) - alternativa la
/// clientul PARTAJAT al rclone-ului pentru Google Drive (limitat agresiv
/// de Google la viteza per fisier).
///
/// **NU e implicit/automat** (decizie explicita a lui Cristi, 2026-08-30,
/// dupa ce a realizat implicatia reala): cat timp proiectul Google ramane
/// in modul "Testing", DOAR conturile adaugate manual ca "test user" in
/// Google Cloud Console se pot conecta prin acest client - orice alt cont
/// primeste un ecran de BLOCAJ TOTAL ("Access blocked", fara nicio optiune
/// de a continua), nu doar un avertisment ignorabil. Daca ar fi implicit
/// pentru toata lumea, orice client nenominalizat manual de Cristi ar
/// ramane blocat la conectare.
///
/// De aceea: implicit, remote-urile Google Drive noi folosesc clientul
/// STANDARD rclone (functioneaza pentru oricine, fara nicio configurare,
/// doar putin mai lent) - Cristi activeaza manual comutatorul "Foloseste
/// client Google rapid (GDC)" din Cloud Manager DOAR pentru un cont pe
/// care l-a adaugat deja ca test user (al lui, sau al unui client caruia
/// i-a promis explicit viteza mai buna). Vezi ghidul PDF, sectiunea
/// "Upload lent pe Google Drive?", pentru varianta ALTERNATIVA in care
/// clientul isi face singur propriul client Google (independenta de
/// limita de 100 test useri) - si `GHID_INTERN_ONBOARDING_GOOGLE_DRIVE.md`
/// pentru procedura completa de onboarding per-client.
public enum GDCOAuthClients {
    // Valorile reale traiesc in GDCOAuthSecrets.generated.swift, fisier
    // NECOMIS in git (vezi .gitignore) - generat la build din variabila de
    // mediu GDC_GOOGLE_DRIVE_CLIENT_SECRET (build_installer.sh), la fel ca
    // APPLE_SIGN_IDENTITY_APP pentru semnare. GitHub Push Protection a
    // blocat push-ul initial cand aceste valori erau hardcodate direct
    // aici (secret literal intr-un repo PUBLIC) - Regula 2 (zero secrete
    // in git) se aplica si aici, nu doar la token-uri de autentificare git.
    public static let googleDriveClientID = GDCOAuthSecretsGenerated.googleDriveClientID
    public static let googleDriveClientSecret = GDCOAuthSecretsGenerated.googleDriveClientSecret

    /// Comutator persistat, implicit FALSE - vezi comentariul de mai sus
    /// pentru motivul exact al acestei decizii.
    private static let useGDCClientKey = "MacMasterControlPro.useGDCGoogleDriveClient"
    public static var useGDCClientForNewRemotes: Bool {
        get { UserDefaults.standard.bool(forKey: useGDCClientKey) }
        set { UserDefaults.standard.set(newValue, forKey: useGDCClientKey) }
    }
}

/// Setari de performanta rclone, reglabile din UI (Cloud Manager › secțiunea
/// "Performanță"), 2026-08-30 - cerinta explicita a lui Cristi dupa fix-ul
/// identic din DataMover ("mai multe opțiuni de configurare"). Spre
/// deosebire de DataMover (unde bug-ul era un proces `rclone` per fisier),
/// `upload`/`download`/`syncFolder` de aici ruleaza deja UN singur proces
/// pe tot folderul - nu exista acelasi bug de arhitectura, dar rulau pe
/// valorile IMPLICITE rclone (`--transfers 4 --checkers 8`), fara nicio
/// optiune reglabila. Valorile implicite de mai jos sunt cele deja
/// confirmate mai rapide pe DataMover (Google Drive, mix fisiere mici+mari).
public enum RclonePerformanceSettings {
    private static let transfersKey = "MacMasterControlPro.rcloneTransfers"
    private static let checkersKey = "MacMasterControlPro.rcloneCheckers"
    private static let chunkMBKey = "MacMasterControlPro.rcloneDriveChunkMB"
    private static let fastListKey = "MacMasterControlPro.rcloneFastList"

    public static let transfersRange = 1...16
    public static let checkersRange = 1...32
    public static let chunkChoicesMB = [8, 16, 32, 64, 128]

    public static var transfers: Int {
        get { let v = UserDefaults.standard.integer(forKey: transfersKey); return v > 0 ? v : 8 }
        set { UserDefaults.standard.set(newValue, forKey: transfersKey) }
    }
    public static var checkers: Int {
        get { let v = UserDefaults.standard.integer(forKey: checkersKey); return v > 0 ? v : 16 }
        set { UserDefaults.standard.set(newValue, forKey: checkersKey) }
    }
    public static var driveChunkMB: Int {
        get { let v = UserDefaults.standard.integer(forKey: chunkMBKey); return v > 0 ? v : 64 }
        set { UserDefaults.standard.set(newValue, forKey: chunkMBKey) }
    }
    public static var fastList: Bool {
        get { UserDefaults.standard.object(forKey: fastListKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: fastListKey) }
    }

    /// Flag-urile gata formatate, de adaugat la orice comanda `rclone
    /// copy`/`sync` - citite live la fiecare apel (Setari fara restart).
    public static var copyFlags: String {
        var flags = "--transfers \(transfers) --checkers \(checkers) --drive-chunk-size \(driveChunkMB)M"
        if fastList { flags += " --fast-list" }
        return flags
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
        // Client OAuth propriu GDC pentru Google Drive - DOAR daca Cristi a
        // activat explicit comutatorul (vezi GDCOAuthClients, NU e implicit
        // - proiectul Google ramane in modul "Testing", un cont neadaugat
        // manual ca test user ar ramane BLOCAT total la conectare cu acest
        // client). Implicit (comutator OFF), foloseste clientul STANDARD
        // rclone - functioneaza pentru orice cont, fara nicio configurare.
        if type == .googleDrive && GDCOAuthClients.useGDCClientForNewRemotes {
            args.append("client_id=\(GDCOAuthClients.googleDriveClientID)")
            args.append("client_secret=\(GDCOAuthClients.googleDriveClientSecret)")
        }
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
        let perf = RclonePerformanceSettings.copyFlags
        DispatchQueue.global(qos: .userInitiated).async {
            for path in localPaths {
                log("$ rclone copy \"\(path)\" \"\(target)\" \(perf) --progress")
                let output = Shell.run("rclone copy \"\(path)\" \"\(target)\" \(perf) -P 2>&1 | tail -n 8")
                if !output.isEmpty { DispatchQueue.main.async { log(output) } }
            }
            DispatchQueue.main.async { log("✔ Încărcare terminată."); completion(true) }
        }
    }

    /// Descarca un fisier/folder de pe remote intr-un folder local.
    public func download(remoteName: String, remotePath: String, isDir: Bool, localDestFolder: String, log: @escaping (String) -> Void, completion: @escaping (Bool) -> Void) {
        let source = "\(remoteName):\(remotePath)"
        let perf = RclonePerformanceSettings.copyFlags
        DispatchQueue.global(qos: .userInitiated).async {
            log("$ rclone copy \"\(source)\" \"\(localDestFolder)\" \(perf) --progress")
            let output = Shell.run("rclone copy \"\(source)\" \"\(localDestFolder)\" \(perf) -P 2>&1 | tail -n 8")
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
        let perf = RclonePerformanceSettings.copyFlags
        DispatchQueue.global(qos: .userInitiated).async {
            log("$ rclone \(verb) \"\(source)\" \"\(dest)\" \(perf) --progress" + (mirror ? "  (oglindă - șterge ce lipsește la sursă)" : ""))
            let output = Shell.run("rclone \(verb) \"\(source)\" \"\(dest)\" \(perf) -P 2>&1 | tail -n 12")
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
