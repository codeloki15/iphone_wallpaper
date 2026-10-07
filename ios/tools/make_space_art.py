#!/usr/bin/env python3
"""Paints the night sky behind the Orbit and Zodiac widgets.

A dark sky with faint clouds of color and a scattering of stars, the same
every time it is run. Writes Shared/WidgetArt.xcassets/space-sky-<size>.imageset,
one for each widget size.

A widget's images have a size limit: WidgetKit refuses to draw the widget
(error "imageTooLarge") if an image is more than about twice as tall, in
pixels, as the widget. So each picture is made no larger than a widget of
its size is on a small iPhone at 2x, doubled.

Run from the ios folder:  python3 tools/make_space_art.py
Needs Pillow and NumPy.
"""
import json
import os

import numpy as np
from PIL import Image, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
ASSETS = os.path.join(os.path.dirname(HERE), "Shared", "WidgetArt.xcassets")
# name: (width, height) in pixels
SIZES = {"small": (540, 540), "medium": (1120, 540), "large": (1080, 1140)}


def paint(width, height):
    rng = np.random.default_rng(27)

    def smooth_noise(cells):
        """Random values on a coarse grid, enlarged until they blend."""
        across = max(2, round(cells * width / height))
        grid = (rng.random((cells, across)) * 255).astype(np.uint8)
        image = Image.fromarray(grid).resize((width, height), Image.BICUBIC)
        return np.asarray(image, dtype=np.float32) / 255

    y, x = np.mgrid[0:height, 0:width].astype(np.float32)
    x, y = x / width, y / height
    distance = np.sqrt((x - 0.5) ** 2 + (y - 0.5) ** 2)

    # Deep blue in the middle, falling to near black at the corners.
    core = np.array([14, 19, 46], dtype=np.float32)
    edge = np.array([3, 4, 11], dtype=np.float32)
    fall = np.clip(distance / 0.72, 0, 1)[..., None]
    sky = core * (1 - fall) + edge * fall

    # Clouds of color: three tints, each where its own noise runs high.
    for tint, cells, strength in [((70, 36, 120), 5, 0.42), ((16, 84, 104), 4, 0.36), ((110, 34, 78), 6, 0.26)]:
        cloud = np.clip((smooth_noise(cells) - 0.45) / 0.55, 0, 1) ** 2
        cloud *= 0.6 + 0.4 * smooth_noise(14)
        sky += np.array(tint, dtype=np.float32) * (cloud * strength)[..., None]

    # Stars: many faint, a few bright, the brightest with a soft glow.
    stars = np.zeros((height, width, 3), dtype=np.float32)
    glow = np.zeros((height, width, 3), dtype=np.float32)
    tints = [(255, 255, 255), (214, 228, 255), (255, 240, 214), (255, 224, 200)]
    for _ in range(round(width * height / 1300)):
        px, py = rng.integers(1, width - 1), rng.integers(1, height - 1)
        brightness = rng.random() ** 3.2
        color = np.array(tints[rng.integers(0, len(tints))], dtype=np.float32)
        stars[py, px] += color * (0.25 + 0.75 * brightness)
        if brightness > 0.45:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                stars[py + dy, px + dx] += color * 0.35 * brightness
        if brightness > 0.8:
            glow[py, px] += color * 26
    blurred = Image.fromarray(np.clip(glow, 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(3.2))
    sky += stars + np.asarray(blurred, dtype=np.float32) * 2.4

    return Image.fromarray(np.clip(sky, 0, 255).astype(np.uint8))


def main():
    for name, (width, height) in SIZES.items():
        folder = os.path.join(ASSETS, f"space-sky-{name}.imageset")
        os.makedirs(folder, exist_ok=True)
        file = f"space-sky-{name}.jpg"
        paint(width, height).save(os.path.join(folder, file), quality=90)
        with open(os.path.join(folder, "Contents.json"), "w") as f:
            json.dump({
                "images": [{"idiom": "universal", "scale": "3x", "filename": file}],
                "info": {"author": "xcode", "version": 1},
            }, f, indent=2)
        print(file, width, height, os.path.getsize(os.path.join(folder, file)) // 1024, "KB")


if __name__ == "__main__":
    main()
