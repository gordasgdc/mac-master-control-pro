import Foundation
import MacMasterControlProCore

// Baseline de scanare disc: `mcsp-bench <folder> [cancel-ms]`. Nu scrie in folder.
// Masoara: timp pana la primul progres, timp total, memorie maxima (RSS), anulare.
func rssMB() -> Double {
    var u = rusage(); getrusage(RUSAGE_SELF, &u)
    return Double(u.ru_maxrss) / 1_048_576  // macOS: octeti
}
func runLoop(until done: () -> Bool, timeout: TimeInterval = 3600) {
    let end = Date().addingTimeInterval(timeout)
    while !done() && Date() < end { RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.01)) }
}
let args = CommandLine.arguments
guard args.count >= 2 else { print("usage: mcsp-bench <folder> [cancel-ms]"); exit(2) }
let root = args[1]
let t0 = Date()
var firstProgress: TimeInterval?
var finished = false
var tree: DiskTreeNode?
if args.count >= 3, let ms = Int(args[2]), !args[2].hasPrefix("--") {
    DiskScanEngine.buildTree(root: root, onProgress: { _ in }, completion: { t, _ in tree = t; finished = true })
    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(ms)) { DiskScanEngine.requestCancel() }
    let c0 = Date()
    runLoop(until: { finished })
    let total = Date().timeIntervalSince(c0)
    print(String(format: "cancel@%dms -> stopped after %.3fs total (cancel latency %.3fs)", ms, total, total - Double(ms) / 1000))
    exit(0)
}
DiskScanEngine.buildTree(root: root, onProgress: { _ in if firstProgress == nil { firstProgress = Date().timeIntervalSince(t0) } },
                         completion: { t, _ in tree = t; finished = true })
runLoop(until: { finished })
let full = Date().timeIntervalSince(t0)
guard let t = tree else { print("no tree"); exit(1) }
print(String(format: "full: %.2fs  firstProgress: %@  files: %d  bytes: %lld  peakRSS: %.0f MB",
             full, firstProgress.map { String(format: "%.2fs", $0) } ?? "n/a", t.totalFileCount, t.sizeBytes, rssMB()))
finished = false; var t2: DiskTreeNode?
let i0 = Date()
let quick = CommandLine.arguments.contains("--quick")
DiskScanEngine.incrementalUpdate(cachedRoot: t, mode: quick ? .structureOnly : .verified, onProgress: { _ in }, completion: { x, _ in t2 = x; finished = true })
runLoop(until: { finished })
print(String(format: "incremental[\(quick ? "structureOnly" : "verified")](no change): %.2fs  size: %lld  peakRSS: %.0f MB", Date().timeIntervalSince(i0), t2?.sizeBytes ?? -1, rssMB()))
