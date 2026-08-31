import Foundation
import AppKit

/// Backup + verificare "proces Resolve blocat" (zombie) — completare la
/// `ResolveMediaAuditService`/`ResolveConfigSyncService` (Nivel 3,
/// brainstorm Master Control Studio Pro).
///
/// ARHITECTURĂ: baza de date "Disk Database" a DaVinci Resolve (implicită,
/// fără server PostgreSQL separat) e un folder simplu pe disc — un backup
/// e deci o copiere/arhivare de folder, NU o operație de bază de date
/// (Resolve trebuie închis cât timp se face backup-ul, altfel fișierele
/// pot fi în scriere).
public enum ResolveDatabaseBackupService {
    public static var databasePath: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Blackmagic Design/DaVinci Resolve/Resolve Project Library")
    }

    private static var backupsDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Movies/MacMasterControlPro-ResolveBackups", isDirectory: true)
    }

    public static func databaseExists() -> Bool {
        FileManager.default.fileExists(atPath: databasePath.path)
    }

    public static func databaseSizeBytes() -> Int64 {
        let output = Shell.run("du -sk \"\(databasePath.path)\" 2>/dev/null | cut -f1")
        return (Int64(output.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0) * 1024
    }

    public struct BackupEntry: Identifiable {
        public let id: String
        public let path: URL
        public let date: Date
        public let sizeBytes: Int64
    }

    public static func listBackups() -> [BackupEntry] {
        guard let entries = try? FileManager.default.contentsOfDirectory(at: backupsDirectory, includingPropertiesForKeys: [.creationDateKey]) else { return [] }
        return entries
            .filter { $0.pathExtension == "zip" }
            .compactMap { url -> BackupEntry? in
                guard let date = (try? url.resourceValues(forKeys: [.creationDateKey]))?.creationDate else { return nil }
                let sizeKB = Shell.run("du -sk \"\(url.path)\" 2>/dev/null | cut -f1")
                let bytes = (Int64(sizeKB.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0) * 1024
                return BackupEntry(id: url.path, path: url, date: date, sizeBytes: bytes)
            }
            .sorted { $0.date > $1.date }
    }

    /// Resolve TREBUIE inchis inainte de backup — copierea unei baze de
    /// date "la cald" poate prinde fisiere in scriere, rezultand o arhiva
    /// coruptibila. Verificam explicit, nu doar recomandam in text.
    public static func isResolveRunning() -> Bool {
        !Shell.run("pgrep -x \"DaVinci Resolve\"").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public enum BackupError: LocalizedError {
        case resolveRunning
        case databaseMissing
        case zipFailed(String)

        public var errorDescription: String? {
            switch self {
            case .resolveRunning: return "Închide DaVinci Resolve înainte de backup — copierea „la cald” poate corupe arhiva."
            case .databaseMissing: return "Nu am găsit baza de date de proiecte a Resolve pe acest Mac."
            case .zipFailed(let output): return "Arhivarea a eșuat: \(output)"
            }
        }
    }

    public static func createBackup() throws -> URL {
        guard !isResolveRunning() else { throw BackupError.resolveRunning }
        guard databaseExists() else { throw BackupError.databaseMissing }
        try FileManager.default.createDirectory(at: backupsDirectory, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let destination = backupsDirectory.appendingPathComponent("ResolveProjectLibrary-\(formatter.string(from: Date())).zip")

        let output = Shell.run("cd \"\(databasePath.deletingLastPathComponent().path)\" && zip -rq \"\(destination.path)\" \"\(databasePath.lastPathComponent)\"")
        guard FileManager.default.fileExists(atPath: destination.path) else {
            throw BackupError.zipFailed(output)
        }
        return destination
    }

    public static func revealInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    // MARK: - Detectare "Resolve zombie" (proces activ, fara fereastra vizibila)
    //
    // Acelasi pattern deja verificat in MediaFlow Monitor: un proces gasit
    // activ DAR fara nicio fereastra reala e aproape sigur blocat, nu doar
    // "in fundal" — Resolve normal are mereu cel putin o fereastra cat timp
    // ruleaza (nu e un daemon).

    public static func isResolveZombie() -> Bool {
        guard isResolveRunning() else { return false }
        let hasVisibleWindow = NSWorkspace.shared.runningApplications
            .contains { $0.localizedName == "DaVinci Resolve" && $0.isActive }
        // NSRunningApplication.isActive nu e suficient de fiabil singur
        // (poate fi false si pentru o fereastra minimizata, legitima) —
        // combinam cu numarul de ferestre raportat de Window Server.
        let windowCount = Shell.run("""
        osascript -e 'tell application "System Events" to count (every window of (first process whose name is "DaVinci Resolve"))' 2>/dev/null
        """).trimmingCharacters(in: .whitespacesAndNewlines)
        let count = Int(windowCount) ?? -1
        return count == 0 && !hasVisibleWindow
    }

    public static func forceQuitResolve() {
        Shell.run("pkill -9 -x \"DaVinci Resolve\"")
    }
}
