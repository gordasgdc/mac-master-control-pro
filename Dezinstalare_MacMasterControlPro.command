#!/usr/bin/env bash
#
# Dezinstalare_MacMasterControlPro.command
# Dezinstalare & curatare completa pentru Master Control Studio Pro.
#
# Bundle ID: com.gordasgdc.macmastercontrolpro (Info.plist).
#
# Rulare: dublu-click, sau click-dreapta -> Open (Terminal).
#
# NOTA: daca fisierul a fost descarcat separat (nu din arhiva .zip
# originala), poate avea flag-ul de quarantine si/sau bitul de executie
# lipsa - ruleaza intai:
#   xattr -d com.apple.quarantine Dezinstalare_MacMasterControlPro.command
#   chmod +x Dezinstalare_MacMasterControlPro.command

set -uo pipefail

BUNDLE_ID="com.gordasgdc.macmastercontrolpro"
APP_PATH="/Applications/Master Control Studio Pro.app"

echo "=================================================="
echo " Master Control Studio Pro — Dezinstalare & Curatare"
echo "=================================================="
echo ""

read -p "Sigur vrei sa stergi Master Control Studio Pro si TOATE datele lui (profil, licenta)? [y/N] " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "Anulat."
    exit 0
fi
echo ""

echo "[1/2] Opresc orice instanta ramasa in fundal..."
pkill -x "MacMasterControlPro" 2>/dev/null
pkill -f "Master Control Studio Pro.app" 2>/dev/null
sleep 1
echo "[+] Procese oprite."
echo ""

echo "[2/2] Sterg aplicatia si preferintele..."

remove_if_exists() {
    local path="$1"
    if [ ! -e "$path" ]; then
        return
    fi
    if rm -rf "$path" 2>/dev/null && [ ! -e "$path" ]; then
        echo "      - sters: $path"
        return
    fi
    echo "      - necesita permisiuni de administrator: $path"
    if sudo rm -rf "$path" && [ ! -e "$path" ]; then
        echo "      - sters (cu sudo): $path"
    else
        echo "      - EROARE: nu am putut sterge $path"
    fi
}

remove_if_exists "$APP_PATH"
defaults delete "$BUNDLE_ID" 2>/dev/null || true
remove_if_exists "$HOME/Library/Preferences/$BUNDLE_ID.plist"
remove_if_exists "$HOME/Library/Caches/$BUNDLE_ID"
remove_if_exists "$HOME/Library/Saved Application State/$BUNDLE_ID.savedState"

echo "[+] Fisiere sterse."
echo ""
echo "=================================================="
echo " [+] Curatare completa finalizata cu succes!"
echo "=================================================="
echo ""
read -p "Apasa Enter pentru a inchide fereastra..."
