# Changelog — Master Control Studio Pro

## v2.3.1 (2026-08-30) — FIX: „Adaugă cont Cloud” eșua cu „rclone: No such file or directory”

**Bug real, raportat de Cristi**: `.app` lansat din Finder/Dock moștenește un
PATH minimal (`/usr/bin:/bin:/usr/sbin:/sbin`), fără `/opt/homebrew/bin`
(unde Homebrew instalează rclone) — `Shell.swift` și procesul separat din
`createRemote` (Cloud Manager) invocau `rclone` ca nume simplu, negăsibil pe
acel PATH, deși dependența era corect detectată ca instalată (verificarea
foloseşte o cale absolută către `brew`, diferit de restul comenzilor).
Fix: PATH augmentat explicit cu `/opt/homebrew/bin:/usr/local/bin` pe orice
proces pornit din aplicație.

## v2.3.0 (2026-08-30)
**Standard Global de Multi-Selecție** — extins peste v2.2.0 la modulele rămase:
- **Spotlight Shield (Tweak-uri Sistem)**: pickerul cu un singur folder a devenit un manager cu listare automată `/Volumes/*` (discuri externe) + foldere adăugate multiplu (`NSOpenPanel` multi-select), fiecare cu bifă proprie ("protejat"/"neprotejat"), Selectează/Deselectează tot, contor „Protejate X din Y".
- **Rețea**: plăcile de rețea detectate apar acum cu bifă individuală (nu doar un adaptor hardcodat); Tuning Gigabit/DNS/TCP se aplică pe toate plăcile bifate simultan.
- **Cloud Manager**: conturile configurate au bifă proprie, Selectează/Deselectează tot, „Montează selecția"/„Demontează selecția" acționează pe toate conturile bifate deodată.

## v2.2.0 (2026-08-30)
**Selecție granulară** (checkbox-uri per element) în locul acțiunilor "totul sau nimic":
- **Curățare & RAM**: fiecare cache (DerivedData/Caches/Adobe/DaVinci) și fiecare snapshot Time Machine are bifă proprie, Selectează/Deselectează tot, contor live „X GB din Y GB" / „X din Y snapshots", butonul de ștergere acționează DOAR pe elementele bifate.
- **Rosetta Inspector**: fiecare aplicație Intel are bifă; nou — „Trimite la Coș aplicațiile selectate" (dezinstalare reală, selectivă, restaurabilă din Coșul de gunoi), separat de eliminarea globală a Rosetta.
- **Tweak-uri Sistem**: Finder avansat + blocare .DS_Store convertite în listă cu bife + „Aplică tweak-urile selectate".
- Toate butoanele de acțiune sunt dezactivate când nu e bifat niciun element.

## v2.1.0 (2026-08-30)
- **Buton „Activează Licența" persistent** în Sidebar Footer (badge Pro/Trial apăsabil oricând, nu doar declanșat de teasing).
- **Contact WhatsApp** în modala de activare (`WhatsAppLink.swift`, port 1:1 din GDCVault/DataMover) — mesaj pre-completat cu numele aplicației și Machine ID.
- Localizare RO/EN/ES completată pentru cele două stringuri noi.

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
