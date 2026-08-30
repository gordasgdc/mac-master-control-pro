import Foundation

/// Mapeaza 1:1 pe menu_network_cloud din Mac_Master_Control.sh.
public struct NetworkAdapter: Identifiable {
    public let id = UUID()
    public let name: String
}

public final class NetworkService: ObservableObject {
    public init() {}
    @Published public var adapters: [NetworkAdapter] = []
    @Published public var selectedAdapter: String = "USB 10/100/1000 LAN"
    @Published public var selectedInterface: String = "en8"

    /// Scanare libera - permisa si in Trial (teasing: arata ce s-ar optimiza).
    public func scanAdapters() {
        let raw = Shell.run("networksetup -listallnetworkservices | tail -n +2")
        adapters = raw.split(separator: "\n").map { NetworkAdapter(name: String($0)) }
    }

    /// Actiune reala - necesita licenta activata (poarta de Trial in UI).
    public func applyTuning() {
        let commands = [
            "sudo networksetup -setmedia \"\(selectedAdapter)\" 1000baseT full-duplex 2>/dev/null || true",
            "sudo networksetup -setdnsservers \"\(selectedAdapter)\" 1.1.1.1 8.8.8.8",
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
}
