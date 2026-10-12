#!/usr/bin/env python3
"""Makes every app icon, the notification icon and the launch screens from the website's icon-512.png.
Run from the app folder (needs Pillow: pip install pillow)."""
import os
from PIL import Image, ImageDraw

APP = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
R = os.path.join(APP, 'resources')
src = Image.open(os.path.join(APP, '..', 'icon-512.png')).convert('RGBA')
big = src.resize((1024, 1024), Image.LANCZOS)

def rounded_mask(size, radius_frac, ellipse=False):
    m = Image.new('L', (size * 4, size * 4), 0)
    d = ImageDraw.Draw(m)
    if ellipse:
        d.ellipse([0, 0, size * 4 - 1, size * 4 - 1], fill=255)
    else:
        d.rounded_rectangle([0, 0, size * 4 - 1, size * 4 - 1], radius=int(size * 4 * radius_frac), fill=255)
    return m.resize((size, size), Image.LANCZOS)

def save(img, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path, optimize=True)

# Android launcher icons
base = os.path.join(R, 'android', 'res')
dens = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}
for d, m in dens.items():
    s = int(48 * m)
    ic = big.resize((s, s), Image.LANCZOS)
    for name, mask in (('ic_launcher.png', rounded_mask(s, 0.18)), ('ic_launcher_round.png', rounded_mask(s, 0, True))):
        out = Image.new('RGBA', (s, s), (0, 0, 0, 0)); out.paste(ic, (0, 0), mask)
        save(out, os.path.join(base, 'mipmap-' + d, name))
    f = int(108 * m)
    save(big.resize((f, f), Image.LANCZOS), os.path.join(base, 'mipmap-' + d, 'ic_launcher_foreground.png'))

# Notification icon: just the white plane, on transparent
px = src.load(); W, H = src.size
plane = Image.new('L', (W, H), 0); pp = plane.load()
for y in range(H):
    for x in range(W):
        r, g, b, a = px[x, y]
        if r > 200 and g > 200 and b > 200:
            pp[x, y] = min(255, int((min(r, g, b) - 200) * 255 / 55))
crop = plane.crop(plane.getbbox()); cw, ch = crop.size; side = int(max(cw, ch) * 1.12)
sq = Image.new('L', (side, side), 0); sq.paste(crop, ((side - cw) // 2, (side - ch) // 2))
for d, m in dens.items():
    s = int(24 * m)
    out = Image.new('RGBA', (s, s), (255, 255, 255, 0)); out.putalpha(sq.resize((s, s), Image.LANCZOS))
    save(out, os.path.join(base, 'drawable-' + d, 'ic_stat_plane.png'))

# Launch screen: navy with the icon in the middle
S, L = 2732, 560
splash = Image.new('RGB', (S, S), (0x14, 0x30, 0x4F))
splash.paste(big.resize((L, L), Image.LANCZOS), ((S - L) // 2, (S - L) // 2), rounded_mask(L, 0.22))
save(splash, os.path.join(base, 'drawable', 'splash.png'))
os.makedirs(os.path.join(base, 'values'), exist_ok=True)
open(os.path.join(base, 'values', 'ic_launcher_background.xml'), 'w').write(
    '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n    <color name="ic_launcher_background">#14304F</color>\n</resources>\n')

# iPhone: one 1024 icon with no transparency, and the launch screen
save(big.convert('RGB'), os.path.join(R, 'ios', 'AppIcon-512@2x.png'))
save(splash, os.path.join(R, 'ios', 'splash-2732x2732.png'))
print('icons and launch screens made')
