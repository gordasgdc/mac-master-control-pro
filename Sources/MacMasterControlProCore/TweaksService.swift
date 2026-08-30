import Foundation

/// Mapeaza 1:1 pe menu_system_tweaks din Mac_Master_Control.sh.
public final class TweaksService: ObservableObject {
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

    /// folderPath vine din drag&drop / NSOpenPanel in UI.
    public func protectFromSpotlight(folderPath: String) -> Bool {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: folderPath, isDirectory: &isDir), isDir.boolValue else {
            return false
        }
        return FileManager.default.createFile(atPath: folderPath + "/.metadata_never_index", contents: nil)
    }
}
