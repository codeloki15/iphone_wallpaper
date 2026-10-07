#!/usr/bin/env python3
"""Draws a recording's frames on one sheet, to look at before it becomes a widget.

    python3 tools/frame_sheet.py tools/ln/frames/globe.json [every]

Reads the frames written by tools/hairline/capture.mjs or tools/ln and
writes <name>.png beside the JSON: the first frame at the size of a large
widget, then every frame (or every `every`-th) small, in order. Paths are
drawn from their straight segments, which is all those two tools write.
Needs Pillow.
"""
import json
import math
import re
import sys

from PIL import Image, ImageDraw

SS = 3  # draw large and shrink, for smooth hairlines


def subpaths(d):
    """A path's subpaths as lists of points, and whether each is closed."""
    out, points = [], []
    for command, body in re.findall(r"([MLZmlz])([^MLZmlz]*)", d):
        numbers = [float(n) for n in re.findall(r"-?\d*\.?\d+(?:e-?\d+)?", body)]
        if command in "Mm" and points:
            out.append((points, False))
            points = []
        if command in "Zz":
            out.append((points, True))
            points = []
            continue
        points += list(zip(numbers[0::2], numbers[1::2]))
    if points:
        out.append((points, False))
    return out


def draw(frame, plate, width):
    scale = width / 400 * SS
    image = Image.new("RGB", (round(400 * scale), round(320 * scale)), plate)
    pen = ImageDraw.Draw(image)
    stroke = max(1, round(1.15 * scale))
    for shape in frame:
        m = shape.get("m", [1, 0, 0, 1, 0, 0])
        at = lambda p: ((m[0] * p[0] + m[2] * p[1] + m[4]) * scale, (m[1] * p[0] + m[3] * p[1] + m[5]) * scale)
        if shape["tag"] == "path":
            for points, closed in subpaths(shape["d"]):
                points = [at(p) for p in points]
                if len(points) < 2:
                    continue
                if shape.get("fill") and len(points) > 2:
                    pen.polygon(points, fill=shape["fill"])
                if shape.get("stroke"):
                    pen.line(points + points[:1] if closed else points, fill=shape["stroke"], width=stroke, joint="curve")
        elif shape["tag"] in ("circle", "ellipse"):
            rx = float(shape.get("r", shape.get("rx", 0)))
            ry = float(shape.get("r", shape.get("ry", 0)))
            ring = [at((float(shape["cx"]) + rx * math.cos(a / 12 * math.pi), float(shape["cy"]) + ry * math.sin(a / 12 * math.pi))) for a in range(24)]
            if shape.get("fill"):
                pen.polygon(ring, fill=shape["fill"])
            if shape.get("stroke"):
                pen.line(ring + ring[:1], fill=shape["stroke"], width=stroke)
    return image.resize((round(width), round(width * 0.8)), Image.LANCZOS)


def main():
    path = sys.argv[1]
    every = int(sys.argv[2]) if len(sys.argv) > 2 else 1
    with open(path, encoding="utf-8") as f:
        record = json.load(f)
    plate = record["palette"]["plate"]
    frames = record["frames"][::every]
    cols = 8
    rows = math.ceil(len(frames) / cols)
    sheet = Image.new("RGB", (cols * 204 + 4, 548 + rows * 164 + 4), "#1b1c22")
    sheet.paste(draw(record["frames"][0], plate, 676), (4, 4))
    sheet.paste(draw(record["frames"][0], plate, 394), (688, 4))
    for i, frame in enumerate(frames):
        sheet.paste(draw(frame, plate, 200), (4 + (i % cols) * 204, 548 + (i // cols) * 164))
    out = path[:-5] + ".png"
    sheet.save(out)
    print(out, f"{len(record['frames'])} frames, {record['seconds']} s")


if __name__ == "__main__":
    main()
