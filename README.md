# Master Control Studio Pro

Panou nativ SwiftUI pentru macOS — conversie a scriptului `Mac_Master_Control.sh`
într-o aplicație completă de tuning sistem, Cloud Manager universal, curățare
cache media și Rosetta Inspector.

**Descarcă**: [gordas.dev/mac-master-control-pro](https://gordas.dev/mac-master-control-pro/) · [Releases](https://github.com/gordasgdc/mac-master-control-pro/releases/latest)

## Module

- 🌐 **Rețea** — tuning Gigabit/TCP la un click
- ☁️ **Cloud Manager** — Google Drive, Dropbox, OneDrive, pCloud, Degoo, Mega, S3, WebDAV, SFTP, FTP (motor Rclone)
- 🧹 **Curățare & RAM** — cache DaVinci/Adobe, Time Machine Snapshots, purjare RAM
- 🛠️ **Tweak-uri Sistem** — Finder avansat, Touch ID sudo, Spotlight Shield
- 🧭 **Rosetta 2 Inspector** — scanare aplicații Intel, eliminare Rosetta
- 🧩 **Dependency Auto-Installer** — Homebrew/Rclone/macFUSE

Trial nelimitat pentru analize; acțiunile de scriere necesită o licență
Lifetime (9€, donație unică de susținere).

## Build local

```bash
swift build -c release
```

Pachet complet de release (`.pkg` semnat + notarizat + stapled):

```bash
./build_installer.sh
```
