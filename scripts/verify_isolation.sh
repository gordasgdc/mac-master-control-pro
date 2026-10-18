#!/bin/zsh
# Probă de regresie la nivel de PROCES: profilul oficial (aplicația instalată) rămâne identic după pornirea și închiderea unui build izolat.
# Uz: scripts/verify_isolation.sh <calea .app izolat> [secunde]   (profilul izolat merge pe volumul extern)
set -euo pipefail
APP="${1:?calea .app}"; SECS="${2:-12}"
PROFILE="/Volumes/CristiGordas/TESTE/GDC_PROJECTS/MasterControlStudioPro/profiles/verify-$(date +%s)"
[[ -d /Volumes/CristiGordas/TESTE ]] || { echo "EXTERNAL TEST STORAGE NOT AVAILABLE"; exit 3; }
fp() {
  python3 - <<'PY'
import os, hashlib, subprocess, json
h = hashlib.sha256()
sup = os.path.expanduser("~/Library/Application Support/MacMasterControlPro")
for root, dirs, files in os.walk(sup):
    dirs.sort()
    for f in sorted(files):
        p = os.path.join(root, f); st = os.stat(p)
        h.update(f"{os.path.relpath(p, sup)}|{st.st_size}|{int(st.st_mtime)}|{hashlib.sha1(open(p,'rb').read()).hexdigest()}\n".encode())
dom = subprocess.run(["defaults", "export", "com.gordasgdc.macmastercontrolpro", "-"], capture_output=True).stdout
h.update(hashlib.sha256(dom).digest())
logs = os.path.expanduser("~/Library/Logs/MasterControlStudioPro")
if os.path.isdir(logs):
    for f in sorted(os.listdir(logs)): h.update(f"{f}|{os.path.getsize(os.path.join(logs, f))}\n".encode())
kc = subprocess.run(["security", "find-generic-password", "-s", "com.gordasgdc.macmastercontrolpro.secrets"], capture_output=True)
h.update(str(kc.returncode).encode())
print(h.hexdigest())
PY
}
BEFORE=$(fp)
MCSP_PROFILE_DIR="$PROFILE" MCSP_DEMO_VOLUMES="Studio SSD,Archive RAID" "$APP/Contents/MacOS/MacMasterControlPro" >/dev/null 2>&1 &
APPPID=$!
sleep "$SECS"
kill "$APPPID" 2>/dev/null || true
wait "$APPPID" 2>/dev/null || true
AFTER=$(fp)
echo "înainte: $BEFORE"; echo "după:    $AFTER"; echo "profil izolat: $PROFILE ($(ls -R "$PROFILE" 2>/dev/null | tr '\n' ' '))"
[[ "$BEFORE" == "$AFTER" ]] && echo "OK: profilul oficial este identic" || { echo "EȘEC: profilul oficial s-a modificat"; exit 1; }
