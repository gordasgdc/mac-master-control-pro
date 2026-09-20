import Foundation
import AppKit

/// Dezinstalare curată din interiorul aplicației (standard global GDC,
/// Regula 45): șterge datele locale, apoi mută aplicația la Coș.
public enum SelfUninstaller {
    public static let bundleID = "com.gordasgdc.macmastercontrolpro"
    public static let appName = "MacMasterControlPro"

    /// Căile de date ale utilizatorului — public, ca să poată fi testate.
    public static func dataPaths(home: String = NSHomeDirectory()) -> [String] {
        let lib = home + "/Library"
        return [
            "\(lib)/Application Support/\(appName)",
            "\(lib)/Preferences/\(bundleID).plist",
            "\(lib)/Caches/\(bundleID)",
            "\(lib)/Caches/\(appName)",
            "\(lib)/Logs/\(appName)",
            "\(lib)/Logs/\(appName).log",
            "\(lib)/Saved Application State/\(bundleID).savedState",
            "\(lib)/HTTPStorages/\(bundleID)",
            "\(lib)/WebKit/\(bundleID)",
        ]
    }

    /// Șterge datele; întoarce căile care n-au putut fi șterse.
    @discardableResult
    public static func removeUserData() -> [String] {
        UserDefaults.standard.removePersistentDomain(forName: bundleID)
        UserDefaults.standard.synchronize()
        var failed: [String] = []
        for path in dataPaths() where FileManager.default.fileExists(atPath: path) {
            do { try FileManager.default.removeItem(atPath: path) }
            catch { failed.append(path) }
        }
        return failed
    }

    /// Mută aplicația la Coș (Finder cere parola dacă instalarea e a root),
    /// re-șterge preferințele după ieșire (cfprefsd le poate rescrie) și închide.
    public static func trashAppAndQuit() {
        let appURL = Bundle.main.bundleURL
        let plist = NSHomeDirectory() + "/Library/Preferences/\(bundleID).plist"
        let finish = {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/bin/sh")
            task.arguments = ["-c", "sleep 2; rm -f \"\(plist)\"; killall cfprefsd 2>/dev/null; true"]
            try? task.run()
            NSApp.terminate(nil)
        }
        NSWorkspace.shared.recycle([appURL]) { _, error in
            DispatchQueue.main.async {
                if error != nil {
                    let src = "tell application \"Finder\" to delete POSIX file \"\(appURL.path)\""
                    var err: NSDictionary?
                    NSAppleScript(source: src)?.executeAndReturnError(&err)
                }
                finish()
            }
        }
    }
}
