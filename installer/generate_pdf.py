# Genereaza Instructiuni_Utilizare_{RO,EN,ES}.pdf pentru Mac Master Control
# Pro, cu reportlab. Necesita `pip install reportlab pypdf` intr-un venv.
#   python3 installer/generate_pdf.py
# Arial (nu Helvetica standard-14) pentru diacritice romanesti (ș/ț).
import os
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import cm
from reportlab.lib import colors
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, ListFlowable, ListItem, PageBreak
)

HERE = os.path.dirname(os.path.abspath(__file__))
APP_VERSION = "2.7.0"

pdfmetrics.registerFont(TTFont("Arial", "/System/Library/Fonts/Supplemental/Arial.ttf"))
pdfmetrics.registerFont(TTFont("Arial-Bold", "/System/Library/Fonts/Supplemental/Arial Bold.ttf"))
pdfmetrics.registerFont(TTFont("Arial-Italic", "/System/Library/Fonts/Supplemental/Arial Italic.ttf"))
styles = getSampleStyleSheet()
ACCENT = colors.HexColor("#D98A3D")
INK_DARK = colors.HexColor("#1A1108")
MUTED = colors.HexColor("#6a6a6a")
FAINT = colors.HexColor("#8a8a8a")
NOTE_BG = colors.HexColor("#fdf3e7")
NOTE_BORDER = colors.HexColor("#D98A3D")

cover_app_style = ParagraphStyle("CoverApp", fontName="Arial-Bold", fontSize=25, textColor=colors.white, leading=29)
cover_sub_style = ParagraphStyle("CoverSub", fontName="Arial", fontSize=13, textColor=colors.HexColor("#F2B766"), spaceBefore=6)
cover_ver_style = ParagraphStyle("CoverVer", fontName="Arial", fontSize=10, textColor=colors.HexColor("#c7cbd1"), spaceBefore=4)
title_style = ParagraphStyle("TitleGDC", parent=styles["Title"], fontName="Arial-Bold",
                              fontSize=19, leading=22, spaceAfter=2, textColor=colors.HexColor("#1a1a1a"))
subtitle_style = ParagraphStyle("Subtitle", parent=styles["Normal"], fontName="Arial",
                                 fontSize=11, textColor=MUTED, spaceAfter=20)
h2_style = ParagraphStyle("H2", parent=styles["Heading2"], fontName="Arial-Bold",
                           fontSize=13, textColor=ACCENT, spaceBefore=16, spaceAfter=6)
h3_style = ParagraphStyle("H3", parent=styles["Heading3"], fontName="Arial-Bold",
                           fontSize=11, textColor=colors.HexColor("#1a1a1a"), spaceBefore=10, spaceAfter=4)
body_style = ParagraphStyle("Body", parent=styles["Normal"], fontName="Arial",
                             fontSize=10.5, leading=15, textColor=colors.HexColor("#1a1a1a"), spaceAfter=6)
li_style = ParagraphStyle("Li", parent=body_style, spaceAfter=4)
note_style = ParagraphStyle("Note", parent=body_style, backColor=NOTE_BG,
                             borderColor=NOTE_BORDER, borderWidth=0, leftIndent=10, fontSize=10)
footer_style = ParagraphStyle("Footer", parent=styles["Normal"], fontName="Arial",
                               fontSize=8.5, textColor=FAINT, spaceBefore=20)


def _cover_canvas(canvas, doc):
    canvas.saveState()
    w, h = A4
    band_h = 8.5 * cm
    canvas.setFillColor(INK_DARK)
    canvas.rect(0, h - band_h, w, band_h, fill=1, stroke=0)
    canvas.setFillColor(ACCENT)
    canvas.rect(0, h - band_h - 0.18 * cm, w, 0.18 * cm, fill=1, stroke=0)
    canvas.restoreState()


def _content_canvas(canvas, doc):
    canvas.saveState()
    w, h = A4
    canvas.setFillColor(ACCENT)
    canvas.rect(0, h - 0.4 * cm, w, 0.4 * cm, fill=1, stroke=0)
    canvas.setFont("Arial", 8)
    canvas.setFillColor(FAINT)
    canvas.drawString(2 * cm, 1.2 * cm, "Master Control Studio Pro — Ghid de utilizare")
    canvas.drawRightString(w - 2 * cm, 1.2 * cm, f"{canvas.getPageNumber()}")
    canvas.restoreState()


def bullets(items):
    return ListFlowable(
        [ListItem(Paragraph(it, li_style), leftIndent=14) for it in items],
        bulletType="bullet", start="•", leftIndent=14, spaceBefore=2, spaceAfter=8,
    )


def note(text):
    return Paragraph(text, note_style)


def build_doc(lang_data, out_path):
    flow = []
    flow.append(Paragraph("Master Control Studio Pro", title_style))
    flow.append(Paragraph(lang_data["subtitle"], subtitle_style))

    flow.append(Paragraph(lang_data["h_install"], h2_style))
    flow.append(bullets(lang_data["install"]))

    flow.append(Paragraph(lang_data["h_deps"], h2_style))
    flow.append(Paragraph(lang_data["deps_intro"], body_style))
    flow.append(bullets(lang_data["deps"]))
    flow.append(note(lang_data["deps_note"]))

    flow.append(Paragraph(lang_data["h_modules"], h2_style))
    flow.append(bullets(lang_data["modules"]))

    flow.append(Paragraph(lang_data["h_cloud"], h2_style))
    flow.append(Paragraph(lang_data["cloud_intro"], body_style))
    flow.append(bullets(lang_data["cloud_setup"]))
    flow.append(Paragraph(lang_data["cloud_mount_h"], h3_style))
    flow.append(bullets(lang_data["cloud_mount"]))
    flow.append(Paragraph(lang_data["cloud_files_h"], h3_style))
    flow.append(bullets(lang_data["cloud_files"]))
    flow.append(Paragraph(lang_data["cloud_sync_h"], h3_style))
    flow.append(bullets(lang_data["cloud_sync"]))
    flow.append(note(lang_data["cloud_note"]))

    flow.append(Paragraph(lang_data["h_trial"], h2_style))
    flow.append(Paragraph(lang_data["trial_intro"], body_style))
    flow.append(bullets(lang_data["trial"]))
    flow.append(note(lang_data["trial_note"]))

    flow.append(Paragraph(lang_data["h_update"], h2_style))
    flow.append(Paragraph(lang_data["update_body"], body_style))

    flow.append(Paragraph(lang_data["h_uninstall"], h2_style))
    flow.append(Paragraph(lang_data["uninstall"], body_style))

    flow.append(Paragraph(lang_data["h_support"], h2_style))
    flow.append(Paragraph(lang_data["support"], body_style))

    flow.append(Paragraph("Master Control Studio Pro — github.com/gordasgdc/mac-master-control-pro", footer_style))

    doc = SimpleDocTemplate(
        out_path, pagesize=A4,
        leftMargin=2 * cm, rightMargin=2 * cm, topMargin=2.2 * cm, bottomMargin=2.2 * cm,
    )
    story = [
        Spacer(1, 3.4 * cm),
        Paragraph("Master Control Studio Pro", cover_app_style),
        Paragraph(lang_data["cover_sub"], cover_sub_style),
        Spacer(1, 3.2 * cm),
        Paragraph(f"Versiunea {APP_VERSION}", cover_ver_style),
        PageBreak(),
    ]
    story.extend(flow)
    doc.build(story, onFirstPage=_cover_canvas, onLaterPages=_content_canvas)
    print("wrote", out_path)


RO = dict(
    cover_sub="Ghid de utilizare — Română",
    subtitle="Instrucțiuni de instalare și utilizare — Română",
    h_install="1. Instalare",
    install=[
        "Descarcă și dezarhivează <b>MacMasterControlPro-Mac.zip</b> de pe gordas.dev/mac-master-control-pro sau din secțiunea Releases de pe GitHub.",
        "Dublu-click pe <b>MacMasterControlPro.pkg</b> — pachet semnat și notarizat oficial de Apple, se instalează direct, fără avertismente Gatekeeper.",
        "Urmează pașii instalatorului. Va trebui să accepți Termenii și Condițiile pentru a continua.",
        "Aplicația se instalează automat în folderul Applications.",
    ],
    h_deps="2. Panoul de Dependențe",
    deps_intro="Modulul „Dependențe” din bara laterală arată dacă Homebrew, Rclone și macFUSE sunt instalate — necesare pentru modulul Cloud Manager.",
    deps=[
        "🟢 <b>verde</b> = instalat și funcțional.",
        "🔴 <b>roșu</b> = lipsește — apasă „Instalează Dependențele Lipsă” și aplicația le instalează automat prin Homebrew, fără să deschizi Terminal.",
        "Dacă <b>Homebrew</b> lipsește (prima instalare pe un Mac nou), apasă butonul dedicat — se deschide o fereastră Terminal cu scriptul oficial deja scris: apasă Enter, introdu parola de Mac (invizibilă la tastare) și apasă Enter din nou.",
    ],
    deps_note="<b>Notă:</b> nu ai nevoie de Homebrew/Rclone/macFUSE decât dacă vrei să folosești Cloud Manager — restul modulelor funcționează fără ele.",
    h_modules="3. Modulele aplicației",
    modules=[
        "<b>Rețea</b> — optimizare Gigabit/TCP la un click (necesită licență pentru aplicare).",
        "<b>Cloud Manager</b> — adaugă conturi cloud, montează-le ca discuri, urcă/descarcă/sincronizează fișiere — vezi ghidul detaliat de mai jos (secțiunea 4).",
        "<b>Curățare & RAM</b> — „Analizează” arată spațiul recuperabil gratuit; curățarea efectivă necesită licență.",
        "<b>Tweak-uri Sistem</b> — Finder avansat, blocare .DS_Store, Touch ID pentru sudo, protecție Spotlight pe un folder ales.",
        "<b>Rosetta Inspector</b> — arată ce aplicații Intel mai ai; eliminarea Rosetta cere confirmare explicită (ireversibilă pentru acele aplicații).",
        "<b>Setări</b> — temă Sistem/Luminos/Întunecat, Mărime text, Limbă (Română/English/Español), profil (Nume/Email).",
    ],
    h_cloud="4. Cloud Manager — Ghid Complet",
    cloud_intro="Cloud Manager transformă contul tău de stocare online (Google Drive, Dropbox, OneDrive, pCloud, Mega, S3, WebDAV, SFTP, FTP) într-un disc pe care poți lucra ca și cu unul local — fără browser, fără upload manual din pagina web a providerului.",
    cloud_setup=[
        "Din bara laterală, deschide <b>Cloud Manager</b> și apasă „+ Adaugă cont”.",
        "Dă-i un nume (ex: „drive_personal”), alege providerul din listă și apasă „Adaugă”.",
        "Pentru Google Drive/Dropbox/OneDrive/pCloud se deschide automat browser-ul o singură dată, ca să te autentifici — flux standard, sigur, gestionat de Rclone.",
        "Pentru S3/WebDAV/SFTP/FTP completează câmpurile cerute (server, utilizator, parolă/cheie) direct în formular.",
    ],
    cloud_mount_h="Montare — accesezi fișierele ca pe un disc",
    cloud_mount=[
        "Apasă „Montează” lângă contul dorit — apare un folder nou (implicit pe Desktop) prin care vezi și modifici fișierele direct din Finder, exact ca pe orice disc extern.",
        "<b>Locație de montare</b>: dacă SSD-ul intern e mic, apasă „Alege folder…” din secțiunea „Locație montare” și selectează un disc extern (Thunderbolt/USB-C) — toate conturile viitoare se montează acolo. „Resetează” revine la Desktop.",
        "<b>Statistici live</b>: cât timp un cont e montat și se transferă date, sub numele contului apare viteza curentă, cât s-a transferat și câte transferuri sunt active — actualizat automat la 2 secunde.",
        "Apasă „Deschide” pentru a deschide direct în Finder folderul montat, sau „Demontează” când ai terminat.",
    ],
    cloud_files_h="Urcare, descărcare și ștergere — fără montare",
    cloud_files=[
        "Apasă „Explorează” lângă un cont pentru a-i vedea conținutul instant, FĂRĂ să-l montezi — util pentru o verificare rapidă.",
        "<b>Urcare</b>: în fereastra de explorare, apasă „⬆︎ Încarcă fișiere aici…”, alege unul sau mai multe fișiere/foldere de pe Mac — se urcă direct în folderul curent de pe cloud, cu progresul afișat live în panoul de jos.",
        "<b>Descărcare</b>: selectează un fișier/folder din listă, apasă „⬇︎ Descarcă selecția”, alege unde pe Mac să ajungă.",
        "<b>Ștergere</b>: selectează, apasă „🗑 Șterge selecția” — cere confirmare explicită, e ireversibil.",
        "<b>Navigare</b>: dublu-click pe un folder pentru a intra în el, „⬅︎ Înapoi” pentru a ieși.",
    ],
    cloud_sync_h="Sincronizare — un folder întreg dintr-o dată",
    cloud_sync=[
        "Din fereastra de explorare, apasă „🔄 Sincronizare folder…”.",
        "Alege folderul local, direcția (Local → Cloud sau Cloud → Local) și apasă „Pornește sincronizarea”.",
        "Implicit, sincronizarea doar <b>adaugă/actualizează</b> — nu șterge nimic la destinație, oricât de multe ori o rulezi.",
        "Bifează „Oglindă exactă” DOAR dacă vrei ca destinația să arate identic cu sursa — acest mod ȘTERGE la destinație orice nu mai există la sursă (ireversibil).",
    ],
    cloud_note="<b>Notă:</b> toate acțiunile de mai sus (montare, urcare, descărcare, sincronizare) necesită licență activă — analizele/explorarea rămân libere.",
    h_trial="5. Trial și licență (donație)",
    trial_intro="Toate analizele și scanările sunt <b>complet libere</b>, nelimitat. Doar acțiunile care modifică efectiv sistemul cer o licență activă.",
    trial=[
        "La prima acțiune de scriere, apare o fereastră cu Machine ID-ul tău (buton de copiere) și un buton „Donează din GDC Plugin Manager” (17€, donație unică de susținere).",
        "După ce primești codul, lipește-l în același ecran și apasă „Activează”.",
    ],
    trial_note="<b>Important:</b> codul e legat de acest calculator — dacă schimbi Mac-ul, ai nevoie de un cod nou pentru noul Machine ID.",
    h_update="6. Actualizări automate",
    update_body="La lansare, aplicația verifică dacă există o versiune nouă. Dacă da, apare un pop-up cu „Actualizează acum” (descarcă și instalează automat, cerând doar parola de administrator — niciodată nu ajungi pe pagina GitHub) și „Mai târziu” (amână, reapare la următoarea versiune).",
    h_uninstall="7. Dezinstalare",
    uninstall="Rulează <b>Dezinstalare_MacMasterControlPro.command</b> din arhiva descărcată — șterge aplicația și toate preferințele.",
    h_support="8. Suport",
    support="Pentru orice întrebare, deschide un Issue pe GitHub (github.com/gordasgdc/mac-master-control-pro) sau scrie pe canalul de contact GDC.",
)

EN = dict(
    cover_sub="User Guide — English",
    subtitle="Installation and usage instructions — English",
    h_install="1. Installation",
    install=[
        "Download and unzip <b>MacMasterControlPro-Mac.zip</b> from gordas.dev/mac-master-control-pro or the GitHub Releases section.",
        "Double-click <b>MacMasterControlPro.pkg</b> — a package officially signed and notarized by Apple, installs directly with no Gatekeeper warnings.",
        "Follow the installer steps. You'll need to accept the Terms and Conditions to continue.",
        "The app installs automatically into the Applications folder.",
    ],
    h_deps="2. Dependencies Panel",
    deps_intro="The \"Dependencies\" module in the sidebar shows whether Homebrew, Rclone and macFUSE are installed — needed for the Cloud Manager module.",
    deps=[
        "🟢 <b>green</b> = installed and working.",
        "🔴 <b>red</b> = missing — tap \"Install Missing Dependencies\" and the app installs them automatically via Homebrew, no Terminal needed.",
        "If <b>Homebrew</b> is missing (first install on a new Mac), tap the dedicated button — a Terminal window opens with the official script already typed: press Enter, type your Mac password (hidden while typing), press Enter again.",
    ],
    deps_note="<b>Note:</b> you only need Homebrew/Rclone/macFUSE if you want to use Cloud Manager — the other modules work without them.",
    h_modules="3. App Modules",
    modules=[
        "<b>Network</b> — one-click Gigabit/TCP tuning (requires a license to apply).",
        "<b>Cloud Manager</b> — add cloud accounts, mount them as drives, upload/download/sync files — see the detailed guide below (section 4).",
        "<b>Cleanup & RAM</b> — \"Analyze\" shows reclaimable space for free; actual cleanup requires a license.",
        "<b>System Tweaks</b> — advanced Finder, block .DS_Store, Touch ID for sudo, Spotlight protection on a chosen folder.",
        "<b>Rosetta Inspector</b> — shows which Intel apps you still have; removing Rosetta requires explicit confirmation (irreversible for those apps).",
        "<b>Settings</b> — System/Light/Dark theme, Text Size, Language (Română/English/Español), profile (Name/Email).",
    ],
    h_cloud="4. Cloud Manager — Full Guide",
    cloud_intro="Cloud Manager turns your online storage account (Google Drive, Dropbox, OneDrive, pCloud, Mega, S3, WebDAV, SFTP, FTP) into a drive you can work with like a local one — no browser, no manual upload from the provider's website.",
    cloud_setup=[
        "From the sidebar, open <b>Cloud Manager</b> and tap \"+ Add account\".",
        "Give it a name (e.g. \"drive_personal\"), pick the provider from the list, and tap \"Add\".",
        "For Google Drive/Dropbox/OneDrive/pCloud, your browser opens automatically once to sign in — standard, secure flow handled by Rclone.",
        "For S3/WebDAV/SFTP/FTP, fill in the required fields (server, username, password/key) directly in the form.",
    ],
    cloud_mount_h="Mounting — access files like a drive",
    cloud_mount=[
        "Tap \"Mount\" next to the desired account — a new folder appears (on the Desktop by default) where you view and edit files directly in Finder, exactly like any external drive.",
        "<b>Mount location</b>: if your internal SSD is small, tap \"Choose folder…\" in the \"Mount location\" section and pick an external drive (Thunderbolt/USB-C) — all future accounts mount there. \"Reset\" goes back to Desktop.",
        "<b>Live stats</b>: while an account is mounted and transferring data, its current speed, total transferred, and active transfers appear below its name — auto-refreshed every 2 seconds.",
        "Tap \"Open\" to open the mounted folder directly in Finder, or \"Unmount\" when done.",
    ],
    cloud_files_h="Upload, download and delete — no mounting needed",
    cloud_files=[
        "Tap \"Browse\" next to an account to see its contents instantly, WITHOUT mounting it — useful for a quick check.",
        "<b>Upload</b>: in the browser window, tap \"⬆︎ Upload files here…\", pick one or more files/folders from your Mac — they upload directly into the current cloud folder, with live progress shown below.",
        "<b>Download</b>: select a file/folder from the list, tap \"⬇︎ Download selection\", pick where on your Mac it should go.",
        "<b>Delete</b>: select it, tap \"🗑 Delete selection\" — requires explicit confirmation, it's irreversible.",
        "<b>Navigation</b>: double-click a folder to enter it, \"⬅︎ Back\" to exit.",
    ],
    cloud_sync_h="Sync — a whole folder at once",
    cloud_sync=[
        "From the browser window, tap \"🔄 Sync folder…\".",
        "Pick the local folder, the direction (Local → Cloud or Cloud → Local), and tap \"Start sync\".",
        "By default, syncing only <b>adds/updates</b> — it never deletes at the destination, no matter how many times you run it.",
        "Check \"Exact mirror\" ONLY if you want the destination to look identical to the source — this mode DELETES at the destination anything no longer present at the source (irreversible).",
    ],
    cloud_note="<b>Note:</b> all actions above (mounting, uploading, downloading, syncing) require an active license — analysis/browsing remain free.",
    h_trial="5. Trial and license (donation)",
    trial_intro="All analyses and scans are <b>completely free</b>, unlimited. Only actions that actually modify the system require an active license.",
    trial=[
        "On the first write action, a window appears with your Machine ID (copy button) and a \"Donate via GDC Plugin Manager\" button (17€, one-time support donation).",
        "Once you receive the code, paste it into the same screen and tap \"Activate\".",
    ],
    trial_note="<b>Important:</b> the code is tied to this computer — if you switch Macs, you'll need a new code for the new Machine ID.",
    h_update="6. Automatic updates",
    update_body="On launch, the app checks for a newer version. If found, a pop-up appears with \"Update now\" (downloads and installs automatically, only asking for your admin password — you never land on the GitHub page) and \"Later\" (postpones, reappears on the next version).",
    h_uninstall="7. Uninstalling",
    uninstall="Run <b>Dezinstalare_MacMasterControlPro.command</b> from the downloaded archive — it removes the app and all preferences.",
    h_support="8. Support",
    support="For any question, open an Issue on GitHub (github.com/gordasgdc/mac-master-control-pro) or message the GDC contact channel.",
)

ES = dict(
    cover_sub="Guía de usuario — Español",
    subtitle="Instrucciones de instalación y uso — Español",
    h_install="1. Instalación",
    install=[
        "Descarga y descomprime <b>MacMasterControlPro-Mac.zip</b> desde gordas.dev/mac-master-control-pro o la sección Releases de GitHub.",
        "Doble clic en <b>MacMasterControlPro.pkg</b> — paquete firmado y notarizado oficialmente por Apple, se instala directamente sin avisos de Gatekeeper.",
        "Sigue los pasos del instalador. Deberás aceptar los Términos y Condiciones para continuar.",
        "La app se instala automáticamente en la carpeta Aplicaciones.",
    ],
    h_deps="2. Panel de Dependencias",
    deps_intro="El módulo \"Dependencias\" en la barra lateral muestra si Homebrew, Rclone y macFUSE están instalados — necesarios para el módulo Cloud Manager.",
    deps=[
        "🟢 <b>verde</b> = instalado y funcionando.",
        "🔴 <b>rojo</b> = falta — pulsa \"Instalar Dependencias Faltantes\" y la app las instala automáticamente vía Homebrew, sin necesidad de Terminal.",
        "Si falta <b>Homebrew</b> (primera instalación en un Mac nuevo), pulsa el botón dedicado — se abre una ventana de Terminal con el script oficial ya escrito: pulsa Enter, escribe tu contraseña de Mac (oculta al escribir), pulsa Enter de nuevo.",
    ],
    deps_note="<b>Nota:</b> solo necesitas Homebrew/Rclone/macFUSE si quieres usar Cloud Manager — los demás módulos funcionan sin ellos.",
    h_modules="3. Módulos de la app",
    modules=[
        "<b>Red</b> — optimización Gigabit/TCP con un clic (requiere licencia para aplicar).",
        "<b>Cloud Manager</b> — añade cuentas cloud, móntalas como discos, sube/descarga/sincroniza archivos — ver la guía detallada abajo (sección 4).",
        "<b>Limpieza y RAM</b> — \"Analizar\" muestra el espacio recuperable gratis; la limpieza real requiere licencia.",
        "<b>Ajustes del Sistema</b> — Finder avanzado, bloqueo de .DS_Store, Touch ID para sudo, protección Spotlight en una carpeta elegida.",
        "<b>Inspector Rosetta</b> — muestra qué apps Intel aún tienes; eliminar Rosetta requiere confirmación explícita (irreversible para esas apps).",
        "<b>Ajustes</b> — tema Sistema/Claro/Oscuro, Tamaño de texto, Idioma (Română/English/Español), perfil (Nombre/Correo).",
    ],
    h_cloud="4. Cloud Manager — Guía Completa",
    cloud_intro="Cloud Manager convierte tu cuenta de almacenamiento en línea (Google Drive, Dropbox, OneDrive, pCloud, Mega, S3, WebDAV, SFTP, FTP) en un disco con el que trabajas como si fuera local — sin navegador, sin subida manual desde la web del proveedor.",
    cloud_setup=[
        "Desde la barra lateral, abre <b>Cloud Manager</b> y pulsa \"+ Añadir cuenta\".",
        "Dale un nombre (ej. \"drive_personal\"), elige el proveedor de la lista y pulsa \"Añadir\".",
        "Para Google Drive/Dropbox/OneDrive/pCloud se abre el navegador automáticamente una sola vez, para iniciar sesión — flujo estándar y seguro gestionado por Rclone.",
        "Para S3/WebDAV/SFTP/FTP completa los campos requeridos (servidor, usuario, contraseña/clave) directamente en el formulario.",
    ],
    cloud_mount_h="Montaje — accede a los archivos como un disco",
    cloud_mount=[
        "Pulsa \"Montar\" junto a la cuenta deseada — aparece una carpeta nueva (por defecto en el Escritorio) donde ves y editas archivos directamente en Finder, igual que en cualquier disco externo.",
        "<b>Ubicación de montaje</b>: si el SSD interno es pequeño, pulsa \"Elegir carpeta…\" en la sección \"Ubicación de montaje\" y selecciona un disco externo (Thunderbolt/USB-C) — todas las cuentas futuras se montarán allí. \"Restablecer\" vuelve al Escritorio.",
        "<b>Estadísticas en vivo</b>: mientras una cuenta está montada y transfiriendo datos, debajo de su nombre aparece la velocidad actual, lo transferido y cuántas transferencias están activas — se actualiza automáticamente cada 2 segundos.",
        "Pulsa \"Abrir\" para abrir directamente en Finder la carpeta montada, o \"Desmontar\" cuando termines.",
    ],
    cloud_files_h="Subir, descargar y eliminar — sin montar",
    cloud_files=[
        "Pulsa \"Explorar\" junto a una cuenta para ver su contenido al instante, SIN montarla — útil para una comprobación rápida.",
        "<b>Subida</b>: en la ventana de exploración, pulsa \"⬆︎ Subir archivos aquí…\", elige uno o varios archivos/carpetas de tu Mac — se suben directamente a la carpeta actual en la nube, con el progreso en vivo abajo.",
        "<b>Descarga</b>: selecciona un archivo/carpeta de la lista, pulsa \"⬇︎ Descargar selección\", elige dónde en tu Mac debe llegar.",
        "<b>Eliminar</b>: selecciónalo, pulsa \"🗑 Eliminar selección\" — pide confirmación explícita, es irreversible.",
        "<b>Navegación</b>: doble clic en una carpeta para entrar, \"⬅︎ Atrás\" para salir.",
    ],
    cloud_sync_h="Sincronización — una carpeta entera de una vez",
    cloud_sync=[
        "Desde la ventana de exploración, pulsa \"🔄 Sincronizar carpeta…\".",
        "Elige la carpeta local, la dirección (Local → Nube o Nube → Local) y pulsa \"Iniciar sincronización\".",
        "Por defecto, la sincronización solo <b>añade/actualiza</b> — nunca elimina nada en el destino, sin importar cuántas veces la ejecutes.",
        "Marca \"Espejo exacto\" SOLO si quieres que el destino se vea idéntico al origen — este modo ELIMINA en el destino todo lo que ya no existe en el origen (irreversible).",
    ],
    cloud_note="<b>Nota:</b> todas las acciones anteriores (montar, subir, descargar, sincronizar) requieren una licencia activa — el análisis/exploración siguen siendo gratis.",
    h_trial="5. Prueba y licencia (donación)",
    trial_intro="Todos los análisis y escaneos son <b>completamente gratuitos</b>, sin límite. Solo las acciones que modifican realmente el sistema requieren una licencia activa.",
    trial=[
        "En la primera acción de escritura, aparece una ventana con tu Machine ID (botón de copiar) y un botón \"Donar desde GDC Plugin Manager\" (17€, donación única de apoyo).",
        "Cuando recibas el código, pégalo en la misma pantalla y pulsa \"Activar\".",
    ],
    trial_note="<b>Importante:</b> el código está vinculado a este ordenador — si cambias de Mac, necesitarás un código nuevo para el nuevo Machine ID.",
    h_update="6. Actualizaciones automáticas",
    update_body="Al iniciar, la app comprueba si hay una versión más reciente. Si la hay, aparece una ventana con \"Actualizar ahora\" (descarga e instala automáticamente, solo pidiendo tu contraseña de administrador — nunca llegas a la página de GitHub) y \"Más tarde\" (pospone, reaparece en la siguiente versión).",
    h_uninstall="7. Desinstalación",
    uninstall="Ejecuta <b>Dezinstalare_MacMasterControlPro.command</b> desde el archivo descargado — elimina la app y todas las preferencias.",
    h_support="8. Soporte",
    support="Para cualquier pregunta, abre un Issue en GitHub (github.com/gordasgdc/mac-master-control-pro) o escribe al canal de contacto GDC.",
)

if __name__ == "__main__":
    build_doc(RO, os.path.join(HERE, "Instructiuni_Utilizare_RO.pdf"))
    build_doc(EN, os.path.join(HERE, "Instructiuni_Utilizare_EN.pdf"))
    build_doc(ES, os.path.join(HERE, "Instructiuni_Utilizare_ES.pdf"))
