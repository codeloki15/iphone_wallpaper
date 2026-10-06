#!/usr/bin/env python3
"""Builds the artwork and flow paths for the Rivers widgets.

For each region it writes two template images into
Shared/WidgetArt.xcassets (the land, and the rivers) and one Swift file,
Shared/RiverData.swift, with each river's course from source to mouth for
the moving dots.

The map data is Natural Earth (naturalearthdata.com), which is in the
public domain. It is downloaded to tools/.cache on first run. Natural
Earth has only three rivers in Japan, so five more are traced here from
the cities they pass; they are approximate.

Run from the ios folder:  python3 tools/make_river_maps.py
Needs Pillow (pip install pillow).
"""
import json
import math
import os
import urllib.request

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
IOS = os.path.dirname(HERE)
CACHE = os.path.join(HERE, ".cache")
ASSETS = os.path.join(IOS, "Shared", "WidgetArt.xcassets")
SWIFT = os.path.join(IOS, "Shared", "RiverData.swift")
BASE = "https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/"

WIDTH = 320          # image width in points
SUPERSAMPLE = 3      # drawn this much larger, then scaled down, for smooth edges
FLOW_POINTS = 36     # points kept along each river's course

# Each river: name shown, names it has in the data, where it ends (lon, lat),
# and optionally a box (lon0, lat0, lon1, lat1) to tell it from namesakes.
# `main` rivers are drawn thicker and carry the moving dots.
REGIONS = {
    "japan": {
        "title": "Japan",
        "projection": ("plain", 37.5),
        "focus": lambda p, ring: p["ISO_A3"] == "JPN",
        "limit": (128.5, 30.8, 146.2, 45.8),
        "rivers_file": "ne_10m_rivers_lake_centerlines.geojson",
        "pad": 0.06,
        "rivers": [
            {"name": "Shinano", "main": True, "mouth": (139.06, 37.95), "trace": [
                (138.70, 35.92), (138.48, 36.25), (138.25, 36.40), (138.19, 36.65), (138.37, 36.85),
                (138.62, 37.00), (138.76, 37.13), (138.80, 37.30), (138.85, 37.45), (138.96, 37.72), (139.06, 37.95)]},
            {"name": "Tone", "main": True, "data": ["Tone"], "mouth": (140.85, 35.75)},
            {"name": "Ishikari", "main": True, "data": ["Ishikari"], "mouth": (141.35, 43.25)},
            {"name": "Kitakami", "main": True, "mouth": (141.30, 38.42), "trace": [
                (141.20, 40.00), (141.15, 39.70), (141.12, 39.39), (141.11, 39.29), (141.13, 38.93),
                (141.22, 38.65), (141.30, 38.42)]},
            {"name": "Teshio", "main": True, "mouth": (141.74, 44.88), "trace": [
                (142.90, 43.95), (142.40, 44.18), (142.46, 44.35), (142.35, 44.48), (142.26, 44.73),
                (142.07, 44.82), (141.74, 44.88)]},
            {"name": "Mogami", "main": False, "data": ["Mogami"], "mouth": (139.80, 38.90)},
            {"name": "Tenryu", "main": False, "mouth": (137.80, 34.65), "trace": [
                (138.08, 36.05), (137.95, 35.75), (137.83, 35.50), (137.82, 35.20), (137.80, 34.90), (137.80, 34.65)]},
            {"name": "Kiso", "main": False, "mouth": (136.72, 35.03), "trace": [
                (137.75, 35.95), (137.60, 35.75), (137.35, 35.55), (137.05, 35.45), (136.85, 35.30), (136.72, 35.03)]},
        ],
    },
    "usa": {
        "title": "the USA",
        "projection": ("conic", 29.5, 45.5, -96.0, 37.5),
        "focus": lambda p, ring: p["ISO_A3"] == "USA" and -128 < sum(x for x, _ in ring) / len(ring) < -60
                 and 24 < sum(y for _, y in ring) / len(ring) < 50,
        "rivers_file": "ne_50m_rivers_lake_centerlines.geojson",
        "pad": 0.03,
        "rivers": [
            {"name": "Mississippi", "main": True, "data": ["Mississippi"], "mouth": (-89.25, 29.15)},
            {"name": "Missouri", "main": True, "data": ["Missouri"], "mouth": (-90.10, 38.80)},
            {"name": "Ohio", "main": True, "data": ["Ohio"], "mouth": (-89.10, 37.00)},
            {"name": "Colorado", "main": True, "data": ["Colorado"], "mouth": (-114.80, 31.80), "box": (-118, 30, -105, 42)},
            {"name": "Columbia", "main": True, "data": ["Columbia"], "mouth": (-124.00, 46.25)},
            {"name": "Rio Grande", "main": True, "data": ["Rio Grande"], "mouth": (-97.15, 25.95), "box": (-110, 24, -96, 39)},
            {"name": "Arkansas", "main": False, "data": ["Arkansas"], "mouth": (-91.10, 33.80)},
            {"name": "Snake", "main": False, "data": ["Snake"], "mouth": (-119.00, 46.20)},
            {"name": "Tennessee", "main": False, "data": ["Tennessee"], "mouth": (-88.60, 37.05)},
            {"name": "Red", "main": False, "data": ["Red"], "mouth": (-91.70, 31.00), "box": (-104, 29, -90, 36)},
        ],
    },
    "canada": {
        "title": "Canada",
        "projection": ("conic", 49.0, 68.0, -96.0, 58.0),
        "focus": lambda p, ring: p["ISO_A3"] == "CAN",
        "limit": (-141.5, 41.0, -52.0, 73.5),
        "rivers_file": "ne_50m_rivers_lake_centerlines.geojson",
        "pad": 0.03,
        "rivers": [
            {"name": "Mackenzie", "main": True, "data": ["Mackenzie"], "mouth": (-134.50, 69.20)},
            {"name": "Peace", "main": True, "data": ["Peace"], "mouth": (-111.50, 59.00)},
            {"name": "Nelson", "main": True, "data": ["Nelson"], "mouth": (-92.60, 57.00)},
            {"name": "Fraser", "main": True, "data": ["Fraser"], "mouth": (-123.20, 49.10)},
            {"name": "St. Lawrence", "main": True, "data": ["St. Lawrence"], "mouth": (-66.00, 49.50)},
            {"name": "Saskatchewan", "main": True, "data": ["Saskatchewan", "South Saskatchewan"], "mouth": (-99.30, 53.20)},
            {"name": "Yukon", "main": False, "data": ["Yukon"], "mouth": (-141.00, 64.70), "box": (-141.5, 59, -128, 66)},
            {"name": "Athabasca", "main": False, "data": ["Athabasca"], "mouth": (-111.00, 58.70)},
            {"name": "North Saskatchewan", "main": False, "data": ["North Saskatchewan"], "mouth": (-105.10, 53.25)},
            {"name": "Churchill", "main": False, "data": ["Churchill"], "mouth": (-94.20, 58.80), "box": (-110, 54, -93, 60)},
            {"name": "Ottawa", "main": False, "data": ["Ottawa"], "mouth": (-73.90, 45.45)},
            {"name": "Albany", "main": False, "data": ["Albany"], "mouth": (-81.50, 52.30)},
            {"name": "Slave", "main": False, "data": ["Slave"], "mouth": (-113.70, 61.30)},
        ],
    },
    "asia": {
        "title": "Asia",
        "projection": ("conic", 15.0, 55.0, 95.0, 35.0),
        "focus": lambda p, ring: (p["CONTINENT"] == "Asia" or p["ISO_A3"] == "RUS")
                 and sum(x for x, _ in ring) / len(ring) > 25,
        "clip_west": {"RUS": 60.0},
        "limit": (26.0, -11.0, 150.0, 77.5),
        "rivers_file": "ne_50m_rivers_lake_centerlines.geojson",
        "pad": 0.02,
        "rivers": [
            {"name": "Yangtze", "main": True, "data": ["Yangtze", "Chang Jiang", "Jinsha"], "mouth": (121.90, 31.40)},
            {"name": "Yellow", "main": True, "data": ["Huang", "Yellow"], "mouth": (119.20, 37.80)},
            {"name": "Mekong", "main": True, "data": ["Mekong", "Lancang"], "mouth": (106.60, 9.80)},
            {"name": "Ganges", "main": True, "data": ["Ganges"], "mouth": (90.40, 22.60)},
            {"name": "Indus", "main": True, "data": ["Indus"], "mouth": (67.50, 24.00)},
            {"name": "Ob", "main": True, "data": ["Ob"], "mouth": (69.00, 66.50)},
            {"name": "Yenisey", "main": True, "data": ["Yenisey"], "mouth": (82.70, 71.00)},
            {"name": "Lena", "main": True, "data": ["Lena"], "mouth": (127.00, 72.50)},
            {"name": "Amur", "main": True, "data": ["Amur"], "mouth": (141.00, 53.00)},
            {"name": "Brahmaputra", "main": False, "data": ["Brahmaputra"], "mouth": (89.80, 23.90)},
            {"name": "Irrawaddy", "main": False, "data": ["Ayeyarwady", "Irrawaddy"], "mouth": (95.20, 15.90)},
            {"name": "Salween", "main": False, "data": ["Salween", "Nu"], "mouth": (97.60, 16.50)},
            {"name": "Irtysh", "main": False, "data": ["Irtysh", "Ertis"], "mouth": (69.00, 61.10)},
            {"name": "Euphrates", "main": False, "data": ["Euphrates"], "mouth": (47.40, 31.00)},
            {"name": "Tigris", "main": False, "data": ["Tigris"], "mouth": (47.40, 31.00)},
            {"name": "Syr Darya", "main": False, "data": ["Syr Darya"], "mouth": (61.00, 46.10)},
        ],
    },
}


def load(name):
    os.makedirs(CACHE, exist_ok=True)
    path = os.path.join(CACHE, name)
    if not os.path.exists(path):
        print("downloading", name)
        urllib.request.urlretrieve(BASE + name, path)
    with open(path) as f:
        return json.load(f)["features"]


def rings_of(feature):
    """Yields (outer ring, [holes]) for each polygon of a feature."""
    g = feature["geometry"]
    if not g:
        return
    polys = [g["coordinates"]] if g["type"] == "Polygon" else g["coordinates"]
    for poly in polys:
        yield [(x, y) for x, y, *_ in poly[0]], [[(x, y) for x, y, *_ in h] for h in poly[1:]]


def lines_of(feature):
    g = feature["geometry"]
    if not g:
        return []
    parts = [g["coordinates"]] if g["type"] == "LineString" else g["coordinates"]
    return [[(x, y) for x, y, *_ in part] for part in parts]


def projector(spec):
    """Returns lon/lat -> x/y (y pointing down), in arbitrary units."""
    if spec[0] == "plain":
        k = math.cos(math.radians(spec[1]))
        return lambda lon, lat: (lon * k, -lat)
    _, p1, p2, lon0, lat0 = spec
    p1, p2, lat0 = (math.radians(v) for v in (p1, p2, lat0))
    t = lambda p: math.tan(math.pi / 4 + p / 2)
    n = math.log(math.cos(p1) / math.cos(p2)) / math.log(t(p2) / t(p1))
    f = math.cos(p1) * t(p1) ** n / n
    rho0 = f / t(lat0) ** n

    def conic(lon, lat):
        rho = f / t(math.radians(max(-80.0, min(89.0, lat)))) ** n
        a = n * math.radians(lon - lon0)
        return rho * math.sin(a) * 57.3, -(rho0 - rho * math.cos(a)) * 57.3
    return conic


def clip_west(ring, lon_min):
    """Keeps the part of a ring east of lon_min (Sutherland-Hodgman)."""
    out = []
    for (x0, y0), (x1, y1) in zip(ring, ring[1:] + ring[:1]):
        inside0, inside1 = x0 >= lon_min, x1 >= lon_min
        if inside0:
            out.append((x0, y0))
        if inside0 != inside1:
            t = (lon_min - x0) / (x1 - x0)
            out.append((lon_min, y0 + (y1 - y0) * t))
    return out


def chain(parts):
    """Joins a river's parts end to end, starting from the longest."""
    parts = [list(p) for p in parts if len(p) > 1]
    if not parts:
        return []
    parts.sort(key=lambda p: sum(math.dist(a, b) for a, b in zip(p, p[1:])), reverse=True)
    line = parts.pop(0)
    while parts:
        # (gap, index, attach at the start?, reverse the part first?)
        best = min(
            option
            for i, part in enumerate(parts)
            for option in (
                (math.dist(line[-1], part[0]), i, False, False),
                (math.dist(line[-1], part[-1]), i, False, True),
                (math.dist(line[0], part[-1]), i, True, False),
                (math.dist(line[0], part[0]), i, True, True),
            )
        )
        gap, i, at_start, reverse = best
        if gap > 1.5:
            break
        part = parts.pop(i)
        if reverse:
            part.reverse()
        line = part + line if at_start else line + part
    return line


def resample(line, count):
    """Evenly spaced points along a line."""
    steps = [0.0]
    for a, b in zip(line, line[1:]):
        steps.append(steps[-1] + math.dist(a, b))
    total = steps[-1] or 1.0
    out, j = [], 0
    for i in range(count):
        target = total * i / (count - 1)
        while j < len(line) - 2 and steps[j + 1] < target:
            j += 1
        seg = steps[j + 1] - steps[j] or 1.0
        t = (target - steps[j]) / seg
        out.append((line[j][0] + (line[j + 1][0] - line[j][0]) * t, line[j][1] + (line[j + 1][1] - line[j][1]) * t))
    return out


def smooth(line, passes=2):
    """Chaikin corner cutting, for the hand-traced rivers."""
    for _ in range(passes):
        out = [line[0]]
        for a, b in zip(line, line[1:]):
            out.append((a[0] * 0.75 + b[0] * 0.25, a[1] * 0.75 + b[1] * 0.25))
            out.append((a[0] * 0.25 + b[0] * 0.75, a[1] * 0.25 + b[1] * 0.75))
        out.append(line[-1])
        line = out
    return line


def write_imageset(name, image_3x):
    folder = os.path.join(ASSETS, name + ".imageset")
    os.makedirs(folder, exist_ok=True)
    w, h = image_3x.size
    image_3x.save(os.path.join(folder, name + "@3x.png"), optimize=True)
    image_3x.resize((w * 2 // 3, h * 2 // 3), Image.LANCZOS).save(os.path.join(folder, name + "@2x.png"), optimize=True)
    with open(os.path.join(folder, "Contents.json"), "w") as f:
        json.dump({
            "images": [
                {"idiom": "universal", "scale": "2x", "filename": name + "@2x.png"},
                {"idiom": "universal", "scale": "3x", "filename": name + "@3x.png"},
            ],
            "info": {"author": "xcode", "version": 1},
            "properties": {"template-rendering-intent": "template"},
        }, f, indent=2)


def build(key, region, countries, lakes):
    project = projector(region["projection"])
    limit = region.get("limit")
    focus, others = [], []
    for country in countries:
        p = country["properties"]
        for outer, holes in rings_of(country):
            if sum(x for x, _ in outer) / len(outer) < -170 and key == "asia":
                continue
            west = region.get("clip_west", {}).get(p["ISO_A3"])
            is_focus = region["focus"](p, outer)
            if is_focus and west is not None:
                # The part west of the line still shows, as a neighbor.
                others.append((outer, holes))
                outer = clip_west(outer, west)
                holes = []
                if len(outer) < 3:
                    continue
            (focus if is_focus else others).append((outer, holes))

    # The frame: the focus land, optionally limited to a lon/lat box.
    xs, ys = [], []
    for outer, _ in focus:
        for lon, lat in outer:
            if limit and not (limit[0] <= lon <= limit[2] and limit[1] <= lat <= limit[3]):
                continue
            x, y = project(lon, lat)
            xs.append(x)
            ys.append(y)
    pad = region["pad"] * (max(xs) - min(xs))
    x0, x1, y0, y1 = min(xs) - pad, max(xs) + pad, min(ys) - pad, max(ys) + pad
    height = round(WIDTH * (y1 - y0) / (x1 - x0))
    scale = WIDTH * 3 * SUPERSAMPLE / (x1 - x0)
    size = (WIDTH * 3 * SUPERSAMPLE, height * 3 * SUPERSAMPLE)
    to_px = lambda lon, lat: ((project(lon, lat)[0] - x0) * scale, (project(lon, lat)[1] - y0) * scale)
    to_unit = lambda lon, lat: ((project(lon, lat)[0] - x0) / (x1 - x0), (project(lon, lat)[1] - y0) / (y1 - y0))

    def near_frame(ring):
        pts = [to_px(lon, lat) for lon, lat in ring]
        return any(-size[0] < x < 2 * size[0] and -size[1] < y < 2 * size[1] for x, y in pts), pts

    # Land: neighbors faint, the focus solid, big lakes cut out.
    land = Image.new("L", size, 0)
    draw = ImageDraw.Draw(land)
    for group, alpha in ((others, 70), (focus, 255)):
        for outer, holes in group:
            visible, pts = near_frame(outer)
            if not visible or len(pts) < 3:
                continue
            draw.polygon(pts, fill=alpha)
            for hole in holes:
                draw.polygon([to_px(lon, lat) for lon, lat in hole], fill=0)
    for lake in lakes:
        if lake["properties"].get("scalerank", 9) > 1:
            continue
        for outer, _ in rings_of(lake):
            visible, pts = near_frame(outer)
            if visible and len(pts) >= 3:
                draw.polygon(pts, fill=0)

    # Rivers.
    features = load(region["rivers_file"])
    water = Image.new("L", size, 0)
    wdraw = ImageDraw.Draw(water)
    flows = []
    for river in region["rivers"]:
        if "trace" in river:
            parts = [smooth(river["trace"])]
        else:
            parts = []
            box = river.get("box")
            for f in features:
                p = f["properties"]
                if p.get("name") not in river["data"] and p.get("name_en") not in river["data"]:
                    continue
                for part in lines_of(f):
                    mx = sum(x for x, _ in part) / len(part)
                    my = sum(y for _, y in part) / len(part)
                    px, py = to_unit(mx, my)
                    if box and not (box[0] <= mx <= box[2] and box[1] <= my <= box[3]):
                        continue
                    if not box and not (-0.3 < px < 1.3 and -0.3 < py < 1.3):
                        continue
                    parts.append(part)
        if not parts:
            print(f"  {key}: no data for {river['name']}, skipped")
            continue
        width = (2.3 if river["main"] else 1.4) * 3 * SUPERSAMPLE
        for part in parts:
            pts = [to_px(lon, lat) for lon, lat in part]
            wdraw.line(pts, fill=255, width=round(width), joint="curve")
            for x, y in (pts[0], pts[-1]):
                wdraw.ellipse((x - width / 2, y - width / 2, x + width / 2, y + width / 2), fill=255)
        if river["main"]:
            line = chain(parts)
            if math.dist(line[0], river["mouth"]) < math.dist(line[-1], river["mouth"]):
                line.reverse()
            unit = resample([to_unit(lon, lat) for lon, lat in line], FLOW_POINTS)
            flows.append((river["name"], unit))

    final = (WIDTH * 3, height * 3)
    for name, mask in ((f"map-{key}-land", land), (f"map-{key}-rivers", water)):
        small = mask.resize(final, Image.LANCZOS)
        rgba = Image.new("RGBA", final, (255, 255, 255, 0))
        rgba.putalpha(small)
        write_imageset(name, rgba)
    print(f"  {key}: {WIDTH}x{height} pt, {len(flows)} flowing rivers of {len(region['rivers'])}")
    return height, flows


def main():
    countries = load("ne_50m_admin_0_countries.geojson")
    lakes = load("ne_50m_lakes.geojson")
    os.makedirs(ASSETS, exist_ok=True)
    with open(os.path.join(ASSETS, "Contents.json"), "w") as f:
        json.dump({"info": {"author": "xcode", "version": 1}}, f, indent=2)
    out = [
        "// Generated by tools/make_river_maps.py. Don't edit by hand.",
        "// Map data: Natural Earth (public domain).",
        "",
        "/// A region's map for the Rivers widgets.",
        "struct RiverRegion {",
        "    let key: String",
        "    /// As in \"Rivers of Japan\".",
        "    let title: String",
        "    /// Width over height of the map images.",
        "    let aspect: Double",
        "    let rivers: [River]",
        "",
        "    struct River {",
        "        let name: String",
        "        /// The course from source to mouth as x, y pairs, each 0...1 across the map image.",
        "        let course: [Double]",
        "    }",
        "",
        "    var landImage: String { \"map-\\(key)-land\" }",
        "    var riversImage: String { \"map-\\(key)-rivers\" }",
        "}",
        "",
        "extension RiverRegion {",
    ]
    for key, region in REGIONS.items():
        height, flows = build(key, region, countries, lakes)
        out.append(f"    static let {key} = RiverRegion(")
        out.append(f"        key: \"{key}\", title: \"{region['title']}\", aspect: {WIDTH / height:.4f},")
        out.append("        rivers: [")
        for name, points in flows:
            numbers = ", ".join(f"{x:.3f}, {y:.3f}" for x, y in points)
            out.append(f"            River(name: \"{name}\", course: [{numbers}]),")
        out.append("        ]")
        out.append("    )")
        out.append("")
    out[-1] = "}"
    with open(SWIFT, "w") as f:
        f.write("\n".join(out) + "\n")
    print("wrote", os.path.relpath(SWIFT, IOS))


if __name__ == "__main__":
    main()
