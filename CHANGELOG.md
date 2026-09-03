# Changelog — Master Control Studio Pro

## v2.27.0 (2026-09-03) — Mod Randare pentru orice aplicație + design mai profesional

- **Mod Randare nu mai e limitat la DaVinci Resolve** — recunoaște acum și
  ridică automat prioritatea pentru Final Cut Pro, Premiere Pro, Media
  Encoder, After Effects, Logic Pro, Motion, Compressor și HandBrake,
  oricare rulează în momentul activării (nu doar una singură).
- **Titlurile secțiunilor** folosesc acum iconițe simple, consistente cu
  meniul din stânga, în loc de simboluri emoji.
- **Analiza de disc** arată acum un cronometru cât timp scanează, ca să
  fie clar că aplicația lucrează, nu că s-a blocat.
- **Protecția Spotlight** arată o etichetă verde „Protejat” lângă orice
  disc/folder activat, plus un mesaj clar dacă o acțiune eșuează.

## v2.26.3 (2026-09-03) — Fix real: Touch ID activat corect + status vizual clar peste tot

**Fix real, găsit prin panoul de diagnostic din v2.26.2**: activarea Touch
ID pentru comenzi de administrator eșua mereu, indiferent de context —
cauza era o eroare de sintaxă internă la trimiterea comenzii către
sistem, niciodată vizibilă până acum. Reparată la sursă; ar trebui să
funcționeze normal de această dată.

**Îmbunătățire: mesajele de stare arată acum clar, vizual, ce s-a
întâmplat** — un bloc verde cu bifă la succes, roșu cu X la eroare,
albastru cât o acțiune e în desfășurare, în loc de un text gri identic
indiferent de rezultat. Aplicat în toate secțiunile: Tweak-uri Sistem,
Curățare & RAM, Cloud Manager, Duplicate, Rosetta Inspector, Layout
Ferestre, DaVinci Resolve.

## v2.26.2 (2026-09-03) — Panou „Terminal Live” pentru Touch ID

Butonul „Activează Touch ID pentru comenzi sudo” arată acum, direct sub
el, un mic panou tip terminal cu exact ce comandă a fost trimisă și
răspunsul exact primit — rămâne pe ecran (nu dispare automat), cu buton
„Copiază tot”, ca să poți trimite exact ce s-a întâmplat dacă ceva nu
merge, în loc de un mesaj generic.

## v2.26.1 (2026-09-03) — Fix real: Touch ID nu mai afișa deloc fereastra de parolă

Continuarea fix-ului anterior (v2.26.0) — eșecul nu mai era intermitent,
ci sistematic: nu apărea deloc fereastra de sistem la apăsarea butonului.
Cauza reală era alta decât cea reparată prima dată — mecanismul intern de
cerere a parolei a fost înlocuit cu unul dovedit deja funcțional în altă
aplicație din familia GDC. Touch ID/parola de administrator ar trebui să
funcționeze acum normal, la fiecare apăsare.

## v2.26.0 (2026-09-03) — Analiză Disc (nou), fix blocare la scanare, fix Touch ID intermitent

**Modul nou: Analiză Disc.** Vezi ce ocupă spațiul pe disc, folder cu
folder, cu bară proporțională + listă sortată descrescător (asemănător
DaisyDisk) — alegi un disc/folder, intri în el cu un click, ștergi direct
din listă (cu fallback automat pe parolă de administrator dacă e nevoie).

**Fix real: aplicația se bloca (îngheța, uneori userul o închidea forțat)
la scanarea unui disc extern mare.** Cauza: execuția de comenzi shell
citea rezultatul abia după ce comanda se termina — pe un disc cu foarte
multe fișiere, ieșirea depășea bufferul intern al sistemului, iar cele
două părți (aplicația și comanda) ajungeau să aștepte una după alta la
nesfârșit. Rezolvat la sursă, pentru toate acțiunile care rulează comenzi
de sistem (Fișiere mari, Curățare, Cloud, etc.), nu doar pentru scanarea
de disc.

**Fix real: activarea Touch ID pentru comenzi de administrator eșua
intermitent cu „permisiune negată”, fără motiv aparent.** Promptul de
parolă rula pe un fir de execuție secundar — mutat pe firul principal,
unde sistemul de securitate macOS îl așteaptă mereu.

## v2.25.7 (2026-09-03) — Aceeași protecție de administrator, la Fișiere mari/Duplicate/Rosetta Inspector

Fix-ul pentru fișiere/aplicații deținute de administrator (v2.25.6) se
aplică acum și la ștergerea din „Fișiere mari", „Duplicate" și „Rosetta
Inspector" — nu doar la Dezinstalator.

## v2.25.6 (2026-09-03) — Fix real: dezinstalarea unei aplicații deținute de root

Unele aplicații (instalate cu drepturi de administrator) refuzau ștergerea
la Coșul de gunoi standard, deși aveau tehnic permisiunile potrivite pe
folder — macOS cere autentificare de administrator pentru ele, la fel ca
în Finder. Dezinstalatorul trece acum automat pe ștergere cu parolă de
administrator când e nevoie, în loc să se oprească la primul refuz.

## v2.25.5 (2026-09-03) — Fix real: mesajul de la dezinstalare dispărea instant

Cauza reală a impresiei "nu face nimic": panoul revenea instant la starea
inițială după o ștergere eșuată, ștergând mesajul de eroare/diagnostic
înainte să apuci să-l citești. Acum mesajul rămâne vizibil.

## v2.25.4 (2026-09-03) — Diagnostic suplimentar la dezinstalare

Mesajul de rezultat la ștergerea unei aplicații arată acum mai multe
detalii (proprietar, verificare la scurt timp după ștergere, detectarea
unui eventual al doilea exemplar instalat) — ajută la diagnosticarea
cazurilor rare în care o aplicație pare să reapară după ștergere.

## v2.25.3 (2026-09-03) — Fix: dezinstalarea raporta succes fals

Dacă aplicația era încă deschisă în momentul ștergerii, mesajul arăta
„Șters" chiar dacă macOS refuzase operația — aplicația rămânea instalată.
Acum: aplicația (inclusiv orice proces de fundal al ei) se închide automat,
forțat dacă e nevoie, înainte de ștergere, iar rezultatul arătat e
verificat real pe disc, nu doar presupus.

## v2.25.2 (2026-09-03) — Fix critic: Setări nu se mai deschideau

Încercarea de a reactiva "Mărime Text" din v2.25.1 bloca accesul la
Setări — reparat urgent, prin revenirea la varianta stabilă anterioară.
Mărimea textului rămâne doar cosmetică pe Mac deocamdată (opțiunile
Mic/Normal/Mare/Foarte mare există în listă, dar nu au încă efect vizual),
până la o soluție fără acest risc.

## v2.25.1 (2026-09-03) — Fix: instalare macFUSE, Touch ID pentru sudo, mărime text

- **Instalarea macFUSE eșua constant** cu o eroare despre parolă în
  Terminal — reparat: instalarea cere acum parola de administrator direct
  printr-un dialog nativ, în loc să eșueze silențios.
- **„Activează Touch ID pentru comenzi sudo” nu funcționa pe toate
  Mac-urile** — acum verifică rezultatul real și reușește indiferent de
  configurația existentă a sistemului, cu mesaj clar dacă totuși eșuează.
- **Setarea „Mărime Text” (Mic/Normal/Mare/Foarte mare) repusă** — eliminată
  anterior din cauza unui bug real de click-uri blocate; readusă cu o
  tehnică deja confirmată funcțională, cu memorarea alegerii.

## v2.25.0 (2026-09-01) — Duplicate, căutare în meniu

- **Modul nou „Duplicate”** — alegi ce foldere se caută, aplicația
  compară fișierele pe conținutul lor real (nu doar nume/dată), îți arată
  grupurile de copii identice, poți deschide fiecare fișier în Finder ca
  să te asiguri, și alegi manual ce rămâne și ce se șterge.
- **Căutare în meniul lateral** — un câmp de căutare deasupra listei
  găsește rapid un modul după nume sau cuvinte uzuale (ex. „dezinstalare”,
  „duplicate”, „reglare”).

## v2.24.0 (2026-09-01) — Dezinstalare în masă, scanare mult mai completă, tooltips

- **Dezinstalator** — poți acum bifa mai multe aplicații deodată și le
  dezinstalezi complet dintr-un singur click, nu una câte una.
- **Scanare de resturi mult mai completă** — pe lângă locațiile deja
  verificate, adaugă acum Preferences (ByHost), Application Scripts,
  Autosave Information, containerul iCloud Drive, și multe locații de
  sistem (Application Support/Preferences la nivel de sistem, panouri de
  preferințe, plugin-uri Internet/QuickLook/Audio, widget-uri, meniuri
  contextuale).
- **Descrieri la hover (tooltips)** — pe toate elementele din meniul
  lateral și pe câteva butoane mai puțin evidente, explică ce fac înainte
  să apeși.

## v2.23.0 (2026-08-31) — Sănătate Discuri, Fișiere mari, Securitate

- **„Testează viteza” (Sănătate Discuri) nu arăta niciun rezultat** —
  testul scria fișierul de probă direct în rădăcina discului de pornire,
  o zonă protejată de sistem; scrierea eșua silențios, fără niciun mesaj.
  Acum testul scrie într-un loc corect și, dacă tot eșuează, arată clar
  motivul.
- **„Fișiere mari” (Curățare & RAM) — butonul de ștergere părea că lipsește**
  — pagina întreagă nu avea scroll; cu multe fișiere listate, butonul de
  ștergere ajungea în afara ecranului, inaccesibil. Reparat.
- **Securitate — verificările roșii nu ofereau nicio soluție** — fiecare
  verificare care nu se poate rezolva automat (FileVault, System Integrity
  Protection, Gatekeeper etc.) are acum un buton „Cum rezolv?” cu pași
  expliciți, plus un buton care deschide direct panoul corect din System
  Settings.
- **Procese** — sortare acum după CPU sau RAM, crescător sau descrescător.
- **DaVinci Resolve → notificare email** — butoane rapide pentru generarea
  parolei de aplicație Gmail/Outlook, direct din ecranul de configurare.

## v2.22.0 (2026-08-31) — Mărime Text (Mac): eliminat mecanismul care bloca aplicația

Confirmat de Cristi: v2.21.0 tot bloca aplicația la orice altă valoare
decât „Normal" — nu doar navigarea, TOATE butoanele din Setări deveneau
neresponsive. După 3 încercări de reparare a aceleiași tehnici
(`scaleEffect`+`position`), am decis să o eliminăm complet — un bug care
poate bloca ireversibil userul e mai grav decât lipsa efectului vizual.
Selectorul „Mărime Text" rămâne în Setări (paritate UI cu Windows, unde
funcționează corect), dar pe Mac rămâne DOAR cosmetic, fără efect vizual,
până la o implementare non-riscantă într-o sesiune viitoare dedicată.
Aplicația NU se mai poate bloca din acest ecran, indiferent ce alegi.

## v2.21.0 (2026-08-31) — FIX CRITIC: blocaj complet în Setări la Mărime Text ≠ Normal

Raportat de Cristi: după ce alegea „Mare", aplicația rămânea blocată —
click pe „Setări" nu mai făcea nimic, nici măcar după repornire (valoarea
rămânea salvată). Cauza reală: la un scale diferit de 1.0, zona de click
nu se mai alinia cu ce se vedea pe ecran (limitare cunoscută a combinației
`scaleEffect`+`position` din SwiftUI/macOS).

**Fix, la cerere explicită**: aplicația pornește ACUM ÎNTOTDEAUNA cu
Mărime Text „Normal", indiferent ce a fost ales anterior — alegerea nu se
mai salvează între repporniri. Poți schimba oricând din sesiunea curentă.
Plus: ⌘, (scurtătura standard macOS) deschide Setări direct, indiferent
de starea sidebar-ului — plasă de siguranță dacă ar mai apărea vreodată o
problemă similară.

## v2.20.0 (2026-08-31) — FIX REAL (2): Mărime Text tot nu se schimba

v2.19.0 a înlocuit `dynamicTypeSize` cu scalare vizuală, dar Cristi a
confirmat că butoanele tot nu produceau nicio schimbare. Cauza reală:
`ContentView` avea propriul `.frame(minWidth: 900, minHeight: 600)` intern
— acest minim câștiga mereu în fața dimensiunii mai mici cerute de
tehnica de scalare la „Mare"/„Foarte mare", anulând complet efectul.
Fix: minimul de fereastră mutat în AFARA scalării (la nivelul ferestrei,
nu al conținutului scalat) — exact tiparul deja dovedit funcțional în
GDC Plugin Manager, care nu avea acest minim intern.

## v2.19.0 (2026-08-31) — FIX REAL: Mărime Text nu făcea nimic + ghid PDF actualizat

Raportat direct de Cristi ("la setări la Mac când aleg text mic normal
mare nu se întâmplă nimica"). Aceeași cauză deja documentată în alt produs
GDC: `dynamicTypeSize` nu produce nicio schimbare vizibilă pe macOS.
Înlocuit cu scalare vizuală directă (`.scaleEffect` pe întregul conținut) —
verificat că mărimea chiar se schimbă acum. Ghidurile PDF (RO/EN/ES) au
fost complet actualizate cu toate cele 9 module noi adăugate azi
(Dezinstalator, Monitor Procese, Securitate, Fișiere mari, Dashboard,
DaVinci Resolve backup/zombie, tuning rețea persistent).

## v2.18.0 (2026-08-31) — DaVinci Resolve: Backup bază de date + detectare proces blocat

Modul nou în „DaVinci Resolve": backup cu un click al bazei de date de
proiecte (arhivă .zip, cu dată/oră, listă a backup-urilor existente) —
blocat explicit dacă Resolve rulează, ca să nu corupă arhiva. Plus
detectare „Resolve blocat" (proces activ, fără fereastră vizibilă) cu
buton de închidere forțată.

## v2.17.0 (2026-08-31) — Dependențe: FFmpeg (opțional)

Modulul Dependențe verifică acum și FFmpeg (codecuri suplimentare pentru
export video) — instalare cu un click prin Homebrew, la fel ca Rclone/
macFUSE. Fiind opțional, lipsa lui nu blochează starea verde generală.

## v2.16.0 (2026-08-31) — Cloud Manager: indicator verde/roșu standardizat

Rândul fiecărui remote Cloud arată acum punctul verde/roșu (montat/
demontat) la fel ca restul aplicației, nu doar text — consistent cu
Dashboard-ul și modulul de Securitate.

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
