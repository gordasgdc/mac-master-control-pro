#!/usr/bin/env bash
# Creeaza (doar daca lipseste) fisierul necomis cu valorile OAuth, GOL: cum se compileaza ediția comunitară dintr-un clone curat.
# Ediția oficială îl generează din GDC_GOOGLE_DRIVE_CLIENT_ID/SECRET (build_installer.sh). Nu suprascrie niciodată un fișier existent.
set -euo pipefail
F="$(cd "$(dirname "$0")/.." && pwd)/Sources/MacMasterControlProCore/GDCOAuthSecrets.generated.swift"
[ -f "$F" ] && exit 0
cat > "$F" <<'SWIFT'
// Stub gol (ediția comunitară): clientul Google rapid GDC rămâne dezactivat. NU se comite în git.
enum GDCOAuthSecretsGenerated {
    static let googleDriveClientID = ""
    static let googleDriveClientSecret = ""
}
SWIFT
