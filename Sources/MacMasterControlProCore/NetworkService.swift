import Foundation

/// Mapeaza 1:1 pe menu_network_cloud din Mac_Master_Control.sh.
public struct NetworkAdapter: Identifiable {
    public let id = UUID()
    public let name: String
}

public final class NetworkService: ObservableObject {
    public init() {}
    @Published public var adapters: [NetworkAdapter] = []
    @Published public var selectedInterface: String = "en8"
    /// Adevarat daca LaunchDaemon-ul de tuning persistent e instalat SI
    /// valorile sysctl curente chiar reflecta tuning-ul (nu doar ca fisierul
    /// exista) — vezi `refreshPersistentTuningStatus()`.
    @Published public private(set) var persistentTuningActive = false

    private static let daemonLabel = "com.gdc.mastercontrolpro.network-tuning"
    private static var appSupportDir: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/MacMasterControlPro", isDirectory: true)
    }
    private static var scriptPath: String { appSupportDir.appendingPathComponent("reapply-network-tuning.sh").path }
    private static var localPlistPath: String { appSupportDir.appendingPathComponent("\(daemonLabel).plist").path }
    private static var installedPlistPath: String { "/Library/LaunchDaemons/\(daemonLabel).plist" }

    /// Scanare libera - permisa si in Trial (teasing: arata ce s-ar optimiza).
    public func scanAdapters() {
        let raw = Shell.run("networksetup -listallnetworkservices | tail -n +2")
        adapters = raw.split(separator: "\n").map { NetworkAdapter(name: String($0)) }
    }

    /// Actiune reala - necesita licenta activata (poarta de Trial in UI).
    /// Aplica media/DNS pe FIECARE adaptor bifat (Bara de Actiune in Masa,
    /// regula globala de multi-selectie 2026-08-30) - sysctl-urile kernel
    /// sunt globale procesului, deci ruleaza o singura data, nu per adaptor.
    public func applyTuning(selectedAdapters: Set<String>) {
        var commands = selectedAdapters.flatMap { adapter in
            [
                "sudo networksetup -setmedia \"\(adapter)\" 1000baseT full-duplex 2>/dev/null || true",
                "sudo networksetup -setdnsservers \"\(adapter)\" 1.1.1.1 8.8.8.8",
            ]
        }
        commands += [
            "sudo sysctl -w net.inet.tcp.sendspace=1048576",
            "sudo sysctl -w net.inet.tcp.recvspace=1048576",
            "sudo sysctl -w net.inet.tcp.fastopen=3",
            "sudo sysctl -w net.inet.tcp.delayed_ack=2"
        ]
        PrivilegedRunner.run(commands)
    }

    public func installRcloneStack() {
        Shell.run("brew install --cask macfuse 2>/dev/null; brew install rclone 2>/dev/null")
    }

    // MARK: - Tuning persistent la pornire (2026-08-31)
    //
    // PROBLEMA REALA: `sysctl -w` e runtime-only — kernel-ul revine la
    // valorile implicite la FIECARE repornire, deci tuning-ul din
    // `applyTuning` trebuia reaplicat manual, din aplicatie, dupa orice
    // restart. Fix: un LaunchDaemon (ruleaza ca root, la boot, fara sesiune
    // de user) reaplica automat ACEEASI comanda, de fiecare data cand
    // porneste Mac-ul — Cristi nu mai trebuie sa deschida aplicatia dupa
    // un restart ca sa ramana stabila configurarea.

    private func tuningScript(for selectedAdapters: [String]) -> String {
        var lines = ["#!/bin/bash", "# Generat automat de Master Control Studio Pro — nu edita manual."]
        for adapter in selectedAdapters {
            lines.append("networksetup -setmedia \"\(adapter)\" 1000baseT full-duplex 2>/dev/null || true")
            lines.append("networksetup -setdnsservers \"\(adapter)\" 1.1.1.1 8.8.8.8 2>/dev/null || true")
        }
        lines += [
            "sysctl -w net.inet.tcp.sendspace=1048576",
            "sysctl -w net.inet.tcp.recvspace=1048576",
            "sysctl -w net.inet.tcp.fastopen=3",
            "sysctl -w net.inet.tcp.delayed_ack=2",
        ]
        return lines.joined(separator: "\n") + "\n"
    }

    private func daemonPlist(scriptPath: String) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key><string>\(Self.daemonLabel)</string>
            <key>ProgramArguments</key>
            <array><string>/bin/bash</string><string>\(scriptPath)</string></array>
            <key>RunAtLoad</key><true/>
            <key>StandardOutPath</key><string>/tmp/mastercontrolpro-network-tuning.log</string>
            <key>StandardErrorPath</key><string>/tmp/mastercontrolpro-network-tuning.log</string>
        </dict>
        </plist>
        """
    }

    /// Scrie scriptul + plist-ul in Application Support (fara privilegii —
    /// fisiere ale userului curent), apoi le instaleaza ca LaunchDaemon
    /// (necesita root: `/Library/LaunchDaemons` + `launchctl`) intr-o
    /// SINGURA cerere de parola. Aplica si tuning-ul imediat, ca userul sa
    /// vada efectul pe loc, nu doar dupa urmatorul restart.
    public func installPersistentTuning(selectedAdapters: Set<String>) {
        let adapters = Array(selectedAdapters)
        try? FileManager.default.createDirectory(at: Self.appSupportDir, withIntermediateDirectories: true)
        try? tuningScript(for: adapters).write(toFile: Self.scriptPath, atomically: true, encoding: .utf8)
        try? daemonPlist(scriptPath: Self.scriptPath).write(toFile: Self.localPlistPath, atomically: true, encoding: .utf8)

        PrivilegedRunner.run([
            "chmod +x \"\(Self.scriptPath)\"",
            "cp \"\(Self.localPlistPath)\" \"\(Self.installedPlistPath)\"",
            "chown root:wheel \"\(Self.installedPlistPath)\"",
            "chmod 644 \"\(Self.installedPlistPath)\"",
            "launchctl bootout system \"\(Self.installedPlistPath)\" 2>/dev/null; launchctl bootstrap system \"\(Self.installedPlistPath)\" || launchctl load -w \"\(Self.installedPlistPath)\"",
            "bash \"\(Self.scriptPath)\"",
        ])
        refreshPersistentTuningStatus()
    }

    /// Elimina complet LaunchDaemon-ul — tuning-ul ramane doar in memorie
    /// pana la urmatorul restart, ca inainte de aceasta functionalitate.
    public func removePersistentTuning() {
        PrivilegedRunner.run([
            "launchctl bootout system \"\(Self.installedPlistPath)\" 2>/dev/null || true",
            "rm -f \"\(Self.installedPlistPath)\"",
        ])
        refreshPersistentTuningStatus()
    }

    /// Verde DOAR daca fisierul LaunchDaemon exista SI valorile sysctl
    /// curente chiar reflecta tuning-ul — nu presupunem succes din faptul
    /// ca fisierul a fost scris candva.
    public func refreshPersistentTuningStatus() {
        let daemonExists = FileManager.default.fileExists(atPath: Self.installedPlistPath)
        let currentSendspace = Shell.run("sysctl -n net.inet.tcp.sendspace").trimmingCharacters(in: .whitespacesAndNewlines)
        persistentTuningActive = daemonExists && currentSendspace == "1048576"
    }
}
