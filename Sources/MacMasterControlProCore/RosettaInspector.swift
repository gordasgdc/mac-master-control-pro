import Foundation

public struct IntelApp: Identifiable, Hashable {
    public var id: String { path }
    public let name: String
    public let path: String
}

/// Modul D: scanare arhitectura + stare Rosetta 2 + curatare optionala.
public final class RosettaInspector: ObservableObject {
    public init() {}

    @Published public var intelApps: [IntelApp] = []
    @Published public var rosettaInstalled: Bool = false

    /// Scanare libera (Trial) - citeste doar, nu modifica nimic.
    public func scan() {
        rosettaInstalled = checkRosettaInstalled()
        intelApps = scanApplicationsFolder()
    }

    private func checkRosettaInstalled() -> Bool {
        // Rosetta traduce transparent - daca reuseste sa execute un binar
        // x86_64, e instalata. Codul de iesire 0 => prezenta.
        let result = Shell.run("arch -x86_64 /usr/bin/true >/dev/null 2>&1; echo $?")
        return result.trimmingCharacters(in: .whitespacesAndNewlines) == "0"
    }

    private func scanApplicationsFolder() -> [IntelApp] {
        var results: [IntelApp] = []
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(atPath: "/Applications") else { return results }
        for item in items where item.hasSuffix(".app") {
            let appPath = "/Applications/" + item
            let execName = (item as NSString).deletingPathExtension
            let binaryPath = appPath + "/Contents/MacOS/" + execName
            guard fm.fileExists(atPath: binaryPath) else { continue }
            let archs = Shell.run("lipo -archs \"\(binaryPath)\" 2>/dev/null")
            // arm64 lipseste => necesita Rosetta pentru a rula pe Apple Silicon.
            if archs.contains("x86_64") && !archs.contains("arm64") {
                results.append(IntelApp(name: execName, path: appPath))
            }
        }
        return results.sorted { $0.name < $1.name }
    }

    /// Actiune distructiva, needocumentata oficial de Apple (fara uninstaller
    /// suportat) - necesita licenta activata SI confirmare separata in UI
    /// inainte de a fi apelata. Nu rula daca mai exista aplicatii Intel active.
    public func removeRosetta() {
        PrivilegedRunner.run([
            "launchctl remove com.apple.oahd 2>/dev/null || true",
            "rm -rf /Library/Apple/usr/share/rosetta 2>/dev/null || true"
        ])
    }

    /// Trimite la Cosul de gunoi DOAR aplicatiile bifate de utilizator -
    /// dezinstalare reala, selectiva (nu "totul sau nimic").
    @discardableResult
    public func moveToTrash(_ selected: Set<IntelApp>) -> Int {
        var moved = 0
        for app in selected {
            let url = URL(fileURLWithPath: app.path)
            if (try? FileManager.default.trashItem(at: url, resultingItemURL: nil)) != nil {
                moved += 1
            }
        }
        scan()
        return moved
    }
}
