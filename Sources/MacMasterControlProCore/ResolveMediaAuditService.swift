import Foundation

/// Un clip semnalat de auditul Media Pool - offline (fisierul sursa nu mai
/// exista pe disc) sau duplicat (aceeasi cale de fisier apare de mai multe
/// ori in Media Pool, in bin-uri diferite sau acelasi bin).
public struct ResolveMediaFlag: Identifiable, Hashable {
    public var id: String { "\(clipName)|\(filePath)" }
    public let clipName: String
    public let filePath: String
    public let reason: Reason
    public enum Reason: String { case offline = "Offline", duplicate = "Duplicat" }
}

public struct ResolveMediaAuditResult {
    public let projectName: String
    public let flags: [ResolveMediaFlag]
    public let totalClips: Int
}

public enum ResolveMediaAuditError: Error {
    case resolveNotRunning
    case noProjectOpen
    case scriptingUnavailable
    case scriptFailed(String)
}

/// Auditor Media Pool (2026-08-31, Nivel 2 #6) - EXCLUSIV prin Scripting
/// API-ul oficial DaVinci (`import DaVinciResolveScript`), NICIODATA
/// scriere directa in baza de date interna a proiectelor Resolve - aceeasi
/// regula de aur ca `PowerGradeImporter.swift` (gdc-plugin-manager):
/// Resolve nu documenteaza formatul intern al bazei de date, o scriere
/// directa risca s-o corupa. Doar CITIRE (GetClipList/GetClipProperty)
/// pentru audit, si `DeleteClips` (API oficial, sigur) doar pentru clipuri
/// EXPLICIT selectate de utilizator - niciodata stergere in masa automata.
public enum ResolveMediaAuditService {
    private static let scriptAPIPath = "/Library/Application Support/Blackmagic Design/DaVinci Resolve/Developer/Scripting/"
    private static var scriptModulesPath: String { scriptAPIPath + "Modules/" }
    private static let scriptLibPath = "/Applications/DaVinci Resolve/DaVinci Resolve.app/Contents/Libraries/Fusion/fusionscript.so"

    private static func findPython3() -> String? {
        for candidate in ["/usr/bin/python3", "/opt/homebrew/bin/python3", "/usr/local/bin/python3"] {
            if FileManager.default.isExecutableFile(atPath: candidate) { return candidate }
        }
        return nil
    }

    public static var isAvailable: Bool {
        findPython3() != nil && FileManager.default.fileExists(atPath: scriptModulesPath)
    }

    /// Scaneaza proiectul curent deschis in Resolve - recursiv prin toate
    /// bin-urile Media Pool-ului, citind "File Path" per clip. Nu modifica
    /// nimic - pur citire.
    public static func scanCurrentProject() -> Result<ResolveMediaAuditResult, ResolveMediaAuditError> {
        guard let pythonPath = findPython3(), FileManager.default.fileExists(atPath: scriptModulesPath) else {
            return .failure(.scriptingUnavailable)
        }
        let script = """
        import sys, os, json
        sys.path.append(r"\(scriptModulesPath)")
        try:
            import DaVinciResolveScript as dvr
            resolve = dvr.scriptapp("Resolve")
            if resolve is None:
                print(json.dumps({"error": "no_scripting_access"}))
                sys.exit(0)
            project = resolve.GetProjectManager().GetCurrentProject()
            if project is None:
                print(json.dumps({"error": "no_project"}))
                sys.exit(0)
            pool = project.GetMediaPool()
            root = pool.GetRootFolder()

            clips = []
            def walk(folder):
                for clip in folder.GetClipList():
                    path = clip.GetClipProperty("File Path") or ""
                    name = clip.GetClipProperty("Clip Name") or clip.GetName()
                    if path:
                        clips.append({"name": name, "path": path})
                for sub in folder.GetSubFolderList():
                    walk(sub)
            walk(root)

            print(json.dumps({"project": project.GetName(), "clips": clips}))
        except Exception as e:
            print(json.dumps({"error": str(e)}))
        """
        guard let output = runPython(pythonPath: pythonPath, script: script),
              let data = output.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return .failure(.scriptFailed("Nu s-a putut citi răspunsul de la Resolve."))
        }
        if let error = json["error"] as? String {
            switch error {
            case "no_scripting_access": return .failure(.resolveNotRunning)
            case "no_project": return .failure(.noProjectOpen)
            default: return .failure(.scriptFailed(error))
            }
        }
        guard let projectName = json["project"] as? String,
              let clipsRaw = json["clips"] as? [[String: String]]
        else {
            return .failure(.scriptFailed("Format neașteptat."))
        }

        var pathCounts: [String: Int] = [:]
        for clip in clipsRaw { pathCounts[clip["path"] ?? "", default: 0] += 1 }

        var flags: [ResolveMediaFlag] = []
        var seenDuplicatePaths: Set<String> = []
        for clip in clipsRaw {
            guard let name = clip["name"], let path = clip["path"] else { continue }
            if !FileManager.default.fileExists(atPath: path) {
                flags.append(ResolveMediaFlag(clipName: name, filePath: path, reason: .offline))
            } else if (pathCounts[path] ?? 0) > 1, !seenDuplicatePaths.contains(path) {
                flags.append(ResolveMediaFlag(clipName: name, filePath: path, reason: .duplicate))
                seenDuplicatePaths.insert(path)
            }
        }
        return .success(ResolveMediaAuditResult(projectName: projectName, flags: flags, totalClips: clipsRaw.count))
    }

    /// Șterge din Media Pool DOAR clipurile ale căror căi de fișier sunt
    /// date explicit (selecție a utilizatorului din UI) - `DeleteClips`,
    /// API oficial de scripting, nu atinge baza de date direct.
    public static func deleteClips(filePaths: [String]) -> Result<Int, ResolveMediaAuditError> {
        guard let pythonPath = findPython3(), FileManager.default.fileExists(atPath: scriptModulesPath) else {
            return .failure(.scriptingUnavailable)
        }
        let pathsLiteral = filePaths.map { "r\"\($0.replacingOccurrences(of: "\"", with: "\\\""))\"" }.joined(separator: ", ")
        let script = """
        import sys, json
        sys.path.append(r"\(scriptModulesPath)")
        try:
            import DaVinciResolveScript as dvr
            resolve = dvr.scriptapp("Resolve")
            project = resolve.GetProjectManager().GetCurrentProject()
            pool = project.GetMediaPool()
            root = pool.GetRootFolder()
            targets = set([\(pathsLiteral)])
            to_delete = []
            def walk(folder):
                for clip in folder.GetClipList():
                    if clip.GetClipProperty("File Path") in targets:
                        to_delete.append(clip)
                for sub in folder.GetSubFolderList():
                    walk(sub)
            walk(root)
            ok = pool.DeleteClips(to_delete) if to_delete else True
            print(json.dumps({"deleted": len(to_delete), "ok": bool(ok)}))
        except Exception as e:
            print(json.dumps({"error": str(e)}))
        """
        guard let output = runPython(pythonPath: pythonPath, script: script),
              let data = output.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return .failure(.scriptFailed("Nu s-a putut citi răspunsul de la Resolve."))
        }
        if let error = json["error"] as? String { return .failure(.scriptFailed(error)) }
        return .success((json["deleted"] as? Int) ?? 0)
    }

    /// Vezi PowerGradeImporter.runPython - timeout dur, puntea de scripting
    /// Resolve poate ramane blocata.
    private static func runPython(pythonPath: String, script: String, timeout: TimeInterval = 20) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: pythonPath)
        process.arguments = ["-c", script]
        process.environment = [
            "RESOLVE_SCRIPT_API": scriptAPIPath,
            "RESOLVE_SCRIPT_LIB": scriptLibPath,
            "PYTHONPATH": scriptModulesPath,
            "PATH": ProcessInfo.processInfo.environment["PATH"] ?? "/usr/bin:/bin",
        ]
        let stdoutPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = Pipe()
        do { try process.run() } catch { return nil }
        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.2)
        }
        if process.isRunning {
            process.terminate()
            return nil
        }
        guard process.terminationStatus == 0 else { return nil }
        let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
