import AppKit

/// Descarca si instaleaza automat un update, fara sa treaca prin browser
/// (Regula 20 — port 1:1 al SelfUpdater din DataMover/GDCVault).
///
/// WARNING: pasul de instalare (promptul de parola admin) NU poate fi
/// verificat automat — cere interactiune fizica reala cu fereastra de
/// sistem. Descarcarea (HTTP 200, fisier scris integral) e verificabila.
enum SelfUpdater {

    enum UpdateError: LocalizedError {
        case downloadFailed(String)
        case installScriptFailed(String)

        var errorDescription: String? {
            switch self {
            case .downloadFailed(let detail): return L.x("Descărcarea a eșuat: \(detail)", "Download failed: \(detail)", "Falló la descarga: \(detail)")
            case .installScriptFailed(let detail): return L.x("Nu am putut porni instalarea: \(detail)", "Could not start the installation: \(detail)", "No se pudo iniciar la instalación: \(detail)")
            }
        }
    }

    @MainActor
    static func downloadAndInstall(pkgURL: URL, version: String) async {
        let progress = UpdateProgressWindow(version: version)
        progress.show()

        do {
            let tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("mmc-update-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            let pkgPath = tempDir.appendingPathComponent("MacMasterControlPro-\(version).pkg")

            progress.setStatus(L.x("Se descarcă…", "Downloading…", "Descargando…"))
            try await download(from: pkgURL, to: pkgPath)

            progress.setStatus(L.x("Se instalează…", "Installing…", "Instalando…"))
            try runInstaller(pkgPath: pkgPath, tempDir: tempDir)

            progress.close()
            NSApp.terminate(nil)
        } catch {
            progress.close()
            presentFailure(error, fallbackURL: releasesPageURLForFallback)
        }
    }

    private static func download(from url: URL, to destination: URL) async throws {
        let (tempLocation, response): (URL, URLResponse)
        do {
            (tempLocation, response) = try await URLSession.shared.download(from: url)
        } catch {
            throw UpdateError.downloadFailed(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw UpdateError.downloadFailed("HTTP \(code)")
        }
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: tempLocation, to: destination)
    }

    private static func runInstaller(pkgPath: URL, tempDir: URL) throws {
        let logPath = tempDir.appendingPathComponent("mmc_update.log")
        let scriptPath = tempDir.appendingPathComponent("mmc_update.sh")

        let scriptContent = """
        #!/bin/bash
        exec > "\(logPath.path)" 2>&1
        sleep 2
        echo "Instalez actualizarea..."
        installer -pkg "\(pkgPath.path)" -target /
        status=$?
        if [ $status -ne 0 ]; then
            echo "Instalarea a esuat (cod $status)."
            exit $status
        fi
        echo "Pornesc aplicatia actualizata..."
        open -a "Master Control Studio Pro"
        rm -rf "\(tempDir.path)"
        """
        do {
            try scriptContent.write(to: scriptPath, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptPath.path)
        } catch {
            throw UpdateError.installScriptFailed(error.localizedDescription)
        }

        let escapedPath = scriptPath.path.replacingOccurrences(of: "\"", with: "\\\"")
        let appleScript = "do shell script \"\(escapedPath)\" with administrator privileges"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", appleScript]
        do {
            try process.run()
        } catch {
            throw UpdateError.installScriptFailed(error.localizedDescription)
        }
    }

    private static let releasesPageURLForFallback = URL(string: "https://github.com/gordasgdc/mac-master-control-pro/releases/latest")!

    @MainActor
    private static func presentFailure(_ error: Error, fallbackURL: URL) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = L.x("Actualizarea a eșuat", "The update failed", "Falló la actualización")
        alert.informativeText = L.x("\(error.localizedDescription)\n\nPoți încerca manual de pe pagina de releases.", "\(error.localizedDescription)\n\nYou can try manually from the releases page.", "\(error.localizedDescription)\n\nPuedes intentarlo a mano desde la página de versiones.")
        alert.addButton(withTitle: L.x("Deschide pagina", "Open page", "Abrir la página"))
        alert.addButton(withTitle: "OK")
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(fallbackURL)
        }
    }
}

@MainActor
final class UpdateProgressWindow {
    private let window: NSWindow
    private let statusLabel: NSTextField
    private let spinner: NSProgressIndicator

    init(version: String) {
        let contentRect = NSRect(x: 0, y: 0, width: 360, height: 110)
        window = NSWindow(contentRect: contentRect, styleMask: [.titled], backing: .buffered, defer: false)
        window.title = L.x("Actualizare disponibilă", "Update available", "Actualización disponible")
        window.isReleasedWhenClosed = false
        window.center()

        let container = NSView(frame: contentRect)

        let titleLabel = NSTextField(labelWithString: "Master Control Studio Pro \(version)")
        titleLabel.font = .boldSystemFont(ofSize: 13)
        titleLabel.frame = NSRect(x: 20, y: 70, width: 320, height: 20)
        container.addSubview(titleLabel)

        statusLabel = NSTextField(labelWithString: "")
        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.lineBreakMode = .byWordWrapping
        statusLabel.maximumNumberOfLines = 2
        statusLabel.frame = NSRect(x: 20, y: 30, width: 320, height: 34)
        container.addSubview(statusLabel)

        spinner = NSProgressIndicator(frame: NSRect(x: 20, y: 12, width: 320, height: 6))
        spinner.style = .bar
        spinner.isIndeterminate = true
        spinner.startAnimation(nil)
        container.addSubview(spinner)

        window.contentView = container
    }

    func show() {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func setStatus(_ text: String) {
        statusLabel.stringValue = text
    }

    func close() {
        window.close()
    }
}
