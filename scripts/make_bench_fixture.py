#!/usr/bin/env python3
"""Fixture deterministic pentru baseline-ul de scanare. Uz: make_bench_fixture.py <destinatie>
Scrie DOAR sub destinatie (trebuie sa fie pe volumul extern, STORAGE_POLICY)."""
import os, sys, random
dest = sys.argv[1]
assert dest.startswith("/Volumes/CristiGordas/TESTE/"), "destinatia trebuie sa fie pe volumul extern"
random.seed(42)
n = 0
for a in range(60):
    for b in range(20):
        d = os.path.join(dest, f"proj{a:02d}", f"sub{b:02d}", "deep", "er")
        os.makedirs(d, exist_ok=True)
        for k in range(60):
            with open(os.path.join(d, f"f{k:03d}.dat"), "wb") as f:
                f.write(os.urandom(random.randint(1, 3000)))
            n += 1
for i in range(12):  # fisiere sparse: dimensiune logica mare, spatiu alocat ~0
    p = os.path.join(dest, "sparse", f"s{i:02d}.bin"); os.makedirs(os.path.dirname(p), exist_ok=True)
    with open(p, "wb") as f: f.truncate(500 * 1024 * 1024)
print("files", n + 12)
