# Changelog — Master Control Studio Pro

## v2.0.0 (2026-08-30)
**Rebranding** (MAJOR, Regula 14): "Mac Master Control Pro" → "Master
Control Studio Pro" — nume neutru, pregătit pentru lansarea viitoare pe
Windows. Actualizat peste tot: UI SwiftUI (titlu fereastră, About, alerte
update), `Info.plist` (CFBundleName/DisplayName), landing page, ghidul PDF
RO/EN/ES, panoul Furnizor (`GenerateSerialView.swift`) și `catalog.json`
(Client). `productID` tehnic (`mac-master-control-pro`), identificatorul
de bundle, numele repo-ului GitHub și numele fișierelor `.pkg`/`.zip`
rămân neschimbate (schimbare cosmetică, nu structurală) — codurile de
licență deja generate rămân valide.

## v1.0.0 (2026-08-30)
Lansare inițială — conversie completă a `Mac_Master_Control.sh` în aplicație nativă SwiftUI:
- **Rețea**: tuning Gigabit/TCP kernel la un click.
- **Cloud Manager Universal**: Google Drive, Dropbox, OneDrive, pCloud, Degoo, Mega, S3, WebDAV, SFTP, FTP — wizard vizual, Chunker opțional, mount/unmount pe Desktop.
- **Curățare & RAM**: analiză spațiu recuperabil, cache DaVinci/Adobe, Time Machine Snapshots, purjare RAM + flush DNS.
- **Tweak-uri Sistem**: Finder avansat, blocare `.DS_Store` USB/NAS, Touch ID pentru sudo, Spotlight Shield.
- **Rosetta 2 Inspector**: scanare `/Applications`, stare Rosetta, eliminare cu confirmare.
- **Dependency Auto-Installer**: Homebrew/Rclone/macFUSE, status live + instalare automată.
- **Sidebar Footer**: profil (Nume/Email), Machine ID cu copy, versiune, Caută Actualizări.
- **Self-Updater** (Regula 20): descarcă și instalează `.pkg` prin prompt nativ de parolă, fără browser.
- Temă System/Light/Dark + Mărime Text (Regula 18/24).
- Trial nelimitat pentru analize; acțiunile de scriere cer licență Lifetime (9€, donație).
- Landing page: `gordas.dev/mac-master-control-pro/`.
