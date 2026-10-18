#!/usr/bin/env python3
"""Volum demonstrativ pentru capturi: imagini APFS montate ca „Studio SSD” si „Arhiva RAID”, cu continut SINTETIC (nume inventate,
date aleatoare reale la scara 1:100). Nu contine nimic personal. Uz: make_demo_volume.py <folder-pe-volumul-extern>
Folosit doar pentru materiale demonstrative; aplicatia se lanseaza cu MCSP_DEMO_VOLUMES="Studio SSD,Arhiva RAID"."""
import os, sys, subprocess, shutil
dest = sys.argv[1]
assert dest.startswith("/Volumes/CristiGordas/TESTE/"), "imaginile se tin pe volumul extern (STORAGE_POLICY)"
os.makedirs(dest, exist_ok=True)

def attach(name, size):
    img = os.path.join(dest, name.replace(" ", "_") + ".sparseimage")
    if not os.path.exists(img):
        subprocess.run(["hdiutil", "create", "-size", size, "-type", "SPARSE", "-fs", "APFS", "-volname", name, img], check=True, capture_output=True)
    subprocess.run(["hdiutil", "attach", img, "-nobrowse" if False else "-quiet"], check=True)
    return f"/Volumes/{name}"

def blob(path, mb, data=None):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        left = mb * 1024 * 1024
        while left > 0:
            n = min(left, 8 * 1024 * 1024); f.write(os.urandom(n)); left -= n

v = attach("Studio SSD", "32g")
P = "Proiecte/Documentar_Delta_v7"
# scara: valori in MB reale
spec = {
 f"{P}/Media_originale/A001-A006.mov": 520, f"{P}/Media_originale/A007-A011.mov": 440,
 f"{P}/CacheClip/cache_001.dvcc": 300, f"{P}/CacheClip/cache_002.dvcc": 180,
 f"{P}/Optimized Media/opt_001.mov": 220,
 f"{P}/Proxy/proxy_001.mov": 150,
 f"{P}/Randare_v1.mov": 180,
 f"{P}/teste_culoare/test_a.mov": 200, f"{P}/teste_culoare/test_b.mov": 150,
 f"{P}/Gallery stills/stills.drx": 310,
 f"{P}/Timeline exports/export.xml": 50,
 "Proiecte/Spot_Banca_Nord/Originale/clip_a.mov": 840, "Proiecte/Spot_Banca_Nord/Cache/CacheClip/c.dvcc": 410, "Proiecte/Spot_Banca_Nord/Randari/v1.mov": 460,
 "Proiecte/Clip_Festival_2026/Originale/clip_b.mov": 700, "Proiecte/Clip_Festival_2026/Cache/CacheClip/c.dvcc": 330, "Proiecte/Clip_Festival_2026/Randari/v1.mov": 250,
 "Proiecte/Arhiva_2025/arhiva.zip": 250,
 "Footage/ARRI/A001-A014_I.mov": 1040, "Footage/ARRI/A001-A014_II.mov": 970, "Footage/Sony FX6/fx6_cam_b.mov": 1120, "Footage/Draona DJI/dji_001.mov": 750,
 "Cache aplicatii/Resolve CacheClip/global.dvcc": 620, "Cache aplicatii/Adobe Media Cache/Media Cache Files/mc.cfa": 380, "Cache aplicatii/Library Caches/Caches/app.cache": 180,
 "Exporturi/Spot_Banca_Nord_v3.mov": 610, "Exporturi/Delta_master.mxf": 580, "Exporturi/Teste de culoare/t.mov": 350,
 "Aplicatii/DaVinci Resolve/resolve.bin": 90, "Aplicatii/Alte aplicatii/apps.bin": 690,
 "Backup iOS/MobileSync/Backup/iPhone/backup.db": 520,
 "Sistem si altele/sys.bin": 290,
}
for rel, mb in spec.items(): blob(os.path.join(v, rel), mb)
# duplicat verificat: copie fizica identica a Randare_v1.mov
src = os.path.join(v, P, "Randare_v1.mov"); dst = os.path.join(v, P, "Randare_v1_copy.mov")
with open(src, "rb") as a, open(dst, "wb") as b: shutil.copyfileobj(a, b, 8 * 1024 * 1024)

w = attach("Arhiva RAID", "16g")
for rel, mb in {"Arhiva/Film_2024/master.mov": 900, "Arhiva/Film_2024/proxy.mov": 300, "Arhiva/Clipuri/c1.mov": 600, "Arhiva/Clipuri/c2.mov": 500}.items():
    blob(os.path.join(w, rel), mb)
print("gata:", v, w)
