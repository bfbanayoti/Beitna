#!/usr/bin/env python3
"""Render the Beitna mark (icons/logo.svg) to the PNG sizes iOS and the web manifest need. Run: .venv/bin/python build_icons.py"""
import os
from PIL import Image, ImageDraw

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'icons')
BG = ((0xc8, 0x66, 0x4a), (0x7e, 0x2f, 0x22))
DOT = ((0xf3, 0xd9, 0xa4), (0xc9, 0x9a, 0x52))
CREAM = (0xfb, 0xf3, 0xea)


def lerp(a, b, t):
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


def mark(size, scale=1.0, rounded=False):
    S = size * 4  # supersample, then downscale for smooth edges
    img = Image.new('RGB', (S, S))
    px = img.load()
    for y in range(S):
        for x in range(S):
            px[x, y] = lerp(*BG, (x + y) / (2 * S))
    d = ImageDraw.Draw(img)
    u = S / 64 * scale
    o = S / 2 - 32 * u  # keep the glyph centred when scaled (maskable safe zone)
    P = lambda x, y: (o + x * u, o + y * u)
    w = 4.6 * u
    # arch: two jambs + half circle, round caps
    d.line([P(21, 49), P(21, 30.6)], fill=CREAM, width=round(w))
    d.line([P(43, 30.6), P(43, 49)], fill=CREAM, width=round(w))
    # PIL strokes arcs inside the box, so grow it by half the stroke to centre the stroke on r=11 like the SVG
    (x0, y0), (x1, y1) = P(21, 20), P(43, 42)
    h = w / 2
    d.arc([x0 - h, y0 - h, x1 + h, y1 + h], 180, 360, fill=CREAM, width=round(w))
    for cx, cy in ((21, 49), (43, 49)):
        (x, y), r = P(cx, cy), w / 2
        d.ellipse([x - r, y - r, x + r, y + r], fill=CREAM)
    # the dot of ب, gold
    (cx, cy), r = P(32, 41), 3.4 * u
    for i in range(int(2 * r) + 1):
        yy = cy - r + i
        half = (max(r * r - (yy - cy) ** 2, 0)) ** .5
        d.line([(cx - half, yy), (cx + half, yy)], fill=lerp(*DOT, i / (2 * r)))
    img = img.resize((size, size), Image.LANCZOS)
    if rounded:
        m = Image.new('L', (S, S), 0)
        ImageDraw.Draw(m).rounded_rectangle([0, 0, S - 1, S - 1], radius=S * 15 / 64, fill=255)
        out = Image.new('RGBA', (size, size), (0, 0, 0, 0))
        out.paste(img, (0, 0), m.resize((size, size), Image.LANCZOS))
        return out
    return img


if __name__ == '__main__':
    mark(180).save(os.path.join(ROOT, 'apple-touch-icon.png'))        # iOS rounds the corners itself
    mark(192, rounded=True).save(os.path.join(ROOT, 'icon-192.png'))
    mark(512, rounded=True).save(os.path.join(ROOT, 'icon-512.png'))
    mark(512, scale=.78).save(os.path.join(ROOT, 'icon-maskable-512.png'))  # full-bleed, glyph inside the safe zone
    mark(1024, rounded=True).save(os.path.join(ROOT, 'logo-1024.png'))
    print('icons written:', sorted(os.listdir(ROOT)))
