# Ghid intern — onboarding client nou pentru Google Drive (Cloud Manager)

**Doar pentru Cristi — NU se distribuie clienților.** Explică ce trebuie
făcut manual de tine, o dată per client nou, ca să poată folosi Google
Drive din Cloud Manager (Master Control Studio Pro) fără să vadă vreun
pas din Google Cloud Console.

## Context (de ce e nevoie de acest pas)

Aplicația folosește deja, embedded în cod (`CloudManagerService.swift`,
`GDCOAuthClients`), un client OAuth Google propriu — clientul NU mai
folosește clientul partajat al rclone-ului (limitat agresiv de Google la
viteză mică per fișier). Clientul final nu trebuie să facă NIMIC din
Google Cloud Console — doar deschide Cloud Manager, apasă "+ Adaugă cont",
Google Drive, se loghează normal cu contul lui.

**SINGURA problemă**: proiectul Google Cloud al acestui client OAuth e
încă în modul **"Testing"** (nu "In Production") — Google permite conectarea
DOAR conturilor adăugate explicit ca "test user", limită 100 de conturi.
Fără acest pas, clientul primește o eroare de tipul "Access blocked: this
app's request is invalid" / "app not verified" la login.

## Pasul obligatoriu, la FIECARE client nou

1. Cere clientului adresa exactă de Gmail (sau contul Google Workspace) pe
   care vrea să-l folosească pentru Google Drive.
2. Loghează-te pe **console.cloud.google.com** cu contul Google pe care ai
   creat proiectul (verifică în bara de sus a consolei — numele proiectului
   e cel folosit la crearea clientului OAuth, vezi `client_id` din
   `GDCOAuthClients.swift`, prefixul numeric `91447189992-...` identifică
   proiectul dacă ai dubii).
3. Link direct: **console.cloud.google.com/auth/audience** (dacă întreabă,
   alege proiectul corect din selectorul de sus). Sau navigare manuală:
   **APIs & Services → OAuth consent screen** → fila **"Audience"** (sau
   "Público" dacă interfața e în spaniolă) → secțiunea **"Test users"**.
4. Apasă **"+ Add users"**, lipește adresa de email a clientului, **Save**.
5. Abia ACUM spune-i clientului să deschidă Cloud Manager și să adauge
   contul — va funcționa din prima încercare.

**Durează sub 1 minut per client.** Fă-l ÎNAINTE ca el să încerce să se
conecteze, nu după ce raportează eroarea.

## Limită & ce faci când te apropii de 100 de clienți

Google permite maxim 100 de "test users" cât timp aplicația e în modul
Testing. Când te apropii de acest prag, ai două variante:

- **Treci aplicația "In Production"** (din același ecran, OAuth consent
  screen) — elimină limita de 100, dar clienții văd un ecran de avertizare
  Google ("Google hasn't verified this app") la prima conectare; tot pot
  continua (buton "Advanced" → "Go to [app] (unsafe)"), dar arată
  neprofesionist pentru un client mai puțin tehnic.
- **Verificare oficială Google** — elimină și avertizarea, dar poate dura
  săptămâni și, pentru scope-ul "Drive" (acces complet, clasificat
  "restricted" de Google), poate cere o evaluare de securitate (CASA),
  posibil costisitoare. De luat în calcul doar dacă ecosistemul crește mult.

**Recomandare practică**: rămâi pe "Testing" + adăugare manuală cât timp
numărul de clienți activi pe Google Drive rămâne sub ~80-90 (marjă de
siguranță), reevaluează abia atunci.

## Dacă un client vrea totuși propriul lui client Google (rar, opțional)

Există și varianta ca un client tehnic să-și facă propriul client OAuth
(nu trece prin al tău deloc) — pașii compleți sunt deja în PDF-ul de
utilizare (`Instructiuni_Utilizare_RO/EN/ES.pdf`, secțiunea "Upload lent pe
Google Drive?"). Nu trebuie să faci nimic tu în acest caz — clientul e
complet independent.
