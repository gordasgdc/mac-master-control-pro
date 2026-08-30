# Genereaza GHID_INTERN_ONBOARDING_GOOGLE_DRIVE.pdf - DOAR pentru Cristi,
# NU se distribuie clientilor, NU face parte din build_installer.sh.
# Reutilizeaza stilurile din generate_pdf.py. Ruleaza:
#   python3 installer/generate_internal_pdf.py
import os
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import cm
from reportlab.lib import colors
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, ListFlowable, ListItem
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(os.path.dirname(HERE), "GHID_INTERN_ONBOARDING_GOOGLE_DRIVE.pdf")

pdfmetrics.registerFont(TTFont("Arial", "/System/Library/Fonts/Supplemental/Arial.ttf"))
pdfmetrics.registerFont(TTFont("Arial-Bold", "/System/Library/Fonts/Supplemental/Arial Bold.ttf"))
styles = getSampleStyleSheet()
ACCENT = colors.HexColor("#D98A3D")
INK_DARK = colors.HexColor("#1A1108")
MUTED = colors.HexColor("#6a6a6a")
FAINT = colors.HexColor("#8a8a8a")
NOTE_BG = colors.HexColor("#fdf3e7")
LINK = colors.HexColor("#1a56db")

cover_app_style = ParagraphStyle("CoverApp", fontName="Arial-Bold", fontSize=22, textColor=colors.white, leading=27)
cover_sub_style = ParagraphStyle("CoverSub", fontName="Arial", fontSize=12, textColor=colors.HexColor("#F2B766"), spaceBefore=6)
title_style = ParagraphStyle("TitleGDC", fontName="Arial-Bold", fontSize=17, leading=21, spaceAfter=2, textColor=colors.HexColor("#1a1a1a"))
subtitle_style = ParagraphStyle("Subtitle", fontName="Arial", fontSize=10.5, textColor=MUTED, spaceAfter=18)
h2_style = ParagraphStyle("H2", fontName="Arial-Bold", fontSize=12.5, textColor=ACCENT, spaceBefore=16, spaceAfter=6)
body_style = ParagraphStyle("Body", fontName="Arial", fontSize=10.5, leading=15.5, textColor=colors.HexColor("#1a1a1a"), spaceAfter=6)
li_style = ParagraphStyle("Li", parent=body_style, spaceAfter=5)
note_style = ParagraphStyle("Note", parent=body_style, backColor=NOTE_BG, leftIndent=10, fontSize=10)

def link(url, label=None):
    label = label or url
    return f'<a href="{url}"><font color="#1a56db"><u>{label}</u></font></a>'

def bullets(items):
    return ListFlowable(
        [ListItem(Paragraph(it, li_style), leftIndent=14) for it in items],
        bulletType="bullet", start="•", leftIndent=14, spaceBefore=2, spaceAfter=8,
    )

def note(text):
    return Paragraph(text, note_style)

def _cover_canvas(canvas, doc):
    canvas.saveState()
    w, h = A4
    band_h = 7.5 * cm
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
    canvas.drawString(2 * cm, 1.2 * cm, "DOAR INTERN — nu se distribuie clienților")
    canvas.drawRightString(w - 2 * cm, 1.2 * cm, f"{canvas.getPageNumber()}")
    canvas.restoreState()

flow = [
    Paragraph("Onboarding client — Google Drive", title_style),
    Paragraph("Ghid intern, doar pentru Cristi", subtitle_style),

    Paragraph("Context", h2_style),
    Paragraph(
        "Aplicația folosește, ca opțiune (comutator „Folosește client Google rapid (GDC)” "
        "în Cloud Manager, dezactivat implicit), un client OAuth Google propriu — evită "
        "limitarea de viteză pe care Google o aplică clientului partajat al rclone-ului. "
        f"Comutatorul e OFF implicit tocmai ca niciun client neconfigurat de tine să nu "
        f"rămână blocat la conectare.", body_style),
    note(
        "<b>Important:</b> cât timp proiectul Google e în modul „Testing”, DOAR conturile "
        "adăugate manual ca „test user” se pot conecta prin acest client — orice alt cont "
        "primește un ecran de BLOCAJ TOTAL („Access blocked”), fără nicio opțiune de a "
        "continua. Nu e doar un avertisment ignorabil."),

    Paragraph("Pasul obligatoriu, la fiecare client care vrea viteză GDC", h2_style),
    bullets([
        "Cere clientului adresa exactă de Gmail (sau contul Google Workspace) pe care vrea să-l folosească pentru Google Drive.",
        f"Loghează-te pe {link('https://console.cloud.google.com', 'console.cloud.google.com')} cu contul Google pe care ai creat proiectul "
        "(verifică selectorul de proiect din bara de sus — clientul OAuth folosit are ID-ul cu prefixul "
        "<font face=\"Courier\">91447189992-...</font>).",
        f"Link direct: {link('https://console.cloud.google.com/auth/audience', 'console.cloud.google.com/auth/audience')} "
        "(alege proiectul corect dacă întreabă). Sau navigare manuală: <b>APIs &amp; Services → OAuth consent screen</b> "
        "→ fila „Audience” („Público” în spaniolă) → secțiunea „Test users”.",
        "Apasă „+ Add users”, lipește adresa de email a clientului, „Save”.",
        "Spune-i clientului să deschidă Cloud Manager → „+ Adaugă cont” → Google Drive, să activeze comutatorul "
        "„Folosește client Google rapid (GDC)” și să se conecteze — va funcționa din prima încercare.",
    ]),
    note("Durează sub 1 minut per client. Fă-l ÎNAINTE ca el să încerce să se conecteze, nu după ce raportează eroarea."),

    Paragraph("Limită & ce faci când te apropii de 100 de clienți", h2_style),
    Paragraph(
        "Google permite maxim 100 de „test users” cât timp aplicația e în modul Testing. "
        "Când te apropii de acest prag, ai două variante:", body_style),
    bullets([
        "<b>Treci aplicația „In Production”</b> (din același ecran, OAuth consent screen) — elimină limita de 100, "
        "dar clienții văd un ecran de avertizare Google („Google hasn't verified this app”) la prima conectare; "
        "tot pot continua (buton „Advanced” → „Go to [app] (unsafe)”), dar arată neprofesionist pentru un client "
        "mai puțin tehnic.",
        "<b>Verificare oficială Google</b> — elimină și avertizarea, dar poate dura săptămâni și, pentru scope-ul "
        "„Drive” (acces complet, clasificat „restricted” de Google), poate cere o evaluare de securitate (CASA), "
        "posibil costisitoare. De luat în calcul doar dacă ecosistemul crește mult.",
    ]),
    note("Recomandare practică: rămâi pe „Testing” + adăugare manuală cât timp numărul de clienți activi pe "
         "Google Drive rămâne sub ~80-90 (marjă de siguranță), reevaluează abia atunci."),

    Paragraph("Dacă un client vrea totuși propriul lui client Google (rar, opțional)", h2_style),
    Paragraph(
        "Există și varianta ca un client tehnic să-și facă propriul client OAuth (independent de limita de 100, "
        "nu trece deloc prin al tău). Pașii compleți sunt deja în PDF-ul public de utilizare "
        "(<i>Instructiuni_Utilizare_RO/EN/ES.pdf</i>, secțiunea „Upload lent pe Google Drive?”). "
        "Nu trebuie să faci nimic tu în acest caz — clientul e complet independent.", body_style),
]

doc = SimpleDocTemplate(
    OUT, pagesize=A4,
    leftMargin=2 * cm, rightMargin=2 * cm, topMargin=2.2 * cm, bottomMargin=2.2 * cm,
)
story = [
    Spacer(1, 2.8 * cm),
    Paragraph("Onboarding Google Drive", cover_app_style),
    Paragraph("Ghid intern — doar Cristi", cover_sub_style),
    Spacer(1, 3.0 * cm),
] + flow
doc.build(story, onFirstPage=_cover_canvas, onLaterPages=_content_canvas)
print("wrote", OUT)
