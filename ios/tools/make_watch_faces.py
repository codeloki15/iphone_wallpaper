#!/usr/bin/env python3
"""Draws the dials for the watch-face widgets.

Each dial is everything that doesn't move: case, bezel, dial, markers and
sub-dials. The hands, date and other moving parts are drawn by the app on
top (Shared/WatchFaces.swift). The designs are original, with no brand
names or logos, and the numerals are a stroke font defined here, so no
typeface is embedded.

Writes Shared/WidgetArt.xcassets/watch-<name>.imageset, and a smaller
watch-<name>-small.imageset for small widgets.
Run from the ios folder:  python3 tools/make_watch_faces.py
Needs Pillow (pip install pillow).
"""
import json
import math
import os

from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
ASSETS = os.path.join(os.path.dirname(HERE), "Shared", "WidgetArt.xcassets")

FINAL = 720          # pixels, for a large widget
SMALL = 480          # pixels, for a small widget: about its size on screen at 3x
SS = 3               # supersampling
SIZE = FINAL * SS
C = SIZE / 2
R = SIZE / 2 * 0.985  # the case's outer edge


def P(angle, r):
    """A point at `angle` degrees clockwise from 12 o'clock, `r` case radii out."""
    a = math.radians(angle)
    return (C + math.sin(a) * r * R, C - math.cos(a) * r * R)


def mix(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def shade(color, k):
    return tuple(max(0, min(255, round(c * k))) for c in color)


def hexc(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


class Dial:
    def __init__(self):
        self.img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.img)

    # ---- surfaces

    def disc(self, r, color, center=(0.0, 0.0)):
        cx, cy = C + center[0] * R, C + center[1] * R
        self.d.ellipse((cx - r * R, cy - r * R, cx + r * R, cy + r * R), fill=color)

    def circle(self, r, color, width, center=(0.0, 0.0)):
        cx, cy = C + center[0] * R, C + center[1] * R
        w = max(1, round(width * R))
        self.d.ellipse((cx - r * R, cy - r * R, cx + r * R, cy + r * R), outline=color, width=w)

    def conic(self, r0, r1, color_at, step=0.5):
        """A ring whose color depends on the angle."""
        a = 0.0
        while a < 360:
            self.d.polygon([P(a, r0), P(a, r1), P(a + step + 0.2, r1), P(a + step + 0.2, r0)], fill=color_at(a))
            a += step

    def metal(self, r0, r1, color, light=-40.0, contrast=0.32):
        """Brushed metal: two highlights opposite each other, and two fainter ones."""
        def at(a):
            k = 0.74 + contrast * math.cos(math.radians(2 * (a - light))) + 0.08 * math.cos(math.radians(4 * (a - light) + 30))
            return shade(color, k)
        self.conic(r0, r1, at)

    def sunburst(self, r, color, light=50.0, contrast=0.22):
        def at(a):
            return shade(color, 0.86 + contrast * math.cos(math.radians(2 * (a - light))))
        self.conic(0, r, at)

    def vignette(self, r, strength=0.45):
        """Darkens a disc toward its edge."""
        layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        ld = ImageDraw.Draw(layer)
        steps = 40
        for i in range(steps):
            t = i / (steps - 1)
            rr = r * (1 - t * 0.55)
            alpha = round(255 * strength * (1 - t) ** 2 / steps * 6)
            ld.ellipse((C - rr * R, C - rr * R, C + rr * R, C + rr * R), outline=(0, 0, 0, min(255, alpha)), width=round(r * R * 0.02))
        self.img = Image.alpha_composite(self.img, layer.filter(ImageFilter.GaussianBlur(SIZE * 0.012)))
        self.d = ImageDraw.Draw(self.img)

    def soft_shadow(self, draw_fn, offset=0.012, blur=0.012, alpha=150):
        """Draws a blurred dark copy of whatever draw_fn draws, slightly offset."""
        layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        saved = self.img, self.d
        self.img, self.d = layer, ImageDraw.Draw(layer)
        draw_fn((0, 0, 0, alpha))
        self.img, self.d = saved
        layer = layer.filter(ImageFilter.GaussianBlur(SIZE * blur))
        shifted = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        shifted.paste(layer, (round(offset * R), round(offset * R * 1.4)))
        self.img = Image.alpha_composite(self.img, shifted)
        self.d = ImageDraw.Draw(self.img)

    # ---- marks

    def tick(self, angle, r0, r1, color, width):
        self.d.line([P(angle, r0), P(angle, r1)], fill=color, width=max(1, round(width * R)))

    def baton(self, angle, r0, r1, width, color):
        """A rectangular marker along a radius."""
        a = math.radians(angle)
        tx, ty = math.cos(a), math.sin(a)
        h = width * R / 2
        (x0, y0), (x1, y1) = P(angle, r0), P(angle, r1)
        self.d.polygon([(x0 - tx * h, y0 - ty * h), (x1 - tx * h, y1 - ty * h), (x1 + tx * h, y1 + ty * h), (x0 + tx * h, y0 + ty * h)], fill=color)

    def applied_baton(self, angle, r0, r1, width, metal, lume):
        self.baton(angle, r0, r1, width, metal)
        self.baton(angle, r0 + 0.012, r1 - 0.012, width - 0.022, lume)

    def applied_dot(self, angle, r, radius, metal, lume):
        x, y = P(angle, r)
        for rad, color in ((radius, metal), (radius - 0.011, lume)):
            self.d.ellipse((x - rad * R, y - rad * R, x + rad * R, y + rad * R), fill=color)

    def triangle(self, angle, r_tip, r_base, half_width, color):
        """Points toward the center when r_tip < r_base."""
        a = math.radians(angle)
        tx, ty = math.cos(a), math.sin(a)
        (x0, y0), (x1, y1) = P(angle, r_tip), P(angle, r_base)
        h = half_width * R
        self.d.polygon([(x0, y0), (x1 - tx * h, y1 - ty * h), (x1 + tx * h, y1 + ty * h)], fill=color)

    def number(self, text, angle, r, height, color, weight=0.15):
        """Digits standing on the circle at `r`, tops pointing outward."""
        a = math.radians(angle)
        nx, ny = math.sin(a), -math.cos(a)      # outward
        tx, ty = math.cos(a), math.sin(a)       # clockwise
        unit = height * R / 1.6
        advance = 1.22
        total = (len(text) - 1) * advance + 1
        ox, oy = P(angle, r)
        width = max(1, round(weight * unit))
        for i, ch in enumerate(text):
            for line in DIGITS[ch]:
                pts = []
                for lx, ly in line:
                    px = (lx + i * advance - total / 2) * unit
                    py = (ly - 0.8) * unit
                    pts.append((ox + tx * px - nx * py, oy + ty * px - ny * py))
                self.d.line(pts, fill=color, width=width, joint="curve")
                for x, y in (pts[0], pts[-1]):
                    self.d.ellipse((x - width / 2, y - width / 2, x + width / 2, y + width / 2), fill=color)

    def gear(self, center, r, teeth, color, spokes=5):
        cx, cy = C + center[0] * R, C + center[1] * R
        pts = []
        for i in range(teeth * 4):
            a = 2 * math.pi * i / (teeth * 4)
            rr = r * (1.0 if i % 4 in (0, 1) else 0.9)
            pts.append((cx + math.cos(a) * rr * R, cy + math.sin(a) * rr * R))
        self.d.polygon(pts, fill=color)
        inner = r * 0.74
        self.d.ellipse((cx - inner * R, cy - inner * R, cx + inner * R, cy + inner * R), fill=(0, 0, 0, 0))
        for i in range(spokes):
            a = 2 * math.pi * i / spokes + 0.3
            self.d.line([(cx, cy), (cx + math.cos(a) * r * 0.8 * R, cy + math.sin(a) * r * 0.8 * R)], fill=color, width=round(r * 0.13 * R))
        hub = r * 0.26
        self.d.ellipse((cx - hub * R, cy - hub * R, cx + hub * R, cy + hub * R), fill=color)

    def jewel(self, center, r, color=(190, 30, 80)):
        cx, cy = C + center[0] * R, C + center[1] * R
        self.d.ellipse((cx - r * 1.5 * R, cy - r * 1.5 * R, cx + r * 1.5 * R, cy + r * 1.5 * R), fill=(196, 160, 104))
        self.d.ellipse((cx - r * R, cy - r * R, cx + r * R, cy + r * R), fill=color)
        self.d.ellipse((cx - r * 0.55 * R, cy - r * 0.7 * R, cx - r * 0.05 * R, cy - r * 0.2 * R), fill=(255, 170, 200))

    def date_window(self, r_center, width, height, frame):
        x, y = P(90, r_center)
        w, h = width * R / 2, height * R / 2
        self.d.rounded_rectangle((x - w - 0.012 * R, y - h - 0.012 * R, x + w + 0.012 * R, y + h + 0.012 * R), radius=0.012 * R, fill=frame)
        self.d.rounded_rectangle((x - w, y - h, x + w, y + h), radius=0.008 * R, fill=(248, 247, 242))

    def save(self, name):
        # Two sizes. WidgetKit won't draw a widget holding an image much
        # larger than itself (about twice its height in pixels), so a small
        # widget gets a picture of its own.
        for asset, pixels in ((name, FINAL), (name + "-small", SMALL)):
            out = self.img.resize((pixels, pixels), Image.LANCZOS)
            folder = os.path.join(ASSETS, asset + ".imageset")
            os.makedirs(folder, exist_ok=True)
            out.save(os.path.join(folder, asset + "@3x.png"), optimize=True)
            with open(os.path.join(folder, "Contents.json"), "w") as f:
                json.dump({
                    "images": [{"idiom": "universal", "scale": "3x", "filename": asset + "@3x.png"}],
                    "info": {"author": "xcode", "version": 1},
                }, f, indent=2)
            print(f"  {asset}: {os.path.getsize(os.path.join(folder, asset + '@3x.png')) // 1024} KB")


# ---- a stroke font for digits, on a 1 x 1.6 box, y down

def arc(cx, cy, rx, ry, a0, a1, n=28):
    """Points along an ellipse from a0 to a1 degrees (0 = right, 90 = down)."""
    return [(cx + rx * math.cos(math.radians(a0 + (a1 - a0) * i / n)), cy + ry * math.sin(math.radians(a0 + (a1 - a0) * i / n))) for i in range(n + 1)]


DIGITS = {
    "0": [arc(0.5, 0.8, 0.40, 0.72, 0, 360, 40)],
    "1": [[(0.24, 0.40), (0.56, 0.08), (0.56, 1.52)]],
    "2": [arc(0.5, 0.48, 0.40, 0.40, 190, 395) + [(0.10, 1.52), (0.92, 1.52)]],
    "3": [arc(0.48, 0.44, 0.36, 0.36, 205, 450), arc(0.48, 1.14, 0.40, 0.38, 270, 515)],
    "4": [[(0.72, 1.52), (0.72, 0.08), (0.08, 1.10), (0.94, 1.10)]],
    "5": [[(0.86, 0.08), (0.22, 0.08), (0.15, 0.74)] + arc(0.47, 1.10, 0.42, 0.42, 232, 505)],
    "6": [arc(0.56, 0.84, 0.46, 0.76, 300, 182), arc(0.5, 1.10, 0.40, 0.42, 0, 360, 36)],
    "7": [[(0.08, 0.08), (0.92, 0.08), (0.40, 1.52)]],
    "8": [arc(0.5, 0.43, 0.33, 0.35, 0, 360, 32), arc(0.5, 1.14, 0.40, 0.38, 0, 360, 36)],
    "9": [arc(0.5, 0.50, 0.40, 0.42, 0, 360, 36), arc(0.44, 0.76, 0.46, 0.76, 0, 118)],
}

STEEL = (228, 231, 238)
LUME = (238, 240, 226)
WHITE = (245, 245, 245)


def case(dial, color, bezel_outer=0.90):
    """The case: a dark rim, brushed metal, and a polished lip."""
    dial.disc(1.0, shade(color, 0.35))
    dial.metal(bezel_outer, 0.985, color)
    dial.circle(bezel_outer + 0.004, shade(color, 0.45), 0.008)


def diver():
    """A dive watch: rotating minute bezel, big luminous markers, date at 3."""
    navy = hexc("#0d2344")
    d = Dial()
    case(d, STEEL)
    # Bezel: a coin edge, then the colored insert with its minute scale.
    d.conic(0.865, 0.90, lambda a: shade(STEEL, 0.55 if int(a / 3) % 2 else 0.95))
    d.conic(0.70, 0.865, lambda a: shade(navy, 0.85 + 0.25 * math.cos(math.radians(2 * (a + 30)))))
    silver = (214, 219, 228)
    for m in range(60):
        angle = m * 6
        if m == 0:
            continue
        if m % 10 == 0:
            d.number(str(m), angle, 0.782, 0.105, silver)
        elif m % 5 == 0:
            d.baton(angle, 0.735, 0.83, 0.03, silver)
        elif m < 15 and m not in (9, 11):
            # Minute marks for the first quarter hour, clear of the "10".
            d.tick(angle, 0.745, 0.80, silver, 0.012)
    d.triangle(0, 0.725, 0.84, 0.062, silver)
    x, y = P(0, 0.798)
    d.d.ellipse((x - 0.026 * R, y - 0.026 * R, x + 0.026 * R, y + 0.026 * R), fill=LUME)
    # Inner ring and dial.
    d.metal(0.66, 0.70, STEEL, light=20)
    d.sunburst(0.66, navy)
    d.vignette(0.66)
    for m in range(60):
        d.tick(m * 6, 0.615, 0.65, WHITE, 0.014 if m % 5 == 0 else 0.007)
    for h in range(12):
        angle = h * 30
        if h == 0:
            d.triangle(0, 0.40, 0.585, 0.085, STEEL)
            d.triangle(0, 0.428, 0.573, 0.062, LUME)
        elif h in (6, 9):
            d.applied_baton(angle, 0.42, 0.585, 0.075, STEEL, LUME)
        elif h != 3:
            d.applied_dot(angle, 0.515, 0.062, STEEL, LUME)
    d.date_window(0.50, 0.17, 0.125, STEEL)
    d.save("watch-diver")


def gmt():
    """A travel watch: a 24-hour bezel that runs from night to day and back."""
    night, dusk, day = hexc("#0b1530"), hexc("#d4572a"), hexc("#e2a23a")
    d = Dial()
    case(d, STEEL)
    d.conic(0.865, 0.90, lambda a: shade(STEEL, 0.55 if int(a / 3) % 2 else 0.95))

    def sky(a):
        t = (1 - math.cos(math.radians(a))) / 2      # 0 at midnight (top), 1 at noon
        if t < 0.5:
            return mix(night, dusk, (t / 0.5) ** 1.6)
        return mix(dusk, day, (t - 0.5) / 0.5)
    d.conic(0.70, 0.865, sky)
    for h in range(24):
        angle = h * 15
        if h == 0:
            d.triangle(0, 0.725, 0.84, 0.06, WHITE)
        elif h % 2 == 0:
            d.number(str(h), angle, 0.782, 0.10, WHITE)
        else:
            x, y = P(angle, 0.782)
            d.d.ellipse((x - 0.014 * R, y - 0.014 * R, x + 0.014 * R, y + 0.014 * R), fill=WHITE)
    d.metal(0.66, 0.70, STEEL, light=20)
    d.disc(0.66, (16, 17, 20))
    d.conic(0, 0.66, lambda a: shade((22, 23, 27), 0.9 + 0.2 * math.cos(math.radians(2 * (a - 60)))))
    d.vignette(0.66, 0.5)
    for m in range(60):
        d.tick(m * 6, 0.62, 0.65, WHITE, 0.012 if m % 5 == 0 else 0.006)
    for h in range(12):
        angle = h * 30
        if h == 0:
            for off in (-0.045, 0.045):
                a = math.degrees(math.atan2(off, 0.5))
                d.applied_baton(a, 0.415, 0.59, 0.052, STEEL, LUME)
        elif h in (6, 9):
            d.applied_baton(angle, 0.415, 0.59, 0.062, STEEL, LUME)
        elif h != 3:
            d.applied_baton(angle, 0.47, 0.59, 0.052, STEEL, LUME)
    d.date_window(0.50, 0.17, 0.125, STEEL)
    d.save("watch-gmt")


def chrono():
    """A chronograph: pale dial, three dark sub-dials, tachymeter bezel."""
    silver = (232, 232, 228)
    ink = (22, 23, 26)
    d = Dial()
    case(d, STEEL)
    # Tachymeter bezel: units per hour for an event timed in seconds.
    d.conic(0.74, 0.90, lambda a: shade((26, 27, 31), 0.85 + 0.3 * math.cos(math.radians(2 * (a + 30)))))
    for value in (400, 300, 240, 200, 180, 160, 140, 120, 110, 100, 90, 80, 70, 60):
        angle = (3600 / value) * 6 % 360
        d.number(str(value), angle, 0.83, 0.062, WHITE, weight=0.17)
    for value in list(range(60, 201, 5)) + list(range(200, 401, 20)):
        angle = (3600 / value) * 6 % 360
        d.tick(angle, 0.745, 0.775, WHITE, 0.006)
    d.metal(0.70, 0.74, STEEL, light=20)
    d.sunburst(0.70, silver, contrast=0.10)
    d.vignette(0.70, 0.25)
    for m in range(300):
        if m % 5 == 0:
            d.tick(m * 1.2, 0.645 if m % 25 else 0.63, 0.69, ink, 0.007 if m % 25 else 0.012)
    for h in range(12):
        if h not in (3, 6, 9):
            angle = h * 30
            d.baton(angle, 0.50, 0.61, 0.045, shade(STEEL, 0.5))
            d.baton(angle, 0.505, 0.605, 0.028, ink)
    # Sub-dials at 3, 6 and 9: sunk, ringed, with a fine scale.
    for cx, cy, count in ((0.36, 0.0, 7), (0.0, 0.36, 31), (-0.36, 0.0, 24)):
        d.disc(0.205, shade(STEEL, 0.55), (cx, cy))
        d.disc(0.19, ink, (cx, cy))
        for k in range(1, 6):
            d.circle(0.19 * k / 6, (40, 41, 46), 0.004, (cx, cy))
        for i in range(count):
            a = math.radians(360 * i / count)
            long = (i % 5 == 0) if count > 12 else True
            r0, r1 = (0.145 if long else 0.16), 0.182
            x0, y0 = C + (cx + math.sin(a) * r0) * R, C + (cy - math.cos(a) * r0) * R
            x1, y1 = C + (cx + math.sin(a) * r1) * R, C + (cy - math.cos(a) * r1) * R
            d.d.line([(x0, y0), (x1, y1)], fill=WHITE, width=max(1, round((0.008 if long else 0.004) * R)))
    d.save("watch-chrono")


def orrery():
    """An open-worked watch: wheels and bridges on show, ringed by an orbit."""
    gold = (214, 160, 118)
    brass = (188, 150, 92)
    plate = (22, 23, 28)
    d = Dial()
    case(d, gold)
    d.metal(0.84, 0.90, gold, light=20, contrast=0.4)
    d.disc(0.84, (10, 10, 13))
    # The flange: a minute track and hour markers floating above the movement.
    for m in range(60):
        x, y = P(m * 6, 0.795)
        rad = 0.011 if m % 5 else 0.0
        if rad:
            d.d.ellipse((x - rad * R, y - rad * R, x + rad * R, y + rad * R), fill=shade(gold, 0.8))
    for h in range(12):
        d.baton(h * 30, 0.745, 0.83, 0.05 if h % 3 == 0 else 0.03, gold)
    d.disc(0.72, plate)
    d.conic(0, 0.72, lambda a: shade((30, 31, 37), 0.85 + 0.25 * math.cos(math.radians(2 * (a - 40)))))
    # The movement: wheels, then bridges across them, then jewels and screws.
    for center, r, teeth in (((-0.30, -0.26), 0.25, 30), ((0.31, -0.30), 0.19, 22), ((0.36, 0.14), 0.15, 18), ((-0.40, 0.16), 0.13, 16), ((0.0, 0.0), 0.17, 20)):
        d.soft_shadow(lambda c, center=center, r=r, teeth=teeth: d.gear(center, r, teeth, c), alpha=170)
        d.gear(center, r, teeth, brass)
    bridge = (58, 60, 70)
    for a0, a1, r in ((200, 330, 0.50), (20, 110, 0.47)):
        pts = [P(a, r) for a in range(a0, a1 + 1, 2)]
        d.d.line(pts, fill=shade(bridge, 0.55), width=round(0.115 * R), joint="curve")
        d.d.line(pts, fill=bridge, width=round(0.095 * R), joint="curve")
        d.d.line([P(a, r + 0.036) for a in range(a0, a1 + 1, 2)], fill=shade(bridge, 1.5), width=round(0.006 * R), joint="curve")
    for center in ((-0.30, -0.26), (0.31, -0.30), (0.36, 0.14), (-0.40, 0.16)):
        d.jewel(center, 0.028)
    for angle, r in ((205, 0.50), (325, 0.50), (25, 0.47), (105, 0.47)):
        x, y = P(angle, r)
        d.d.ellipse((x - 0.03 * R, y - 0.03 * R, x + 0.03 * R, y + 0.03 * R), fill=(44, 78, 160))
        d.d.line([(x - 0.02 * R, y), (x + 0.02 * R, y)], fill=(14, 28, 70), width=round(0.008 * R))
    # The path the orbiting globe follows.
    d.circle(0.635, shade(gold, 0.55), 0.005)
    # The cock that holds the balance wheel, at 6 o'clock.
    d.d.line([P(180, 0.26), P(180, 0.66)], fill=shade(bridge, 0.55), width=round(0.14 * R))
    d.d.line([P(180, 0.27), P(180, 0.65)], fill=bridge, width=round(0.12 * R))
    d.jewel((0.0, 0.45), 0.03)
    d.save("watch-orrery")


# ---- faces with moving scenes
#
# For these four the image is only the stage: the case, the bezel and
# whatever stays still. The scene itself (pistons, a roulette wheel, an
# orrery, dragons) is a motion font made by tools/make_motion_fonts.py.

def gem_bezel(dial, r0, r1, count, base=(232, 237, 246)):
    """A bezel set with rectangular stones, each catching the light its own way."""
    step = 360 / count
    for i in range(count):
        a0, a1 = i * step + step * 0.07, (i + 1) * step - step * 0.07
        glint = 0.80 + 0.2 * math.sin(i * 2.4) * math.cos(i * 0.7) + (0.14 if i % 7 == 3 else 0)
        color = shade(base, max(0.58, min(1.08, glint)))
        dial.d.polygon([P(a0, r0), P(a0, r1), P(a1, r1), P(a1, r0)], fill=color)
        # The table: the flat top of the stone, inside its sloping sides.
        inset_a, inset_r = (a1 - a0) * 0.24, (r1 - r0) * 0.24
        table = [P(a0 + inset_a, r0 + inset_r), P(a0 + inset_a, r1 - inset_r), P(a1 - inset_a, r1 - inset_r), P(a1 - inset_a, r0 + inset_r)]
        dial.d.polygon(table, fill=shade(color, 1.14))
        dial.d.line([table[0], table[2]], fill=shade(color, 0.86), width=SS)


def upright_number(dial, text, x, y, height, color, weight=0.16):
    """Digits the right way up, centered on a point given in case radii."""
    unit = height * R / 1.6
    advance = 1.22
    total = (len(text) - 1) * advance + 1
    width = max(1, round(weight * unit))
    for i, ch in enumerate(text):
        for line in DIGITS[ch]:
            pts = [(C + x * R + (lx + i * advance - total / 2) * unit, C + y * R + (ly - 0.8) * unit) for lx, ly in line]
            dial.d.line(pts, fill=color, width=width, joint="curve")


def engine():
    """A watch with an engine in it: a rev counter for the seconds, and a
    row of cylinders whose pistons the font drives."""
    gun = (104, 108, 118)
    red = (218, 44, 46)
    d = Dial()
    case(d, gun)
    d.conic(0.86, 0.90, lambda a: shade(red, 0.72 + 0.28 * math.cos(math.radians(2 * (a - 30)))))
    d.disc(0.86, (10, 11, 13))
    d.conic(0, 0.86, lambda a: shade((23, 24, 29), 0.82 + 0.26 * math.cos(math.radians(2 * (a - 40)))))
    d.vignette(0.86, 0.4)
    for m in range(60):
        d.tick(m * 6, 0.805, 0.848, WHITE, 0.012 if m % 5 == 0 else 0.005)
    for h in range(12):
        d.baton(h * 30, 0.70, 0.79, 0.042, WHITE)
        d.baton(h * 30, 0.70, 0.728, 0.042, red)

    # The rev counter: the red needle (in the font) crosses it once a minute.
    gx, gy = 0.0, -0.36
    d.disc(0.262, shade(gun, 0.85), (gx, gy))
    d.disc(0.243, (7, 8, 10), (gx, gy))
    for second in range(61):
        a = math.radians(-120 + 4 * second)
        long = second % 10 == 0
        r0, r1 = (0.195 if long else 0.215), 0.238
        color = red if second >= 50 else WHITE
        d.d.line(
            [(C + (gx + math.sin(a) * r0) * R, C + (gy - math.cos(a) * r0) * R), (C + (gx + math.sin(a) * r1) * R, C + (gy - math.cos(a) * r1) * R)],
            fill=color, width=max(1, round((0.012 if long else 0.005) * R)))
        if long:
            upright_number(d, str(second // 10), gx + math.sin(a) * 0.155, gy - math.cos(a) * 0.155, 0.05, color)

    # The engine bay: eight glass cylinders over a crankcase.
    x0, x1, y0, y1 = -0.46, 0.46, 0.14, 0.60
    box = (C + x0 * R, C + y0 * R, C + x1 * R, C + y1 * R)
    d.d.rounded_rectangle((box[0] - 0.014 * R, box[1] - 0.014 * R, box[2] + 0.014 * R, box[3] + 0.014 * R), radius=0.05 * R, fill=shade(gun, 0.8))
    d.d.rounded_rectangle(box, radius=0.04 * R, fill=(15, 16, 20))
    d.d.rectangle((C + (x0 + 0.02) * R, C + 0.475 * R, C + (x1 - 0.02) * R, C + (y1 - 0.02) * R), fill=(26, 28, 34))
    for i in range(8):
        cx = -0.3675 + i * 0.105
        d.d.rectangle((C + (cx - 0.045) * R, C + 0.165 * R, C + (cx + 0.045) * R, C + 0.205 * R), fill=shade(gun, 0.95))
        d.d.rectangle((C + (cx - 0.008) * R, C + 0.15 * R, C + (cx + 0.008) * R, C + 0.17 * R), fill=red)
        d.d.rectangle((C + (cx - 0.0435) * R, C + 0.205 * R, C + (cx + 0.0435) * R, C + 0.475 * R), fill=(30, 34, 42), outline=(128, 138, 156), width=max(1, round(0.005 * R)))
        d.d.line([(C + (cx - 0.03) * R, C + 0.215 * R), (C + (cx - 0.03) * R, C + 0.465 * R)], fill=(86, 94, 110), width=max(1, round(0.006 * R)))
    d.save("watch-engine")


def roulette():
    """A casino watch. The image is the case, a bezel of stones and the
    track the ball runs on; the wheel and the ball are the font."""
    d = Dial()
    case(d, STEEL)
    gem_bezel(d, 0.872, 0.978, 44)
    d.metal(0.842, 0.872, STEEL, light=20)
    d.conic(0.775, 0.842, lambda a: shade((104, 58, 28), 0.74 + 0.34 * math.cos(math.radians(2 * (a - 30)))))
    d.circle(0.842, (58, 30, 14), 0.006)
    d.disc(0.775, (12, 12, 14))
    d.save("watch-roulette")


def carousel():
    """A night-blue dial scattered with gold flecks, for an orrery whose
    four arms the font carries round."""
    import random
    rng = random.Random(11)
    d = Dial()
    case(d, STEEL)
    d.metal(0.855, 0.90, STEEL, light=20)
    blue = hexc("#0b1a52")
    d.disc(0.855, blue)
    d.conic(0, 0.855, lambda a: shade(blue, 0.74 + 0.32 * math.cos(math.radians(2 * (a - 55)))))
    for _ in range(520):
        r, a = 0.84 * math.sqrt(rng.random()), rng.random() * 360
        x, y = P(a, r)
        size = (0.0035 + 0.007 * rng.random() ** 3) * R
        glint = rng.choice([(255, 232, 178), (255, 246, 222), (214, 228, 255)])
        d.d.ellipse((x - size, y - size, x + size, y + size), fill=glint + (round(90 + 165 * rng.random()),))
    d.vignette(0.855, 0.5)
    for m in range(60):
        if m % 5:
            x, y = P(m * 6, 0.80)
            d.d.ellipse((x - 0.008 * R, y - 0.008 * R, x + 0.008 * R, y + 0.008 * R), fill=(196, 204, 222))
    for h in range(12):
        d.applied_baton(h * 30, 0.725, 0.825, 0.05 if h % 3 == 0 else 0.034, STEEL, (250, 250, 252))
    # The circle the four arms' ends follow.
    d.circle(0.50, (120, 136, 190), 0.004)
    d.save("watch-carousel")


def dragon():
    """Red lacquer in a rose-gold case, with a stone at every hour. Two
    dragons (the font) circle the well in the middle."""
    rose = (224, 166, 130)
    red = hexc("#7d0f1f")
    d = Dial()
    case(d, rose)
    d.metal(0.84, 0.90, rose, light=20, contrast=0.4)
    d.disc(0.84, red)
    d.conic(0, 0.84, lambda a: shade(red, 0.72 + 0.36 * math.cos(math.radians(2 * (a - 40)))))
    # Engine-turned rings.
    for k in range(1, 28):
        d.circle(0.03 * k, shade(red, 0.62), 0.004)
    d.vignette(0.84, 0.55)
    for h in range(12):
        angle = h * 30
        long = h % 3 == 0
        tip, base = (0.70 if long else 0.735), 0.815
        for scale, color in ((1.0, shade(rose, 0.9)), (0.74, (246, 248, 252))):
            d.triangle(angle, base - (base - tip) * scale, base, 0.034 * scale, color)
            x, y = P(angle, base)
            rad = 0.034 * scale * R
            d.d.ellipse((x - rad, y - rad, x + rad, y + rad), fill=color)
    # The well the cage turns in.
    d.disc(0.235, shade(rose, 0.8))
    d.disc(0.215, (16, 8, 10))
    d.save("watch-dragon")


if __name__ == "__main__":
    os.makedirs(ASSETS, exist_ok=True)
    for make in (diver, gmt, chrono, orrery, engine, roulette, carousel, dragon):
        make()
