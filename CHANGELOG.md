# Changelog — Master Control Studio Pro

## v2.15.0 (2026-08-31) — Dashboard cu status verde/roșu per modul

Ecranul principal arată acum carduri cu starea reală a modulelor cheie
(Securitate, Tuning rețea persistent, Dependențe) — verde/roșu vizibil
FĂRĂ să intri în fiecare modul. Click pe orice card te duce direct acolo.

## v2.14.0 (2026-08-31) — Modul nou: Monitor Procese

Vezi ce consumă CPU/RAM chiar acum (top 20, auto-actualizat la 3s) și
închide direct un proces blocat — SIGTERM întâi, SIGKILL doar dacă
insistă. Complementar „Aplicații de fundal la pornire" (Login Items).

## v2.13.0 (2026-08-31) — Curățare extinsă: Coș de gunoi, Mail, backup-uri iOS + Găsitor fișiere mari

Categorii noi de curățare (tip CleanMyMac): Coșul de gunoi, atașamente
Mail descărcate, backup-uri iOS orfane (MobileSync). Plus modul nou
„Fișiere mari" — scanează Downloads/Desktop/Documents/Movies și arată top
100 fișiere peste 200 MB, cu ștergere selectivă (Coș de gunoi, reversibil).

## v2.12.0 (2026-08-31) — Modul nou: Securitate & Confidențialitate

Verificări 🔴/🟢 (FileVault, System Integrity Protection, Gatekeeper,
Firewall, XProtect, parolă la screensaver), plus 2 acțiuni sigure cu un
click: activare Firewall + Stealth Mode, cerere parolă imediată la
screensaver. Bazat pe recomandările din drduh/macOS-Security-and-Privacy-
Guide — doar verificările/acțiunile care nu riscă să blocheze Mac-ul.

## v2.11.0 (2026-08-31) — Modul nou: Dezinstalator complet

Șterge orice aplicație instalată (nu doar produse GDC) ÎMPREUNĂ cu toate
urmele ei — Application Support, Caches, Preferences, Saved Application
State, Logs, HTTPStorages, WebKit, Containers, Group Containers,
LaunchAgents/LaunchDaemons (userul curent + sistem). Fiecare categorie e
bifabilă separat, cu dimensiunea reală (MB), înainte de ștergere. Verifică
la final că aplicația chiar a dispărut din `/Applications`.

## v2.10.0 (2026-08-31) — Tuning de rețea persistent la pornire

Tuning-ul Gigabit/TCP se putea aplica doar manual, din aplicație, și
dispărea la fiecare repornire a Mac-ului (setările de kernel nu
supraviețuiesc unui restart). Nou: buton „Activează la pornire
(persistent)" — instalează un serviciu de sistem care reaplică automat
aceeași configurare la fiecare pornire, fără să mai deschizi aplicația.
Indicator 🔴/🟢 arată dacă tuning-ul e activ chiar acum, nu doar dacă a
fost activat cândva.

## v2.9.1 (2026-08-31) — Preț dinamic din Furnizor
Suma de donație din modalul de Trial + mesajul WhatsApp se citește acum
din `pricing.json` (Furnizor), nu mai e fixă în cod — orice ofertă
programată apare automat, fără recompilare.

## v2.9.0 (2026-08-31) — 7 module noi de optimizare workflow

Cerință directă: "ce mai pot introduce ca să fie o aplicație foarte
profesională de optimizare workflow?" — 7 funcționalități noi, alese din
lista propusă:
- **⚡️ Mod Randare** — oprește Time Machine + indexare Spotlight, ridică
  prioritatea DaVinci Resolve, un singur comutator, o singură parolă.
- **🔌 Pornire Sistem** — auditor servicii de fundal terțe, buton
  roșu/verde per element, reversibil.
- **💽 Sănătate Discuri** — spațiu liber, status SMART, test de viteză de
  scriere la cerere.
- **🎬 DaVinci Resolve** — Notificare la final de randare (+ opțional pe
  email, ca să ajungă și pe telefon) + Auditor Media Pool (clipuri
  offline/duplicate, prin Scripting API oficial) + Sincronizare LUT-uri/
  Fusion între stații prin Cloud Manager.
- **🪟 Layout Ferestre** — salvează/restaurează poziții de ferestre per
  aplicație (util pentru configurații multi-monitor diferite).

Toate testate live (Layout Ferestre confirmat funcțional cu TextEdit).
Port complet și pe Windows, aceeași versiune de funcționalități
(`mac-master-control-pro-win` v1.10.0).

## v2.8.0 (2026-08-30) — Upload Google Drive mult mai rapid + Setări performanță rclone

Cerință reală, apărută în timpul testării DataMover cu rclone: upload-uri
lente pe Google Drive. Cauza: Google limitează agresiv clientul OAuth
PARTAJAT al rclone-ului (același folosit de toți utilizatorii rclone din
lume), independent de conexiunea reală a userului.

- **Client OAuth Google Drive propriu, embedded** — orice cont Google
  Drive nou adăugat prin Cloud Manager (+ Adaugă cont) folosește acum
  automat clientul propriu GDC, nu mai pe cel partajat — clientul final NU
  trece prin niciun pas din Google Cloud Console. Măsurat direct: ~18x mai
  rapid (2.5 Mbit/s → ~47 Mbit/s), același cont, același fișier.
- **Secțiune nouă „Performanță rclone"** în Cloud Manager — Transferuri
  paralele, Verificări paralele (checkers), dimensiune fragment (chunk
  size), Listare rapidă (`--fast-list`) — reglabile, persistate, aplicate
  la Încărcare/Descărcare/Sincronizare.
- **Ghid PDF (RO/EN/ES)** — secțiune nouă opțională „Upload lent pe Google
  Drive?" cu pașii pentru cine vrea totuși propriul client Google
  (alternativă, nu obligatorie).
- **[Doar intern]** `GHID_INTERN_ONBOARDING_GOOGLE_DRIVE.md` — procedura
  exactă pentru Cristi la fiecare client nou (adăugare ca test user în
  Google Cloud Console, cât timp aplicația e în modul Testing).
- Pagina web (`docs/index.html`) — prețul fix (17€) scos din text.

## v2.7.2 (2026-08-30) — FIX REAL: „Explorează” tot nu se redimensiona

Raportat de Cristi după v2.7.1: fereastra rămânea "tot la o dimensiune așa
îngustă", oricât trăgea de margine. Cauza reală: pe un `.sheet` macOS,
fereastra devine efectiv redimensionabilă doar dacă frame-ul exterior
specifică explicit `maxWidth`/`maxHeight` ca `.infinity` — fix-ul din
v2.7.1 seta doar `minWidth`/`idealWidth`, fără `maxWidth`, iar SwiftUI
trata `idealWidth` ca plafon real. Adăugat `maxWidth: .infinity,
maxHeight: .infinity` pe frame-ul `RemoteBrowserSheet` — acum se trage
liber de margine, de la 560×420 în sus.

## v2.7.1 (2026-08-30) — Fereastra „Explorează” redimensionabilă

Fereastra de explorare Cloud (`RemoteBrowserSheet`) era prea mică pentru
liste lungi de fișiere — mărită implicit (780×560) și complet
redimensionabilă, ca userul s-o adapteze după nevoie.

## v2.7.0 (2026-08-30) — Faza 4: Upload / Download / Sincronizare + Ghid PDF complet + Landing page

- **Faza 4 — Cloud Manager, sistem complet de lucru cu fișiere**: din fereastra „Explorează" — încărcare fișiere/foldere de pe Mac, descărcare selecție pe Mac, ștergere (cu confirmare explicită, ireversibilă), și sincronizare folder local ↔ cloud (implicit non-distructiv — doar adaugă/actualizează; „Oglindă exactă" e opțională, explicit bifată, pentru sincronizare cu ștergere).
- **Ghid PDF (RO/EN/ES) rescris** — secțiune nouă dedicată „Cloud Manager — Ghid Complet”: setup cont, montare + locație externă, statistici live, explorare, upload/download/ștergere, sincronizare.
- **Landing page**: secțiune nouă, vizibilă, care expune că motorul e Rclone (open-source, folosit de zeci de mii de proiecte) — interfață 100% nativă, fără linie de comandă.

## v2.6.0 (2026-08-30) — Fazele 2+3: Statistici live + Explorare remote fără montare

- **Faza 2**: fiecare cont montat afișează acum viteza de transfer live,
  bytes transferați și transferuri active (`rclone rc core/stats`, port RC
  unic per montare — port comun ar fi amestecat statisticile mai multor
  conturi montate simultan).
- **Faza 3**: buton „Explorează" — răsfoiește conținutul unui cont Cloud
  (`rclone lsjson`) FĂRĂ să-l montezi, cu navigare pe foldere. Buton
  „Deschide" pe conturile montate — deschide direct în Finder.
- Cloud Manager complet: alegere locație de montare (v2.5.0), statistici
  live, explorare fără montare — toate în stilul nativ al aplicației.

## v2.5.0 (2026-08-30) — Faza 1: Locație de montare configurabilă (disc extern)

Cloud Manager permite acum alegerea folderului unde se montează conturile
(implicit `~/Desktop`) — util pentru discuri externe Thunderbolt/USB-C, ca
să nu se ocupe spațiu pe SSD-ul intern (adesea mic pe Mac). Dacă folderul
configurat nu mai există la momentul montării (disc extern deconectat),
aplicația cade automat pe Desktop, cu avertisment în panoul Terminal Live —
niciodată eșec silențios. Progresul de montare/demontare apare acum linie
cu linie în Terminal Live (Regula 26).

## v2.4.1 (2026-08-30) — Donație actualizată la 17€

Decizie Cristi: rămâne un singur nivel de licențiere (fără Standard/Pro
separate) — doar suma de referință a donației Lifetime crește de la 9€ la
17€. Actualizat în UI (`TrialGateModal`), mesajul WhatsApp de activare,
ghidurile PDF (RO/EN/ES) și landing page.

## v2.4.0 (2026-08-30) — Panou „terminal live” + butoane roșu/verde la Dependențe

Standard nou, cerut explicit de Cristi (devine Regula 26 GDC, propagată în
tot ecosistemul): instalarea în masă ("Instalează tot ce lipsește") poate
bloca sistemul — orice componentă instalabilă are acum **butonul ei propriu**
(roșu = neinstalat, verde = instalat), niciodată un bulk install automat.

- **`TerminalLogView`** — panou reutilizabil tip terminal (fundal negru,
  text monospace verde, auto-scroll), afișează linie cu linie orice comandă
  externă rulată (instalare, ștergere fișiere) — fără el, „Șterge cache-ul"
  părea că nu face nimic (bug real raportat, catch-ul original ascundea
  orice eroare silențios).
- **Dependențe**: fiecare pachet instalabil (Rclone, macFUSE) are propriul
  buton — Homebrew păstrează fluxul separat prin Terminal.app (interactiv).
- **Curățare & RAM**: ștergerea afișează acum progresul real (fișier cu
  fișier) în panoul terminal, în loc de un mesaj static „✔ șterse".

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
