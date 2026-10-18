#!/usr/bin/env bash
# Poarta de stocare externa (STORAGE_POLICY) + cai de iesire pentru build/test/packaging.
# Se incarca cu `source`. Fara volum extern real si writable => oprire, fara fallback intern.
MCSP_EXT_ROOT="${MCSP_EXT_ROOT:-/Volumes/CristiGordas/TESTE/GDC_PROJECTS/MasterControlStudioPro}"
if ! mount | grep -q " on /Volumes/CristiGordas " || ! [ -d "$MCSP_EXT_ROOT" ] || ! touch "$MCSP_EXT_ROOT/.w.$$" 2>/dev/null; then
    echo "EXTERNAL TEST STORAGE NOT AVAILABLE" >&2; return 3 2>/dev/null || exit 3
fi
rm -f "$MCSP_EXT_ROOT/.w.$$"
export MCSP_EXT_ROOT
export MCSP_SCRATCH="$MCSP_EXT_ROOT/builds/swiftpm"        # SwiftPM --scratch-path
export MCSP_DIST_DIR="$MCSP_EXT_ROOT/artifacts/dist"        # packaging
export MCSP_BUILD_ROOT="$MCSP_EXT_ROOT/builds/dotnet"       # .NET bin/obj (Directory.Build.props)
export TMPDIR="$MCSP_EXT_ROOT/temp/"                        # temporare (swift, mktemp, hdiutil)
mkdir -p "$MCSP_SCRATCH" "$MCSP_DIST_DIR" "$MCSP_BUILD_ROOT" "$TMPDIR"
