# Componente terțe

## Ce acoperă licența MIT

MIT se aplică codului sursă original al acestui repository. Nu se aplică: dependențelor terțe (vezi mai jos, fiecare cu licența ei), numelui „Master Control Studio Pro”, siglei, iconului și altor active de identitate GDC, componentelor comerciale externe sau altor materiale de la terți. Distribuțiile oficiale (DMG/installer semnat) sunt activate prin drepturi GDC; MIT permite modificarea și redistribuirea sursei, iar activarea ediției oficiale nu anulează aceste drepturi.

Nu există în acest repository chei private, certificate sau cod privat din core-ul comercial GDC. Verificat prin scanarea fișierelor urmărite.

## Dependențe
- Nicio dependență Swift Package Manager. Se folosesc doar framework-urile Apple din sistem (SwiftUI, AppKit, Security, CryptoKit, Compression, OSLog).
- Instrumente externe invocate la rulare, instalate separat de utilizator: rclone (MIT), macFUSE (licență proprie, instalat separat), Homebrew (BSD-2-Clause). Nu sunt incluse în acest repository.
- LicenseCore/MachineID: cod GDC propriu, format de serial compatibil în tot ecosistemul GDC; conține doar cheia publică de verificare.
