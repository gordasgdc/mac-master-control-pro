import Foundation

/// Model generic - acelasi tipar ca SystemDependencyChecker din DataMover
/// (Regula 4: Manager de Dependente, indicator rosu/verde).
public struct DependencyItem: Identifiable, Equatable {
    public let id: String          // ex: "homebrew"
    public let name: String        // ex: "Homebrew"
    public var isInstalled: Bool
    public var version: String?
    public var installHint: String // afisat cand lipseste
    /// Componentele optionale (ex. FFmpeg) NU blocheaza starea verde
    /// generala — Regula 4 (Manager de Dependente): verde doar daca toate
    /// componentele OBLIGATORII sunt OK.
    public var isOptional: Bool = false
}

public final class DependencyChecker: ObservableObject {
    public init() {}

    @Published public var items: [DependencyItem] = []
    @Published public var isChecking: Bool = false
    @Published public var isInstalling: Bool = false
    @Published public var lastLog: String = ""
    /// Panou "terminal live" (Regula UI 2026-08-30) - linie cu linie, per
    /// comanda rulata, ca userul sa vada CONCRET ca se intampla ceva.
    @Published public var logLines: [String] = []

    public var allInstalled: Bool {
        let required = items.filter { !$0.isOptional }
        return !required.isEmpty && required.allSatisfy(\.isInstalled)
    }

    private var brewPath: String? {
        if FileManager.default.fileExists(atPath: "/opt/homebrew/bin/brew") { return "/opt/homebrew/bin/brew" }
        if FileManager.default.fileExists(atPath: "/usr/local/bin/brew") { return "/usr/local/bin/brew" }
        return nil
    }

    // MARK: - Scanare (rulata la prima pornire + manual)

    public func checkAll() {
        isChecking = true
        var results: [DependencyItem] = []

        // Homebrew
        if let brew = brewPath {
            let version = Shell.run("\"\(brew)\" --version 2>/dev/null").split(separator: "\n").first.map(String.init) ?? "instalat"
            results.append(DependencyItem(id: "homebrew", name: "Homebrew", isInstalled: true, version: version, installHint: "brew.sh"))
        } else {
            results.append(DependencyItem(id: "homebrew", name: "Homebrew", isInstalled: false, version: nil, installHint: "Necesar pentru Rclone și macFUSE."))
        }

        // Rclone
        if let brew = brewPath, !Shell.run("\"\(brew)\" list --versions rclone 2>/dev/null").isEmpty {
            let v = Shell.run("rclone version 2>/dev/null | head -n1")
            results.append(DependencyItem(id: "rclone", name: "Rclone", isInstalled: true, version: v, installHint: ""))
        } else {
            results.append(DependencyItem(id: "rclone", name: "Rclone", isInstalled: false, version: nil, installHint: "Necesar pentru Cloud Manager."))
        }

        // macFUSE
        let macfuseInstalled = FileManager.default.fileExists(atPath: "/Library/Filesystems/macfuse.fs")
        // [2026-09-03] Hint extins: instalarea cere parola de administrator
        // (dialog nativ, vezi Shell.runElevated) - normal, macFUSE instaleaza
        // o extensie de sistem. macOS poate arăta separat o notificare
        // "Software from 'Benjamin Fleischer' can run in the background" -
        // e dezvoltatorul oficial al macFUSE, nu un semnal de alarmă.
        results.append(DependencyItem(id: "macfuse", name: "macFUSE", isInstalled: macfuseInstalled, version: macfuseInstalled ? "instalat" : nil, installHint: "Necesar pentru montare Cloud ca disc virtual. Instalarea cere parola de administrator (extensie de sistem) — o notificare macOS despre \"Benjamin Fleischer\" e normală, e dezvoltatorul oficial al macFUSE."))

        // FFmpeg — opțional, util pentru codecuri de export pe care DaVinci
        // Resolve (mai ales varianta Free) nu le acoperă nativ.
        if let brew = brewPath, !Shell.run("\"\(brew)\" list --versions ffmpeg 2>/dev/null").isEmpty {
            let v = Shell.run("ffmpeg -version 2>/dev/null | head -n1")
            results.append(DependencyItem(id: "ffmpeg", name: "FFmpeg", isInstalled: true, version: v, installHint: "", isOptional: true))
        } else {
            results.append(DependencyItem(id: "ffmpeg", name: "FFmpeg", isInstalled: false, version: nil, installHint: "Opțional — codecuri suplimentare pentru export video.", isOptional: true))
        }

        // Utilitare de sistem (parte din macOS, verificare simpla de prezenta)
        for tool in ["sysctl", "tmutil", "networksetup", "lipo"] {
            let found = !Shell.run("command -v \(tool)").isEmpty
            results.append(DependencyItem(id: tool, name: tool, isInstalled: found, version: nil, installHint: "Utilitar de sistem macOS."))
        }

        items = results
        isChecking = false
    }

    // MARK: - Auto-install (fara Terminal manual pentru Rclone/macFUSE)

    /// Homebrew lipsa: scriptul oficial e interactiv (cere Return + parola)
    /// - il deschidem in Terminal.app in loc sa-l rulam orb in fundal.
    public func installHomebrewInTerminal() {
        let script = "/bin/bash -c \\\"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\\\""
        let osa = "tell application \"Terminal\" to do script \"\(script)\""
        var error: NSDictionary?
        NSAppleScript(source: osa)?.executeAndReturnError(&error)
    }

    /// Rclone/macFUSE: odata Homebrew prezent, instalarea e non-interactiva.
    public func installMissingViaBrew(completion: @escaping () -> Void) {
        guard let brew = brewPath else { completion(); return }
        isInstalling = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            var log = ""
            if self.items.first(where: { $0.id == "rclone" })?.isInstalled == false {
                log += Shell.run("\"\(brew)\" install rclone 2>&1") + "\n"
            }
            if self.items.first(where: { $0.id == "macfuse" })?.isInstalled == false {
                // Cask, nu formula - instaleaza o extensie de sistem, are
                // nevoie de sudo intern -> Shell.runElevated (askpass), nu
                // Shell.run simplu (vezi comentariul din Shell.swift).
                log += Shell.runElevated("\"\(brew)\" install --cask macfuse 2>&1") + "\n"
            }
            DispatchQueue.main.async {
                self.lastLog = log
                self.isInstalling = false
                self.checkAll()
                completion()
            }
        }
    }

    /// Instaleaza DOAR componenta ceruta - buton propriu per element (rosu/
    /// verde), cerinta explicita 2026-08-30: instalare pas-cu-pas, niciodata
    /// bulk automat, ca sa nu blocheze sistemul cu mai multe instalari deodata.
    public func installOne(id: String, completion: @escaping () -> Void) {
        guard let brew = brewPath else { completion(); return }
        let brewPackage: String
        let isCask: Bool
        switch id {
        case "rclone": brewPackage = "rclone"; isCask = false
        case "macfuse": brewPackage = "macfuse"; isCask = true
        case "ffmpeg": brewPackage = "ffmpeg"; isCask = false
        default: completion(); return
        }
        isInstalling = true
        logLines.append("$ brew install \(isCask ? "--cask " : "")\(brewPackage)")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            // macFUSE (cask) instaleaza o extensie de sistem prin `installer
            // -pkg ... -target /`, care ruleaza intern `sudo` FARA terminal
            // disponibil - are nevoie de askpass (Shell.runElevated), altfel
            // esueaza mereu cu "sudo: a terminal is required" (vezi
            // comentariul din Shell.swift). Formulele simple (rclone/ffmpeg)
            // nu ating sistemul, raman pe Shell.run.
            let cmd = "\"\(brew)\" install \(isCask ? "--cask " : "")\(brewPackage) 2>&1"
            let output = isCask ? Shell.runElevated(cmd) : Shell.run(cmd)
            DispatchQueue.main.async {
                guard let self else { return }
                self.logLines.append(contentsOf: output.split(separator: "\n").map(String.init))
                self.logLines.append("✔ \(brewPackage): comandă terminată.")
                self.isInstalling = false
                self.checkAll()
                completion()
            }
        }
    }

    /// Check & Update All - `brew update && brew upgrade` pentru pachetele noastre.
    public func checkAndUpdateAll(completion: @escaping () -> Void) {
        guard let brew = brewPath else { completion(); return }
        isInstalling = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            // "upgrade macfuse" poate re-rula installer-ul pkg (sudo intern) -
            // acelasi motiv ca la instalare, foloseste askpass.
            let log = Shell.runElevated("\"\(brew)\" update 2>&1 && \"\(brew)\" upgrade rclone macfuse 2>&1")
            DispatchQueue.main.async {
                self?.lastLog = log
                self?.isInstalling = false
                self?.checkAll()
                completion()
            }
        }
    }
}
