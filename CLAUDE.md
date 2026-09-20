# Master Control Studio Pro (Mac) — note de arhitectura

**[REBRANDING 2026-08-30]** Numele afișat a devenit "Master Control
Studio Pro" (fost "Mac Master Control Pro") — nume neutru, pregătit
pentru lansarea pe Windows. Identificatorii tehnici NU s-au schimbat:
`productID` (`mac-master-control-pro`), bundle ID
(`com.gordasgdc.macmastercontrolpro`), numele repo-ului GitHub
(`mac-master-control-pro`) și numele fișierelor `.pkg`/`.zip` publicate.
Restul acestui fișier menționează încă vechiul nume în intrările vechi —
rămâne așa intenționat (jurnal append-only, Regula 10), doar identitatea
curentă s-a schimbat.

Aplicatie standalone GDC: conversie a scriptului Mac_Master_Control.sh
intr-un panou nativ de tuning sistem, Cloud Manager universal (Rclone),
curatare cache media si Rosetta Inspector. ID produs oficial:
`mac-master-control-pro`.

## [PARTEA 1: REGULI GLOBALE ECOSISTEM GDC] — mutată în `~/Developer/CLAUDE.md`

> Din 2026-09-18, regulile globale stau într-un singur fișier,
> `~/Developer/CLAUDE.md`, citit automat de Claude Code în orice proiect din
> `~/Developer/`. Nu se mai copiază aici. Ce era specific acestui repo în fosta
> Partea 1 (statusuri, excepții) e la finalul fișierului.

## [PARTEA 2: SPECIFICATII TEHNICE PROIECT]

## Structura repo-ului

- `Sources/MacMasterControlProCore/` — model + servicii fara UI: `LicenseCore.swift`/
  `MachineID.swift` (copiate BYTE-FOR-BYTE din GDCVaultCore, Regula 3 — aceeasi
  cheie publica Ed25519), `LicenseState.swift` (productID `mac-master-control-pro`),
  `Shell.swift`/`PrivilegedRunner.swift` (executie shell/AppleScript admin),
  `NetworkService.swift`, `CloudManagerService.swift` (Universal Multi-Cloud —
  Drive/Dropbox/OneDrive/pCloud/Degoo/Mega/S3/WebDAV/SFTP/FTP), `CleanupService.swift`,
  `TweaksService.swift`, `RosettaInspector.swift`, `DependencyChecker.swift`
  (Homebrew/Rclone/macFUSE), `UserProfileStore.swift`.
- `Sources/MacMasterControlPro/` — UI SwiftUI (Sidebar, module, Setari, Localization
  RO/EN/ES, UpdateChecker/SelfUpdater portate 1:1 din GDCVault, Regula 20).
- `installer/` — `License.txt` (Regula 19), `generate_pdf.py` (Regula 8, RO/EN/ES),
  `scripts/preinstall`.
- `codesigning/` — copiat NESCHIMBAT din GDCVault (Regula standard).
- `docs/` — landing page (mirror in gdc-plugin-manager-catalog-vendor/docs/mac-master-control-pro/,
  gordas.dev e servit de acel repo, nu de acesta).

## Licentiere (2026-08-30)

Trial nelimitat (analize/scanari libere) + Lifetime 9€ (donatie) —
`LicenseState.swift`, `productID = \"mac-master-control-pro\"`, adaugat in
`gdcStandaloneProducts` (Furnizor, `GenerateSerialView.swift`). Activare:
buton \"Doneaza din GDC Plugin Manager\" + camp cheie in `TrialGateModal.swift`,
Machine ID afisat cu copy.

## Release v1.0.0 (2026-08-30)

Primul release oficial — semnat Developer ID Application+Installer,
notarizat, stapled (verificat `spctl -a -vv -t install`: \"accepted\",
\"Notarized Developer ID\"). Assets: `MacMasterControlPro-1.0.0.pkg`,
`MacMasterControlPro.pkg` (stabil), `MacMasterControlPro-Mac.zip` +
`MacMasterControlPro-Mac-1.0.0.zip` (Regula 17). Iconita generata programatic
(`generate_icon.py`, squircle metalic auriu + glif angrenaj).

## Etapa 2026-08-30 (2) — Upload Google Drive lent, client OAuth propriu embedded (v2.8.0)

Descoperit in timpul testarii Cloud (DataMover): un upload pe Google Drive
prin rclone rula la doar ~2.5 Mbit/s, desi conexiunea reala masurata
(`networkQuality -s`) era de 753 Mbps upload - net sub capacitatea reala.
Cauza REALA, nu presupusa: Google limiteaza agresiv clientul OAuth
PARTAJAT al rclone-ului (acelasi ID pentru toti utilizatorii rclone din
lume) - fix documentat oficial de rclone insusi (rclone.org/drive/
#making-your-own-client-id).

**Fix implementat**: `GDCOAuthClients` (nou, `CloudManagerService.swift`) -
un client OAuth Google Cloud propriu al GDC (Desktop app,
`client_id` incepe cu `91447189992-...`), EMBEDDED direct in binar (secretul
unui client "Desktop app" nu e tratat ca fiind confidential de Google
insusi, RFC 8252 - sigur de distribuit). `createRemote()` adauga acum
automat `client_id=`/`client_secret=` la `rclone config create` cand
`type == .googleDrive` - clientul final nu vede NICIUN pas din Google
Cloud Console, doar "+ Adauga cont" -> Google Drive -> login normal.
Masurat direct (acelasi cont, acelasi fisier, inainte/dupa): **~18x mai
rapid** (2.5 Mbit/s -> ~47 Mbit/s).

**Decizie de scop** (cerut explicit de Cristi): doar Google Drive a
primit acest tratament acum - Dropbox/OneDrive/pCloud (celelalte 3
providere OAuth din `CloudProviderType.isOAuth`) raman pe clientul
implicit rclone, de facut separat daca se confirma aceeasi problema.
S3/WebDAV/SFTP/FTP/Mega/Degoo NU au nevoie de asta - folosesc direct
credentialele userului, fara un "client" OAuth comun.

**Sectiune noua UI "Performanta rclone"** (`CloudManagerView.swift`) -
Transferuri paralele/Checkers/dimensiune fragment/`--fast-list`,
persistate in `UserDefaults` (`RclonePerformanceSettings`), aplicate la
`upload`/`download`/`syncFolder` (NU la `mount` - ramane neschimbat).

**Limitare arhitecturala reala, NU de cod**: proiectul Google Cloud al
acestui client OAuth ramane in modul "Testing" (limita 100 "test users") -
fiecare client NOU care vrea Google Drive trebuie adaugat MANUAL de
Cristi ca test user in Google Cloud Console INAINTE sa se poata conecta,
altfel primeste "app not verified". Procedura completa, doar pentru
Cristi (NU in PDF-ul de client): `GHID_INTERN_ONBOARDING_GOOGLE_DRIVE.md`
(radacina acestui repo). PDF-ul public (`installer/generate_pdf.py`,
sectiunea "Upload lent pe Google Drive?") ofera clientilor tehnici o cale
ALTERNATIVA (propriul lor client Google), independenta de limita de 100.

**Verificat**: `swift build` - 0 erori, 0 avertismente. Testat REAL, live,
de Cristi: dupa configurarea manuala a unui client propriu pe un cont de
test (inainte de a fi embedded in cod), viteza masurata cu `nettop` a
crescut de la ~2.5 Mbit/s la ~27-47 Mbit/s pe transferuri reale.

## Etapa 2026-08-31 (2) — Notificare pe email pentru randare + release v2.9.0

Completare la notificarea de randare (Etapa anterioară): Cristi a intrebat
explicit "nu inteleg cum functioneaza daca nu vad sa pun nr de telefon" -
clarificat ca WhatsApp NU poate trimite automat fara click manual (doar
deschide o conversatie pre-completata, la fel ca la activarea licentei) -
email e SINGURA varianta cu adevarat automata catre telefon.
`EmailNotifierService.swift` (nou) - trimite prin `curl` (preinstalat pe
orice Mac, `smtp://...--ssl-reqd`), evita implementarea manuala a
protocolului SMTP. Stocare LOCALA in clar (`UserDefaults`) - UI recomanda
explicit o "parola de aplicatie" Gmail/Outlook, nu parola reala a contului.
Port 1:1 pe Windows (`EmailNotifierService.cs`, `SmtpClient`).

**Release v2.9.0**: toate cele 7 module de mai sus + notificarea pe email,
publicate ca produs final (Mac semnat+notarizat, Windows CI real +
installer Inno Setup) - vezi CHANGELOG.md.

## v2.30.0 (2026-09-04) — Analiză Disc: cache persistent + scanare diferențială, refacută din temelii

Cerință explicită de la Cristi, cu date reale: scanarea ajunsese la peste
624.000 de fișiere, dura peste o oră, și relua totul de la zero la fiecare
deschidere a aplicației sau pornire de analiză — spre deosebire de
DaisyDisk/TreeSize/WizTree, care nu parcurg tot discul la fiecare scanare.
Trei schimbări arhitecturale, toate cerute explicit, plus două cerințe
suplimentare adăugate în aceeași sesiune (deschiderea reală a folderelor,
paritate Mac/Windows).

**1. `DiskScanEngine` — nativ (`fts(3)`), nu shell.** Varianta veche
(`/usr/bin/find -exec stat +`, v2.28.0) shell-a un proces extern și parsa
text — funcțională, dar cu un bug latent nelovit niciodată (un nume de
fișier cu TAB literal ar fi rupt `split(separator: "\t")`) și cost real de
proces+pipe. Înlocuită cu `fts_open`/`fts_read` (POSIX, API-ul intern
folosit chiar de `find`) — `fts_statp` dă mărimea ȘI mtime-ul DIRECT, ca
struct, fără nicio conversie prin text.

**2. Paralelizare pe toate nucleele.** Fiecare subfolder de PRIM NIVEL al
rădăcinii primește propriul `fts` independent, rulat concurent
(`DispatchQueue.concurrentPerform`) — fiecare thread construiește propriul
subarbore, ZERO stare comună mutabilă în timpul scanării; unirea în
arborele final e un pas simplu, secvențial, la sfârșit.

**3. Cache persistent + scanare incrementală.** `DiskCacheStore` (nou) —
salvează/încarcă arborele complet prin `PropertyListEncoder`/`Decoder`
(format binar, fără dependință nouă), un fișier per rădăcină scanată, numit
stabil printr-un hash SHA256 al căii (NU `Hashable`/`Hasher` din Swift —
randomizează sămânța per-proces intenționat, nepotrivit pentru un nume de
fișier persistent). `DiskTreeNode` devine `Codable` + capătă
`directoryModifiedAt` (mtime-ul folderului la ultima scanare) —
`DiskScanEngine.incrementalUpdate`/`refreshDirectory` compară mtime-ul
curent al fiecărui folder cu cel din cache: neschimbat → subarborele
cache-uit rămâne intact, ZERO citire suplimentară de disc dincolo de acel
`stat()`; schimbat → doar ACEL folder e relistat (un nivel), recursând mai
departe doar unde chiar s-a schimbat ceva. Reduce o rescanare pe un disc
mare, majoritar neatins, de la ore la câteva secunde. Nu detectează un
fișier existent a cărui CONȚINUT s-a schimbat păstrând exact aceeași
mărime (caz extrem de rar) — pentru asta rămâne „Resetare Cache & Scanare
Completă".

**UI (`DiskAnalyzerViewModel`/`DiskAnalyzerView`)**: alegerea unei rădăcini
încarcă instant cache-ul salvat, dacă există (`startIndexing`); un banner
nou arată data/ora ultimei analize + „Re-scanează doar modificările"
(`rescanChangesOnly`, discret, arborele rămâne navigabil normal cât timp
rulează) și „Resetare Cache & Scanare Completă" (`resetCacheAndFullRescan`,
în spatele unui `.alert` de confirmare — acțiune rară, distructivă pentru
cache). `delete(_:)` salvează cache-ul actualizat după orice ștergere
reușită — altfel cache-ul vechi ar arăta din nou, la următoarea deschidere,
un fișier deja șters.

**Cerință adăugată mid-sesiune: deschiderea reală a folderelor.** Butonul
„Arată în Finder" de lângă un folder folosea `NSWorkspace.selectFile(
inFileViewerRootedAtPath:)`, care doar evidențiază folderul în fereastra
PĂRINTELUI — nu arată ce e ÎNĂUNTRU. Pentru foldere, schimbat la
`NSWorkspace.shared.open(URL(fileURLWithPath:))`, care deschide o fereastră
Finder navigată DIRECT în acel folder; pentru fișiere, comportamentul vechi
(evidențiat în folderul care-l conține) rămâne corect neschimbat.

**Bug REAL, grav, găsit DOAR prin rulare — niciodată vizibil din citirea
codului.** Metodologia deja stabilită în acest repo (CLAUDE.md v2.28.0): un
executabil de test izolat (`Sources/DiskEngineTest`, ȘTERS după verificare),
exercitând codul REAL (nu o reimplementare) pe o structură de foldere
cunoscută — scanare completă, round-trip cache, update incremental cu
adăugare+ștergere simulată, 3 rulări consecutive pe 200 de fișiere pentru
curse de date. La prima rulare, executabilul a scanat 0 fișiere, mărime 0,
pe o structură cunoscută să aibă 1500 de octeți în 5 fișiere.

**Root-cauza reală**: `ent.pointee.fts_path` (câmpul C `char *fts_path` din
`FTSENT`) e deja un `UnsafeMutablePointer<CChar>` — un POINTER către
șirul de caractere, nu un buffer inline ÎN struct. Codul inițial făcea
`withUnsafePointer(to: &ent.pointee.fts_path) { $0.withMemoryRebound(
to: CChar.self, ...) { String(cString: $0) } }` — asta ia adresa CÂMPULUI-
POINTER însuși și reinterpretează OCTEȚII POINTERULUI ca text, în loc să
urmeze pointerul către șirul real. Rezultatul: `fullPath` conținea gunoi
(octeții propriei adrese de memorie interpretați ca ASCII), niciodată
calea reală — `guard fullPath.hasPrefix(rootPrefix) else { continue }`
respingea tăcut ABSOLUT FIECARE intrare, deci scanarea "reușea" (fără crash,
fără eroare) dar nu găsea niciodată vreun fișier. Fix, o singură linie:
`String(cString: ent.pointee.fts_path)` — verificat direct, izolat, cu un
script separat care confirmă tipul câmpului și extrage corect calea reală,
ÎNAINTE de a aplica fix-ul în `DiskScanEngine.swift`.

**A doua problemă găsită, în HARNESS-ul de test, nu în cod de producție**:
prima rulare a testului a INTRAT ÎN DEADLOCK (0% CPU, niciun output,
proces agățat la nesfârșit) — nu era o scanare lentă, era un blocaj real.
Cauza: un executabil simplu de linie de comandă (`main.swift`) NU are un
run loop AppKit/SwiftUI care să "pompeze" automat `DispatchQueue.main` —
`group.wait()` (blocare sincronă pe semafor) ține thread-ul principal
ocupat la nesfârșit, deci `completion`-urile din `DiskScanEngine`
(dispatch-uite explicit pe `.main`, CORECT pentru UI-ul real al aplicației)
nu se executau NICIODATĂ în acest context de test. Fix DOAR în test:
`waitOnMain(group)` rulează `RunLoop.main.run(...)` în buclă scurtă până
grupul se termină, în loc de `group.wait()` orb. După ambele fix-uri, toate
cele 18 verificări (scanare completă, round-trip cache, update incremental,
3× stress pe 200 de fișiere) au trecut, PASS.

**De ce ambele bug-uri au scăpat de la `swift build`**: niciunul nu e o
eroare de compilare — `withUnsafePointer`/`withMemoryRebound` compilează
perfect (tipurile sunt corecte din punctul de vedere al compilatorului,
doar semantica e greșită), iar deadlock-ul apare DOAR la execuție reală,
niciodată la o simplă verificare statică. Exact motivul pentru care
practica de verificare izolată, prin rulare reală (nu doar `swift build`),
rămâne obligatorie la orice schimbare cu potențial de eșec silențios —
al patrulea bug de acest fel găsit în acest modul, după cele 3 din v2.28.0.

**TODO explicit, nu ascuns — paritate Windows (Regula 31).** Verificat prin
`grep`: `MacMasterControlProWin` NU are niciun echivalent al Analizei de
Disc — doar un `DiskHealthService`/`DiskHealthPage` complet diferit (SMART,
sănătatea discului, nu explorare de spațiu). Portul complet (UI + engine)
rămâne de construit de la zero, într-o sesiune viitoare — strategia de
scanare incrementală bazată pe mtime de folder e explicit portabilă
(`Directory.GetLastWriteTime` în C#), fără nevoie de USN Journal/MFT.

**Verificat**: `swift build -c release` — 0 erori. `.pkg` semnat Developer
ID Application+Installer, notarizat, stapled (`spctl -a -vv -t install`:
„accepted", „Notarized Developer ID"). Instalare finală (`installer -pkg
... -target /`) cere parola de administrator — pas fizic, confirmat de
Cristi, nu de Claude.

## v2.29.0 (2026-09-03) — 4 ghiduri PDF detaliate per modul, în meniul Help

Cerință explicită de la Cristi: manuale PDF ultra-detaliate pentru fiecare
modul important, integrate în meniul Help, deschise prin viewer-ul nativ
de sistem (Preview) — nu doar ghidul general de instalare deja existent.

**`installer/generate_module_guides.py`** (nou, autonom — NU importă din
`generate_pdf.py`, aceeași convenție ca `codesigning/` copiat neschimbat
între repo-uri: stilul vizual — Arial pentru diacritice, aceleași culori
accent — e duplicat intenționat, nu partajat prin import, ca fiecare
script să rămână independent rulabil). Generează 4 ghiduri × 3 limbi = 12
PDF-uri în `installer/`:
- `Ghid_ModRandare_{RO,EN,ES}.pdf` — ce face exact `tmutil disable`/
  `mdutil -a -i off`/`renice`, cele 10 aplicații recunoscute automat,
  avertismentul de dezactivare manuală.
- `Ghid_AnalizaDisc_{RO,EN,ES}.pdf` — cum funcționează indexarea completă
  + navigarea instantă (v2.28.0), cum se citește bara proporțională.
- `Ghid_TweaksSistem_{RO,EN,ES}.pdf` — ce schimbă exact Finder avansat,
  ce e `.metadata_never_index` (Spotlight Shield), ce fișier de sistem
  modifică Touch ID (`/etc/pam.d/sudo_local`).
- `Ghid_BackupSecuritate_{RO,EN,ES}.pdf` — notificare randare + email,
  Auditor Media Pool, sincronizare LUT/Fusion, backup bază de date
  (de ce trebuie închis Resolve întâi), ce înseamnă fiecare verificare de
  Securitate + de ce 3 acțiuni NU sunt automate (FileVault/SIP/DNS).

**`ModuleGuidePDF.swift`** (nou) — enum cu 4 cazuri, port 1:1 al tiparului
deja existent în `GuidePDF.swift` (deschide limba curentă din
`LanguageStore`, fallback RO dacă fișierul lipsește), parametrizat pe
numele de bază al ghidului — nu repetă logica de 4 ori.

**`MacMasterControlProApp.swift`** — meniul Help capătă 4 butoane noi,
sub un separator, după ghidul general existent.

**`build_installer.sh`** — actualizat să copieze toate cele 12 PDF-uri noi
în `Contents/Resources`, alături de cele 3 existente (15 total).

**Verificat**: `swift build` — 0 erori. Fiecare din cele 12 PDF-uri
verificat cu `pypdf` — diacritice românești corecte (ă/ș/î/â/ț), 3 pagini
fiecare, footer + numerotare corectă. Instalat local, 2.29.0 confirmat pe
disc, cele 12 fișiere confirmate prezente în bundle.

## v2.28.1 (2026-09-03) — Audit din capturi de ecran (20 poze trimise de Cristi)

Cristi a trimis 20 de capturi de ecran (v2.27.0) cerând analiză vizuală
completă + curățenie de cod legacy. Am revizuit fiecare ecran sistematic —
majoritatea confirmă că design-ul curent (StatusBanner, iconițe SF Symbols
din v2.27.x) funcționează corect. 3 probleme REALE găsite, toate în
`DashboardView`:

1. **Cardul "Aplicații de fundal" (`DashboardCard`) avea `isGood: nil`
   HARDCODAT** — un `ProgressView` care se învârte etern, niciodată
   înlocuit cu un cerc verde/roșu real, CONTRAR intenției documentate
   explicit chiar în comentariul de deasupra clasei ("verde/roșu la orice
   tip de configurare, direct pe dashboard"). Fix: `loginItemsGood`
   calculat real din `LoginItemsService.scan()` — verde daca niciun agent
   terț nu e încărcat acum (nimic concurează pentru CPU/RAM), roșu altfel.
2. **`"dashboard.title"` avea emoji `📊` hardcodat** — scăpat la trecerea
   sistemică de emoji→SF Symbols din v2.27.0, fiindcă e citit prin
   `L.t(...)` (Localization.swift), nu un `Text("📊 ...")` direct — grep-ul
   de atunci nu l-a prins. Fix: text curat + `Label(..., systemImage:
   "gauge.with.dots.needle.67percent")`, aceeași iconiță ca-n sidebar.
3. **`"dashboard.tagline"` avea `.ro` IDENTIC cu `.en`** (text de marketing
   englezesc, netradus) — singura appariție de text englez într-o
   aplicație altfel complet localizată RO/EN/ES. `.es` era deja tradus
   corect; doar `.ro` rămăsese netradus. Fix: traducere reală RO + EN
   reformulat mai concis.

**Verificare sistemică suplimentară**: `grep` pentru alte apariții
`isGood: nil` (zero găsite) și emoji rămase în `Localization.swift` (zero
găsite) — confirmă că acestea au fost singurele 3, nu doar cele vizibile
în capturile trimise.

**Verificat**: `swift build` — 0 erori. Instalat local, 2.28.1 confirmat
pe disc.

## v2.28.0 (2026-09-03) — Analiză Disc: indexare completă + 3 bug-uri reale, grave, prinse la testare

Cerință explicită de la Cristi: "declanșează o nouă scanare de la zero" la
fiecare intrare în subfolder — modelul vechi (`DiskAnalyzerService.
scanLevel`, ȘTERS complet) rescana discul cu `du`/`find` la FIECARE
navigare, ca o pagină web care se reîncarcă la fiecare click. Cerință: un
explorator real (DaisyDisk/GrandPerspective/TreeSize) — indexare completă
O SINGURĂ DATĂ, arbore în memorie, navigare instantă.

**Arhitectură nouă**: `DiskTreeNode` (Core, nou) — nod de arbore (nume,
cale, mărime, copii). `DiskScanEngine.buildTree(root:)` (Core, nou) — O
SINGURĂ trecere recursivă (`find -x <root> -type f -exec stat -f '%z\t%N'
{} +`, batching `+` nu `;` — mult mai rapid), streaming linie-cu-linie
(Regula 21 — niciodată tot output-ul brut într-un blob uriaș). `remove(
nodePath:from:)` actualizează arborele DUPĂ o ștergere reușită (scade
mărimea din toți ancestorii), fără nicio rescanare. `DiskAnalyzerViewModel`
rescris să navigheze prin noduri deja indexate (`pathStack: [DiskTreeNode]`),
ZERO acces nou la disc la navigare.

**3 bug-uri REALE, grave, găsite prin testare izolată înainte de livrare —
niciunul vizibil doar din citirea codului:**

1. **`-x` trebuie ÎNAINTEA căii, nu după.** Verificarea inițială a trecut
   din greșeală pe un shim `find`/`bfs` din mediul de shell (Claude Code
   își înlocuiește `find`-ul cu o unealtă proprie, mai permisivă) — binarul
   REAL de sistem (`/usr/bin/find`, apelat aici prin cale absolută)
   respinge `-x` după cale cu "illegal option". Lecție: o verificare de
   comandă shell trebuie făcută cu path ABSOLUT către binarul real, nu prin
   numele simplu care poate fi umbrit de mediul de dezvoltare.
2. **Cursă de date REALĂ, cu crash reproductibil (SIGSEGV)** la fișiere
   multe (500+): varianta inițială cu `readabilityHandler` (pattern deja
   folosit "sigur" în `Shell.swift`) procesa date pe thread-ul intern al
   dispatch source-ului, ÎN TIMP CE codul de după `waitUntilExit()` (alt
   thread) citea/scria aceeași variabilă capturată — fără nicio
   sincronizare. La puține fișiere mergea (fereastra de cursă prea mică
   să se manifeste); la sute de fișiere, fie pierdea tăcut majoritatea, fie
   crăpa. Fix: citire BLOCANTĂ, secvențială, pe UN SINGUR thread (deja pe
   fundal) — `FileHandle.availableData` într-o buclă `while`, fără
   `readabilityHandler`, fără acces concurent posibil.
3. **`waitUntilExit()` nu garantează că tot output-ul a fost citit** — o
   cursă documentată separat de #2: procesul copil se poate termina
   ÎNAINTE ca ultimii octeți din bufferul kernel al pipe-ului să fi fost
   livrați. Rezolvată implicit de fix-ul #2 (citirea blocantă se termină
   abia la EOF real, nu la ieșirea procesului).

**Metodologie de verificare, nu doar "swift build"**: pentru fiecare fix,
un mic executabil de test separat (`Sources/DiskTreeTest`, ȘTERS după
verificare — nu rămâne în repo), rulat REAL, de mai multe ori, pe date
reale: 3 fișiere (caz simplu), 501 fișiere (caz care a expus cursa de
date — 5 rulări consecutive, toate corecte), nume cu spații (caz real
frecvent pe Mac), și `~/Developer/MacMasterControlPro` însuși (3791
fișiere reale, 252 MB, indexat corect în 0.27s). Fiecare bug de mai sus a
fost prins DOAR prin rulare reală, niciunul vizibil din citirea codului —
motivul exact pentru care Regula de verificare izolată (deja aplicată la
fix-ul de escaping AppleScript) rămâne obligatorie la orice schimbare cu
potențial de eșec silențios sau concurență.

**Verificat**: `swift build` — 0 erori. Instalat local, 2.28.0 confirmat
pe disc.

## v2.27.1 (2026-09-03) — Iconițe REALE, cerute explicit ("iconița oficială")

TODO-ul lăsat deschis explicit în v2.27.0 rezolvat: `RenderModeService`
rescris de la `pgrep -x` (potrivire EXACTĂ de nume de proces — fragil, un
"Adobe Premiere Pro 2026" cu anul în nume n-ar mai fi fost găsit
niciodată) la `NSWorkspace.shared.runningApplications` + potrivire prin
SUBSTRING (`localizedCaseInsensitiveContains`) pe `localizedName` — mult
mai robust la variații de nume între versiuni, ȘI oferă gratuit iconița
REALĂ a aplicației (`NSRunningApplication.icon`), fără nicio dependință
nouă — exact tiparul deja folosit de `InstalledApp.icon`
(`UninstallerService.swift`).

`DetectedRenderApp` (nou, Core) — nume + PID + `NSImage` reală. Secțiunea
nouă „Aplicații detectate acum” din `RenderModeView` arată iconițele
PERMANENT (nu doar în jurnalul de activare), cu reîmprospătare automată
la 5 secunde (`Timer.publish`) — userul poate porni Premiere/Final Cut
chiar cât se uită la ecran, fără să dea Refresh manual.

**Verificat**: API-ul `NSRunningApplication.icon` confirmat funcțional
izolat (test cu „Finder”, rulat separat de build — icon prezent, 32×32).
Niciuna din aplicațiile din listă (DaVinci Resolve, Final Cut, Premiere
etc.) nu rula pe acest Mac în momentul verificării — comportamentul cu o
iconiță REALĂ afișată nu a fost văzut vizual de Claude, doar mecanismul
de potrivire + API-ul de icon, separat. Cristi confirmă vizual la
următoarea rulare cu o aplicație din listă deschisă.

**Verificat build**: `swift build` — 0 erori. Instalat local, 2.27.1
confirmat pe disc.

## v2.27.0 (2026-09-03) — Mod Randare universal + curățenie vizuală sistemică

Feedback direct de la Cristi, în 3 părți, după fix-urile Touch ID:
1. **"Mod Randare... l-am gândit doar pentru DaVinci Resolve, dar e valabil
   pentru orice aplicație... Final Cut, Premiere, Media Encoder."**
2. **"Nu văd un indicativ să văd dacă am făcut... Spotlight Shield...
   analizatorul de disc durează mult și nu pot vedea... dacă e ok."**
3. **"Nu-mi place stilul emoji/desen tipic de AI — trebuie profesional,
   ca GDC Plugin Manager (SVG-uri simple), nu pop-up amator."**

**(1) `RenderModeService.swift` — generalizat.** `resolvePID()` (un singur
proces hardcodat, "DaVinci Resolve") înlocuit cu `knownRenderApps: [String]`
(Final Cut Pro, Compressor, Motion, Premiere Pro, Media Encoder, After
Effects, Logic Pro, Fusion, HandBrake) + `runningRenderApps()`, care
verifică și ridică prioritatea TUTUROR celor care rulează ACUM, nu doar
prima găsită — un flux real poate avea Premiere ȘI Media Encoder pornite
simultan. Time Machine/Spotlight erau deja la nivel de sistem, neafectate
de bug. Textul din `RenderModeView` actualizat să nu mai numească doar
Resolve.

**(2) Feedback vizual la acțiuni lente/discrete.**
- `DiskAnalyzerView` — cronometru viu (`Timer.publish(every: 1)`) cât
  scanează, ca un disc extern mare să nu pară o aplicație blocată.
- Spotlight Shield (`TweaksModuleView`) — etichetă verde „Protejat" +
  iconiță lângă orice țintă activă (nu doar bifa toggle-ului, ușor de
  ratat), plus mesaj explicit de eroare dacă scrierea markerului eșuează
  (înainte, un eșec silențios lăsa toggle-ul pur și simplu neschimbat,
  fără nicio explicație).

**(3) `StatusBanner.swift` (nou, v2.26.3) — extins conceptual, plus
curățenie de iconițe.** Toate cele 16 titluri de secțiune (`Text("🛠️
...")`, `"🧹 ..."`, etc.) înlocuite cu `Label(text, systemImage:)`,
folosind EXACT aceleași SF Symbols ca în sidebar (`ContentView.icon`) —
monocrome, consistente, fără niciun emoji ilustrativ. Botonul „🗑 Șterge
selecția" (RemoteBrowserSheet) la fel.

**TODO real, nu ascuns**: Cristi a cerut și iconițele OFICIALE ale
aplicațiilor (Final Cut, Premiere) acolo unde sunt numite explicit (ex.
lista din Mod Randare) — necesită extragerea `NSWorkspace.icon(forFile:)`
din bundle-ul real al aplicației găsite (nu doar un SF Symbol generic),
o bucată de lucru separată, mai mare, rămasă neimplementată în acest
release. La fel, `logic`-ul de „state" pentru restul tweak-urilor
(Finder avansat, DS_Store) tot n-are `onOutput`/Terminal Live — risc mic
(scrieri `defaults` fără sudo), dar portul e trivial dacă devine necesar.

**Verificat**: `swift build` — 0 erori. Instalat local, 2.27.0 confirmat
pe disc.

## v2.26.3 (2026-09-03) — ROOT-CAUZA REALĂ a Touch ID + StatusBanner peste tot

Panoul Terminal Live adăugat în v2.26.2 și-a dovedit imediat rostul:
Cristi a trimis output-ul real la prima încercare, dezvăluind eroarea
adevărată — `176:177: syntax error: Expected """ but found unknown
token. (-2741)`. NU era deloc o problemă de permisiuni/prompt — era un
bug de escaping AppleScript, prezent probabil din prima implementare a
`PrivilegedRunner`, doar că niciun apelant anterior nu trimisese o
comandă cu destule backslash-uri ca să-l declanșeze vizibil.

**Root-cauza exactă**: `PrivilegedRunner.run` scăpa DOAR ghilimelele
(`"` → `\"`) când construia literalul de string AppleScript, niciodată
backslash-urile proprii ale comenzii. Scriptul Touch ID conține
`\.`/`\1` (escape-uri regex din `sed`) — un backslash neescapat într-un
literal AppleScript e interpretat de PARSERUL AppleScript ca începutul
propriei sale secvențe de escape, rupând literalul de string ÎNAINTE ca
`osascript` să ajungă vreodată să compileze scriptul, darămite să ceară
parola — exact de-aia nicio fereastră de sistem nu apărea NICIODATĂ, în
niciuna din cele 2 versiuni anterioare (amândouă reparau cauze reale,
dar nu ȘI pe asta).

**Fix**: ordinea corectă de escaping — backslash-urile ÎNTÂI (`\` →
`\\`), ghilimelele DUPĂ. Verificat izolat, ÎNAINTE de a declara fixul
gata: `osacompile -e "<scriptul escapat>"` → compilare validă (confirmat
"SINTAXA VALIDA"), spre deosebire de varianta veche care ar fi eșuat
identic cu eroarea raportată.

**A doua cerință, mai largă**: Cristi a semnalat că starea aplicației e
general ambiguă — "nu știi ce face, a rulat, nu a rulat... clientul
trebuie psihologic să înțeleagă, să zică ok, l-am rulat, e bine".
`StatusBanner.swift` (nou) — bloc COLORAT (verde/roșu/albastru), cu
iconiță, care înlocuiește tiparul vechi `Text(status).font(.caption)
.foregroundStyle(.secondary)` (identic vizual la succes și eșec) —
folosește convenția deja existentă în tot codul (`"✔ ..."`/`"✘ ..."` la
începutul mesajului), deci niciun apelant nu trece un enum nou, doar
textul deja scris. Aplicat în toate cele 8 locuri reale unde exista un
mesaj de status/rezultat: Tweak-uri Sistem, Curățare & RAM, Cloud
Manager, Duplicate, Rosetta Inspector, Layout Ferestre, DaVinci Resolve
(2 locuri). NU aplicat peste texte informative neutre (dimensiuni,
descrieri, numărători) — acelea rămân caption gri, corect, fiindcă nu
sunt un rezultat de succes/eșec.

**Verificat**: `swift build` — 0 erori. Instalat local, 2.26.3 confirmat
pe disc. **Touch ID efectiv NU verificat live de Claude** (cere
interacțiune fizică cu promptul de sistem) — dar de data asta cu o
explicație tehnică completă și verificabilă independent (nu doar o
presupunere), spre deosebire de v2.26.0/v2.26.1.

## v2.26.2 (2026-09-03) — Terminal Live pentru Touch ID (diagnostic vizibil)

Cristi a confirmat, cu screenshot: v2.26.1 (fix osascript-ca-proces-extern)
tot eșuează IDENTIC ("Promptul de administrator a fost respins"). Fără
diagnostic REAL vizibil, nu se putea distinge dacă: (a) fix-ul din v2.26.1
n-a rezolvat root-cauza, (b) userul chiar respinge promptul fără să
realizeze, sau (c) o a treia cauză complet diferită. Cerere explicită de
la Cristi: "o fereastră tip terminal în care să rămână comenzile ce
s-au încercat și eroarea... să nu dispară fereastra... la orice tip de
comandă".

**Găsit prin audit** (`grep -rn "TerminalLogView"`): panoul „Terminal
Live" (Regula 26) era deja cablat în 9 din module (Cloud, Curățare,
Dependențe, Login Items, Duplicate, Resolve Tools, Mod Randare, Remote
Browser, Dezinstalator) — dar LIPSEA exact din `TweaksModuleView` (Touch
ID), singurul loc unde userul raporta o problemă reală și persistentă.

**Fix**: `PrivilegedRunner.run` capătă un parametru opțional `onOutput`
(port 1:1 al celui deja existent pe Windows, `PrivilegedRunner.cs`) —
emite comanda EXACTĂ trimisă + fiecare linie de output/eroare de la
`osascript` + statusul final (cod de ieșire). `TweaksService.
enableTouchIDForSudo` îl propagă mai departe; `TweaksModuleView` afișează
rezultatul într-un `TerminalLogView` persistent (nu se golește la eșec)
+ buton „Copiază tot".

**De ce e important dincolo de Touch ID**: data viitoare când acest buton
(sau oricare altul din acest modul) eșuează, răspunsul RAW de la sistem e
vizibil și copiabil imediat — nu mai depindem de un mesaj generic
presupus de noi ("promptul a fost respins") care ascunde cauza reală.

**TODO reale, nu ascunse**: restul acțiunilor din acest fișier
(`TweaksService`: Finder avansat, blocare .DS_Store, Spotlight Shield)
NU au `onOutput` — sunt scrieri `defaults`/`chflags` fără sudo, risc de
eșec silențios mult mai mic, dar dacă un client raportează vreodată o
problemă și la ele, portul e identic, trivial.

**Verificat**: `swift build` — 0 erori. Instalat local, 2.26.2 confirmat
pe disc. **Diagnosticul real al Touch ID rămâne deschis** — următorul
mesaj din panoul Terminal Live, trimis de Cristi, va arăta exact ce
eroare dă `osascript` pe acest Mac.

## v2.26.1 (2026-09-03) — Fix REAL #2 la Touch ID: root-cauza era alta

v2.26.0 mutase execuția `NSAppleScript` pe main thread (fix corect pentru
eșecuri INTERMITENTE), dar Cristi a raportat ceva diferit: eșec
SISTEMATIC, fără ca fereastra nativă de parolă să apară VREODATĂ —
confirmat explicit, prin întrebare directă, că nu apărea nicio fereastră
de sistem. Asta a exclus imediat "userul respinge promptul" și a arătat
că fix-ul de threading, deși corect ca principiu, nu era root-cauza
completă.

**Root-cauza reală**: `PrivilegedRunner` folosea `NSAppleScript`
IN-PROCES (`.executeAndReturnError`) — sub Hardened Runtime (obligatoriu
pentru notarizare), fără entitlement-ul `com.apple.security.automation.
apple-events`, sistemul poate refuza executarea INAINTE ca ea să ajungă
la Security Agent, deci fără nicio fereastră vizibilă. Comparat direct
cu `GDCVault/Sources/GDCVault/SelfUpdater.swift` (dovedit funcțional în
producție, confirmat de Cristi) — acolo `do shell script ... with
administrator privileges` rulează prin `/usr/bin/osascript` ca PROCES
EXTERN (`Process`), nu `NSAppleScript` in-proces. Un proces extern are
propria identitate TCC/Hardened-Runtime, neafectată de restricțiile
binarului părinte.

**Fix**: `PrivilegedRunner.run` rescris să lanseze `osascript -e "..."`
ca proces extern, identic cu tiparul din `GDCVault`, plus citirea
incrementală a pipe-ului (fix-ul de deadlock din `Shell.swift`, aplicat
și aici — o comandă privilegiată poate produce output mare, ex. `rm -rf`
verbose). Interfața publică (`Result{output, success}`) neschimbată — toți
cei 15 apelanți existenți funcționează identic, fără nicio altă
modificare.

**Lecție de proces**: primul fix (threading) NU era greșit — doar
incomplet, tratând un simptom (intermitență) fără să elimine o cale de
eșec complet diferită (refuz sistematic, fără prompt). Verificarea
"apare fereastra de sistem sau nu?" a fost decisivă pentru diagnostic —
fără ea, aș fi continuat să presupun că threading-ul era singura cauză.

**Verificat**: `swift build` — 0 erori. Instalat local (2.26.1 confirmat
pe disc). **NU verificat live de Claude** — promptul de sistem efectiv
cere interacțiune fizică; Cristi confirmă la următoarea încercare.

## v2.26.0 (2026-09-03) — Audit total: Analiză Disc + 2 bug-uri reale, sistemice

Cerut de Cristi ca audit complet ("touch ID zice permisiune negată",
"scanezi fișiere mari și hard disk mare se blochează, se închide") +
cerință nouă (analiză vizuală de disc, gen DaisyDisk).

**1. `Shell.swift` — deadlock clasic `Process`/`Pipe`, cauza REALĂ a
blocării la scanare.** `run`/`runElevated` citeau output-ul
(`readDataToEndOfFile()`) abia DUPĂ `process.waitUntilExit()`. Pipe-ul
kernel are un buffer FIX (~64 KB) — un `find` pe un disc extern cu sute
de mii de fișiere mari (Big File Finder) depășește garantat asta:
procesul copil se blochează la `write()` (buffer plin, nimeni nu
citește), părintele așteaptă la nesfârșit `waitUntilExit()` un proces
care nu mai poate ieși — cei doi se blochează reciproc. Simptom exact
raportat: aplicația înghețată, userul o închide forțat. Afecta TOATE
cele ~15 fișiere care folosesc `Shell.run`, nu doar scanarea de disc.
**Fix**: citire INCREMENTALĂ a pipe-ului (`readabilityHandler`), pe
măsură ce datele sosesc — părintele nu mai lasă niciodată bufferul să se
umple, indiferent cât de mare e output-ul.

**2. `PrivilegedRunner.swift` — Touch ID/sudo eșua intermitent cu
"permisiune negată".** `NSAppleScript.executeAndReturnError` e
documentat explicit de Apple ca NEFIIND thread-safe, trebuie apelat DOAR
de pe main thread — dar toate cele 15 apeluri `PrivilegedRunner.run(...)`
din aplicație vin din `DispatchQueue.global().async` (ca UI-ul să nu se
blocheze cât așteaptă parola). Execuția de pe fundal producea erori
intermitente de autorizare de la Security Server — tiparul exact
"câteodată merge, câteodată nu" raportat. **Fix**: `run` forțează
executarea efectivă a AppleScript-ului pe main thread
(`DispatchQueue.main.sync`, cu verificare `Thread.isMainThread` ca să nu
se auto-blocheze dacă apelantul e deja pe main) — apelanții existenți nu
s-au schimbat, tot pot chema din fundal.

**3. Modul nou: `DiskAnalyzerService.swift` + `DiskAnalyzerView.swift`
("Analiză Disc", gen DaisyDisk).** Drill-down pe niveluri (nu sunburst
complet — efort disproporționat față de valoarea reală): `du -xsk` pentru
subfoldere (nu traversează alte volume montate, ca Finder), `find
-maxdepth 1 -type f` + `stat` pentru fișiere individuale de la același
nivel (pe care `du -d 1` nu le listează separat) — ambele prin `Shell.run`
(fix-ul de mai sus, sigur chiar și pe un folder cu sute de mii de
fișiere). UI: breadcrumb + bară proporțională colorată (click = drill-down)
+ listă cu Arată în Finder/Șterge (`PrivilegedFileOps`, fallback automat
pe parolă admin). Protecție împotriva cursei intre scanări: un
`scanGeneration` (token incrementat la fiecare navigare) — dacă userul
schimbă folderul cât timp o scanare veche, lentă, tot rulează pe fundal,
rezultatul ei întârziat NU mai suprascrie folderul nou deschis.

**Verificat**: `swift build -c release` — 0 erori. Instalat local
(2.26.0 confirmat pe disc), lansat, logica de parsare `du`/`stat`
verificată manual byte-cu-byte (confirmat: `\t` dintr-un literal Swift
devine tab real ÎNAINTE să ajungă la shell — niciun bug de escaping,
verificare făcută explicit ca să nu presupun).

## Rebuild local

```bash
cd ~/Developer/MacMasterControlPro && swift build -c release
```

Pachet complet de release (.pkg semnat+notarizat+stapled + arhive):

```bash
cd ~/Developer/MacMasterControlPro && ./build_installer.sh
```

## Etapa 2026-09-11 — Duplicate: actor asincron, hash în cascadă, UI animat

Cerere de arhitectură de la Cristi (crash-uri la volume mari, scanare pierdută
la schimbarea tabului, UI static, onboarding dependențe). **Plan prezentat și
aprobat explicit înainte de orice cod.**

**Trei dintre cele cerute existau deja — verificat în cod, nu presupus:**
`DiskScanEngine` folosește din 2026-09-04 `fts(3)` (API-ul POSIX pe care îl
folosește `find` intern), paralelizat pe toate nucleele, cu cache persistent și
delta scan pe `mtime`. `DiskAnalyzerViewModel` e deja singleton, deci analiza de
disc NU se pierdea la schimbarea tabului. Nu s-a rescris nimic acolo.

**Corecție de specificație, comunicată explicit**: Spotlight/`NSMetadataQuery`
ar fi fost o REGRESIE, nu o optimizare — nu indexează fiabil volumele externe
(exact `/Volumes/GDC`, `/Volumes/DavinciResolve` din capturile lui Cristi), nu
dă dimensiuni agregate pe foldere, și returnează date stale. DaisyDisk nu-l
folosește nici el.

**Problema reală era la duplicate. Patru defecte, toate în
`DuplicateFinderService.scan`:**

1. **Cauza crash-ului**: `bySize` acumula TOATE căile într-un dicționar înainte
   de orice hashing — pe 1,44 TB, sute de mii de String-uri vii simultan.
   Ironic, același fișier cita Regula 21 pentru hashing (corect, pe bucăți) dar
   o încălca la enumerare. **Fix**: două treceri — prima reține doar un CONTOR
   per dimensiune (`[Int64: Int]`), a doua doar căile candidaților reali.
   Dimensiunile unice nu rețin nicio cale.
2. **Hash complet pe fiecare candidat** — două fișiere video de 40 GB cu aceeași
   mărime dar conținut diferit erau citite integral (80 GB) ca să afli că diferă
   la primul octet. **Fix**: cascadă dimensiune → primii 64 KB → complet doar
   pentru supraviețuitori.
3. **Fără anulare** — niciun punct de oprire. **Fix**: `Task.checkCancellation()`
   între fișiere, la fiecare 200 de intrări la enumerare.
4. **Starea în `@State` pe View** — la schimbarea tabului SwiftUI distruge
   view-ul, rezultatele dispar, munca continuă scriind în nimic. **Fix**:
   `DuplicateFinderViewModel.shared`, exact tiparul deja dovedit de
   `DiskAnalyzerViewModel` în acest repo — nu s-a inventat o soluție nouă
   pentru o problemă rezolvată deja o dată aici.

**Măsurat, nu estimat** (4 fișiere × 40 MB, duplicate reale + false pozitive de
aceeași dimensiune): vechi 0,085s → nou 0,023s, **3,8×**, cu rezultat IDENTIC
(1 grup, aceleași fișiere). Raportul crește cu dimensiunea fișierelor — pe
video-uri reale de zeci de GB, vechiul citește tot, noul 64 KB. Anularea
verificată separat: oprire în 0,20s din plină scanare, actorul confirmă că nu
mai rulează.

**`ioLaneCount`**: pe volum EXTERN (rotativ) se limitează la 4 fire — mai multe
citiri simultane pe un cap fizic încetinesc, nu accelerează. Pe intern, până la
8. Citit din `volumeIsInternalKey`, nu presupus.

**`ScanProgressView`** (nou, reutilizabil de ambele module): inele radiale și
arc de progres desenate PROCEDURAL în `Canvas` + `TimelineView`, zero asset-uri.
Arcul se adaptează: `fraction == nil` (enumerare, unde totalul chiar nu e
cunoscut) → arc rotativ, altfel procent real — un procent inventat în faza de
enumerare ar fi o minciună. Respectă `accessibilityReduceMotion` (Regula 24).
Iconița e cea NATIVĂ a volumului (`NSWorkspace.icon(forFile:)`).

**TENSIUNE REZOLVATĂ cu Regula 26.** Cerința nouă („un pop-up cu un singur
buton") contrazicea Regula 26, stabilită tot de Cristi după un incident real
(„o instalare în masă, silențioasă, poate bloca sistemul clientului").
Împăcarea, semnalată explicit lui Cristi: un singur buton, DAR lista exactă a
componentelor afișată ÎNAINTE, instalare SECVENȚIALĂ (nu paralelă), fiecare
linie vizibilă în `TerminalLogView`, iar butoanele individuale rămân. Comod ca
un buton, transparent ca înainte — nu „în masă și silențios".

`DependencyInstaller` folosește `PrivilegedRunner` (prompt NATIV de parolă,
Regula 20), niciodată Terminal vizibil. `NONINTERACTIVE=1` la scriptul oficial
Homebrew e obligatoriu — altfel așteaptă un ENTER pe care userul n-are unde
să-l dea și instalarea atârnă la infinit. Homebrew se instalează primul și, dacă
pică, restul se opresc (depind de el) în loc să înșire erori.

Windows: NEATINS, conform deciziei explicite. De portat doar cascada de hash
(câștigul algoritmic), fără `fts`, fără Canvas — marcat în `CHANGELOG.md`.

Versiune: 2.30.0 → **2.31.0** (MINOR, Regula 14).

## Etapa 2026-09-11 (2) — Rotița de așteptare: cauza reală și navigarea lipsă

Raportat de Cristi cu capturi, pe 2.31.0 INSTALATĂ (verificat, nu presupus —
`PlistBuddy` pe bundle-ul din `/Applications` confirma 2.31.0).

**Diagnostic**: `sample` pe procesul viu a arătat main thread-ul INACTIV
(`mach_msg_trap`, în așteptare de evenimente) — deci blocarea nu era o buclă
infinită, ci o sufocare temporară. Asta a dus direct la cauza corectă.

**CAUZA ROTIȚEI, în codul adăugat de mine cu o etapă înainte**: în faza de
hashing se emitea un eveniment de progres la FIECARE fișier. Fiecare traversează
spre `DuplicateFinderViewModel` (`@MainActor`), atinge un `@Published` și
declanșează o redesenare SwiftUI. Pe zeci de mii de fișiere = mii de redesenări
pe secundă. Scanarea rula corect în fundal; ceea ce bloca UI-ul era RAPORTAREA
ei. Fix: `EmitThrottle`, maximum 10 evenimente de progres pe secundă — peste ce
percepe ochiul ca „live", la o fracțiune din cost. Evenimentele `.group` și
`.finished` NU se limitează niciodată: acelea poartă rezultate, nu progres.

**Lecție**: „am mutat munca pe alt thread" nu e suficient. Un job de fundal care
raportează prea des blochează UI-ul la fel de sigur ca unul care rulează pe main
thread — costul s-a mutat din calcul în sincronizare.

**A doua problemă, reală și independentă**: în Analiză Disc, `indexingProgress`
era doar un spinner și un text, FĂRĂ niciun buton, iar `DiskAnalyzerViewModel`
n-avea deloc anulare. Odată pornită indexarea unui volum de 4 TB, userul rămânea
blocat acolo — nu putea reveni la lista de discuri, nu putea alege altul.
Breadcrumb-ul (buton înapoi + salt pe orice nivel) EXISTA deja, dar se afișa
doar după terminarea indexării (`vm.tree != nil`), deci nu ajuta deloc în
timpul ei.

Adăugat: `DiskScanEngine.requestCancel()` (flag sub `NSLock`, citit o dată la
512 intrări în bucla `fts` — nu la fiecare, ca să nu plătim un lock pe fiecare
fișier dintr-un milion) + `cancelIndexing()` în ViewModel + `ScanProgressView`
cu Stop în locul spinnerului.

**Detaliu care conta**: la anulare, `completion` primește un arbore PARȚIAL.
Fără garda adăugată, acesta ar fi fost salvat în cache și ar fi părut complet la
următoarea deschidere — mărimi greșite, fără niciun semn că sunt greșite.

**Testare — și o capcană în propriul test**: prima variantă bloca main thread-ul
cu `semaphore.wait()`, iar `completion` se întoarce prin
`DispatchQueue.main.async` → deadlock ÎN TEST, raportat ca „anularea nu
funcționează". Rescris cu așteptare asincronă: oprire în 0,01-0,04s după cerere.
Progresul raportat 0 fișiere în teste NU e un bug: `ProgressCounter` raportează
o dată pe secundă, iar testele durau sub o secundă.

Versiune: 2.31.0 → **2.31.1** (PATCH).

## Etapa 2026-09-11 (3) — Rotița, cauza ADEVĂRATĂ: cache de 2,4 GB decodat pe main thread

Cristi a raportat că rotița persistă pe 2.31.1. Etapa anterioară reparase o
cauză reală (flood de progres pe MainActor), dar NU pe asta — două defecte
diferite cu același simptom.

**Diagnostic, pe procesul viu**: `ps` arăta 99,9% CPU în stare R — deci de data
asta chiar o buclă de calcul, nu o sufocare de UI (spre deosebire de prima dată,
când main thread-ul era în `mach_msg_trap`). Distincția asta a orientat căutarea
corect din prima. `sample` a dat stiva completă:

```
DiskAnalyzerView.rootPicker (click pe disc)
  -> DiskAnalyzerViewModel.startIndexing(root:)   [DiskAnalyzerViewModel.swift:86]
    -> DiskCacheStore.SnapshotFile.init(from:)    [decodare plist]
```

**Cauza**: `DiskCacheStore.load` rula SINCRON, pe main thread, direct din
acțiunea butonului. Comentariul de deasupra promitea „încarcă INSTANT cache-ul
salvat (0 acces la disc dincolo de citirea unui singur fișier local **mic**)".

**Măsurat, nu presupus**: `ls -lahS` pe folderul de cache → **2,4 GB** un singur
fișier, 5,3 GB în total. Presupunerea „mic" din comentariu n-a fost niciodată
verificată pe date reale, iar pe un volum de 4 TB e falsă cu trei ordine de
mărime.

**Lecție**: un comentariu care afirmă o caracteristică de PERFORMANȚĂ („mic",
„instant", „ieftin") e o ipoteză până e măsurată. Aici ipoteza a trecut prin
review și a rămas în cod până a produs simptomul.

**Fixuri:**

1. **Încărcare pe thread de fundal**, cu `ScanProgressView` și Stop. Gardă
   `isLoadingCache`: dacă userul apasă Stop cât se încarcă, rezultatul sosit
   ulterior NU mai suprascrie ce a ales între timp.
2. **Compresie LZFSE** (`Compression`, nativ Apple) la salvare. Măsurat pe un
   arbore de 10.201 noduri: 1,2 MB → 536 KB (**2,3×**), salvare 0,076s,
   încărcare 0,095s.
3. **Compatibilitate cu cache-urile vechi** — necomprimate. Marcaj propriu
   `MMCPZ1` la începutul fișierului; un plist binar începe cu „bplist", deci
   formatele nu pot fi confundate. Fișierele vechi se citesc ca atare și se
   rescriu comprimat la următoarea scanare. **Testat explicit**, fiindcă o
   greșeală aici ar fi însemnat că fiecare user pierde cache-ul și rescanează
   ore întregi.
4. `Data(contentsOf:options: .mappedIfSafe)` — fișierul e mapat, nu copiat
   integral în RAM la citire.

**RĂMÂNE DE DECIS DE CRISTI (nu am luat decizia singur)**: cauza de fond e că
se stochează FIECARE fișier ca nod separat. Compresia reduce fișierul, dar la
încărcare arborele tot ajunge întreg în RAM. Reducerea reală ar cere agregarea
fișierelor mici (sub ~1 MB) într-un nod „alte fișiere" — câștig mare de memorie,
dar userul pierde vizibilitatea fișierelor mici în interfață. E o decizie de
produs, nu una tehnică.

Versiune: 2.31.1 → **2.31.2** (PATCH).

## Etapa 2026-09-11 (4) — Rotița, a TREIA cauză: layout SwiftUI pe zeci de mii de rânduri

**Trei cauze DISTINCTE, același simptom, raportat de Cristi de trei ori.**
Fiecare fix anterior a fost real și a reparat un defect real; niciunul nu era
cauza pe care o vedea el. Ordinea în care au ieșit la iveală:

1. **(2.31.1)** flood de evenimente de progres pe MainActor — sufocare de UI;
   main thread în `mach_msg_trap`, CPU normal.
2. **(2.31.2)** `DiskCacheStore.load` sincron pe main thread, pe un cache de
   2,4 GB — buclă de calcul; 99,9% CPU, RSS normal.
3. **(2.32.0)** layout SwiftUI — 99,8% CPU **ȘI 4,2 GB RSS**.

**Semnătura de resurse a fost de fiecare dată cheia diagnosticului.** `ps -o
%cpu,rss,state` înainte de `sample` a orientat căutarea corect din prima, de
fiecare dată. Un simptom identic pentru user („se învârte roata") a avut trei
semnături complet diferite la nivel de proces.

**Cauza a treia**: `entryList` folosea `VStack` + `ForEach` peste TOȚI copiii
folderului curent. `VStack` își dimensionează toți copiii deodată, la fiecare
redesenare — într-un folder cu zeci de mii de fișiere, zeci de mii de
`sizeThatFits` recursive. `sample` a dat stiva integral în `SwiftUICore`
(`StackLayout.placeChildren` → `sizeThatFits` → …), fără NICIUN cadru din codul
nostru — semnul clar că problema e în cum CEREM randarea, nu în ce calculăm.

**Fix 1**: `LazyVStack` — construiește doar rândurile vizibile.

**Fix 2 — agregarea fișierelor mici** (aprobată explicit de Cristi, decizie de
produs): în fiecare folder, fișierele sub 1 MB devin UN nod „Alte fișiere mici
(N)". Măsurat pe un arbore realist de volum video (100 proiecte × 5 clipuri mari
+ 400 fișiere mici): **40.601 → 701 noduri, −98,3%**, cu `sizeBytes` și
`totalFileCount` IDENTICE (verificat în test, nu presupus). Fișierele mari rămân
vizibile individual.

Detalii care contează:
- se agregă doar FIȘIERE, niciodată foldere — structura rămâne navigabilă;
- sub 2 fișiere mici nu se agregă: „Alte fișiere mici (1)" ar fi strict mai
  puțin informativ decât numele real;
- `aggregatedFileCount` păstrează numărul real, altfel totalul afișat ar scădea
  brusc și ar părea că s-au pierdut fișiere;
- nodul agregat n-are cale reală pe disc → UI-ul ascunde „Arată în Finder" și
  ștergerea pentru el;
- agregarea se aplică ȘI la încărcarea din cache, nu doar la scanare — userii cu
  cache vechi (neagregat) beneficiază imediat, fără rescanare.

**Lecție de proces, nu tehnică**: am raportat „rezolvat" de trei ori după ce am
reparat câte o cauză reală, fără confirmare pe hardware-ul lui Cristi. Testele
izolate nu reproduceau niciuna dintre cele trei — toate cereau volume reale de
date (4 TB, cache de 2,4 GB, foldere cu zeci de mii de fișiere). Ciclul care a
funcționat: Cristi raportează → `ps` + `sample` pe procesul VIU → cauză exactă
în două minute. Pentru simptome de performanță, măsurarea pe mașina reală nu e
un pas opțional de confirmare, e singura sursă de adevăr.

Versiune: 2.31.2 → **2.32.0** (MINOR — agregarea schimbă ce vede userul).

## Etapa 2026-09-20 — Distribuție DMG notarizat (Regula 45/K)
- `build_installer.sh` produce `dist/MasterControlStudioPro-<v>.dmg` + `MasterControlStudioPro.dmg` (pkg notarizat + ghid PDF); `codesigning/sign-and-notarize.sh dmg` semnează, notarizează, staple. Eliminat: `.zip` (Mac-Mac-<v>.zip) și `Dezinstalare_MacMasterControlPro.command`.
- Verificat pe v2.32.0: notarytool Accepted, `codesign --verify` valid, `spctl --type open --context context:primary-signature` accepted (Notarized Developer ID), după montare pkg-ul: semnat + `stapler validate` OK.
- `.pkg` rămâne fallback de Self-Updater (`SelfUpdater.swift` neschimbat, descarcă încă pkg-ul).
- **TODO/NEVERIFICAT**: dezinstalarea nu mai are `.command` — de mutat în aplicație (Regula 6 modificată de 45); DMG-ul nu a fost testat pe un Mac curat/cu SIP activ (Regula 42); GitHub Release nepublicat; site/`update.json` neatinse (link versionat, Regula 41).
