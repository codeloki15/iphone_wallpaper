#!/usr/bin/env python3
"""Builds the star maps for the Zodiac widget (Shared/ZodiacData.swift).

For each of the twelve constellations of the zodiac: where its stars are,
how bright each one is, and the lines that join them into the figure. The
stars are placed as they appear in the sky with north up, in a square.

Star positions and figures come from d3-celestial (BSD 3-Clause,
Copyright (c) 2015 Olaf Frohn), downloaded to tools/.cache on first use.
tools/make_motion_fonts.py reads the same maps to make the stars twinkle.

Run from the ios folder:  python3 tools/make_zodiac.py
"""
import json
import math
import os
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
CACHE = os.path.join(HERE, ".cache")
SOURCE = "https://raw.githubusercontent.com/ofrohn/d3-celestial/master/data/"
OUT = os.path.join(HERE, "..", "Shared", "ZodiacData.swift")

# name, constellation, symbol, element, first day, last day (month, day)
SIGNS = [
    ("Aries", "Ari", "♈", "Fire", (3, 21), (4, 19)),
    ("Taurus", "Tau", "♉", "Earth", (4, 20), (5, 20)),
    ("Gemini", "Gem", "♊", "Air", (5, 21), (6, 20)),
    ("Cancer", "Cnc", "♋", "Water", (6, 21), (7, 22)),
    ("Leo", "Leo", "♌", "Fire", (7, 23), (8, 22)),
    ("Virgo", "Vir", "♍", "Earth", (8, 23), (9, 22)),
    ("Libra", "Lib", "♎", "Air", (9, 23), (10, 22)),
    ("Scorpio", "Sco", "♏", "Water", (10, 23), (11, 21)),
    ("Sagittarius", "Sgr", "♐", "Fire", (11, 22), (12, 21)),
    ("Capricorn", "Cap", "♑", "Earth", (12, 22), (1, 19)),
    ("Aquarius", "Aqr", "♒", "Air", (1, 20), (2, 18)),
    ("Pisces", "Psc", "♓", "Water", (2, 19), (3, 20)),
]

# How much of the square the figure may fill.
MARGIN = 0.13


def load(name):
    path = os.path.join(CACHE, "celestial-" + name)
    if not os.path.exists(path):
        os.makedirs(CACHE, exist_ok=True)
        urllib.request.urlretrieve(SOURCE + name, path)
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def vector(lon, lat):
    lon, lat = math.radians(lon), math.radians(lat)
    return (math.cos(lat) * math.cos(lon), math.cos(lat) * math.sin(lon), math.sin(lat))


def separation(a, b):
    """Degrees between two [lon, lat] positions."""
    dot = sum(p * q for p, q in zip(vector(*a), vector(*b)))
    return math.degrees(math.acos(max(-1.0, min(1.0, dot))))


def signs():
    """The twelve signs, each a dict with its stars and lines."""
    figures = {f["id"]: f["geometry"]["coordinates"] for f in load("constellations.lines.json")["features"]}
    catalog = [(f["geometry"]["coordinates"], f["properties"]["mag"], str(f["id"])) for f in load("stars.6.json")["features"]]
    names = load("starnames.json")
    out = []
    for name, constellation, symbol, element, first, last in SIGNS:
        positions = []
        lines = []
        for run in figures[constellation]:
            line = []
            for lon, lat in run:
                key = (round(lon, 3), round(lat, 3))
                if key not in positions:
                    positions.append(key)
                line.append(positions.index(key))
            lines.append(line)

        # Brightness and name of each star, from the nearest catalog star.
        magnitudes = []
        brightest = (99.0, "")
        for position in positions:
            nearest = min(catalog, key=lambda star: separation(position, star[0]))
            magnitude = nearest[1] if separation(position, nearest[0]) < 0.3 else 4.5
            magnitudes.append(magnitude)
            proper = names.get(nearest[2], {}).get("name", "")
            if proper and magnitude < brightest[0]:
                brightest = (magnitude, proper)

        # Flatten the patch of sky around the figure's middle, looking up
        # at it: north at the top, east to the left.
        cx, cy, cz = (sum(v[i] for v in map(lambda p: vector(*p), positions)) for i in range(3))
        lon0, lat0 = math.atan2(cy, cx), math.atan2(cz, math.hypot(cx, cy))
        flat = []
        for lon, lat in positions:
            lon, lat = math.radians(lon), math.radians(lat)
            x = math.cos(lat) * math.sin(lon - lon0)
            y = math.cos(lat0) * math.sin(lat) - math.sin(lat0) * math.cos(lat) * math.cos(lon - lon0)
            flat.append((-x, -y))
        xs, ys = [p[0] for p in flat], [p[1] for p in flat]
        span = max(max(xs) - min(xs), max(ys) - min(ys))
        scale = (1 - 2 * MARGIN) / span
        midx, midy = (max(xs) + min(xs)) / 2, (max(ys) + min(ys)) / 2
        stars = [(0.5 + (x - midx) * scale, 0.5 + (y - midy) * scale, m) for (x, y), m in zip(flat, magnitudes)]
        out.append({
            "name": name, "key": name.lower(), "symbol": symbol, "element": element,
            "first": first, "last": last, "brightest": brightest[1],
            "stars": stars, "lines": lines,
        })
    return out


def main():
    rows = []
    for sign in signs():
        stars = ", ".join(f"{x:.3f}, {y:.3f}, {m:.1f}" for x, y, m in sign["stars"])
        lines = ", ".join("[" + ", ".join(map(str, line)) + "]" for line in sign["lines"])
        rows.append(
            f'        ZodiacSign(\n'
            f'            key: "{sign["key"]}", name: "{sign["name"]}", symbol: "{sign["symbol"]}\\u{{FE0E}}", element: "{sign["element"]}",\n'
            f'            first: ({sign["first"][0]}, {sign["first"][1]}), last: ({sign["last"][0]}, {sign["last"][1]}), brightest: "{sign["brightest"]}",\n'
            f'            stars: [{stars}],\n'
            f'            lines: [{lines}]),'
        )
        print(f'{sign["name"]:12s} {len(sign["stars"]):2d} stars  brightest: {sign["brightest"]}')
    with open(OUT, "w", encoding="utf-8") as f:
        f.write(
            "// Generated by tools/make_zodiac.py. Don't edit by hand.\n"
            "// Star positions and figures: d3-celestial, BSD 3-Clause, Copyright (c) 2015 Olaf Frohn.\n\n"
            "/// A constellation of the zodiac, for the Zodiac widget.\n"
            "struct ZodiacSign: Identifiable {\n"
            "    let key: String\n"
            "    let name: String\n"
            "    let symbol: String\n"
            "    let element: String\n"
            "    /// The first and last day the sun is in the sign, as month and day.\n"
            "    let first: (Int, Int)\n"
            "    let last: (Int, Int)\n"
            "    /// The name of its brightest named star.\n"
            "    let brightest: String\n"
            "    /// Each star as x, y (0...1 across a square, north up) and its magnitude.\n"
            "    let stars: [Double]\n"
            "    /// The figure: each line is a run of star numbers.\n"
            "    let lines: [[Int]]\n\n"
            "    var id: String { key }\n"
            "}\n\n"
            "extension ZodiacSign {\n"
            "    /// In order from Aries.\n"
            "    static let all: [ZodiacSign] = [\n" + "\n".join(rows) + "\n    ]\n}\n"
        )


if __name__ == "__main__":
    main()
