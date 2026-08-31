import Foundation
import UserNotifications

/// Notificare la finalul randarii (2026-08-31, Nivel 2 #7) - interogheaza
/// periodic coada de randare din DaVinci Resolve (Scripting API, READ-ONLY,
/// `GetRenderJobList()`) si trimite o notificare nativa macOS cand un job
/// trece intr-o stare finala (Complete/Failed/Cancelled) - util cand
/// randarea dureaza ore si userul lucreaza in alta parte pe alt monitor.
public final class RenderNotificationService: ObservableObject {
    @Published public var isWatching = false
    @Published public var lastError: String?

    private var timer: Timer?
    private var notifiedJobStates: [String: String] = [:] // jobID -> ultima stare notificata

    public init() {}

    public func start() {
        requestPermission()
        isWatching = true
        lastError = nil
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.pollOnce()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
        isWatching = false
    }

    private func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func pollOnce() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            switch ResolveRenderJobQuery.fetchJobs() {
            case .success(let jobs):
                DispatchQueue.main.async { self.lastError = nil }
                for job in jobs {
                    let terminal = ["Complete", "Failed", "Cancelled"].first { job.status.contains($0) }
                    guard let terminal else { continue }
                    if self.notifiedJobStates[job.id] == terminal { continue }
                    self.notifiedJobStates[job.id] = terminal
                    self.fireNotification(jobName: job.name, status: terminal)
                }
            case .failure(let error):
                DispatchQueue.main.async { self.lastError = "\(error)" }
            }
        }
    }

    private func fireNotification(jobName: String, status: String) {
        let title = status == "Complete" ? "✔ Randare terminată" : "✘ Randare \(status.lowercased())"
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = jobName
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)

        // Notificare pe email (2026-08-31) - ADITIONALA, nu inlocuieste
        // notificarea nativa de mai sus - cerut explicit de Cristi, ca sa
        // ajunga si pe telefon, nu doar cat timp e la calculator.
        DispatchQueue.global(qos: .utility).async {
            EmailNotifierService.send(subject: "\(title) — \(jobName)", body: "Job: \(jobName)\nStatus: \(status)")
        }
    }
}

struct ResolveRenderJob {
    let id: String
    let name: String
    let status: String
}

struct SimpleError: Error, CustomStringConvertible {
    let message: String
    var description: String { message }
}

/// Interogare separata (nu reutilizeaza ResolveMediaAuditService direct ca
/// sa nu cupleze doua responsabilitati diferite in aceeasi clasa) - acelasi
/// tipar de bridge Python peste Scripting API.
enum ResolveRenderJobQuery {
    private static let scriptAPIPath = "/Library/Application Support/Blackmagic Design/DaVinci Resolve/Developer/Scripting/"
    private static var scriptModulesPath: String { scriptAPIPath + "Modules/" }
    private static let scriptLibPath = "/Applications/DaVinci Resolve/DaVinci Resolve.app/Contents/Libraries/Fusion/fusionscript.so"

    private static func findPython3() -> String? {
        for candidate in ["/usr/bin/python3", "/opt/homebrew/bin/python3", "/usr/local/bin/python3"] {
            if FileManager.default.isExecutableFile(atPath: candidate) { return candidate }
        }
        return nil
    }

    static func fetchJobs() -> Result<[ResolveRenderJob], SimpleError> {
        guard let pythonPath = findPython3(), FileManager.default.fileExists(atPath: scriptModulesPath) else {
            return .failure(SimpleError(message: "Scripting Resolve indisponibil"))
        }
        let script = """
        import sys, json
        sys.path.append(r"\(scriptModulesPath)")
        try:
            import DaVinciResolveScript as dvr
            resolve = dvr.scriptapp("Resolve")
            project = resolve.GetProjectManager().GetCurrentProject() if resolve else None
            if project is None:
                print(json.dumps({"jobs": []}))
                sys.exit(0)
            jobs = []
            for job_id in project.GetRenderJobList() and [j["JobId"] for j in project.GetRenderJobList()] or []:
                status = project.GetRenderJobStatus(job_id)
                jobs.append({"id": job_id, "name": job_id, "status": status.get("JobStatus", "") if isinstance(status, dict) else str(status)})
            print(json.dumps({"jobs": jobs}))
        except Exception as e:
            print(json.dumps({"error": str(e)}))
        """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: pythonPath)
        process.arguments = ["-c", script]
        process.environment = [
            "RESOLVE_SCRIPT_API": scriptAPIPath,
            "RESOLVE_SCRIPT_LIB": scriptLibPath,
            "PYTHONPATH": scriptModulesPath,
            "PATH": ProcessInfo.processInfo.environment["PATH"] ?? "/usr/bin:/bin",
        ]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
        } catch {
            return .failure(SimpleError(message: "Nu s-a putut porni python3"))
        }
        let deadline = Date().addingTimeInterval(10)
        while process.isRunning && Date() < deadline { Thread.sleep(forTimeInterval: 0.2) }
        if process.isRunning { process.terminate(); return .failure(SimpleError(message: "Timeout")) }
        guard process.terminationStatus == 0 else { return .failure(SimpleError(message: "Cod ieșire \(process.terminationStatus)")) }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let text = String(data: data, encoding: .utf8),
              let jsonData = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
        else { return .failure(SimpleError(message: "Răspuns invalid")) }
        if let error = json["error"] as? String { return .failure(SimpleError(message: error)) }
        let jobsRaw = json["jobs"] as? [[String: String]] ?? []
        return .success(jobsRaw.compactMap { dict in
            guard let id = dict["id"], let status = dict["status"] else { return nil }
            return ResolveRenderJob(id: id, name: dict["name"] ?? id, status: status)
        })
    }
}
