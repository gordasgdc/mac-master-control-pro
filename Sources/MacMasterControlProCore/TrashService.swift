import Foundation

/// Mutare RECUPERABILĂ în Coș. Nu folosește niciodată `rm -rf`: dacă sistemul refuză, rezultatul e o eroare per element,
/// cu motiv, iar elementul rămâne neatins. Fallback: Finder („delete”), care cere el însuși autorizarea nativă când e nevoie.
public enum TrashService {
    public enum Outcome: Equatable, Sendable {
        case moved
        case failed(String)
    }

    public static func moveToTrash(path: String) -> Outcome {
        let fm = FileManager.default
        guard fm.fileExists(atPath: path) else { return .failed("nu mai există") }
        do {
            try fm.trashItem(at: URL(fileURLWithPath: path), resultingItemURL: nil)
            return fm.fileExists(atPath: path) ? .failed("tot există după mutare") : .moved
        } catch {
            // Fallback recuperabil prin Finder.
            let escaped = path.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            p.arguments = ["-e", "tell application \"Finder\" to delete POSIX file \"\(escaped)\""]
            let err = Pipe(); p.standardError = err; p.standardOutput = Pipe()
            do { try p.run(); p.waitUntilExit() } catch { return .failed(error.localizedDescription) }
            if p.terminationStatus == 0, !fm.fileExists(atPath: path) { return .moved }
            let msg = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let reason = msg.isEmpty ? error.localizedDescription : msg
            return .failed(reason.contains("-1743") || reason.contains("not allowed") ? "lipsește permisiunea de Automatizare pentru Finder" : reason)
        }
    }
}
