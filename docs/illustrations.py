#!/usr/bin/env python3
"""Genera las ilustraciones del README: un escritorio de ejemplo con cada escena de Nimbo.
Generates the README illustrations: a sample desktop with each Nimbo scene.

Uso / Usage:   python3 docs/illustrations.py      (requiere / requires Pillow)
"""
import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter

W, H, S = 1600, 1000, 2          # tamaño final y factor de dibujo / final size and draw scale
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "screenshots")

WIN_A = (170, 180, 800, 620)     # ventanas de ejemplo / sample windows (x0, y0, x1, y1)
WIN_B = (880, 330, 1420, 760)
DOCK = (500, 918, 1100, 984)

SKIES = {
    "snow": ((40, 58, 108), (126, 156, 204)),
    "rain": ((50, 60, 76), (100, 114, 132)),
    "storm": ((20, 24, 40), (62, 68, 90)),
    "petals": ((142, 196, 238), (250, 216, 226)),
    "leaves": ((226, 164, 96), (128, 76, 56)),
    "fireflies": ((12, 24, 38), (26, 58, 50)),
    "meteors": ((8, 10, 30), (32, 38, 84)),
    "cloud": ((118, 138, 164), (184, 196, 208)),
    "mist": ((146, 156, 166), (202, 207, 210)),
    "clear": ((66, 146, 228), (172, 216, 250)),
}
DARK = {"storm", "fireflies", "meteors"}


def s(v):
    return int(round(v * S))


def box(b):
    return [s(b[0]), s(b[1]), s(b[2]), s(b[3])]


def layer(base=(255, 255, 255)):
    # Fondo transparente del mismo color que lo dibujado, para que el desenfoque no oscurezca los bordes.
    # Transparent background in the drawn colour, so blurring does not darken the edges.
    return Image.new("RGBA", (W * S, H * S), base + (0,))


def blurred(img, radius):
    return img.filter(ImageFilter.GaussianBlur(radius * S))


def desktop(kind):
    top, bottom = SKIES[kind]
    img = Image.new("RGBA", (W * S, H * S))
    d = ImageDraw.Draw(img)
    for y in range(H * S):
        t = y / (H * S - 1)
        d.line([(0, y), (W * S, y)], fill=tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)) + (255,))
    # Colinas suaves al fondo / soft hills in the background
    hills = layer()
    hd = ImageDraw.Draw(hills)
    shade = tuple(int(c * 0.62) for c in bottom)
    hd.ellipse(box((-300, 760, 900, 1300)), fill=shade + (255,))
    hd.ellipse(box((600, 800, 1900, 1400)), fill=tuple(int(c * 0.5) for c in bottom) + (255,))
    img = Image.alpha_composite(img, hills)

    ui = layer()
    d = ImageDraw.Draw(ui)
    dark = kind in DARK
    # Barra de menús / menu bar
    d.rectangle(box((0, 0, W, 28)), fill=(20, 24, 34, 120) if dark else (255, 255, 255, 110))
    ink = (235, 238, 245, 200) if dark else (40, 46, 60, 190)
    x = 22
    for width in (16, 46, 34, 40, 30):
        d.rounded_rectangle(box((x, 10, x + width, 18)), radius=s(4), fill=ink)
        x += width + 18
    for x in (1440, 1474, 1508):
        d.ellipse(box((x, 8, x + 12, 20)), fill=ink)
    d.rounded_rectangle(box((1536, 10, 1580, 18)), radius=s(4), fill=ink)

    # Ventanas / windows
    for b, title in ((WIN_A, 150), (WIN_B, 110)):
        shadow = layer((0, 0, 0))
        ImageDraw.Draw(shadow).rounded_rectangle(box((b[0], b[1] + 14, b[2], b[3] + 22)), radius=s(14), fill=(0, 0, 0, 90))
        ui_shadow = blurred(shadow, 16)
        img = Image.alpha_composite(img, ui_shadow)
        body = (40, 44, 56, 255) if dark else (247, 248, 250, 255)
        bar = (54, 58, 72, 255) if dark else (232, 234, 239, 255)
        line = (86, 92, 110, 255) if dark else (208, 212, 220, 255)
        d.rounded_rectangle(box(b), radius=s(12), fill=body)
        d.rounded_rectangle(box((b[0], b[1], b[2], b[1] + 40)), radius=s(12), fill=bar)
        d.rectangle(box((b[0], b[1] + 26, b[2], b[1] + 40)), fill=bar)
        for i in range(3):
            d.ellipse(box((b[0] + 16 + i * 20, b[1] + 14, b[0] + 28 + i * 20, b[1] + 26)), fill=line)
        d.rounded_rectangle(box(((b[0] + b[2]) / 2 - title / 2, b[1] + 16, (b[0] + b[2]) / 2 + title / 2, b[1] + 24)),
                            radius=s(4), fill=line)
        # Contenido de relleno / placeholder content
        d.rounded_rectangle(box((b[0] + 22, b[1] + 62, b[0] + 150, b[3] - 22)), radius=s(8), fill=bar)
        y = b[1] + 66
        rnd = random.Random(title)
        while y < b[3] - 40:
            d.rounded_rectangle(box((b[0] + 172, y, b[0] + 172 + rnd.randint(140, b[2] - b[0] - 210), y + 10)),
                                radius=s(5), fill=line)
            y += 30

    # Dock
    d.rounded_rectangle(box(DOCK), radius=s(20), fill=(30, 34, 46, 150) if dark else (255, 255, 255, 120))
    tones = [(96, 132, 196), (214, 120, 96), (110, 170, 130), (220, 180, 90), (150, 120, 190),
             (90, 160, 190), (200, 110, 150), (130, 140, 160), (120, 180, 110)]
    for i, tone in enumerate(tones):
        x = DOCK[0] + 20 + i * 63
        d.rounded_rectangle(box((x, DOCK[1] + 9, x + 48, DOCK[1] + 57)), radius=s(11), fill=tone + (255,))
    return Image.alpha_composite(img, ui)


def ledges():
    """Bordes donde se posa algo: ventanas, Dock y piso. / Edges where things land."""
    return [(WIN_A[0], WIN_A[2], WIN_A[1]), (WIN_B[0], WIN_B[2], WIN_B[1]), (DOCK[0], DOCK[2], DOCK[1]),
            (0, DOCK[0] - 30, H), (DOCK[2] + 30, W, H)]


def pile(d, x0, x1, y, peak, rnd):
    points = [(s(x0), s(y))]
    height = 0.0
    steps = max(4, int((x1 - x0) / 10))
    for i in range(steps + 1):
        edge = min(i, steps - i) / 4
        height += rnd.uniform(-2.2, 2.2)
        height = max(peak * 0.45, min(peak, height if i else peak * 0.7))
        points.append((s(x0 + (x1 - x0) * i / steps), s(y - height * min(1, edge + 0.08))))
    points.append((s(x1), s(y)))
    d.polygon(points, fill=(255, 255, 255, 250), outline=(178, 200, 228, 255))


def dots(img, rnd, count, size, color, alpha, blur=0.0, area=None):
    lay = layer(color)
    d = ImageDraw.Draw(lay)
    x0, y0, x1, y1 = area or (0, 0, W, H)
    for _ in range(count):
        x, y, r = rnd.uniform(x0, x1), rnd.uniform(y0, y1), rnd.uniform(*size) / 2
        d.ellipse(box((x - r, y - r, x + r, y + r)), fill=color + (int(255 * rnd.uniform(*alpha)),))
    if blur:
        lay = blurred(lay, blur)
    return Image.alpha_composite(img, lay)


def tint(img, color, alpha):
    return Image.alpha_composite(img, Image.new("RGBA", img.size, color + (int(255 * alpha),)))


def rotated(cx, cy, a, b, angle, n=14, leaf=False):
    pts = []
    for i in range(n):
        t = 2 * math.pi * i / n
        x, y = a * math.cos(t), b * math.sin(t)
        if leaf:                                        # forma de lente, con dos puntas / lens shape, two tips
            y = b * (1 - (x / a) ** 2) * (1 if math.sin(t) >= 0 else -1)
        pts.append((s(cx + x * math.cos(angle) - y * math.sin(angle)), s(cy + x * math.sin(angle) + y * math.cos(angle))))
    return pts


def falling_shapes(img, rnd, count, colors, a, b, leaf):
    lay = layer()
    d = ImageDraw.Draw(lay)
    for _ in range(count):
        k = rnd.uniform(0.75, 1.35)
        d.polygon(rotated(rnd.uniform(0, W), rnd.uniform(30, H), a * k, b * k, rnd.uniform(0, math.pi), leaf=leaf),
                  fill=rnd.choice(colors) + (235,))
    for x0, x1, y in ledges()[:3]:                      # algunas ya posadas / some already resting
        for _ in range(int((x1 - x0) / 55)):
            d.polygon(rotated(rnd.uniform(x0 + 10, x1 - 10), y - b * 0.6, a, b, rnd.uniform(-0.3, 0.3), leaf=leaf),
                      fill=rnd.choice(colors) + (240,))
    return Image.alpha_composite(img, lay)


def rain(img, rnd, count, slant, alpha):
    lay = layer()
    d = ImageDraw.Draw(lay)
    for _ in range(count):
        x, y, length = rnd.uniform(-60, W + 120), rnd.uniform(0, H), rnd.uniform(16, 30)
        d.line([(s(x), s(y)), (s(x - slant * length), s(y + length))], fill=(214, 230, 255, int(255 * rnd.uniform(*alpha))),
               width=s(1.4))
    for x0, x1, y in ledges():                          # salpicaduras / splashes
        for _ in range(int((x1 - x0) / 36)):
            x = rnd.uniform(x0, x1)
            for dx in (-4, 4):
                d.line([(s(x), s(y - 1)), (s(x + dx), s(y - rnd.uniform(3, 6)))], fill=(226, 238, 255, 130), width=s(1))
    return Image.alpha_composite(img, lay)


def glow(img, x, y, radius, color, alpha):
    lay = layer(color)
    ImageDraw.Draw(lay).ellipse(box((x - radius, y - radius, x + radius, y + radius)), fill=color + (int(255 * alpha),))
    return Image.alpha_composite(img, blurred(lay, radius * 0.45))


def workshop(img):
    """Cabaña, árbol y muñeco sobre el Dock. / Cabin, tree and snowman on the Dock."""
    lay = layer()
    d = ImageDraw.Draw(lay)
    y = DOCK[1]
    cx = DOCK[0] - 70                                    # cabaña / cabin
    wood, dark = (116, 72, 42, 255), (76, 46, 26, 255)
    d.rectangle(box((cx + 8, y - 48, cx + 16, y - 28)), fill=dark)
    d.rectangle(box((cx - 22, y - 26, cx + 22, y)), fill=wood)
    d.polygon([(s(cx - 28), s(y - 25)), (s(cx), s(y - 46)), (s(cx + 28), s(y - 25))], fill=dark)
    d.polygon([(s(cx - 28), s(y - 28)), (s(cx), s(y - 49)), (s(cx + 28), s(y - 28)), (s(cx + 24), s(y - 26)),
               (s(cx), s(y - 44)), (s(cx - 24), s(y - 26))], fill=(255, 255, 255, 250))
    d.rectangle(box((cx - 16, y - 17, cx - 6, y)), fill=dark)
    d.rectangle(box((cx + 3, y - 18, cx + 15, y - 8)), fill=(255, 208, 104, 255))
    for i, r in enumerate((5, 7, 9)):                    # humo / smoke
        d.ellipse(box((cx + 12 + i * 7 - r, y - 58 - i * 15 - r, cx + 12 + i * 7 + r, y - 58 - i * 15 + r)),
                  fill=(226, 228, 232, 150 - i * 40))
    tx = DOCK[2] + 70                                    # árbol / tree
    d.rectangle(box((tx - 4, y - 10, tx + 4, y)), fill=(92, 56, 30, 255))
    for i, (base, half, height) in enumerate(((8, 30, 34), (28, 23, 30), (46, 16, 26))):
        d.polygon([(s(tx - half), s(y - base)), (s(tx), s(y - base - height)), (s(tx + half), s(y - base))],
                  fill=(22, 92 + i * 16, 52, 255))
    rnd = random.Random(5)
    for _ in range(9):
        base, half, height = rnd.choice(((8, 30, 34), (28, 23, 30), (46, 16, 26)))
        v = rnd.uniform(0.1, 0.65)
        ox, oy = tx + rnd.uniform(-1, 1) * half * (1 - v) * 0.8, y - base - height * v
        d.ellipse(box((ox - 3, oy - 3, ox + 3, oy + 3)), fill=rnd.choice(((230, 40, 52), (255, 204, 52), (64, 140, 255))) + (255,))
    d.regular_polygon((s(tx), s(y - 74), s(7)), 5, rotation=0, fill=(255, 214, 64, 255))
    mx = WIN_B[0] + 120                                  # muñeco sobre una ventana / snowman on a window
    my = WIN_B[1] - 14
    for r, oy in ((15, 13), (11, 33), (8, 48)):
        d.ellipse(box((mx - r, my - oy - r, mx + r, my - oy + r)), fill=(255, 255, 255, 255), outline=(196, 206, 222, 255))
    d.ellipse(box((mx - 4, my - 51, mx - 2, my - 49)), fill=(26, 26, 26, 255))
    d.ellipse(box((mx + 2, my - 51, mx + 4, my - 49)), fill=(26, 26, 26, 255))
    d.polygon([(s(mx), s(my - 48)), (s(mx + 8), s(my - 46.5)), (s(mx), s(my - 45.5))], fill=(255, 128, 26, 255))
    d.rectangle(box((mx - 8, my - 57, mx + 8, my - 55)), fill=(26, 26, 26, 255))
    d.rectangle(box((mx - 5, my - 66, mx + 5, my - 56)), fill=(26, 26, 26, 255))
    return Image.alpha_composite(img, lay)


def render(kind):
    rnd = random.Random(kind)
    img = desktop(kind)
    if kind == "snow":
        img = workshop(img)
        lay = layer()
        d = ImageDraw.Draw(lay)
        for (x0, x1, y), peak in zip(ledges(), (22, 22, 18, 30, 30)):
            pile(d, x0, x1, y, peak, rnd)
        img = Image.alpha_composite(img, lay)
        img = dots(img, rnd, 30, (14, 22), (255, 255, 255), (0.25, 0.4), blur=2.2)
        img = dots(img, rnd, 520, (3, 8), (246, 250, 255), (0.6, 1.0), blur=0.35)
    elif kind == "rain":
        img = tint(img, (5, 10, 30), 0.08)
        img = rain(img, rnd, 620, 0.08, (0.3, 0.6))
    elif kind == "storm":
        img = tint(img, (5, 10, 30), 0.16)
        img = rain(img, rnd, 900, 0.24, (0.3, 0.65))
        bolt = layer((214, 226, 255))
        d = ImageDraw.Draw(bolt)
        x, y, points = 1090.0, 0.0, [(s(1090), 0)]
        while y < 470:
            x, y = x + rnd.uniform(-38, 38), y + rnd.uniform(28, 70)
            points.append((s(x), s(y)))
        d.line(points, fill=(214, 226, 255, 255), width=s(7), joint="curve")
        img = Image.alpha_composite(img, blurred(bolt, 7))
        d.line(points, fill=(255, 255, 255, 255), width=s(2.4), joint="curve")
        img = Image.alpha_composite(img, bolt)
        img = tint(img, (255, 255, 255), 0.06)
    elif kind == "petals":
        img = falling_shapes(img, rnd, 110, [(255, 190, 212), (255, 206, 224), (250, 172, 200)], 7, 4.5, leaf=False)
    elif kind == "leaves":
        img = falling_shapes(img, rnd, 80, [(216, 90, 26), (242, 154, 30), (178, 52, 26), (230, 192, 52)], 11, 6.5, leaf=True)
    elif kind == "fireflies":
        img = tint(img, (5, 10, 30), 0.14)
        img = dots(img, rnd, 46, (16, 30), (206, 255, 96), (0.3, 0.8), blur=4.5, area=(0, 250, W, H - 20))
        img = dots(img, random.Random(kind), 46, (3, 5), (244, 255, 190), (0.7, 1.0), area=(0, 250, W, H - 20))
    elif kind == "meteors":
        img = glow(img, 230, 150, 60, (236, 240, 255), 0.75)
        img = dots(img, rnd, 150, (1.5, 3.6), (255, 255, 255), (0.3, 0.9), area=(0, 30, W, 640))
        lay = layer()
        d = ImageDraw.Draw(lay)
        for x, y, length in ((1180, 120, 190), (700, 70, 140), (1460, 300, 160)):
            for i in range(24):
                t = i / 24
                d.line([(s(x - length * t * 0.87), s(y + length * t * 0.5)),
                        (s(x - length * (t + 0.05) * 0.87), s(y + length * (t + 0.05) * 0.5))],
                       fill=(255, 255, 255, int(235 * t)), width=s(2.4))
        img = Image.alpha_composite(img, lay)
    elif kind == "cloud":
        lay = layer()
        d = ImageDraw.Draw(lay)
        for cx, cy, k, a in ((260, 150, 1.0, 190), (760, 110, 1.25, 170), (1270, 190, 1.1, 185), (1010, 300, 0.8, 130), (430, 300, 0.7, 120)):
            for ox, oy, r in ((-130, 20, 80), (-50, -10, 105), (50, 5, 100), (130, 25, 75), (0, 35, 90)):
                d.ellipse(box((cx + ox * k - r * k, cy + oy * k - r * k, cx + ox * k + r * k, cy + oy * k + r * k)), fill=(255, 255, 255, a))
        img = Image.alpha_composite(img, blurred(lay, 16))
    elif kind == "mist":
        lay = layer()
        d = ImageDraw.Draw(lay)
        for _ in range(11):
            cx, cy, a, b = rnd.uniform(0, W), rnd.uniform(380, H), rnd.uniform(380, 560), rnd.uniform(110, 190)
            d.ellipse(box((cx - a, cy - b, cx + a, cy + b)), fill=(255, 255, 255, rnd.randint(70, 110)))
        img = Image.alpha_composite(img, blurred(lay, 60))
    elif kind == "clear":
        img = glow(img, W - 70, 40, 330, (255, 220, 140), 0.55)
        img = glow(img, W - 70, 40, 110, (255, 246, 214), 0.9)
        img = dots(img, rnd, 36, (2, 4.5), (255, 238, 190), (0.35, 0.7))
    return img.convert("RGB").resize((W, H), Image.LANCZOS)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for kind in SKIES:
        render(kind).save(os.path.join(OUT, f"{kind}.jpg"), quality=88)
        print(kind)
