#!/usr/bin/env python3
"""Genereaza AppIcon.icns pentru Master Control Studio Pro — squircle metallic/
gold cu glif de angrenaj, in linie cu identitatea vizuala GDC (accent
amber/cupru, Regula 16), dar cu tonuri metalice/aurii cerute explicit pentru
brand-ul acestei aplicatii (System Tuning Panel)."""
import math
import os
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
ICONSET = os.path.join(HERE, "AppIcon.iconset")
SIZE = 1024

GOLD_LIGHT = (247, 210, 140)
GOLD_MID = (217, 138, 61)
GOLD_DARK = (120, 70, 24)
INK = (26, 17, 8)


def squircle_mask(size, n=4.5):
    mask = Image.new("L", (size, size), 0)
    px = mask.load()
    c = (size - 1) / 2
    r = c
    for y in range(size):
        for x in range(size):
            nx = (x - c) / r
            ny = (y - c) / r
            if abs(nx) ** n + abs(ny) ** n <= 1:
                px[x, y] = 255
    return mask


def make_base(size):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    grad = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    gpx = grad.load()
    for y in range(size):
        t = y / (size - 1)
        r = int(GOLD_LIGHT[0] * (1 - t) + GOLD_DARK[0] * t)
        g = int(GOLD_LIGHT[1] * (1 - t) + GOLD_DARK[1] * t)
        b = int(GOLD_LIGHT[2] * (1 - t) + GOLD_DARK[2] * t)
        for x in range(size):
            gpx[x, y] = (r, g, b, 255)
    mask = squircle_mask(size)
    img.paste(grad, (0, 0), mask)

    # sheen diagonal subtil
    sheen = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    sdraw = ImageDraw.Draw(sheen)
    sdraw.polygon(
        [(0, 0), (size * 0.65, 0), (size * 0.25, size), (0, size)],
        fill=(255, 255, 255, 40),
    )
    sheen.putalpha(Image.composite(sheen.split()[3], Image.new("L", (size, size), 0), mask))
    img = Image.alpha_composite(img, sheen)

    # bordura fina
    border = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    bdraw = ImageDraw.Draw(border)
    bmask = squircle_mask(size)
    inner_mask = squircle_mask(int(size * 0.985))
    inner_img = Image.new("L", (size, size), 0)
    off = (size - int(size * 0.985)) // 2
    inner_img.paste(inner_mask, (off, off))
    ring = Image.composite(Image.new("L", (size, size), 255), Image.new("L", (size, size), 0), bmask)
    ring_final = Image.new("L", (size, size), 0)
    rpx_a, rpx_b = ring.load(), inner_img.load()
    outpx = ring_final.load()
    for y in range(size):
        for x in range(size):
            outpx[x, y] = 255 if (rpx_a[x, y] == 255 and rpx_b[x, y] == 0) else 0
    bdraw.rectangle([0, 0, size, size], fill=(255, 236, 200, 90))
    border.putalpha(ring_final)
    img = Image.alpha_composite(img, border)
    return img, mask


def draw_gear(img, size):
    draw = ImageDraw.Draw(img)
    cx, cy = size / 2, size / 2
    outer_r = size * 0.30
    inner_r = size * 0.19
    tooth_r_out = size * 0.36
    teeth = 8
    pts = []
    for i in range(teeth * 2):
        angle = math.pi * i / teeth
        r = tooth_r_out if i % 2 == 0 else outer_r
        pts.append((cx + r * math.cos(angle), cy + r * math.sin(angle)))
    draw.polygon(pts, fill=INK)
    hole_r = size * 0.10
    draw.ellipse([cx - hole_r, cy - hole_r, cx + hole_r, cy + hole_r], fill=GOLD_LIGHT)
    # inner ring accent
    draw.ellipse(
        [cx - inner_r, cy - inner_r, cx + inner_r, cy + inner_r],
        outline=GOLD_LIGHT, width=int(size * 0.012)
    )


def main():
    os.makedirs(ICONSET, exist_ok=True)
    base, mask = make_base(SIZE)
    draw_gear(base, SIZE)
    base = base.filter(ImageFilter.SMOOTH_MORE)

    specs = [
        (16, "icon_16x16.png"), (32, "icon_16x16@2x.png"),
        (32, "icon_32x32.png"), (64, "icon_32x32@2x.png"),
        (128, "icon_128x128.png"), (256, "icon_128x128@2x.png"),
        (256, "icon_256x256.png"), (512, "icon_256x256@2x.png"),
        (512, "icon_512x512.png"), (1024, "icon_512x512@2x.png"),
    ]
    for px, name in specs:
        base.resize((px, px), Image.LANCZOS).save(os.path.join(ICONSET, name))

    print(f"Iconset scris in {ICONSET}")


if __name__ == "__main__":
    main()
