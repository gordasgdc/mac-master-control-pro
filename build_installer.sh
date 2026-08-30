#!/usr/bin/env bash
# Builds "Master Control Studio Pro.app" apoi il impacheteaza intr-un .pkg
# semnat + notarizat, cu panou de licenta (Regula 19).
set -euo pipefail
cd "$(dirname "$0")"

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Info.plist)
PKG_ID="com.gordasgdc.macmastercontrolpro.installer"
APP_NAME="Master Control Studio Pro.app"
DIST_DIR="dist"
PAYLOAD_ROOT="$DIST_DIR/payload"
COMPONENT_PKG="$DIST_DIR/MacMasterControlPro-component.pkg"
FINAL_PKG="$DIST_DIR/MacMasterControlPro-$VERSION.pkg"

# Garda impotriva dist/ detinut de root (Regula 23).
if [ -d "$DIST_DIR" ] && ! [ -w "$DIST_DIR" ] || find "$DIST_DIR" -maxdepth 2 -user root -print -quit 2>/dev/null | grep -q .; then
    echo "EROARE: 'dist/' contine fisiere detinute de root. Ruleaza manual:" >&2
    echo "    sudo rm -rf \$(pwd)/dist" >&2
    exit 1
fi

# Genereaza GDCOAuthSecrets.generated.swift din variabila de mediu (Regula
# 2 - zero secrete in git), la fel ca APPLE_SIGN_IDENTITY_APP pentru
# semnare. Fallback sigur (stringuri goale) daca variabila lipseste -
# comutatorul "client rapid GDC" din Cloud Manager ramane OFF implicit,
# deci lipsa clientului nu sparge nimic, doar dezactiveaza optiunea.
SECRETS_FILE="Sources/MacMasterControlProCore/GDCOAuthSecrets.generated.swift"
if [ -z "${GDC_GOOGLE_DRIVE_CLIENT_SECRET:-}" ] && [ ! -f "$SECRETS_FILE" ]; then
    echo "AVERTISMENT: GDC_GOOGLE_DRIVE_CLIENT_SECRET nesetata si '$SECRETS_FILE' nu exista - clientul Google Drive rapid GDC va fi dezactivat in acest build (comutatorul din Cloud Manager va ramane fara efect)." >&2
fi
if [ -n "${GDC_GOOGLE_DRIVE_CLIENT_SECRET:-}" ]; then
    cat > "$SECRETS_FILE" <<SWIFTEOF
// GENERAT AUTOMAT de build_installer.sh - NU se comite in git.
enum GDCOAuthSecretsGenerated {
    static let googleDriveClientID = "${GDC_GOOGLE_DRIVE_CLIENT_ID:-}"
    static let googleDriveClientSecret = "${GDC_GOOGLE_DRIVE_CLIENT_SECRET}"
}
SWIFTEOF
elif [ ! -f "$SECRETS_FILE" ]; then
    cat > "$SECRETS_FILE" <<'SWIFTEOF'
// GENERAT AUTOMAT de build_installer.sh - NU se comite in git.
enum GDCOAuthSecretsGenerated {
    static let googleDriveClientID = ""
    static let googleDriveClientSecret = ""
}
SWIFTEOF
fi

echo "==> Building app…"
swift build -c release --product MacMasterControlPro
BUILD_OUT="/tmp/Master Control Studio Pro.app.build-$$"
rm -rf "$BUILD_OUT"
mkdir -p "$BUILD_OUT/Contents/MacOS" "$BUILD_OUT/Contents/Resources"
cp .build/release/MacMasterControlPro "$BUILD_OUT/Contents/MacOS/MacMasterControlPro"
cp Info.plist "$BUILD_OUT/Contents/Info.plist"
cp AppIcon.icns "$BUILD_OUT/Contents/Resources/AppIcon.icns"
for pdf in installer/Instructiuni_Utilizare_RO.pdf installer/Instructiuni_Utilizare_EN.pdf installer/Instructiuni_Utilizare_ES.pdf; do
    if [ -f "$pdf" ]; then cp "$pdf" "$BUILD_OUT/Contents/Resources/"; fi
done

if [ -n "${APPLE_SIGN_IDENTITY_APP:-}" ]; then
    ./codesigning/sign-and-notarize.sh app "$BUILD_OUT"
else
    echo "AVERTISMENT: APPLE_SIGN_IDENTITY_APP nesetat - semnez ad-hoc (pachetul final va ramane nesemnat)."
    codesign --force --deep --sign - "$BUILD_OUT"
fi

rm -rf "$DIST_DIR"
mkdir -p "$PAYLOAD_ROOT/Applications"
cp -R "$BUILD_OUT" "$PAYLOAD_ROOT/Applications/$APP_NAME"
rm -rf "$BUILD_OUT"

echo "==> Building component package…"
pkgbuild \
    --root "$PAYLOAD_ROOT" \
    --identifier "$PKG_ID" \
    --version "$VERSION" \
    --install-location "/" \
    --scripts "installer/scripts" \
    "$COMPONENT_PKG"

echo "==> Writing distribution definition…"
cat > "$DIST_DIR/Distribution.xml" << EOF
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="1">
    <title>Master Control Studio Pro $VERSION</title>
    <license file="License.txt" mime-type="text/plain"/>
    <options customize="never" require-scripts="false" rootVolumeOnly="true"/>
    <domains enable_localSystem="true"/>
    <choices-outline>
        <line choice="default">
            <line choice="$PKG_ID"/>
        </line>
    </choices-outline>
    <choice id="default"/>
    <choice id="$PKG_ID" visible="false">
        <pkg-ref id="$PKG_ID"/>
    </choice>
    <pkg-ref id="$PKG_ID" version="$VERSION" onConclusion="none">MacMasterControlPro-component.pkg</pkg-ref>
</installer-gui-script>
EOF

cp installer/License.txt "$DIST_DIR/License.txt"

echo "==> Building final installer package…"
productbuild \
    --distribution "$DIST_DIR/Distribution.xml" \
    --package-path "$DIST_DIR" \
    --resources "$DIST_DIR" \
    "$FINAL_PKG"

rm -rf "$PAYLOAD_ROOT" "$COMPONENT_PKG"

./codesigning/sign-and-notarize.sh pkg "$FINAL_PKG"

cp "$FINAL_PKG" "$DIST_DIR/MacMasterControlPro.pkg"

echo "==> Copying uninstaller…"
cp "Dezinstalare_MacMasterControlPro.command" "$DIST_DIR/Dezinstalare_MacMasterControlPro.command"
chmod +x "$DIST_DIR/Dezinstalare_MacMasterControlPro.command"

echo "==> Building MacMasterControlPro-Mac.zip (pkg + uninstaller + instructiuni RO)…"
ZIP_STAGE="$DIST_DIR/zip_stage"
rm -rf "$ZIP_STAGE"
mkdir -p "$ZIP_STAGE"
cp "$DIST_DIR/MacMasterControlPro.pkg" "$ZIP_STAGE/"
cp "installer/Instructiuni_Utilizare_RO.pdf" "$ZIP_STAGE/Instructiuni_Utilizare.pdf" 2>/dev/null || true
cp "$DIST_DIR/Dezinstalare_MacMasterControlPro.command" "$ZIP_STAGE/"
chmod +x "$ZIP_STAGE/Dezinstalare_MacMasterControlPro.command"
( cd "$ZIP_STAGE" && zip -q -r -y "../MacMasterControlPro-Mac.zip" . )
rm -rf "$ZIP_STAGE"

cp "$DIST_DIR/MacMasterControlPro-Mac.zip" "$DIST_DIR/MacMasterControlPro-Mac-$VERSION.zip"

echo "==> Done: $FINAL_PKG"
echo "==> Also: $DIST_DIR/MacMasterControlPro.pkg, $DIST_DIR/MacMasterControlPro-Mac.zip, $DIST_DIR/MacMasterControlPro-Mac-$VERSION.zip"
