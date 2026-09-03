# Genereaza 4 ghiduri PDF detaliate, per modul, pentru meniul Help:
# Mod Randare, Analiza Disc, Tweak-uri Sistem, Backup & Securitate.
# Stil identic cu generate_pdf.py (Arial, aceleasi culori/cover) - fisier
# separat, nu import, ca sa ramana autonom (acelasi motiv ca styling-ul
# din generate_pdf.py: repo-uri diferite copiaza acest tipar neschimbat).
#   pip install reportlab
#   python3 installer/generate_module_guides.py
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
APP_VERSION = "2.28.1"

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

cover_app_style = ParagraphStyle("CoverApp", fontName="Arial-Bold", fontSize=22, textColor=colors.white, leading=26)
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


def _content_canvas_factory(footer_text):
    def _content_canvas(canvas, doc):
        canvas.saveState()
        w, h = A4
        canvas.setFillColor(ACCENT)
        canvas.rect(0, h - 0.4 * cm, w, 0.4 * cm, fill=1, stroke=0)
        canvas.setFont("Arial", 8)
        canvas.setFillColor(FAINT)
        canvas.drawString(2 * cm, 1.2 * cm, footer_text)
        canvas.drawRightString(w - 2 * cm, 1.2 * cm, f"{canvas.getPageNumber()}")
        canvas.restoreState()
    return _content_canvas


def bullets(items):
    return ListFlowable(
        [ListItem(Paragraph(it, li_style), leftIndent=14) for it in items],
        bulletType="bullet", start="•", leftIndent=14, spaceBefore=2, spaceAfter=8,
    )


def note(text):
    return Paragraph(text, note_style)


def build_module_doc(guide_title, footer_text, sections, cover_sub, out_path):
    flow = []
    flow.append(Paragraph(guide_title, title_style))
    for sec in sections:
        flow.append(Paragraph(sec["h"], h2_style))
        if "intro" in sec:
            flow.append(Paragraph(sec["intro"], body_style))
        if "items" in sec:
            flow.append(bullets(sec["items"]))
        if "sub" in sec:
            for sub_h, sub_items in sec["sub"]:
                flow.append(Paragraph(sub_h, h3_style))
                flow.append(bullets(sub_items))
        if "note" in sec:
            flow.append(note(sec["note"]))
        if "body" in sec:
            flow.append(Paragraph(sec["body"], body_style))

    flow.append(Paragraph("Master Control Studio Pro — github.com/gordasgdc/mac-master-control-pro", footer_style))

    doc = SimpleDocTemplate(
        out_path, pagesize=A4,
        leftMargin=2 * cm, rightMargin=2 * cm, topMargin=2.2 * cm, bottomMargin=2.2 * cm,
    )
    story = [
        Spacer(1, 3.6 * cm),
        Paragraph(guide_title, cover_app_style),
        Paragraph(cover_sub, cover_sub_style),
        Spacer(1, 3.4 * cm),
        Paragraph(f"Versiunea {APP_VERSION}", cover_ver_style),
        PageBreak(),
    ]
    story.extend(flow)
    doc.build(story, onFirstPage=_cover_canvas, onLaterPages=_content_canvas_factory(footer_text))
    print("wrote", out_path)


# =====================================================================
# GHID 1: MOD RANDARE
# =====================================================================

RENDER_RO = dict(
    title="Ghid: Optimizare Mod Randare",
    footer="Master Control Studio Pro — Ghid Mod Randare",
    cover_sub="Ghid detaliat — Română",
    sections=[
        dict(h="Ce este Modul Randare",
             intro="Un export/randare lung (DaVinci Resolve, Final Cut Pro, Premiere Pro, After Effects, HandBrake și altele) concurează adesea cu procese de fundal ale macOS pentru același disc și același procesor — asta se traduce direct în randări mai lente sau întrerupte la mijloc. Modul Randare elimină cele 3 surse cele mai frecvente de contenție, dintr-un singur comutator."),
        dict(h="Ce face exact, sub capotă",
             items=[
                 "<b>Oprește indexarea Spotlight</b> (<font face=\"Courier\">mdutil -a -i off</font>) — Spotlight scanează continuu discul, inclusiv fișierele media NOI, scrise chiar în timp ce randezi, concurând pentru citire/scriere pe același disc.",
                 "<b>Pune pe pauză Time Machine</b> (<font face=\"Courier\">tmutil disable</font>) — un backup care pornește exact la mijlocul unui export lung poate satura discul și încetini totul brusc, fără avertisment.",
                 "<b>Ridică prioritatea CPU</b> (<font face=\"Courier\">renice -n -15</font>) pentru fiecare aplicație de randare detectată rulând acum — sistemul de operare le dă prioritate mai mare la CPU față de restul proceselor de fundal.",
             ]),
        dict(h="Aplicații recunoscute automat",
             intro="Modulul nu e limitat la DaVinci Resolve — verifică și optimizează TOATE aplicațiile din lista de mai jos care rulează chiar acum, simultan, nu doar prima găsită (util dacă, de exemplu, ai Premiere Pro ȘI Media Encoder pornite în același timp):",
             items=[
                 "DaVinci Resolve", "Final Cut Pro", "Compressor", "Motion",
                 "Adobe Premiere Pro", "Adobe Media Encoder", "Adobe After Effects",
                 "Logic Pro", "Blackmagic Fusion", "HandBrake",
             ],
             note="Secțiunea „Aplicații detectate acum” din ecranul Mod Randare arată, cu iconița oficială a fiecăreia, exact ce ar optimiza modulul dacă l-ai porni chiar în acest moment — se actualizează automat la fiecare 5 secunde."),
        dict(h="Cum se folosește",
             items=[
                 "Deschide <b>Mod Randare</b> din bara laterală și apasă comutatorul — o SINGURĂ cerere de parolă de administrator pentru tot lanțul de comenzi de mai sus.",
                 "Punctul verde + „Mod Randare ACTIV” confirmă că s-a aplicat cu succes.",
                 "Pornește randarea/exportul normal, din aplicația ta de editare — Modul Randare rulează în fundal, nu interferează cu nimic altceva.",
                 "După ce randarea se termină, revino în acest ecran și dezactivează comutatorul — Time Machine și Spotlight revin automat la normal.",
             ],
             note="<b>Important:</b> Time Machine și Spotlight rămân OPRITE cât timp comutatorul e activ, chiar dacă închizi aplicația de randare între timp — dezactivează manual când ai terminat, nu se reactivează singur."),
        dict(h="Ce NU face Modul Randare",
             items=[
                 "Nu oprește actualizări automate de sistem sau alte aplicații — doar Time Machine și indexarea Spotlight.",
                 "Nu modifică memoria RAM alocată — pentru asta, vezi modulul „Curățare & RAM”.",
                 "Prioritatea CPU (<font face=\"Courier\">renice</font>) nu e permanentă — dispare automat la repornirea aplicației de randare sau a Mac-ului, nu trebuie resetată manual.",
             ]),
    ],
)

RENDER_EN = dict(
    title="Guide: Render Mode Optimization",
    footer="Master Control Studio Pro — Render Mode Guide",
    cover_sub="Detailed guide — English",
    sections=[
        dict(h="What Render Mode is",
             intro="A long export/render (DaVinci Resolve, Final Cut Pro, Premiere Pro, After Effects, HandBrake and others) often competes with macOS background processes for the same disk and the same processor — this translates directly into slower or interrupted renders. Render Mode removes the 3 most common sources of contention with a single switch."),
        dict(h="What it does exactly, under the hood",
             items=[
                 "<b>Stops Spotlight indexing</b> (<font face=\"Courier\">mdutil -a -i off</font>) — Spotlight continuously scans the disk, including NEW media files being written while you render, competing for read/write on the same disk.",
                 "<b>Pauses Time Machine</b> (<font face=\"Courier\">tmutil disable</font>) — a backup starting right in the middle of a long export can saturate the disk and suddenly slow everything down, with no warning.",
                 "<b>Raises CPU priority</b> (<font face=\"Courier\">renice -n -15</font>) for every detected render application currently running — the OS gives them higher CPU priority over other background processes.",
             ]),
        dict(h="Automatically recognized applications",
             intro="The module isn't limited to DaVinci Resolve — it checks and optimizes ALL applications below that are running right now, simultaneously, not just the first one found (useful if, for example, you have Premiere Pro AND Media Encoder open at the same time):",
             items=[
                 "DaVinci Resolve", "Final Cut Pro", "Compressor", "Motion",
                 "Adobe Premiere Pro", "Adobe Media Encoder", "Adobe After Effects",
                 "Logic Pro", "Blackmagic Fusion", "HandBrake",
             ],
             note="The \"Detected applications now\" section on the Render Mode screen shows, with each app's official icon, exactly what the module would optimize if you turned it on right now — refreshed automatically every 5 seconds."),
        dict(h="How to use it",
             items=[
                 "Open <b>Render Mode</b> in the sidebar and tap the switch — a SINGLE administrator password prompt for the whole chain of commands above.",
                 "The green dot + \"Render Mode ACTIVE\" confirms it applied successfully.",
                 "Start your render/export normally, from your editing app — Render Mode runs in the background and doesn't interfere with anything else.",
                 "Once the render finishes, come back to this screen and turn the switch off — Time Machine and Spotlight return to normal automatically.",
             ],
             note="<b>Important:</b> Time Machine and Spotlight stay OFF as long as the switch is on, even if you close the render app in the meantime — turn it off manually when done, it does not re-enable itself."),
        dict(h="What Render Mode does NOT do",
             items=[
                 "It does not stop automatic system updates or other apps — only Time Machine and Spotlight indexing.",
                 "It does not change allocated RAM — for that, see the \"Cleanup & RAM\" module.",
                 "CPU priority (<font face=\"Courier\">renice</font>) is not permanent — it clears automatically when the render app or the Mac restarts, no manual reset needed.",
             ]),
    ],
)

RENDER_ES = dict(
    title="Guía: Optimización del Modo Renderizado",
    footer="Master Control Studio Pro — Guía Modo Renderizado",
    cover_sub="Guía detallada — Español",
    sections=[
        dict(h="Qué es el Modo Renderizado",
             intro="Una exportación/renderizado largo (DaVinci Resolve, Final Cut Pro, Premiere Pro, After Effects, HandBrake y otros) suele competir con los procesos en segundo plano de macOS por el mismo disco y el mismo procesador — esto se traduce directamente en renderizados más lentos o interrumpidos. El Modo Renderizado elimina las 3 causas más frecuentes de esta contención con un solo interruptor."),
        dict(h="Qué hace exactamente, por dentro",
             items=[
                 "<b>Detiene la indexación de Spotlight</b> (<font face=\"Courier\">mdutil -a -i off</font>) — Spotlight escanea continuamente el disco, incluidos los archivos multimedia NUEVOS escritos mientras renderizas, compitiendo por lectura/escritura en el mismo disco.",
                 "<b>Pausa Time Machine</b> (<font face=\"Courier\">tmutil disable</font>) — una copia de seguridad que comienza justo a mitad de una exportación larga puede saturar el disco y ralentizar todo de repente, sin previo aviso.",
                 "<b>Aumenta la prioridad de CPU</b> (<font face=\"Courier\">renice -n -15</font>) para cada aplicación de renderizado detectada en ejecución — el sistema les da mayor prioridad de CPU frente al resto de procesos en segundo plano.",
             ]),
        dict(h="Aplicaciones reconocidas automáticamente",
             intro="El módulo no se limita a DaVinci Resolve — verifica y optimiza TODAS las aplicaciones de la lista siguiente que estén en ejecución ahora mismo, simultáneamente, no solo la primera encontrada (útil si, por ejemplo, tienes Premiere Pro Y Media Encoder abiertos a la vez):",
             items=[
                 "DaVinci Resolve", "Final Cut Pro", "Compressor", "Motion",
                 "Adobe Premiere Pro", "Adobe Media Encoder", "Adobe After Effects",
                 "Logic Pro", "Blackmagic Fusion", "HandBrake",
             ],
             note="La sección «Aplicaciones detectadas ahora» de la pantalla Modo Renderizado muestra, con el icono oficial de cada una, exactamente qué optimizaría el módulo si lo activaras en este momento — se actualiza automáticamente cada 5 segundos."),
        dict(h="Cómo usarlo",
             items=[
                 "Abre <b>Modo Renderizado</b> en la barra lateral y pulsa el interruptor — UNA sola solicitud de contraseña de administrador para toda la cadena de comandos anterior.",
                 "El punto verde + «Modo Renderizado ACTIVO» confirma que se aplicó correctamente.",
                 "Inicia tu renderizado/exportación normalmente, desde tu aplicación de edición — el Modo Renderizado funciona en segundo plano y no interfiere con nada más.",
                 "Cuando termine el renderizado, vuelve a esta pantalla y desactiva el interruptor — Time Machine y Spotlight vuelven automáticamente a la normalidad.",
             ],
             note="<b>Importante:</b> Time Machine y Spotlight permanecen DESACTIVADOS mientras el interruptor esté activo, incluso si cierras la app de renderizado mientras tanto — desactívalo manualmente al terminar, no se reactiva solo."),
        dict(h="Qué NO hace el Modo Renderizado",
             items=[
                 "No detiene las actualizaciones automáticas del sistema ni otras apps — solo Time Machine y la indexación de Spotlight.",
                 "No modifica la RAM asignada — para eso, consulta el módulo «Limpieza y RAM».",
                 "La prioridad de CPU (<font face=\"Courier\">renice</font>) no es permanente — se restablece automáticamente al reiniciar la app de renderizado o el Mac, no requiere restablecimiento manual.",
             ]),
    ],
)

# =====================================================================
# GHID 2: ANALIZA DISC
# =====================================================================

DISK_RO = dict(
    title="Ghid: Analiză Disc",
    footer="Master Control Studio Pro — Ghid Analiză Disc",
    cover_sub="Ghid detaliat — Română",
    sections=[
        dict(h="Ce este Analiza de Disc",
             intro="Un explorator vizual de spațiu ocupat, în stilul DaisyDisk/GrandPerspective — arată exact ce foldere/fișiere ocupă cel mai mult spațiu pe un disc, cu drill-down instant în orice subfolder."),
        dict(h="Cum funcționează, sub capotă",
             items=[
                 "La alegerea unui disc/folder, aplicația <b>indexează O SINGURĂ DATĂ, complet, recursiv</b> — toate fișierele și subfolderele, la orice adâncime, într-o singură trecere.",
                 "Rezultatul e păstrat într-un <b>arbore în memorie</b> — fiecare folder știe deja mărimea sa totală (suma tuturor descendenților).",
                 "Odată indexarea terminată, intrarea în orice subfolder e <b>instantă (0 secunde)</b> — nu se mai citește discul din nou, se navighează prin arborele deja construit.",
                 "Arborele rămâne în memorie cât timp aplicația e deschisă — poți naviga înainte-înapoi oricât de mult, fără nicio rescanare.",
             ]),
        dict(h="Pas cu pas",
             items=[
                 "Deschide <b>Analiză Disc</b> din bara laterală.",
                 "Alege discul sau folderul de analizat din listă (volumul principal + orice disc extern conectat).",
                 "Așteaptă indexarea inițială — un contor viu arată câte fișiere s-au indexat până acum, ca să știi că aplicația lucrează, nu s-a blocat (poate dura de la câteva secunde la câteva minute, în funcție de câte fișiere are discul).",
                 "Odată terminată, apasă pe orice segment din bara colorată sau pe orice rând din listă pentru a intra în acel folder — instant.",
                 "Bara de sus (breadcrumb) arată calea completă parcursă — click pe orice nivel anterior pentru a reveni direct acolo.",
             ]),
        dict(h="Cum se citește bara proporțională",
             body="Fiecare segment colorat reprezintă un fișier sau folder de la nivelul curent, cu lățimea proporțională cu mărimea lui față de restul conținutului — segmentul cel mai lat e cel mai mare consumator de spațiu. Treci cu mouse-ul peste un segment pentru numele și mărimea exactă."),
        dict(h="Ștergerea unui fișier/folder",
             items=[
                 "Apasă iconița de coș lângă orice rând din listă.",
                 "Fișierul/folderul se mută la Coșul de gunoi al sistemului (recuperabil, nu ireversibil).",
                 "Dacă permisiunile refuză ștergerea normală, aplicația cere automat parola de administrator, o singură dată.",
                 "Arborele din memorie se actualizează instant după ștergere — mărimile ancestorilor scad corect, fără nicio rescanare.",
             ]),
    ],
)

DISK_EN = dict(
    title="Guide: Disk Analyzer",
    footer="Master Control Studio Pro — Disk Analyzer Guide",
    cover_sub="Detailed guide — English",
    sections=[
        dict(h="What Disk Analyzer is",
             intro="A visual explorer of used disk space, DaisyDisk/GrandPerspective-style — shows exactly which folders/files take up the most space on a disk, with instant drill-down into any subfolder."),
        dict(h="How it works, under the hood",
             items=[
                 "When you pick a disk/folder, the app <b>indexes it ONCE, completely, recursively</b> — every file and subfolder, at any depth, in a single pass.",
                 "The result is kept in an <b>in-memory tree</b> — every folder already knows its total size (the sum of all descendants).",
                 "Once indexing finishes, entering any subfolder is <b>instant (0 seconds)</b> — the disk is never read again, you navigate the already-built tree.",
                 "The tree stays in memory as long as the app is open — you can navigate back and forth as much as you like, with no rescanning.",
             ]),
        dict(h="Step by step",
             items=[
                 "Open <b>Disk Analyzer</b> in the sidebar.",
                 "Pick the disk or folder to analyze from the list (main volume + any connected external disk).",
                 "Wait for the initial indexing — a live counter shows how many files have been indexed so far, so you know the app is working, not stuck (can take from a few seconds to a few minutes depending on how many files the disk has).",
                 "Once done, tap any segment in the colored bar or any row in the list to enter that folder — instantly.",
                 "The top bar (breadcrumb) shows the full path taken — click any previous level to jump straight back there.",
             ]),
        dict(h="How to read the proportional bar",
             body="Each colored segment represents a file or folder at the current level, with a width proportional to its size relative to the rest of the content — the widest segment is the biggest space consumer. Hover over a segment for its exact name and size."),
        dict(h="Deleting a file/folder",
             items=[
                 "Tap the trash icon next to any row in the list.",
                 "The file/folder moves to the system Trash (recoverable, not permanent).",
                 "If permissions deny the normal delete, the app automatically asks for the administrator password, once.",
                 "The in-memory tree updates instantly after deletion — ancestor sizes decrease correctly, with no rescanning.",
             ]),
    ],
)

DISK_ES = dict(
    title="Guía: Analizador de Disco",
    footer="Master Control Studio Pro — Guía Analizador de Disco",
    cover_sub="Guía detallada — Español",
    sections=[
        dict(h="Qué es el Analizador de Disco",
             intro="Un explorador visual del espacio ocupado, al estilo DaisyDisk/GrandPerspective — muestra exactamente qué carpetas/archivos ocupan más espacio en un disco, con navegación instantánea a cualquier subcarpeta."),
        dict(h="Cómo funciona, por dentro",
             items=[
                 "Al elegir un disco/carpeta, la app <b>indexa UNA SOLA VEZ, por completo, de forma recursiva</b> — todos los archivos y subcarpetas, a cualquier profundidad, en una sola pasada.",
                 "El resultado se guarda en un <b>árbol en memoria</b> — cada carpeta ya conoce su tamaño total (la suma de todos sus descendientes).",
                 "Una vez terminada la indexación, entrar en cualquier subcarpeta es <b>instantáneo (0 segundos)</b> — el disco nunca se vuelve a leer, navegas por el árbol ya construido.",
                 "El árbol permanece en memoria mientras la app esté abierta — puedes navegar de un lado a otro tantas veces como quieras, sin volver a escanear.",
             ]),
        dict(h="Paso a paso",
             items=[
                 "Abre <b>Analizador de Disco</b> en la barra lateral.",
                 "Elige el disco o carpeta a analizar de la lista (volumen principal + cualquier disco externo conectado).",
                 "Espera la indexación inicial — un contador en vivo muestra cuántos archivos se han indexado hasta ahora, para que sepas que la app está funcionando, no bloqueada (puede tardar desde unos segundos hasta varios minutos según cuántos archivos tenga el disco).",
                 "Una vez terminada, pulsa cualquier segmento de la barra de colores o cualquier fila de la lista para entrar en esa carpeta — al instante.",
                 "La barra superior (ruta de navegación) muestra el camino completo recorrido — haz clic en cualquier nivel anterior para volver directamente allí.",
             ]),
        dict(h="Cómo leer la barra proporcional",
             body="Cada segmento de color representa un archivo o carpeta del nivel actual, con un ancho proporcional a su tamaño respecto al resto del contenido — el segmento más ancho es el que más espacio consume. Pasa el ratón sobre un segmento para ver su nombre y tamaño exactos."),
        dict(h="Eliminar un archivo/carpeta",
             items=[
                 "Pulsa el icono de papelera junto a cualquier fila de la lista.",
                 "El archivo/carpeta se mueve a la Papelera del sistema (recuperable, no definitivo).",
                 "Si los permisos deniegan el borrado normal, la app pide automáticamente la contraseña de administrador, una sola vez.",
                 "El árbol en memoria se actualiza al instante tras el borrado — los tamaños de los ancestros disminuyen correctamente, sin volver a escanear.",
             ]),
    ],
)

# =====================================================================
# GHID 3: TWEAK-URI SISTEM
# =====================================================================

TWEAKS_RO = dict(
    title="Ghid: Tweak-uri Sistem",
    footer="Master Control Studio Pro — Ghid Tweak-uri Sistem",
    cover_sub="Ghid detaliat — Română",
    sections=[
        dict(h="Finder avansat",
             intro="Un singur buton activează simultan 4 setări native macOS, utile pentru orice editor:",
             items=[
                 "Arată extensiile TUTUROR fișierelor (nu doar unele) — util ca să distingi „proiect.drp” de „proiect.drp.bak”.",
                 "Arată bara de cale (Path Bar) în josul ferestrelor Finder.",
                 "Arată bara de stare (Status Bar) — spațiu liber, număr de elemente.",
                 "Comută vizualizarea implicită pe listă (List View), cea mai densă pentru foldere cu multe fișiere.",
             ],
             note="Finder se repornește automat după aplicare — orice fereastră Finder deschisă se închide și se redeschide, e normal."),
        dict(h="Blocare .DS_Store pe discuri externe / USB",
             body="macOS scrie automat un fișier ascuns „.DS_Store” în orice folder deschis în Finder, ca să-și amintească aspectul lui (poziții de iconițe etc.). Pe discuri externe/USB partajate cu alte sisteme (Windows, alți colegi), aceste fișiere sunt inutile și pot deranja. Acest tweak dezactivează scrierea lor pe volume de rețea și USB — discurile tale externe rămân curate."),
        dict(h="Spotlight Shield — protecție per disc/folder",
             intro="Indexarea Spotlight pe discuri mari de proiect (video, arhive) poate consuma resurse fără rost — acest modul protejează selectiv orice disc extern sau folder ales manual.",
             items=[
                 "Bifează orice disc extern conectat sau folder adăugat manual (\"+ Adaugă foldere…\") pentru a-l proteja — se scrie un fișier marker „.metadata_never_index” în rădăcina lui, pe care Spotlight îl respectă și nu-l mai indexează.",
                 "Debifează oricând pentru a elimina protecția — markerul se șterge, indexarea normală reia.",
                 "Eticheta verde „Protejat” de lângă fiecare element arată clar starea reală, citită direct de pe disc (nu presupusă).",
                 "„Rescanează” reîmprospătă lista de discuri conectate acum + starea reală de protecție a fiecăruia.",
             ]),
        dict(h="Touch ID pentru comenzi sudo",
             intro="Activează Touch ID/parolă rapidă pentru comenzi de administrator (sudo) în Terminal — util dacă lucrezi des cu linia de comandă.",
             items=[
                 "Apasă „Activează Touch ID pentru comenzi sudo” — modifică fișierul de sistem <font face=\"Courier\">/etc/pam.d/sudo_local</font> (cere parola de administrator o singură dată).",
                 "După activare, repornește Terminal-ul ca să vezi promptul nou de Touch ID la următoarea comandă <font face=\"Courier\">sudo</font>.",
                 "Dacă activarea eșuează, apare automat un mic jurnal cu comanda exactă trimisă și răspunsul exact al sistemului — util pentru diagnosticare, poate fi copiat integral cu „Copiază tot”.",
             ]),
    ],
)

TWEAKS_EN = dict(
    title="Guide: System Tweaks",
    footer="Master Control Studio Pro — System Tweaks Guide",
    cover_sub="Detailed guide — English",
    sections=[
        dict(h="Advanced Finder",
             intro="One button turns on 4 native macOS settings at once, useful for any editor:",
             items=[
                 "Show file extensions for ALL files (not just some) — useful to tell \"project.drp\" apart from \"project.drp.bak\".",
                 "Show the Path Bar at the bottom of Finder windows.",
                 "Show the Status Bar — free space, item count.",
                 "Switch the default view to List View, the densest one for folders with many files.",
             ],
             note="Finder restarts automatically after applying — any open Finder window closes and reopens, that's expected."),
        dict(h="Block .DS_Store on external / USB drives",
             body="macOS automatically writes a hidden \".DS_Store\" file in every folder opened in Finder, to remember its appearance (icon positions etc.). On external/USB drives shared with other systems (Windows, other people), these files are useless and can be annoying. This tweak disables writing them on network and USB volumes — your external drives stay clean."),
        dict(h="Spotlight Shield — per-disk/folder protection",
             intro="Spotlight indexing on large project disks (video, archives) can waste resources for no reason — this module selectively protects any external disk or manually chosen folder.",
             items=[
                 "Check any connected external disk or manually added folder (\"+ Add folders…\") to protect it — a marker file \".metadata_never_index\" is written at its root, which Spotlight respects and no longer indexes it.",
                 "Uncheck at any time to remove protection — the marker is deleted, normal indexing resumes.",
                 "The green \"Protected\" badge next to each item clearly shows the real state, read directly from disk (never assumed).",
                 "\"Rescan\" refreshes the list of currently connected disks + each one's real protection state.",
             ]),
        dict(h="Touch ID for sudo commands",
             intro="Enables Touch ID/quick password for administrator (sudo) commands in Terminal — useful if you often work with the command line.",
             items=[
                 "Tap \"Enable Touch ID for sudo commands\" — modifies the system file <font face=\"Courier\">/etc/pam.d/sudo_local</font> (asks for the administrator password once).",
                 "After enabling, restart Terminal to see the new Touch ID prompt on the next <font face=\"Courier\">sudo</font> command.",
                 "If enabling fails, a small log automatically appears with the exact command sent and the system's exact response — useful for diagnosis, can be fully copied with \"Copy all\".",
             ]),
    ],
)

TWEAKS_ES = dict(
    title="Guía: Ajustes del Sistema",
    footer="Master Control Studio Pro — Guía Ajustes del Sistema",
    cover_sub="Guía detallada — Español",
    sections=[
        dict(h="Finder avanzado",
             intro="Un solo botón activa a la vez 4 ajustes nativos de macOS, útiles para cualquier editor:",
             items=[
                 "Muestra las extensiones de TODOS los archivos (no solo algunos) — útil para distinguir «proyecto.drp» de «proyecto.drp.bak».",
                 "Muestra la barra de ruta (Path Bar) en la parte inferior de las ventanas de Finder.",
                 "Muestra la barra de estado (Status Bar) — espacio libre, número de elementos.",
                 "Cambia la vista predeterminada a Lista (List View), la más densa para carpetas con muchos archivos.",
             ],
             note="Finder se reinicia automáticamente tras aplicar los cambios — cualquier ventana de Finder abierta se cierra y se vuelve a abrir, es normal."),
        dict(h="Bloquear .DS_Store en discos externos / USB",
             body="macOS escribe automáticamente un archivo oculto «.DS_Store» en cada carpeta abierta en Finder, para recordar su apariencia (posiciones de iconos, etc.). En discos externos/USB compartidos con otros sistemas (Windows, otras personas), estos archivos son inútiles y pueden molestar. Este ajuste desactiva su escritura en volúmenes de red y USB — tus discos externos permanecen limpios."),
        dict(h="Spotlight Shield — protección por disco/carpeta",
             intro="La indexación de Spotlight en discos de proyecto grandes (vídeo, archivos) puede desperdiciar recursos sin motivo — este módulo protege selectivamente cualquier disco externo o carpeta elegida manualmente.",
             items=[
                 "Marca cualquier disco externo conectado o carpeta añadida manualmente («+ Añadir carpetas…») para protegerlo — se escribe un archivo marcador «.metadata_never_index» en su raíz, que Spotlight respeta y deja de indexar.",
                 "Desmarca en cualquier momento para eliminar la protección — el marcador se borra, la indexación normal se reanuda.",
                 "La etiqueta verde «Protegido» junto a cada elemento muestra claramente el estado real, leído directamente del disco (nunca supuesto).",
                 "«Volver a escanear» actualiza la lista de discos conectados ahora + el estado real de protección de cada uno.",
             ]),
        dict(h="Touch ID para comandos sudo",
             intro="Activa Touch ID/contraseña rápida para comandos de administrador (sudo) en Terminal — útil si trabajas a menudo con la línea de comandos.",
             items=[
                 "Pulsa «Activar Touch ID para comandos sudo» — modifica el archivo de sistema <font face=\"Courier\">/etc/pam.d/sudo_local</font> (pide la contraseña de administrador una sola vez).",
                 "Tras activarlo, reinicia Terminal para ver el nuevo aviso de Touch ID en el próximo comando <font face=\"Courier\">sudo</font>.",
                 "Si la activación falla, aparece automáticamente un pequeño registro con el comando exacto enviado y la respuesta exacta del sistema — útil para diagnosticar, se puede copiar entero con «Copiar todo».",
             ]),
    ],
)

# =====================================================================
# GHID 4: BACKUP & SECURITATE
# =====================================================================

BACKUP_RO = dict(
    title="Ghid: Backup & Securitate",
    footer="Master Control Studio Pro — Ghid Backup & Securitate",
    cover_sub="Ghid detaliat — Română",
    sections=[
        dict(h="Notificare la final de randare",
             intro="Primești o alertă nativă macOS automat când coada de randare din DaVinci Resolve se termină (Terminat/Eșuat/Anulat) — util pentru randări care durează ore, ca să nu stai lângă Mac să aștepți.",
             items=[
                 "Activează comutatorul principal pentru notificarea nativă (apare ca orice alertă macOS obișnuită).",
                 "Bifează suplimentar „Trimite și pe email” ca alerta să-ți ajungă și pe telefon — completează Server SMTP, Port, Email expeditor, Parolă și Destinatar.",
                 "Recomandat: folosește o „parolă de aplicație” (App Password) Gmail/Outlook, NU parola reală a contului — parola se salvează local, în clar, pe acest Mac.",
                 "Apasă „Generează parolă Gmail”/„Generează parolă Outlook” pentru instrucțiuni ghidate de creare a acelei parole dedicate.",
                 "„Trimite email de test” confirmă că totul e configurat corect, înainte să te bazezi pe el la o randare reală.",
             ]),
        dict(h="Auditor Media Pool",
             body="„Scanează proiectul curent” citește (doar citire, nu modifică nimic) proiectul deschis chiar acum în DaVinci Resolve și semnalează clipurile ale căror fișiere sursă nu mai există pe disc (media offline) sau care apar de mai multe ori în Media Pool (duplicate) — util înainte de un backup sau o predare de proiect, ca să nu descoperi media lipsă abia la randarea finală."),
        dict(h="Sincronizare LUT-uri & Fusion între stații",
             intro="Urcă sau descarcă LUT-urile și macro-urile/șabloanele/script-urile Fusion printr-un cont Cloud deja configurat (din modulul Cloud Manager) — util dacă lucrezi pe mai multe stații de lucru și vrei aceleași preferințe peste tot.",
             items=[
                 "Bifează ce categorii vrei sincronizate: LUT-uri (.LUT), Fusion — Macro-uri, Fusion — Șabloane, Fusion — Script-uri.",
                 "Alege contul Cloud (deja adăugat în Cloud Manager) și direcția: „Urcă în Cloud” sau „Descarcă din Cloud”.",
                 "Apasă „Sincronizează”.",
             ],
             note="PowerGrade-urile NU sunt incluse aici — trăiesc în baza de date internă a proiectelor Resolve, nu ca fișiere separate pe disc."),
        dict(h="Backup bază de date proiecte",
             intro="Salvează o copie .zip completă a bazei de date de proiecte DaVinci Resolve (setări, culoare, structură — nu media în sine).",
             items=[
                 "Verifică dimensiunea reală a bazei de date, afișată direct pe ecran.",
                 "Apasă „Backup acum” — arhiva .zip se salvează local.",
             ],
             note="<b>Foarte important:</b> închide DaVinci Resolve ÎNAINTE de a face backup — o copiere „la cald”, cu Resolve deschis și baza de date activă, poate corupe arhiva rezultată."),
        dict(h="Resolve blocat (zombie)",
             body="Aplicația verifică automat dacă există un proces DaVinci Resolve rămas blocat (activ în fundal, dar fără nicio fereastră vizibilă — tipic după un crash) și oferă un buton de închidere forțată, ca să nu trebuiască să deschizi manual Activity Monitor."),
        dict(h="Securitate & Confidențialitate — ce înseamnă fiecare verificare",
             items=[
                 "<b>FileVault (criptare disc)</b> — criptează întregul disc de sistem; fără el, oricine scoate discul fizic din Mac poate citi datele direct.",
                 "<b>System Integrity Protection (SIP)</b> — protejează fișierele de sistem critice de modificări, chiar și cu drepturi de administrator; dezactivarea lui slăbește semnificativ securitatea generală a Mac-ului.",
                 "<b>Gatekeeper</b> — verifică semnătura digitală a oricărei aplicații înainte de prima lansare, blocând software nesemnat/necunoscut.",
                 "<b>Firewall</b> — blochează conexiuni de rețea nesolicitate către Mac-ul tău.",
                 "<b>XProtect</b> — antivirusul nativ, silențios, al Apple; verifică semnături de malware cunoscute la fiecare fișier descărcat.",
                 "<b>Parolă imediată la screensaver</b> — cere parola IMEDIAT ce pornește economizorul de ecran, nu după o întârziere — previne accesul neautorizat dacă lași Mac-ul nesupravegheat câteva secunde.",
             ]),
        dict(h="Acțiuni rapide, cu un click",
             items=[
                 "<b>„Activează Firewall + Stealth Mode”</b> — pornește firewall-ul ȘI face Mac-ul invizibil la ping-uri/scanări de rețea, dintr-o singură apăsare.",
                 "<b>„Cere parolă imediat la screensaver”</b> — setează întârzierea la 0 secunde, automat.",
             ]),
        dict(h="Ce NU se face automat, și de ce",
             body="Dezactivarea FileVault (cere confirmarea cheii de recuperare, manual), dezactivarea System Integrity Protection (necesită repornire în Recovery Mode, un proces intenționat greoi de Apple) și configurarea DNS/VPN/Tor (alegere strict personală, fără o variantă „corectă” universală) rămân decizii luate direct din System Settings — niciodată dintr-un singur buton al acestei aplicații. Riscul de a bloca sau expune Mac-ul fără să-ți dai seama e prea mare pentru o acțiune automată."),
    ],
)

BACKUP_EN = dict(
    title="Guide: Backup & Security",
    footer="Master Control Studio Pro — Backup & Security Guide",
    cover_sub="Detailed guide — English",
    sections=[
        dict(h="Render-finished notification",
             intro="Get a native macOS alert automatically when the DaVinci Resolve render queue finishes (Done/Failed/Canceled) — useful for renders that take hours, so you don't have to sit by the Mac waiting.",
             items=[
                 "Turn on the main switch for the native notification (appears like any regular macOS alert).",
                 "Additionally check \"Also send by email\" so the alert reaches your phone too — fill in SMTP Server, Port, Sender email, Password and Recipient.",
                 "Recommended: use an \"app password\" for Gmail/Outlook, NOT your real account password — the password is saved locally, in plain text, on this Mac.",
                 "Tap \"Generate Gmail password\"/\"Generate Outlook password\" for guided instructions to create that dedicated password.",
                 "\"Send test email\" confirms everything is configured correctly before you rely on it for a real render.",
             ]),
        dict(h="Media Pool Auditor",
             body="\"Scan current project\" reads (read-only, changes nothing) the project currently open in DaVinci Resolve and flags clips whose source files no longer exist on disk (offline media) or that appear more than once in the Media Pool (duplicates) — useful before a backup or project handoff, so you don't discover missing media only at final render."),
        dict(h="LUT & Fusion sync across workstations",
             intro="Upload or download LUTs and Fusion macros/templates/scripts through an already-configured Cloud account (from the Cloud Manager module) — useful if you work across multiple workstations and want the same preferences everywhere.",
             items=[
                 "Check which categories to sync: LUTs (.LUT), Fusion — Macros, Fusion — Templates, Fusion — Scripts.",
                 "Pick the Cloud account (already added in Cloud Manager) and the direction: \"Upload to Cloud\" or \"Download from Cloud\".",
                 "Tap \"Sync\".",
             ],
             note="PowerGrades are NOT included here — they live in Resolve's internal project database, not as separate files on disk."),
        dict(h="Project database backup",
             intro="Saves a full .zip copy of the DaVinci Resolve project database (settings, color, structure — not the media itself).",
             items=[
                 "Check the real database size, shown directly on screen.",
                 "Tap \"Backup now\" — the .zip archive is saved locally.",
             ],
             note="<b>Very important:</b> close DaVinci Resolve BEFORE backing up — a \"hot\" copy, with Resolve open and the database active, can corrupt the resulting archive."),
        dict(h="Stuck Resolve process (zombie)",
             body="The app automatically checks for a stuck DaVinci Resolve process (running in the background but with no visible window — typical after a crash) and offers a force-quit button, so you don't have to manually open Activity Monitor."),
        dict(h="Security & Privacy — what each check means",
             items=[
                 "<b>FileVault (disk encryption)</b> — encrypts the whole system disk; without it, anyone who physically removes the disk from the Mac can read the data directly.",
                 "<b>System Integrity Protection (SIP)</b> — protects critical system files from modification, even with administrator rights; disabling it significantly weakens overall Mac security.",
                 "<b>Gatekeeper</b> — checks the digital signature of any app before its first launch, blocking unsigned/unknown software.",
                 "<b>Firewall</b> — blocks unsolicited network connections to your Mac.",
                 "<b>XProtect</b> — Apple's native, silent antivirus; checks every downloaded file against known malware signatures.",
                 "<b>Password immediately at screensaver</b> — requires the password AS SOON AS the screensaver starts, not after a delay — prevents unauthorized access if you leave the Mac unattended for a few seconds.",
             ]),
        dict(h="One-click quick actions",
             items=[
                 "<b>\"Enable Firewall + Stealth Mode\"</b> — turns on the firewall AND makes the Mac invisible to network pings/scans, in one tap.",
                 "<b>\"Require password immediately at screensaver\"</b> — sets the delay to 0 seconds, automatically.",
             ]),
        dict(h="What is NOT done automatically, and why",
             body="Disabling FileVault (requires manual recovery-key confirmation), disabling System Integrity Protection (requires restarting into Recovery Mode, a deliberately heavyweight process by Apple), and configuring DNS/VPN/Tor (a strictly personal choice, with no universal \"correct\" answer) remain decisions made directly in System Settings — never from a single button in this app. The risk of locking yourself out or exposing the Mac without realizing it is too high for an automatic action."),
    ],
)

BACKUP_ES = dict(
    title="Guía: Copia de Seguridad y Seguridad",
    footer="Master Control Studio Pro — Guía Backup y Seguridad",
    cover_sub="Guía detallada — Español",
    sections=[
        dict(h="Notificación al terminar el renderizado",
             intro="Recibe una alerta nativa de macOS automáticamente cuando la cola de renderizado de DaVinci Resolve termina (Terminado/Fallido/Cancelado) — útil para renderizados que duran horas, para no tener que esperar junto al Mac.",
             items=[
                 "Activa el interruptor principal para la notificación nativa (aparece como cualquier alerta habitual de macOS).",
                 "Marca además «Enviar también por email» para que la alerta también llegue a tu teléfono — completa Servidor SMTP, Puerto, Email remitente, Contraseña y Destinatario.",
                 "Recomendado: usa una «contraseña de aplicación» de Gmail/Outlook, NO la contraseña real de la cuenta — la contraseña se guarda localmente, en texto plano, en este Mac.",
                 "Pulsa «Generar contraseña de Gmail»/«Generar contraseña de Outlook» para instrucciones guiadas para crear esa contraseña dedicada.",
                 "«Enviar email de prueba» confirma que todo está bien configurado antes de confiar en ello para un renderizado real.",
             ]),
        dict(h="Auditor de Media Pool",
             body="«Escanear proyecto actual» lee (solo lectura, no modifica nada) el proyecto abierto ahora mismo en DaVinci Resolve y señala los clips cuyos archivos de origen ya no existen en el disco (media offline) o que aparecen más de una vez en el Media Pool (duplicados) — útil antes de una copia de seguridad o entrega de proyecto, para no descubrir media faltante justo en el renderizado final."),
        dict(h="Sincronización de LUTs y Fusion entre estaciones",
             intro="Sube o descarga LUTs y macros/plantillas/scripts de Fusion mediante una cuenta Cloud ya configurada (desde el módulo Cloud Manager) — útil si trabajas en varias estaciones y quieres las mismas preferencias en todas partes.",
             items=[
                 "Marca qué categorías quieres sincronizar: LUTs (.LUT), Fusion — Macros, Fusion — Plantillas, Fusion — Scripts.",
                 "Elige la cuenta Cloud (ya añadida en Cloud Manager) y la dirección: «Subir a la Nube» o «Descargar de la Nube».",
                 "Pulsa «Sincronizar».",
             ],
             note="Los PowerGrades NO están incluidos aquí — viven en la base de datos interna de proyectos de Resolve, no como archivos separados en el disco."),
        dict(h="Copia de seguridad de la base de datos de proyectos",
             intro="Guarda una copia .zip completa de la base de datos de proyectos de DaVinci Resolve (ajustes, color, estructura — no el media en sí).",
             items=[
                 "Comprueba el tamaño real de la base de datos, mostrado directamente en pantalla.",
                 "Pulsa «Copia de seguridad ahora» — el archivo .zip se guarda localmente.",
             ],
             note="<b>Muy importante:</b> cierra DaVinci Resolve ANTES de hacer la copia de seguridad — una copia «en caliente», con Resolve abierto y la base de datos activa, puede corromper el archivo resultante."),
        dict(h="Proceso Resolve bloqueado (zombie)",
             body="La app verifica automáticamente si hay un proceso de DaVinci Resolve bloqueado (activo en segundo plano, pero sin ninguna ventana visible — típico tras un fallo) y ofrece un botón para forzar su cierre, para que no tengas que abrir manualmente el Monitor de Actividad."),
        dict(h="Seguridad y Privacidad — qué significa cada verificación",
             items=[
                 "<b>FileVault (cifrado de disco)</b> — cifra todo el disco del sistema; sin él, cualquiera que extraiga físicamente el disco del Mac puede leer los datos directamente.",
                 "<b>System Integrity Protection (SIP)</b> — protege los archivos críticos del sistema frente a modificaciones, incluso con derechos de administrador; desactivarlo debilita significativamente la seguridad general del Mac.",
                 "<b>Gatekeeper</b> — comprueba la firma digital de cualquier app antes de su primer inicio, bloqueando software sin firmar/desconocido.",
                 "<b>Firewall</b> — bloquea conexiones de red no solicitadas hacia tu Mac.",
                 "<b>XProtect</b> — el antivirus nativo y silencioso de Apple; comprueba cada archivo descargado contra firmas de malware conocidas.",
                 "<b>Contraseña inmediata al salvapantallas</b> — exige la contraseña EN CUANTO se activa el salvapantallas, no tras un retraso — evita el acceso no autorizado si dejas el Mac sin vigilancia unos segundos.",
             ]),
        dict(h="Acciones rápidas, con un clic",
             items=[
                 "<b>«Activar Firewall + Modo Sigiloso»</b> — activa el firewall Y hace el Mac invisible a pings/escaneos de red, con una sola pulsación.",
                 "<b>«Exigir contraseña inmediata al salvapantallas»</b> — establece el retraso en 0 segundos, automáticamente.",
             ]),
        dict(h="Qué NO se hace automáticamente, y por qué",
             body="Desactivar FileVault (requiere confirmación manual de la clave de recuperación), desactivar System Integrity Protection (requiere reiniciar en Modo de Recuperación, un proceso deliberadamente pesado de Apple) y configurar DNS/VPN/Tor (una elección estrictamente personal, sin una respuesta «correcta» universal) siguen siendo decisiones que se toman directamente en Ajustes del Sistema — nunca desde un solo botón de esta app. El riesgo de bloquear o exponer el Mac sin darte cuenta es demasiado alto para una acción automática."),
    ],
)

GUIDES = [
    ("Ghid_ModRandare", RENDER_RO, RENDER_EN, RENDER_ES),
    ("Ghid_AnalizaDisc", DISK_RO, DISK_EN, DISK_ES),
    ("Ghid_TweaksSistem", TWEAKS_RO, TWEAKS_EN, TWEAKS_ES),
    ("Ghid_BackupSecuritate", BACKUP_RO, BACKUP_EN, BACKUP_ES),
]

if __name__ == "__main__":
    out_dir = HERE  # installer/ — acelasi loc ca Instructiuni_Utilizare_*.pdf, de unde build_installer.sh le copiaza in Contents/Resources
    for base_name, ro, en, es in GUIDES:
        for suffix, data in (("RO", ro), ("EN", en), ("ES", es)):
            out_path = os.path.join(out_dir, f"{base_name}_{suffix}.pdf")
            build_module_doc(data["title"], data["footer"], data["sections"], data["cover_sub"], out_path)
