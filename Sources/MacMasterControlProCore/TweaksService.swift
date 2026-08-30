import Foundation

/// O locatie (volum extern sau folder ales manual) gestionata de Spotlight
/// Shield — vezi "Manager de Discuri & Foldere Multi-Select", regula
/// globala de multi-selectie (2026-08-30).
public struct SpotlightTarget: Identifiable, Hashable {
    public var id: String { path }
    public let name: String
    public let path: String
    public let isVolume: Bool
}

/// Mapeaza 1:1 pe menu_system_tweaks din Mac_Master_Control.sh.
public final class TweaksService: ObservableObject {
    @Published public var spotlightTargets: [SpotlightTarget] = []
    /// Bifa = protejat (fisier `.metadata_never_index` prezent) - citita
    /// direct de pe disc la fiecare scanare, nu presupusa din persistenta.
    @Published public var protectedPaths: Set<String> = []

    private static let customFoldersKey = "mmc.spotlightShield.customFolders"

    public init() {}

    /// Toate 4 sunt scrieri in domeniul utilizatorului sau fisiere pe SSD-uri
    /// proprii - fara sudo, cu exceptia Touch ID (fisier sub /etc).
    public func enableFinderAdvancedView() {
        Shell.run("defaults write com.apple.finder AppleShowAllExtensions -bool true")
        Shell.run("chflags nohidden ~/Library")
        Shell.run("defaults write com.apple.finder ShowPathbar -bool true")
        Shell.run("defaults write com.apple.finder ShowStatusBar -bool true")
        Shell.run("defaults write com.apple.finder FXPreferredViewStyle -string Nlsv")
        Shell.run("killall Finder")
    }

    public func blockDSStoreOnExternalVolumes() {
        Shell.run("defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true")
        Shell.run("defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true")
    }

    public func enableTouchIDForSudo() {
        PrivilegedRunner.run([
            "test -f /etc/pam.d/sudo_local || cp /etc/pam.d/sudo_local.template /etc/pam.d/sudo_local",
            "sed -i '' 's/#auth       sufficient     pam_tid.so/auth       sufficient     pam_tid.so/g' /etc/pam.d/sudo_local"
        ])
    }

    // MARK: - Spotlight Shield (Manager Multi-Select)

    /// Rescaneaza `/Volumes/*` (discuri externe conectate acum, exclus
    /// volumul de boot) + folderele custom adaugate manual (persistate),
    /// si recitesc starea reala de protectie de pe disc pentru fiecare.
    public func scanSpotlightTargets() {
        var targets: [SpotlightTarget] = []

        if let volumes = try? FileManager.default.contentsOfDirectory(atPath: "/Volumes") {
            for name in volumes.sorted() {
                let path = "/Volumes/\(name)"
                // Volumul de boot apare in /Volumes ca legatura catre "/" -
                // il excludem, Spotlight Shield vizeaza doar discuri externe.
                if (try? URL(fileURLWithPath: path).resourceValues(forKeys: [.volumeUUIDStringKey]))?.volumeUUIDString
                    == (try? URL(fileURLWithPath: "/").resourceValues(forKeys: [.volumeUUIDStringKey]))?.volumeUUIDString {
                    continue
                }
                targets.append(SpotlightTarget(name: name, path: path, isVolume: true))
            }
        }

        for path in customFolders() {
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else { continue }
            targets.append(SpotlightTarget(name: URL(fileURLWithPath: path).lastPathComponent, path: path, isVolume: false))
        }

        spotlightTargets = targets
        protectedPaths = Set(targets.filter { isProtected($0.path) }.map(\.path))
    }

    /// Adauga mai multe foldere deodata (Multi-Select NSOpenPanel in UI).
    public func addCustomFolders(_ paths: [String]) {
        var stored = customFolders()
        for path in paths where !stored.contains(path) { stored.append(path) }
        UserDefaults.standard.set(stored, forKey: Self.customFoldersKey)
        scanSpotlightTargets()
    }

    public func removeCustomFolder(_ path: String) {
        var stored = customFolders()
        stored.removeAll { $0 == path }
        UserDefaults.standard.set(stored, forKey: Self.customFoldersKey)
        setProtected(path, false)
        scanSpotlightTargets()
    }

    private func customFolders() -> [String] {
        UserDefaults.standard.stringArray(forKey: Self.customFoldersKey) ?? []
    }

    public func isProtected(_ path: String) -> Bool {
        FileManager.default.fileExists(atPath: path + "/.metadata_never_index")
    }

    @discardableResult
    public func setProtected(_ path: String, _ protect: Bool) -> Bool {
        let markerPath = path + "/.metadata_never_index"
        let ok: Bool
        if protect {
            ok = FileManager.default.createFile(atPath: markerPath, contents: nil)
        } else {
            ok = (try? FileManager.default.removeItem(atPath: markerPath)) != nil || !FileManager.default.fileExists(atPath: markerPath)
        }
        if ok {
            if protect { protectedPaths.insert(path) } else { protectedPaths.remove(path) }
        }
        return ok
    }

    /// Aplica protectia pe exact setul bifat (Bara de Actiune in Masa) -
    /// dezactiveaza restul, la fel ca modulele Curatare/Rosetta.
    public func applyProtection(selected: Set<String>) {
        for target in spotlightTargets {
            setProtected(target.path, selected.contains(target.path))
        }
    }
}
