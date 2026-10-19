import XCTest
@testable import MacMasterControlProCore

/// Probă cu dialogul REAL macOS (nu stub), pe fixture-uri sacrificabile din directoare doar-citire (Coșul eșuează, `rm` ca root reușește).
/// Se rulează DOAR explicit: `MCSP_REAL_DIALOG=1 MCSP_FIXTURE_ROOT=<folder extern> MCSP_REAL_DIALOG_OUT=<fișier> swift test --filter PrivilegeRealDialogTests`.
/// Două scenarii consecutive, cu semnal sonor + notificare înainte de fiecare dialog: (1) CONFIRMARE (utilizatorul introduce parola), (2) ANULARE (utilizatorul apasă Anulează).
/// Rezultatele (număr de solicitări, rezultat per element, existența fișierelor) se scriu în fișierul de ieșire; parola nu e văzută de cod.
final class PrivilegeRealDialogTests: XCTestCase {
    private func cue(_ text: String) {
        _ = try? Process.run(URL(fileURLWithPath: "/usr/bin/afplay"), arguments: ["/System/Library/Sounds/Glass.aiff"])
        _ = try? Process.run(URL(fileURLWithPath: "/usr/bin/osascript"), arguments: ["-e", "display notification \"\(text)\" with title \"Probă plan privilegiat\""])
        Thread.sleep(forTimeInterval: 6)
    }
    private func fixture(_ root: URL, _ name: String, _ n: Int) throws -> (URL, [String]) {
        let d = root.appendingPathComponent("privreal-\(name)-\(UUID().uuidString.prefix(6))", isDirectory: true)
        let locked = d.appendingPathComponent("locked", isDirectory: true)
        try FileManager.default.createDirectory(at: locked, withIntermediateDirectories: true)
        let files = (0..<n).map { locked.appendingPathComponent("sacrificial-\($0).bin").path }
        for f in files { try Data(count: 1000).write(to: URL(fileURLWithPath: f)) }
        chmod(locked.path, 0o555)   // utilizatorul nu mai poate șterge/muta fișierele; root poate
        return (d, files)
    }
    private func cleanup(_ d: URL) {
        chmod(d.appendingPathComponent("locked").path, 0o755); try? FileManager.default.removeItem(at: d)
    }

    func testRealDialogConfirmThenCancel() throws {
        let env = ProcessInfo.processInfo.environment
        try XCTSkipUnless(env["MCSP_REAL_DIALOG"] == "1", "probă manuală cu dialog real: setează MCSP_REAL_DIALOG=1")
        let root = URL(fileURLWithPath: try XCTUnwrap(env["MCSP_FIXTURE_ROOT"]))
        let out = try XCTUnwrap(env["MCSP_REAL_DIALOG_OUT"])
        PrivilegedPlan.approver = { _, _ in true }   // fereastra proprie de confirmare e verificată separat; aici contează dialogul de sistem
        var report: [String: Any] = ["note": "dialog real macOS (osascript, with administrator privileges); NU stub", "date": ISO8601DateFormatter().string(from: Date())]

        // 1) CONFIRMARE
        let (d1, f1) = try fixture(root, "confirm", 3); defer { cleanup(d1) }
        XCTAssertTrue(f1.allSatisfy { !FileManager.default.isDeletableFile(atPath: $0) }, "fixture trebuie să fie nedeletabile de utilizator")
        cue("Dialogul 1 de 2: CONFIRMĂ (introdu parola)"); _ = try? Process.run(URL(fileURLWithPath: "/usr/bin/osascript"), arguments: ["-e", "display notification \"Dialogul 1 de 2 se deschide ACUM: introdu parola\" with title \"Probă\""])
        let c0 = PrivilegedRunner.promptCount
        let t1 = Date(); let b1 = PrivilegedFileOps.deleteBatch(f1); let e1 = Int(Date().timeIntervalSince(t1) * 1000)
        report["confirm"] = ["elapsedMs": e1, "prompts": PrivilegedRunner.promptCount - c0, "cancelled": b1.cancelled,
                             "perItem": f1.map { ["path": ($0 as NSString).lastPathComponent, "error": (b1.results[$0] ?? nil) ?? "OK", "stillExists": FileManager.default.fileExists(atPath: $0)] }]

        // 2) ANULARE
        let (d2, f2) = try fixture(root, "cancel", 3); defer { cleanup(d2) }
        cue("Dialogul 2 de 2: ANULEAZĂ (apasă Anulează)")
        let c1 = PrivilegedRunner.promptCount
        let t2 = Date(); let b2 = PrivilegedFileOps.deleteBatch(f2); let e2 = Int(Date().timeIntervalSince(t2) * 1000)
        report["cancel"] = ["elapsedMs": e2, "prompts": PrivilegedRunner.promptCount - c1, "cancelled": b2.cancelled,
                            "perItem": f2.map { ["path": ($0 as NSString).lastPathComponent, "error": (b2.results[$0] ?? nil) ?? "OK", "stillExists": FileManager.default.fileExists(atPath: $0)] }]
        try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]).write(to: URL(fileURLWithPath: out))
    }
}
