import Foundation

public struct RunningProcess: Identifiable, Hashable {
    public let id: Int32 // pid
    public let name: String
    public let cpuPercent: Double
    public let memoryMB: Double
}

/// Monitor de procese "grele" (tip CleanMyMac "Activity Monitor" +
/// MediaFlow Monitor `ProcessInspector`, portat aici la nivel de sistem
/// general, nu doar DaVinci Resolve). Doar `ps` — nu are nevoie de
/// privilegii pentru citire, doar la `kill -9` pe un proces al altui user.
public enum ProcessMonitorService {
    /// Top N procese dupa %CPU, excluzand kernel_task/procese cu PID sub 10
    /// (aproape mereu sistem, nu ceva ce un user vrea sa inchida).
    public static func topProcesses(limit: Int = 20) -> [RunningProcess] {
        let output = Shell.run("ps -A -o pid=,pcpu=,rss=,comm= | sort -rn -k2 | head -n \(limit)")
        return output.split(separator: "\n").compactMap { line -> RunningProcess? in
            let parts = line.split(separator: " ", maxSplits: 3, omittingEmptySubsequences: true)
            guard parts.count == 4,
                  let pid = Int32(parts[0]),
                  let cpu = Double(parts[1]),
                  let rssKB = Double(parts[2]),
                  pid > 10 else { return nil }
            let name = (String(parts[3]) as NSString).lastPathComponent
            return RunningProcess(id: pid, name: name, cpuPercent: cpu, memoryMB: rssKB / 1024.0)
        }
    }

    /// SIGTERM întâi (oprire curată), SIGKILL doar dacă procesul insistă —
    /// evită pierderea de date a unei aplicații care doar procesează ceva,
    /// nu e blocată.
    public static func terminate(pid: Int32, force: Bool) {
        Shell.run("kill \(force ? "-9" : "-15") \(pid) 2>/dev/null")
    }
}
