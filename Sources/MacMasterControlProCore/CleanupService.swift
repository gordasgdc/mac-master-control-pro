import Foundation

/// Mapeaza 1:1 pe menu_cleanup din Mac_Master_Control.sh.
public final class CleanupService: ObservableObject {
    public init() {}

    @Published public var lastReport: String = ""

    /// Scanare libera (permisa in Trial) - calculeaza GB recuperabile fara sa stearga nimic.
    public func scanReclaimable() -> String {
        let paths = [
            NSHomeDirectory() + "/Library/Developer/Xcode/DerivedData",
            NSHomeDirectory() + "/Library/Caches",
            NSHomeDirectory() + "/Library/Application Support/Adobe/Common/Media Cache Files",
            NSHomeDirectory() + "/Library/Application Support/Blackmagic Design/DaVinci Resolve/CacheClip"
        ]
        var totalBytes: Int64 = 0
        var lines: [String] = []
        for path in paths {
            let sizeKB = Shell.run("du -sk \"\(path)\" 2>/dev/null | cut -f1")
            let kb = Int64(sizeKB) ?? 0
            totalBytes += kb * 1024
            let gb = Double(kb) / 1024.0 / 1024.0
            lines.append(String(format: "• %@: %.2f GB", (path as NSString).lastPathComponent, gb))
        }
        let totalGB = Double(totalBytes) / 1024.0 / 1024.0 / 1024.0
        lines.insert(String(format: "Total recuperabil: %.2f GB", totalGB), at: 0)
        lastReport = lines.joined(separator: "\n")
        return lastReport
    }

    /// Actiune reala - fisiere proprii utilizatorului, fara sudo.
    public func cleanDevAndSystemCaches() {
        Shell.run("rm -rf ~/Library/Developer/Xcode/DerivedData/* 2>/dev/null")
        Shell.run("rm -rf ~/Library/Caches/* 2>/dev/null")
        Shell.run("rm -rf ~/Library/Logs/* 2>/dev/null")
    }

    public func cleanMediaCaches() {
        Shell.run("rm -rf ~/Library/Application\\ Support/Adobe/Common/Media\\ Cache\\ Files/* 2>/dev/null")
        Shell.run("rm -rf ~/Library/Application\\ Support/Blackmagic\\ Design/DaVinci\\ Resolve/CacheClip/* 2>/dev/null")
    }

    /// tmutil are nevoie de sudo.
    public func deleteTimeMachineSnapshots() {
        PrivilegedRunner.run("for d in $(tmutil listlocalsnapshotdates | grep '-'); do tmutil deletelocalsnapshots \"$d\"; done")
    }

    public func purgeRAMAndFlushDNS() {
        PrivilegedRunner.run(["dscacheutil -flushcache", "killall -HUP mDNSResponder", "purge"])
    }

    public func fullClean() {
        cleanDevAndSystemCaches()
        cleanMediaCaches()
        deleteTimeMachineSnapshots()
        purgeRAMAndFlushDNS()
    }
}
