#!/usr/bin/env python3
"""Builds the fonts that keep widgets moving (ios/Shared/Fonts/*.ttf).

iOS redraws a widget only when its timeline moves on to a new entry, with
one exception: text that shows a running timer, which iOS itself updates
every second for as long as the widget is on screen. These fonts turn that
timer into animation. A font here has no letters. Its digits are blank, and
a ligature replaces the whole of what the timer reads ("7:05") with a single
glyph that draws the scene as it should look at that second: a second hand
at five past, or every planet where it should be 425 seconds into the hour.
The timer must count from the top of an hour, and a scene may take up to an
hour to repeat.

The text is always exactly one glyph, and so one em, wide and tall: the
view that shows it (TimerGlyph in MotionFonts.swift) is the same size, which
leaves nothing for text alignment to decide.

A glyph is either an outline, which the widget colors like any text, or an
SVG drawing with colors of its own.

Glyph space: the em is 1000 units and holds the whole scene; the baseline is
its bottom edge. Outlines have y up. SVG has y down, so the em's center is
(500, -500).

Needs fontTools (pip install fonttools). The technique is from Bryce
Bostwick's WidgetAnimation (github.com/brycebostwick/WidgetAnimation).
"""

import json
import math
import os
import random
import re
import sys

from fontTools.feaLib.builder import addOpenTypeFeaturesFromString
from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib import newTable
from fontTools.ttLib.tables.S_V_G_ import SVGDocument

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from make_watch_faces import DIGITS as STROKE_DIGITS  # noqa: E402
from make_zodiac import signs  # noqa: E402

OUT = os.path.join(HERE, "..", "Shared", "Fonts")
RIVER_DATA = os.path.join(HERE, "..", "Shared", "RiverData.swift")

EM = 1000
DIGITS = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine"]
# The timer's separator, and anything else that might stand in for it.
SEPARATORS = [0x3A, 0x2236, 0xFF1A, 0xA789, 0x2E]
# Characters that must draw nothing rather than fall back to a system font.
BLANKS = [0x20, 0xA0, 0x202F, 0x2009, 0x200E, 0x200F, 0x061C, 0x2212, 0x2D, 0x2C]
# Other digit sets a phone's region may use, mapped onto the same glyphs.
DIGIT_BLOCKS = [0x30, 0x0660, 0x06F0, 0x0966]


# ---------------------------------------------------------------- outlines

def area(points):
    return sum(x0 * y1 - x1 * y0 for (x0, y0), (x1, y1) in zip(points, points[1:] + points[:1])) / 2


def outline(contours):
    """A glyph from closed polygons. All are wound the same way, so that
    overlapping pieces join instead of cutting holes in each other."""
    pen = TTGlyphPen(None)
    for points in contours:
        points = [(round(x), round(y)) for x, y in points]
        if area(points) > 0:
            points.reverse()
        pen.moveTo(points[0])
        for point in points[1:]:
            pen.lineTo(point)
        pen.closePath()
    return pen.glyph()


def speck_box():
    """What an SVG glyph has for an outline: two specks at opposite corners
    of the em, so the glyph's bounds are the whole em but nothing shows if
    the outline is ever drawn in place of the SVG."""
    return outline([[(0, 0), (0, 2), (2, 0)], [(EM, EM), (EM, EM - 2), (EM - 2, EM)]])


def disc(cx, cy, r, sides=36):
    return [(cx + r * math.cos(2 * math.pi * i / sides), cy + r * math.sin(2 * math.pi * i / sides)) for i in range(sides)]


class Dial:
    """Places shapes on a watch dial: angles clockwise from 12 in degrees,
    distances in case radii, as WatchFaces.swift measures them."""

    unit = EM / 2 * 0.985

    def __init__(self, angle):
        a = math.radians(angle)
        self.sin, self.cos = math.sin(a), math.cos(a)

    def point(self, across, out):
        """`out` toward the hand's tip, `across` to its right."""
        x = across * self.cos + out * self.sin
        y = -across * self.sin + out * self.cos
        return (EM / 2 + x * self.unit, EM / 2 + y * self.unit)

    def hand(self, start, length, width, tip_width, point=0.0):
        points = [self.point(-width / 2, start), self.point(-tip_width / 2, length - point)]
        if point > 0:
            points.append(self.point(0, length))
        points += [self.point(tip_width / 2, length - point), self.point(width / 2, start)]
        return points

    def dot(self, out, radius):
        cx, cy = self.point(0, out)
        return disc(cx, cy, radius * self.unit)


def needle_hand(length, dot_at=None, tail=-0.18):
    """A thin second hand, with a round counterweight or a luminous dot."""
    def glyph(second):
        dial = Dial(second * 6)
        parts = [dial.hand(tail, length, 0.016, 0.009), dial.dot(0, 0.03)]
        if dot_at is not None:
            parts.append(dial.dot(dot_at, 0.036))
        else:
            parts.append(dial.dot(tail + 0.02, 0.026))
        return outline(parts)
    return glyph


def sweep_ring(second):
    """The Dial Clock's seconds: an arc that grows from 12 through the
    minute, led round by a dot. Sizes match SecondsSweep in WidgetViews.swift."""
    width = EM * 0.065
    dot = width * 2.1
    radius = (EM - dot) / 2
    cx = cy = EM / 2
    angle = second * 6

    def at(r, degrees):
        a = math.radians(degrees)
        return (cx + r * math.sin(a), cy + r * math.cos(a))

    parts = []
    if second > 0:
        steps = max(2, int(angle / 3))
        outer = [at(radius + width / 2, angle * i / steps) for i in range(steps + 1)]
        inner = [at(radius - width / 2, angle * i / steps) for i in range(steps, -1, -1)]
        parts.append(outer + inner)
        parts.append(disc(*at(radius, 0), width / 2, 20))
    parts.append(disc(*at(radius, angle), dot / 2))
    return outline(parts)


# -------------------------------------------------------------- SVG pieces

def svg_document(defs, glyphs):
    """One SVG document holding several glyphs: [(glyph id, body)]."""
    body = "".join(f'<g id="glyph{gid}">{content}</g>' for gid, content in glyphs)
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">'
        f"<defs>{defs}</defs>{body}</svg>"
    )


def use(name, x, y, rotate=None, scale=None):
    transform = f"translate({x:.1f} {y:.1f})"
    if rotate is not None:
        transform += f" rotate({rotate:.0f})"
    if scale is not None:
        transform += f" scale({scale:g})"
    return f'<use xlink:href="#{name}" transform="{transform}"/>'


# A planet is drawn in two layers. Its surface keeps the same way up
# wherever it is; over that goes shading, turned so the lit side faces the
# sun. The shading is drawn for a planet of radius 100 with the sun to its
# left, and scaled to fit.
SHADE = (
    '<linearGradient id="sg" gradientUnits="userSpaceOnUse" x1="-100" y1="0" x2="100" y2="0">'
    '<stop offset="0" stop-color="#000" stop-opacity="0"/>'
    '<stop offset="0.42" stop-color="#000" stop-opacity="0.06"/>'
    '<stop offset="0.74" stop-color="#00020a" stop-opacity="0.58"/>'
    '<stop offset="1" stop-color="#00020a" stop-opacity="0.84"/></linearGradient>'
    '<radialGradient id="hg" gradientUnits="userSpaceOnUse" cx="-48" cy="-22" r="74">'
    '<stop offset="0" stop-color="#fff" stop-opacity="0.5"/>'
    '<stop offset="1" stop-color="#fff" stop-opacity="0"/></radialGradient>'
    '<g id="S"><circle cx="0" cy="0" r="100" fill="url(#hg)"/><circle cx="0" cy="0" r="101" fill="url(#sg)"/></g>'
)


def clip(name, r):
    return f'<clipPath id="{name}"><circle cx="0" cy="0" r="{r}"/></clipPath>'


def bands(r, stripes):
    """Horizontal stripes across a planet: [(top, height, color, opacity)]
    as fractions of the radius."""
    return "".join(
        f'<rect x="{-r}" y="{top * r:.1f}" width="{2 * r}" height="{height * r:.1f}" fill="{color}" fill-opacity="{opacity}"/>'
        for top, height, color, opacity in stripes
    )


class Planet:
    def __init__(self, key, radius, period, phase, surface, extra_front=""):
        self.key = key
        self.radius = radius
        self.period = period
        self.phase = phase
        self.surface = surface
        self.extra_front = extra_front


def planet_art():
    """The eight planets and the Moon, each as SVG centered on its own
    origin. Returns the definitions and the list of planets, sun outward."""
    defs = [SHADE]
    planets = []

    def add(key, radius, period, phase, inner, front=""):
        defs.append(clip(f"c{key}", radius))
        defs.append(f'<g id="p{key}">{inner}</g>')
        if front:
            defs.append(f'<g id="f{key}">{front}</g>')
        planets.append(Planet(key, radius, period, phase, f"p{key}", f"f{key}" if front else ""))

    def ball(key, r, light, dark, details=""):
        gradient = (
            f'<radialGradient id="g{key}" gradientUnits="userSpaceOnUse" cx="0" cy="0" r="{r}">'
            f'<stop offset="0" stop-color="{light}"/><stop offset="1" stop-color="{dark}"/></radialGradient>'
        )
        defs.append(gradient)
        return f'<circle cx="0" cy="0" r="{r}" fill="url(#g{key})"/><g clip-path="url(#c{key})">{details}</g>'

    # Mercury: grey rock with craters.
    r = 11
    add("1", r, 90, 40, ball("1", r, "#b9aea3", "#857a70",
        f'<circle cx="-3" cy="-4" r="2.6" fill="#6f655d" fill-opacity="0.75"/>'
        f'<circle cx="4" cy="2" r="3.2" fill="#6f655d" fill-opacity="0.6"/>'
        f'<circle cx="-2" cy="6" r="1.8" fill="#655c55" fill-opacity="0.7"/>'
        f'<circle cx="6" cy="-6" r="1.5" fill="#d2c8bd" fill-opacity="0.6"/>'))

    # Venus: cream cloud with soft swirls.
    r = 16
    add("2", r, 180, 205, ball("2", r, "#f6e6b8", "#dba659",
        bands(r, [(-0.75, 0.22, "#fff6d8", 0.55), (-0.2, 0.2, "#c98f45", 0.45), (0.3, 0.26, "#fff1c9", 0.5), (0.7, 0.2, "#c58a43", 0.4)])
        + '<path d="M-16 -3 Q-4 -9 6 -3 T16 -4 V1 Q8 -1 0 2 T-16 2 Z" fill="#fffbe9" fill-opacity="0.45"/>'))

    # Earth: ocean, land, cloud, and a thin blue atmosphere.
    r = 17
    land = (
        '<path d="M-13 -9 Q-8 -14 -2 -11 Q1 -7 -3 -4 Q-1 1 -6 3 Q-10 0 -11 -4 Z" fill="#4cae4f"/>'
        '<path d="M-5 4 Q0 2 2 7 Q3 12 -1 15 Q-5 12 -4 8 Z" fill="#3f9a45"/>'
        '<path d="M5 -10 Q11 -12 14 -6 Q15 0 11 3 Q7 1 8 -4 Q4 -6 5 -10 Z" fill="#59b04f"/>'
        '<path d="M9 6 Q13 5 14 9 Q12 12 9 10 Z" fill="#c9b077"/>'
        '<ellipse cx="0" cy="-16" rx="9" ry="2.6" fill="#f4fbff"/>'
        '<ellipse cx="0" cy="16.4" rx="8" ry="2.2" fill="#f4fbff"/>'
        '<path d="M-17 -2 Q-9 -6 -1 -3 Q5 -1 10 -4" fill="none" stroke="#fff" stroke-opacity="0.8" stroke-width="2.2" stroke-linecap="round"/>'
        '<path d="M-10 9 Q-2 6 5 9 Q10 11 16 8" fill="none" stroke="#fff" stroke-opacity="0.7" stroke-width="1.8" stroke-linecap="round"/>'
    )
    add("3", r, 300, 115,
        f'<circle cx="0" cy="0" r="{r + 1.6}" fill="#9ad6ff" fill-opacity="0.34"/>' + ball("3", r, "#4fa8ff", "#1456bd", land))

    # Mars: rust, darker plains, a polar cap.
    r = 13
    add("4", r, 450, 300, ball("4", r, "#e9794a", "#a23f20",
        '<path d="M-12 -2 Q-6 -7 0 -3 Q5 0 3 4 Q-3 6 -8 3 Z" fill="#7d2e17" fill-opacity="0.65"/>'
        '<path d="M4 -8 Q9 -9 11 -4 Q8 -2 5 -4 Z" fill="#7d2e17" fill-opacity="0.5"/>'
        '<path d="M2 7 Q7 5 10 8 Q7 11 3 10 Z" fill="#f2a06f" fill-opacity="0.6"/>'
        '<ellipse cx="0" cy="-12.6" rx="6.5" ry="2.4" fill="#fff5ee"/>'))

    # Jupiter: belts and zones, and the red spot.
    r = 30
    add("5", r, 900, 25, ball("5", r, "#f0dfc0", "#d8b98c",
        bands(r, [
            (-1.0, 0.2, "#a98562", 0.9), (-0.8, 0.14, "#e8d2ae", 1), (-0.66, 0.2, "#b9814f", 1),
            (-0.46, 0.2, "#f5ead3", 1), (-0.26, 0.24, "#a86c3c", 1), (-0.02, 0.2, "#f7efdc", 1),
            (0.18, 0.2, "#b67b47", 1), (0.38, 0.16, "#ecd9b6", 1), (0.54, 0.18, "#b98c62", 1),
            (0.72, 0.28, "#9c7c5e", 0.9),
        ])
        + '<ellipse cx="10" cy="8.5" rx="7.5" ry="4.2" fill="#c4553a"/>'
        + '<ellipse cx="10" cy="8.5" rx="4.6" ry="2.3" fill="#dd7d5c"/>'
        + '<ellipse cx="-12" cy="-10" rx="4" ry="1.4" fill="#f7efdc" fill-opacity="0.8"/>'))

    # Saturn: pale gold, with rings that pass behind and in front.
    r = 24
    ring = lambda sweep: (
        f'<g transform="rotate(-16)">'
        f'<path d="M-52 0 A52 14.5 0 0 {sweep} 52 0" fill="none" stroke="#e9dcb4" stroke-width="5.5"/>'
        f'<path d="M-43.5 0 A43.5 12 0 0 {sweep} 43.5 0" fill="none" stroke="#bda97a" stroke-width="4.5"/>'
        f'<path d="M-47.6 0 A47.6 13.2 0 0 {sweep} 47.6 0" fill="none" stroke="#3b3324" stroke-width="0.9"/>'
        f'<path d="M-37 0 A37 10.2 0 0 {sweep} 37 0" fill="none" stroke="#8f7f5c" stroke-width="2.4" stroke-opacity="0.8"/>'
        "</g>"
    )
    add("6", r, 1200, 170,
        ring(1) + ball("6", r, "#f3e6bb", "#d2b877",
            bands(r, [(-0.8, 0.22, "#c9ad6e", 0.7), (-0.4, 0.2, "#fbf2d2", 0.8), (-0.05, 0.22, "#c7a865", 0.7), (0.35, 0.2, "#f6ebc6", 0.7), (0.65, 0.4, "#b69a5f", 0.7)])),
        front=ring(0))

    # Uranus: smooth pale cyan, tipped on its side, with a faint ring.
    r = 18
    add("7", r, 1800, 250,
        '<ellipse cx="0" cy="0" rx="7" ry="29" fill="none" stroke="#d9fbff" stroke-opacity="0.35" stroke-width="1.4" transform="rotate(12)"/>'
        + ball("7", r, "#c9f4f4", "#63bfcb", bands(r, [(-0.3, 0.5, "#e9ffff", 0.35)])))

    # Neptune: deep blue with a dark storm and a bright streak.
    r = 17
    add("8", r, 3600, 70, ball("8", r, "#5f8dff", "#2238ae",
        bands(r, [(-0.55, 0.25, "#8fb4ff", 0.35), (0.3, 0.3, "#1a2c96", 0.4)])
        + '<ellipse cx="-4" cy="3" rx="5.5" ry="3" fill="#162583" fill-opacity="0.85"/>'
        + '<path d="M2 -6 Q8 -8 13 -5" fill="none" stroke="#dfe9ff" stroke-opacity="0.8" stroke-width="1.5" stroke-linecap="round"/>'))

    # The Moon, which goes round the Earth.
    defs.append('<g id="pm"><circle cx="0" cy="0" r="4.6" fill="#d5d8dc"/><circle cx="-1.2" cy="-0.8" r="1.3" fill="#a9adb3"/><circle cx="1.6" cy="1.4" r="0.9" fill="#a9adb3"/></g>')
    return "".join(defs), planets


# How far each planet is from the sun, in em units. The wide scene is for a
# widget about twice as wide as it is tall: the orbits are seen at a tilt,
# so they become ellipses `WIDE_TILT` as tall as they are wide.
ORBITS_ROUND = [92, 138, 190, 242, 308, 380, 436, 480]
ORBITS_WIDE = [118, 160, 206, 252, 312, 378, 432, 478]
WIDE_TILT = 0.42
MOON_ORBIT = 29
MOON_PERIOD = 60


def orbit_scene(planets, radii, tilt):
    def glyph(v):
        placed = []
        for planet, radius in zip(planets, radii):
            a = math.radians(planet.phase + 360.0 * v / planet.period)
            # Counter-clockwise on screen, as seen from above the north pole.
            x = 500 + radius * math.cos(a)
            y = -500 - radius * tilt * math.sin(a)
            placed.append((y, planet, x))
        # Far side first, so nearer planets cover farther ones.
        placed.sort(key=lambda item: item[0])
        parts = []
        for y, planet, x in placed:
            to_sun = math.degrees(math.atan2(-500 - y, 500 - x))
            lit = to_sun - 180
            parts.append(use(planet.surface, x, y))
            parts.append(use("S", x, y, rotate=lit, scale=planet.radius / 100))
            if planet.extra_front:
                parts.append(use(planet.extra_front, x, y))
            if planet.key == "3":
                m = math.radians(360.0 * v / MOON_PERIOD)
                mx = x + MOON_ORBIT * math.cos(m)
                my = y - MOON_ORBIT * max(tilt, 0.55) * math.sin(m)
                moon_lit = math.degrees(math.atan2(-500 - my, 500 - mx)) - 180
                parts.append(use("pm", mx, my))
                parts.append(use("S", mx, my, rotate=moon_lit, scale=0.046))
        return "".join(parts)
    return glyph


def skeleton_scene():
    """The Skeleton watch's moving parts: a balance wheel that swings each
    second, a globe that circles the dial once a minute and a gem that
    takes five. Measured in case radii, as WatchFaces.swift does."""
    u = Dial.unit
    gold = "#dba87a"
    wheel_r = 0.15 * u
    spoke = wheel_r * 0.95
    defs = (
        '<linearGradient id="gl" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#8cd9f2"/><stop offset="1" stop-color="#1a529e"/></linearGradient>'
        f'<g id="wh"><circle cx="0" cy="0" r="{wheel_r:.1f}" fill="none" stroke="{gold}" stroke-width="{0.026 * u:.1f}"/>'
        f'<rect x="{-0.011 * u:.1f}" y="{-spoke:.1f}" width="{0.022 * u:.1f}" height="{2 * spoke:.1f}" fill="{gold}"/>'
        f'<rect x="{-spoke:.1f}" y="{-0.011 * u:.1f}" width="{2 * spoke:.1f}" height="{0.022 * u:.1f}" fill="{gold}"/>'
        f'<circle cx="0" cy="0" r="{0.03 * u:.1f}" fill="{gold}"/></g>'
        f'<g id="gb"><circle cx="0" cy="0" r="{0.07 * u:.1f}" fill="url(#gl)"/>'
        f'<circle cx="0" cy="0" r="{0.07 * u:.1f}" fill="none" stroke="#e8f6ff" stroke-opacity="0.5" stroke-width="{0.008 * u:.1f}"/></g>'
        f'<g id="gm"><circle cx="0" cy="0" r="{0.0375 * u:.1f}" fill="#ebebeb"/><circle cx="{-0.012 * u:.1f}" cy="{-0.012 * u:.1f}" r="{0.012 * u:.1f}" fill="#fff"/></g>'
    )

    def glyph(v):
        second = v % 60
        globe = math.radians(second * 6)
        gem = math.radians(180 + v * 1.2)
        orbit = 0.635 * u
        return (
            use("wh", 500, -500 + 0.45 * u, rotate=42 if v % 2 == 0 else -42)
            + use("gb", 500 + orbit * math.sin(globe), -500 - orbit * math.cos(globe))
            + use("gm", 500 + orbit * math.sin(gem), -500 - orbit * math.cos(gem))
        )
    return defs, glyph


# ------------------------------------------------------- scenes for watches
#
# The four faces whose dial is a scene. Each is drawn around the origin in
# case radii times `U` and placed at the middle of the em, over the image
# tools/make_watch_faces.py makes for it.

U = Dial.unit


def centered(content, rotate=None):
    transform = "translate(500 -500)" + (f" rotate({rotate:g})" if rotate is not None else "")
    return f'<g transform="{transform}">{content}</g>'


def poly(points, fill, opacity=None):
    d = "M" + " L".join(f"{x:.1f} {y:.1f}" for x, y in points) + " Z"
    extra = f' fill-opacity="{opacity}"' if opacity is not None else ""
    return f'<path d="{d}" fill="{fill}"{extra}/>'


def engine_scene():
    """Eight pistons rising and falling in turn, a spark above each as it
    reaches the top, and the rev counter's needle crossing its dial once a
    minute. The crank turns a quarter each second."""
    xs = [-0.3675 + i * 0.105 for i in range(8)]
    # A quarter turn apart, in an order that sends a wave along the block.
    quarters = [0, 2, 1, 3, 3, 1, 2, 0]
    crank_y, throw, rod = 0.545, 0.055, 0.17
    defs = (
        '<linearGradient id="ps" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#7c8493"/>'
        '<stop offset="0.45" stop-color="#eef1f6"/><stop offset="1" stop-color="#6d7482"/></linearGradient>'
        f'<radialGradient id="sp" gradientUnits="userSpaceOnUse" cx="0" cy="0" r="{0.06 * U:.1f}">'
        '<stop offset="0" stop-color="#fff6c8"/><stop offset="0.4" stop-color="#ffab2e" stop-opacity="0.9"/>'
        '<stop offset="1" stop-color="#ff5a1f" stop-opacity="0"/></radialGradient>'
        # A piston, drawn around its pin.
        f'<g id="pi"><rect x="{-0.039 * U:.1f}" y="{-0.04 * U:.1f}" width="{0.078 * U:.1f}" height="{0.08 * U:.1f}" rx="{0.008 * U:.1f}" fill="url(#ps)"/>'
        f'<rect x="{-0.039 * U:.1f}" y="{-0.028 * U:.1f}" width="{0.078 * U:.1f}" height="{0.007 * U:.1f}" fill="#3b404b"/>'
        f'<rect x="{-0.039 * U:.1f}" y="{-0.013 * U:.1f}" width="{0.078 * U:.1f}" height="{0.007 * U:.1f}" fill="#3b404b"/>'
        f'<circle cx="0" cy="{0.012 * U:.1f}" r="{0.012 * U:.1f}" fill="#2a2e37"/></g>'
        f'<g id="fl"><circle cx="0" cy="0" r="{0.06 * U:.1f}" fill="url(#sp)"/></g>'
        f'<g id="nd"><path d="M{-0.012 * U:.1f} {0.035 * U:.1f} L0 {-0.21 * U:.1f} L{0.012 * U:.1f} {0.035 * U:.1f} Z" fill="#e8262c"/>'
        f'<circle cx="0" cy="0" r="{0.03 * U:.1f}" fill="#d9dde6"/><circle cx="0" cy="0" r="{0.012 * U:.1f}" fill="#1b1d22"/></g>'
    )

    def glyph(v):
        parts = [f'<rect x="{-0.44 * U:.1f}" y="{(crank_y - 0.012) * U:.1f}" width="{0.88 * U:.1f}" height="{0.024 * U:.1f}" fill="#8a909c"/>']
        for x, quarter in zip(xs, quarters):
            turn = math.radians(90 * (v + quarter))
            big_end = crank_y - throw * math.cos(turn)
            pin = big_end - math.sqrt(rod ** 2 - (throw * math.sin(turn)) ** 2)
            # Crank web, connecting rod, piston.
            top, bottom = min(big_end, crank_y), max(big_end, crank_y)
            parts.append(f'<rect x="{(x - 0.03) * U:.1f}" y="{(top - 0.014) * U:.1f}" width="{0.06 * U:.1f}" height="{(bottom - top + 0.028) * U:.1f}" rx="{0.012 * U:.1f}" fill="#565c69"/>')
            parts.append(f'<rect x="{(x - 0.011) * U:.1f}" y="{pin * U:.1f}" width="{0.022 * U:.1f}" height="{(big_end - pin) * U:.1f}" fill="#b9bfca"/>')
            parts.append(f'<circle cx="{x * U:.1f}" cy="{big_end * U:.1f}" r="{0.02 * U:.1f}" fill="#d5d9e1"/>')
            parts.append(use("pi", x * U, pin * U))
            if (v + quarter) % 4 == 0:
                parts.append(use("fl", x * U, 0.245 * U))
        needle = -120 + 4 * (v % 60)
        parts.append(f'<g transform="translate(0 {-0.36 * U:.1f}) rotate({needle})"><use xlink:href="#nd"/></g>')
        return centered("".join(parts))
    return defs, glyph


# A roulette wheel's numbers in the order they sit round a single-zero wheel.
WHEEL = [0, 32, 15, 19, 4, 21, 2, 25, 17, 34, 6, 27, 13, 36, 11, 30, 8, 23, 10, 5, 24, 16, 33, 1, 20, 14, 31, 9, 22, 18, 29, 7, 28, 12, 35, 3, 26]
RED_NUMBERS = {1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36}


def number_path(text, height):
    """A number as stroked lines, centered on the origin, in the digits
    the dials use (they are lines, not a typeface)."""
    unit = height / 1.6
    advance = 1.22
    total = (len(text) - 1) * advance + 1
    d = []
    for i, ch in enumerate(text):
        for line in STROKE_DIGITS[ch]:
            points = [((lx + i * advance - total / 2) * unit, (ly - 0.8) * unit) for lx, ly in line]
            d.append("M" + " L".join(f"{x:.1f} {y:.1f}" for x, y in points))
    return f'<path d="{" ".join(d)}" fill="none" stroke="#fff" stroke-width="{0.15 * unit:.1f}" stroke-linecap="round" stroke-linejoin="round"/>'


def roulette_scene():
    """The wheel turns one way while the ball runs the other way round the
    track. Each minute the ball slows, drops into a pocket and rides there,
    and then it is sent round again."""
    pocket = 360 / 37
    rim, floor, cone = 0.765 * U, 0.50 * U, 0.47 * U

    def at(radius, degrees):
        a = math.radians(degrees)
        return (radius * math.sin(a), -radius * math.cos(a))

    wheel = [f'<circle cx="0" cy="0" r="{rim + 0.008 * U:.1f}" fill="#c9a24e"/>']
    for j, number in enumerate(WHEEL):
        a0, a1 = j * pocket, (j + 1) * pocket
        color = "#0c7a3d" if number == 0 else ("#c2202b" if number in RED_NUMBERS else "#17181c")
        steps = [a0 + (a1 - a0) * k / 4 for k in range(5)]
        wheel.append(poly([at(rim, a) for a in steps] + [at(floor, a) for a in reversed(steps)], color))
        # The pocket itself is the darker inner half of the wedge.
        wheel.append(poly([at(0.615 * U, a) for a in steps] + [at(floor, a) for a in reversed(steps)], "#000", 0.3))
        x, y = at(0.69 * U, (a0 + a1) / 2)
        wheel.append(f'<g transform="translate({x:.1f} {y:.1f}) rotate({(a0 + a1) / 2:.1f})">{number_path(str(number), 0.066 * U)}</g>')
    for j in range(37):
        (x0, y0), (x1, y1) = at(floor, j * pocket), at(rim, j * pocket)
        wheel.append(f'<path d="M{x0:.1f} {y0:.1f} L{x1:.1f} {y1:.1f}" stroke="#d9b866" stroke-width="{0.008 * U:.1f}"/>')
    wheel.append(f'<circle cx="0" cy="0" r="{0.615 * U:.1f}" fill="none" stroke="#d9b866" stroke-width="{0.007 * U:.1f}"/>')
    wheel.append(f'<circle cx="0" cy="0" r="{cone + 0.03 * U:.1f}" fill="#d9b866"/>')
    wheel.append(f'<circle cx="0" cy="0" r="{cone:.1f}" fill="url(#cn)"/>')
    for k in range(8):
        x, y = at(cone, k * 45)
        wheel.append(f'<path d="M0 0 L{x:.1f} {y:.1f}" stroke="#e7cd8a" stroke-opacity="0.5" stroke-width="{0.006 * U:.1f}"/>')
    # The turret: four arms with a ball at the end of each.
    for k in range(4):
        x, y = at(0.19 * U, k * 90 + 45)
        wheel.append(f'<path d="M0 0 L{x:.1f} {y:.1f}" stroke="#f0dca4" stroke-width="{0.03 * U:.1f}" stroke-linecap="round"/>')
        wheel.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{0.03 * U:.1f}" fill="url(#gd)"/>')
    wheel.append(f'<circle cx="0" cy="0" r="{0.075 * U:.1f}" fill="url(#gd)"/>')
    defs = (
        f'<radialGradient id="cn" gradientUnits="userSpaceOnUse" cx="0" cy="0" r="{cone:.1f}">'
        '<stop offset="0" stop-color="#b27a36"/><stop offset="0.7" stop-color="#7b4a1e"/><stop offset="1" stop-color="#4f2c12"/></radialGradient>'
        '<radialGradient id="gd" cx="0.35" cy="0.3" r="0.8"><stop offset="0" stop-color="#fff3c9"/><stop offset="0.6" stop-color="#d9ad4f"/><stop offset="1" stop-color="#8c6420"/></radialGradient>'
        '<radialGradient id="bl" cx="0.35" cy="0.3" r="0.8"><stop offset="0" stop-color="#fff"/><stop offset="0.7" stop-color="#d7dbe2"/><stop offset="1" stop-color="#8f96a3"/></radialGradient>'
        f'<g id="wh">{"".join(wheel)}</g>'
        f'<g id="ba"><circle cx="{0.008 * U:.1f}" cy="{0.012 * U:.1f}" r="{0.036 * U:.1f}" fill="#000" fill-opacity="0.45"/>'
        f'<circle cx="0" cy="0" r="{0.036 * U:.1f}" fill="url(#bl)"/></g>'
    )
    track, rest = 0.808 * U, 0.565 * U

    def ball(v):
        minute, t = divmod(v, 60)
        if t < 36:
            return track, -30.0 * t
        # Slowing from its own speed to the wheel's, and drifting inward.
        angle, speeds = -30.0 * 36, [-30 + 40 * (k + 1) / 8 for k in range(8)]
        landed = angle + sum(speeds)
        # Where that is on the wheel, moved to the middle of a pocket.
        on_wheel = landed - 10 * (minute * 60 + 44)
        on_wheel = (math.floor(on_wheel / pocket) + 0.5) * pocket
        if t >= 44:
            return rest, on_wheel + 10 * v
        k = t - 36
        slide = (k + 1) / 8
        target = on_wheel + 10 * (minute * 60 + 44)
        return track + (rest - track) * slide ** 2, angle + sum(speeds[:k]) + (target - landed) * slide

    def glyph(v):
        radius, degrees = ball(v)
        x, y = at(radius, degrees)
        return centered(f'<use xlink:href="#wh" transform="rotate({10 * v % 360})"/>' + use("ba", x, y))
    return defs, glyph


def carousel_scene():
    """An orrery: four arms going round once a minute, carrying a globe, a
    cut stone, a turning cage and a sun, each of which stays the right way
    up and has a small motion of its own."""
    reach = 0.50 * U
    globe_r, stone_r, cage_r, sun_r = 0.115 * U, 0.095 * U, 0.105 * U, 0.08 * U

    def globe(shift):
        land = "".join(
            f'<ellipse cx="{(x + shift) * globe_r:.1f}" cy="{y * globe_r:.1f}" rx="{rx * globe_r:.1f}" ry="{ry * globe_r:.1f}" fill="#f1f4fa" fill-opacity="0.92"/>'
            for x, y, rx, ry in ((-0.9, -0.3, 0.42, 0.3), (-0.55, 0.35, 0.22, 0.4), (0.25, -0.35, 0.5, 0.28), (0.55, 0.3, 0.3, 0.36), (1.5, -0.2, 0.4, 0.3), (-1.9, 0.1, 0.36, 0.42))
        )
        return (
            f'<circle cx="0" cy="0" r="{globe_r:.1f}" fill="url(#ob)"/><g clip-path="url(#oc)">{land}</g>'
            f'<circle cx="0" cy="0" r="{globe_r:.1f}" fill="url(#os)"/>'
        )

    def stone(turn):
        """A round brilliant seen from above: a table and two rings of facets."""
        parts = [f'<circle cx="0" cy="0" r="{stone_r:.1f}" fill="#dfe6f2"/>']
        tones = ["#ffffff", "#aab6cc", "#eef3fb", "#8c99b3", "#f7faff", "#bcc7da", "#ffffff", "#98a5be"]
        for k in range(8):
            a0, a1 = math.radians(k * 45 + turn), math.radians((k + 1) * 45 + turn)
            mid = (a0 + a1) / 2
            outer = [(stone_r * math.cos(a), stone_r * math.sin(a)) for a in (a0, mid, a1)]
            inner = (0.5 * stone_r * math.cos(mid), 0.5 * stone_r * math.sin(mid))
            parts.append(poly([outer[0], outer[1], inner], tones[k]))
            parts.append(poly([outer[1], outer[2], inner], tones[(k + 3) % 8]))
            parts.append(poly([(0, 0), (0.5 * stone_r * math.cos(a0 + 0.39), 0.5 * stone_r * math.sin(a0 + 0.39)), (0.5 * stone_r * math.cos(a1 + 0.39), 0.5 * stone_r * math.sin(a1 + 0.39))], tones[(k + 5) % 8]))
        return "".join(parts)

    spokes = "".join(
        f'<path d="M0 0 L{cage_r * math.sin(math.radians(a)):.1f} {-cage_r * math.cos(math.radians(a)):.1f}" stroke="#e2b08a" stroke-width="{0.016 * U:.1f}"/>'
        for a in (0, 120, 240)
    )
    rays = "".join(poly([(sun_r * 1.5 * math.sin(math.radians(a)), -sun_r * 1.5 * math.cos(math.radians(a))),
                         (sun_r * 0.95 * math.sin(math.radians(a - 9)), -sun_r * 0.95 * math.cos(math.radians(a - 9))),
                         (sun_r * 0.95 * math.sin(math.radians(a + 9)), -sun_r * 0.95 * math.cos(math.radians(a + 9)))], "#f2c14e")
                   for a in range(0, 360, 30))
    defs = (
        f'<radialGradient id="ob" gradientUnits="userSpaceOnUse" cx="{-0.3 * globe_r:.1f}" cy="{-0.3 * globe_r:.1f}" r="{1.3 * globe_r:.1f}">'
        '<stop offset="0" stop-color="#4f7dff"/><stop offset="1" stop-color="#0f1f8c"/></radialGradient>'
        f'<radialGradient id="os" gradientUnits="userSpaceOnUse" cx="{-0.35 * globe_r:.1f}" cy="{-0.35 * globe_r:.1f}" r="{1.5 * globe_r:.1f}">'
        '<stop offset="0" stop-color="#fff" stop-opacity="0.35"/><stop offset="0.5" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#000" stop-opacity="0.6"/></radialGradient>'
        '<radialGradient id="sn" cx="0.4" cy="0.35" r="0.75"><stop offset="0" stop-color="#fff6c2"/><stop offset="0.7" stop-color="#f2b631"/><stop offset="1" stop-color="#c47a12"/></radialGradient>'
        '<linearGradient id="st" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#8f97a6"/><stop offset="0.5" stop-color="#f4f6fa"/><stop offset="1" stop-color="#858d9c"/></linearGradient>'
        f'<clipPath id="oc"><circle cx="0" cy="0" r="{globe_r:.1f}"/></clipPath>'
        + "".join(f'<g id="g{k}">{globe(shift)}</g>' for k, shift in enumerate((0.0, 0.45, 0.9)))
        + "".join(f'<g id="d{k}">{stone(turn)}</g>' for k, turn in enumerate((0.0, 22.5)))
        + f'<g id="cg"><circle cx="0" cy="0" r="{cage_r:.1f}" fill="#12131a" fill-opacity="0.55"/>'
        f'<circle cx="0" cy="0" r="{cage_r:.1f}" fill="none" stroke="#e2b08a" stroke-width="{0.02 * U:.1f}"/>{spokes}'
        f'<circle cx="0" cy="0" r="{0.55 * cage_r:.1f}" fill="none" stroke="#f3d2b4" stroke-width="{0.012 * U:.1f}"/>'
        f'<circle cx="0" cy="0" r="{0.2 * cage_r:.1f}" fill="#d0214a"/></g>'
        f'<g id="su">{rays}<circle cx="0" cy="0" r="{sun_r:.1f}" fill="url(#sn)"/></g>'
        f'<g id="ar"><rect x="{-0.02 * U:.1f}" y="{-reach:.1f}" width="{0.04 * U:.1f}" height="{reach:.1f}" fill="url(#st)"/></g>'
        f'<g id="hb"><circle cx="0" cy="0" r="{0.085 * U:.1f}" fill="#8b93a2"/><circle cx="0" cy="0" r="{0.065 * U:.1f}" fill="#e9ecf2"/></g>'
    )

    def glyph(v):
        turn = 6 * v
        parts = [f'<use xlink:href="#ar" transform="rotate({turn + 90 * k})"/>' for k in range(4)]
        spots = [(reach * math.sin(math.radians(turn + 90 * k)), -reach * math.cos(math.radians(turn + 90 * k))) for k in range(4)]
        parts.append(use(f"g{v % 3}", *spots[0]))
        parts.append(use(f"d{v % 2}", *spots[1]))
        parts.append(use("cg", *spots[2], rotate=(40 * v) % 120))
        parts.append(use("su", *spots[3], rotate=(15 * v) % 30))
        parts.append('<use xlink:href="#hb"/>')
        return centered("".join(parts))
    return defs, glyph


def dragon_art(start, body, shadow, belly, accent, eye):
    """One dragon, its body following a wavy arc clockwise from `start`
    degrees, tail first, head leading."""
    steps = 72
    line = []
    for i in range(steps + 1):
        t = i / steps
        a = math.radians(start + 152 * t)
        r = (0.525 + 0.06 * math.sin(2 * math.pi * 1.5 * t + 0.6)) * U
        line.append((r * math.sin(a), -r * math.cos(a)))

    def frame(i):
        """The body's direction and its outward side at point i."""
        (x0, y0), (x1, y1) = line[max(i - 1, 0)], line[min(i + 1, steps)]
        length = math.hypot(x1 - x0, y1 - y0)
        tx, ty = (x1 - x0) / length, (y1 - y0) / length
        nx, ny = ty, -tx
        # Outward is away from the middle of the dial.
        if nx * line[i][0] + ny * line[i][1] < 0:
            nx, ny = -nx, -ny
        return tx, ty, nx, ny

    def width(i):
        t = i / steps
        return (0.008 + 0.056 * math.sin(math.pi * t / 1.22) ** 0.7) * U

    def offset(i, k):
        _, _, nx, ny = frame(i)
        return (line[i][0] + nx * width(i) * k, line[i][1] + ny * width(i) * k)

    span = range(steps + 1)
    parts = [poly([offset(i, 1) for i in span] + [offset(i, -1) for i in reversed(span)], shadow)]
    parts.append(poly([offset(i, 0.78) for i in span] + [offset(i, -0.3) for i in reversed(span)], body))
    parts.append(poly([offset(i, -0.38) for i in span] + [offset(i, -0.92) for i in reversed(span)], belly, 0.9))
    # Scales, as a row of small arcs along the back.
    for i in range(4, steps - 3, 2):
        x, y = offset(i, 0.28)
        parts.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{width(i) * 0.5:.1f}" fill="none" stroke="{accent}" stroke-opacity="0.55" stroke-width="{0.006 * U:.1f}"/>')
    # A crest of spines along the outer edge.
    for i in range(6, steps - 4, 3):
        _, _, nx, ny = frame(i)
        tip = (line[i][0] + nx * (width(i) + 0.034 * U), line[i][1] + ny * (width(i) + 0.034 * U))
        parts.append(poly([offset(i - 1, 0.95), tip, offset(i + 1, 0.95)], accent))
    # The tail ends in a tuft.
    tx, ty, nx, ny = frame(0)
    for spread in (-1.0, 0.0, 1.0):
        tip = (line[0][0] - tx * 0.09 * U + nx * spread * 0.04 * U, line[0][1] - ty * 0.09 * U + ny * spread * 0.04 * U)
        parts.append(poly([offset(0, 1.6), tip, offset(0, -1.6)], accent))

    # The head, drawn along the body's direction at its leading end.
    tx, ty, nx, ny = frame(steps)
    hx, hy = line[steps]

    def head(forward, out):
        return (hx + (tx * forward + nx * out) * U, hy + (ty * forward + ny * out) * U)

    for side in (1, -1):
        parts.append(poly([head(0.0, 0.035 * side), head(-0.105, 0.115 * side), head(0.035, 0.05 * side)], accent))
        parts.append(poly([head(-0.02, 0.03 * side), head(-0.085, 0.055 * side), head(-0.03, 0.062 * side)], shadow))
    parts.append(poly([head(-0.04, 0.056), head(0.045, 0.062), head(0.125, 0.036), head(0.165, 0.0), head(0.125, -0.036), head(0.045, -0.058), head(-0.04, -0.05)], shadow))
    parts.append(poly([head(-0.03, 0.044), head(0.045, 0.05), head(0.118, 0.026), head(0.15, 0.0), head(0.118, -0.024), head(0.045, -0.044), head(-0.03, -0.038)], body))
    parts.append(poly([head(0.05, -0.046), head(0.12, -0.024), head(0.15, 0.0), head(0.07, -0.012)], belly))
    for side in (1, -1):
        (x0, y0), (x1, y1), (x2, y2) = head(0.135, 0.018 * side), head(0.215, 0.07 * side), head(0.16, 0.13 * side)
        parts.append(f'<path d="M{x0:.1f} {y0:.1f} Q{x1:.1f} {y1:.1f} {x2:.1f} {y2:.1f}" fill="none" stroke="{accent}" stroke-width="{0.009 * U:.1f}" stroke-linecap="round"/>')
    ex, ey = head(0.07, 0.024)
    parts.append(f'<circle cx="{ex:.1f}" cy="{ey:.1f}" r="{0.014 * U:.1f}" fill="#fff"/><circle cx="{ex:.1f}" cy="{ey:.1f}" r="{0.007 * U:.1f}" fill="{eye}"/>')
    return "".join(parts)


def dragon_scene():
    """Two dragons, jade and gold, chasing each other round the dial once
    a minute, and a cage in the middle turning the other way."""
    ring = 0.165 * U
    arms = "".join(
        f'<path d="M0 0 Q{ring * 0.7 * math.sin(math.radians(a + 40)):.1f} {-ring * 0.7 * math.cos(math.radians(a + 40)):.1f} '
        f'{ring * math.sin(math.radians(a)):.1f} {-ring * math.cos(math.radians(a)):.1f}" fill="none" stroke="#e8b48e" stroke-width="{0.02 * U:.1f}"/>'
        for a in (0, 120, 240)
    )
    defs = (
        '<radialGradient id="rb" cx="0.38" cy="0.32" r="0.8"><stop offset="0" stop-color="#ff9fb4"/><stop offset="0.5" stop-color="#d81e4a"/><stop offset="1" stop-color="#6d0a22"/></radialGradient>'
        f'<g id="dr">{dragon_art(0, "#1f9d63", "#0b4a30", "#bfe8b0", "#f0cf7a", "#b3121f")}'
        f'{dragon_art(180, "#e6bd5c", "#8a5a16", "#fff0c2", "#c9302c", "#111")}</g>'
        f'<g id="ca"><circle cx="0" cy="0" r="{ring:.1f}" fill="none" stroke="#e8b48e" stroke-width="{0.024 * U:.1f}"/>{arms}'
        f'<circle cx="0" cy="0" r="{0.6 * ring:.1f}" fill="none" stroke="#f6d8bd" stroke-width="{0.012 * U:.1f}"/>'
        f'<circle cx="0" cy="0" r="{0.3 * ring:.1f}" fill="url(#rb)"/></g>'
    )

    def glyph(v):
        return centered(f'<use xlink:href="#ca" transform="rotate({(-12 * v) % 120})"/><use xlink:href="#dr" transform="rotate({6 * v})"/>')
    return defs, glyph


# ------------------------------------------------------------------ zodiac

def star_radius(magnitude):
    """A star's radius in em units: brighter stars (lower magnitudes) are
    larger. ZodiacView in Zodiac.swift draws the stars to the same rule."""
    return max(6.5, 19 - 3.2 * magnitude)


# A sparkle drawn for a star of radius 10: a soft halo and four fine rays.
TWINKLE = (
    '<radialGradient id="tg" gradientUnits="userSpaceOnUse" cx="0" cy="0" r="62">'
    '<stop offset="0" stop-color="#fff" stop-opacity="0.8"/>'
    '<stop offset="0.35" stop-color="#cfe0ff" stop-opacity="0.3"/>'
    '<stop offset="1" stop-color="#9fc0ff" stop-opacity="0"/></radialGradient>'
    '<g id="t"><circle cx="0" cy="0" r="62" fill="url(#tg)"/>'
    '<path d="M0 -104 L5 -5 L104 0 L5 5 L0 104 L-5 5 L-104 0 L-5 -5 Z" fill="#fff" fill-opacity="0.94"/></g>'
)


def twinkle_scene(sign):
    """Each star of a constellation flares for three seconds every so
    often: it brightens, peaks and fades. Every star keeps its own time."""
    rng = random.Random(sign["key"])
    schedule = [(rng.choice([10, 12, 15, 20, 30]), rng.randrange(60)) for _ in sign["stars"]]

    def glyph(second):
        parts = []
        for (x, y, magnitude), (every, offset) in zip(sign["stars"], schedule):
            step = (second - offset) % every
            if step > 2:
                continue
            strength = 1.0 if step == 1 else 0.58
            parts.append(use("t", x * EM, (y - 1) * EM, scale=star_radius(magnitude) / 10 * strength))
        return "".join(parts)
    return glyph


# ------------------------------------------------------------------ rivers

def river_regions():
    """The regions in RiverData.swift: (key, width over height, courses)."""
    with open(RIVER_DATA, encoding="utf-8") as f:
        source = f.read()
    regions = []
    for block in source.split("static let ")[1:]:
        head = re.match(r'(\w+) = RiverRegion\(\s*key: "(\w+)", title: "[^"]+", aspect: ([\d.]+)', block)
        if not head:
            continue
        courses = [
            [float(n) for n in course.split(",")]
            for course in re.findall(r'River\(name: "[^"]+", course: \[([^\]]+)\]\)', block)
        ]
        regions.append((head.group(2), float(head.group(3)), courses))
    return regions


def river_lights(aspect, courses):
    """Lights drifting down each river from source to mouth, each with a
    short tail. The em is the longer side of the map; the map's top left
    corner is the em's."""
    wide, tall = (1.0, 1.0 / aspect) if aspect >= 1 else (aspect, 1.0)
    periods = [30, 60, 20, 60, 30, 60, 20, 30, 60]
    radius = 17 * wide

    def along(course, p):
        last = len(course) // 2 - 1
        f = min(max(p, 0.0), 1.0) * last
        i = min(int(f), last - 1)
        u = f - i
        x = course[i * 2] + (course[i * 2 + 2] - course[i * 2]) * u
        y = course[i * 2 + 1] + (course[i * 2 + 3] - course[i * 2 + 1]) * u
        return (x * wide * EM, EM - y * tall * EM)

    def glyph(second):
        parts = []
        for r, course in enumerate(courses):
            period = periods[r % len(periods)]
            count = 2 if r < 4 else 1
            for k in range(count):
                turns = second / period + k / count + r * 0.137
                p = turns - math.floor(turns)
                # Grow after the source and shrink before the mouth, so the
                # jump back to the source is never seen.
                fade = min(1.0, p / 0.1) * min(1.0, max(0.0, 1 - p) / 0.12)
                for tail, size in ((0.0, 1.0), (0.035, 0.62), (0.07, 0.36)):
                    if p - tail <= 0:
                        continue
                    r_dot = radius * size * fade ** 0.6
                    if r_dot >= 2:
                        parts.append(disc(*along(course, p - tail), r_dot, 14))
        return outline(parts) if parts else TTGlyphPen(None).glyph()
    return glyph


# -------------------------------------------------------------------- race

# Race Day is a start, over and over: three cars form up on the grid, five
# red lights come on a second apart, the lights go out and the cars are
# away, and the next three roll up. Twelve seconds in all.
#
# The em is the widget's width. RaceView in MotionScenes.swift lays the
# track out by the same numbers: its top edge and its height, in ems.
RACE_TOP, RACE_TRACK = 0.075, 0.318
# Each car: lane (0 to 1 down the track), height (of the track's), where its
# tail is when it stands on the grid, and how well it gets away.
RACE_CARS = [(0.26, 0.25, 0.44, 1.0), (0.54, 0.29, 0.29, 1.15), (0.82, 0.33, 0.14, 0.9)]
# Second by second: how far a car is from its grid slot, and how long its
# speed line is, in ems.
RACE_RUN = [(0.0, 0.0)] * 6 + [(0.09, 0.06), (0.42, 0.24), (1.3, 0.0), (-0.62, 0.0), (-0.28, 0.0), (-0.08, 0.0)]
# The start lights: where the five are, and their radius, in ems.
RACE_LIGHTS = [(0.728 + 0.036 * i, 0.037) for i in range(5)]
RACE_LIGHT_RADIUS = 0.0125


def race_point(x, y):
    """A point given in ems from the widget's top left corner."""
    return (x * EM, EM - y * EM)


def race_car_box(car, second):
    lane, size, tail, getaway = RACE_CARS[car]
    moved, streak = RACE_RUN[second % len(RACE_RUN)]
    height = RACE_TRACK * size
    left = tail + moved * (getaway if moved > 0 else 1.0)
    top = RACE_TOP + RACE_TRACK * lane - height / 2
    return left, top, height * 3.4, height, streak * (getaway if moved > 0 else 1.0)


def race_body(car):
    """An open-wheel race car from the side, nose to the right, drawn on a
    grid 100 wide and 30 tall. An original outline, not any team's car."""
    def curve(p0, control, p1, steps=6):
        return [((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * control[0] + t * t * p1[0],
                 (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * control[1] + t * t * p1[1]) for t in (k / steps for k in range(1, steps + 1))]

    body = [(6, 22), (8, 15), (26, 12)] + curve((26, 12), (33, 6.5), (40, 6)) + [(46, 6)] + curve((46, 6), (50, 7), (52, 13))
    body += [(70, 15.5)] + curve((70, 15.5), (88, 17.5), (97, 21)) + [(98, 23.5), (6, 23.5)]
    helmet = [(48 + 3.5 * math.cos(2 * math.pi * k / 16), 8.75 + 3.25 * math.sin(2 * math.pi * k / 16)) for k in range(16)]
    shapes = [body, helmet, [(1, 4), (5, 4), (5, 17), (1, 17)], [(1, 4), (14, 4), (14, 7.5), (1, 7.5)], [(90, 23), (100, 23), (100, 26), (90, 26)]]

    def glyph(second):
        left, top, width, height, streak = race_car_box(car, second)
        parts = [[race_point(left + x / 100 * width, top + y / 30 * height) for x, y in shape] for shape in shapes]
        if streak > 0:
            middle = top + height * 0.62
            parts.append([race_point(left - streak, middle), race_point(left + 0.01, middle - height * 0.07), race_point(left + 0.01, middle + height * 0.07)])
        return outline(parts)
    return glyph


def race_wheels(second):
    parts = []
    for car in range(len(RACE_CARS)):
        left, top, width, height, _ = race_car_box(car, second)
        for x in (18, 78):
            cx, cy = race_point(left + x / 100 * width, top + 22.5 / 30 * height)
            parts.append(disc(cx, cy, 7 / 30 * height * EM, 20))
    return outline(parts)


def race_lights(second):
    """Seconds 1 to 5 light one more lamp each; at 6 they all go out."""
    lit = second % len(RACE_RUN)
    if not 1 <= lit <= 5:
        return TTGlyphPen(None).glyph()
    return outline([disc(*race_point(x, y), RACE_LIGHT_RADIUS * EM, 20) for x, y in RACE_LIGHTS[:lit]])


# ------------------------------------------------------------------- fonts

def build(name, period, outline_glyph=None, svg_defs=None, svg_glyph=None, chunk=30):
    """Writes one font. `period` is how many seconds the scene takes to
    repeat; there is one glyph per second of it. Pass `outline_glyph(v)` for
    a font the widget colors, or `svg_defs` and `svg_glyph(v)` for one with
    its own colors."""
    assert 3600 % period == 0
    frames = [f"f{v:04d}" for v in range(period)]
    names = [".notdef", "blank", "sep"] + DIGITS + frames
    glyphs = {n: TTGlyphPen(None).glyph() for n in names}
    for v, frame in enumerate(frames):
        glyphs[frame] = outline_glyph(v) if outline_glyph else speck_box()

    fb = FontBuilder(EM, isTTF=True)
    fb.setupGlyphOrder(names)
    cmap = {code: "blank" for code in BLANKS}
    cmap.update({code: "sep" for code in SEPARATORS})
    for block in DIGIT_BLOCKS:
        cmap.update({block + i: digit for i, digit in enumerate(DIGITS)})
    fb.setupCharacterMap(cmap)
    fb.setupGlyf(glyphs)
    # Only a frame takes up room, so the text is as wide as its one frame.
    # The second number is where the outline's left edge sits: get it wrong
    # and the whole glyph is drawn shifted sideways.
    glyf = fb.font["glyf"]
    metrics = {}
    for n in names:
        glyf[n].recalcBounds(glyf)
        metrics[n] = (EM if n in frames else 0, getattr(glyf[n], "xMin", 0) if glyf[n].numberOfContours else 0)
    fb.setupHorizontalMetrics(metrics)
    fb.setupHorizontalHeader(ascent=EM, descent=0)
    fb.setupNameTable({"familyName": name, "styleName": "Regular", "psName": name})
    fb.setupOS2(sTypoAscender=EM, sTypoDescender=0, sTypoLineGap=0, usWinAscent=EM, usWinDescent=0)
    fb.setupPost()

    def spell(number, width):
        return " ".join(DIGITS[int(c)] for c in str(number).zfill(width))

    rules = []
    for v in range(3600):
        minutes, seconds = divmod(v, 60)
        rules.append(f"sub {spell(minutes, 1)} sep {spell(seconds, 2)} by {frames[v % period]};")
    # If iOS is late bringing the next hour's entry, the timer runs on into
    # "1:00:07"; the scene has come round to where it started.
    for seconds in range(60):
        rules.append(f"sub one sep zero zero sep {spell(seconds, 2)} by {frames[seconds % period]};")
    fea = (
        "languagesystem DFLT dflt; languagesystem latn dflt;\n"
        "lookup frames useExtension {\n" + "\n".join(rules) + "\n} frames;\n"
        # Standard ligatures are what text uses by default; the other two
        # are applied even where an app turns those off.
        "feature liga { lookup frames; } liga;\n"
        "feature rlig { lookup frames; } rlig;\n"
        "feature ccmp { lookup frames; } ccmp;\n"
    )
    addOpenTypeFeaturesFromString(fb.font, fea)

    if svg_glyph:
        table = newTable("SVG ")
        table.docList = []
        first = names.index(frames[0])
        for start in range(0, period, chunk):
            block = range(start, min(period, start + chunk))
            document = svg_document(svg_defs, [(first + v, svg_glyph(v)) for v in block])
            table.docList.append(SVGDocument(document, first + block[0], first + block[-1], True))
        fb.font["SVG "] = table

    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name + ".ttf")
    fb.save(path)
    print(f"{name}.ttf  {period} frames  {os.path.getsize(path) / 1024:.0f} KB")
    return path


def main():
    # Second hands, colored by the widget.
    build("PWHandDot", 60, outline_glyph=needle_hand(0.62, dot_at=0.43))
    build("PWHandNeedle", 60, outline_glyph=needle_hand(0.64))
    build("PWHandLong", 60, outline_glyph=needle_hand(0.67))
    build("PWSweep", 60, outline_glyph=sweep_ring)

    defs, glyph = skeleton_scene()
    build("PWSkeleton", 300, svg_defs=defs, svg_glyph=glyph)
    for name, period, scene in (("PWEngine", 60, engine_scene), ("PWRoulette", 180, roulette_scene), ("PWCarousel", 60, carousel_scene), ("PWDragon", 60, dragon_scene)):
        defs, glyph = scene()
        build(name, period, svg_defs=defs, svg_glyph=glyph)

    defs, planets = planet_art()
    build("PWOrbit", 3600, svg_defs=defs, svg_glyph=orbit_scene(planets, ORBITS_ROUND, 1.0))
    build("PWOrbitWide", 3600, svg_defs=defs, svg_glyph=orbit_scene(planets, ORBITS_WIDE, WIDE_TILT))

    for sign in signs():
        build("PWStars" + sign["name"], 60, svg_defs=TWINKLE, svg_glyph=twinkle_scene(sign))

    for key, aspect, courses in river_regions():
        build("PWRivers" + key.capitalize(), 60, outline_glyph=river_lights(aspect, courses))

    for car, name in enumerate("ABC"):
        build("PWRace" + name, len(RACE_RUN), outline_glyph=race_body(car))
    build("PWRaceWheels", len(RACE_RUN), outline_glyph=race_wheels)
    build("PWRaceLights", len(RACE_RUN), outline_glyph=race_lights)

    # Every font must be listed under UIAppFonts in project.yml.
    print("UIAppFonts:", json.dumps(sorted(f for f in os.listdir(OUT) if f.endswith(".ttf"))))


if __name__ == "__main__":
    sys.exit(main())
