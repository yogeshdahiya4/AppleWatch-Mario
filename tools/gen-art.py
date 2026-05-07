#!/usr/bin/env python3
"""
Procedural art generator for PixelHop's parallax backgrounds.

Outputs PNGs to apps/watch/PixelHop/Resources/Sprites/Backgrounds.atlas/.

Why this exists: the Kenney pack we're using doesn't include cohesive sky
gradients, sun discs, vignettes or themed mountain silhouettes. Rather than
ship a second asset pack we generate them deterministically from this script.

Run:
    python3 tools/gen-art.py

It's idempotent — running twice produces byte-identical output.
"""
from __future__ import annotations
import math
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "apps/watch/PixelHop/Resources/Sprites/Backgrounds.atlas"
OUT.mkdir(parents=True, exist_ok=True)

# Per-theme palettes.
# Each theme has a sky gradient (top → bottom), a sun/moon tint, and
# silhouette colours for far/mid mountain layers.
THEMES = {
    "overworld": {
        "sky_top":      (255, 178, 138),   # warm peach (dawn)
        "sky_mid":      (255, 200, 168),
        "sky_bottom":   (188, 226, 247),   # soft cyan
        "sun_color":    (255, 235, 200),
        "far_mtn":      (78,  101, 134),   # cool slate
        "mid_mtn":      (115, 145, 168),
    },
    "underground": {
        "sky_top":      (24,  18,  46),
        "sky_mid":      (38,  28,  64),
        "sky_bottom":   (62,  44,  92),
        "sun_color":    (210, 180, 240),
        "far_mtn":      (16,  10,  30),
        "mid_mtn":      (32,  22,  56),
    },
    "sky": {
        "sky_top":      (148, 196, 235),
        "sky_mid":      (188, 220, 244),
        "sky_bottom":   (228, 240, 250),
        "sun_color":    (255, 250, 230),
        "far_mtn":      (180, 200, 222),
        "mid_mtn":      (210, 224, 238),
    },
    "castle": {
        "sky_top":      (28,  6,   16),
        "sky_mid":      (96,  24,  32),
        "sky_bottom":   (210, 80,  40),
        "sun_color":    (255, 165, 60),
        "far_mtn":      (12,  6,   12),
        "mid_mtn":      (28,  12,  18),
    },
}

SKY_W, SKY_H = 768, 512
MTN_W, MTN_H = 1024, 220
SUN_SIZE = 220


def lerp_color(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def make_sky(theme: str, palette: dict) -> Image.Image:
    """Top-to-bottom three-stop gradient with a touch of horizontal banding."""
    img = Image.new("RGB", (SKY_W, SKY_H))
    px = img.load()
    top = palette["sky_top"]
    mid = palette["sky_mid"]
    bot = palette["sky_bottom"]
    for y in range(SKY_H):
        if y < SKY_H * 0.55:
            t = y / (SKY_H * 0.55)
            base = lerp_color(top, mid, t)
        else:
            t = (y - SKY_H * 0.55) / (SKY_H * 0.45)
            base = lerp_color(mid, bot, t)
        for x in range(SKY_W):
            # Subtle horizontal cloud-band shimmer
            shimmer = int(2 * math.sin((x / SKY_W) * math.pi * 2 + y * 0.02))
            r = max(0, min(255, base[0] + shimmer))
            g = max(0, min(255, base[1] + shimmer))
            b = max(0, min(255, base[2] + shimmer))
            px[x, y] = (r, g, b)
    return img


def make_sun(palette: dict) -> Image.Image:
    """Soft radial-gradient disc."""
    img = Image.new("RGBA", (SUN_SIZE, SUN_SIZE), (0, 0, 0, 0))
    px = img.load()
    cx = cy = SUN_SIZE / 2
    color = palette["sun_color"]
    for y in range(SUN_SIZE):
        for x in range(SUN_SIZE):
            d = math.hypot(x - cx, y - cy) / (SUN_SIZE / 2)
            if d > 1:
                continue
            # Inner solid disc, soft outer falloff.
            if d < 0.55:
                a = 255
            else:
                a = int(255 * (1.0 - (d - 0.55) / 0.45) ** 1.6)
            px[x, y] = (color[0], color[1], color[2], max(0, min(255, a)))
    return img.filter(ImageFilter.GaussianBlur(radius=2))


def make_mountains(theme: str, palette: dict, near: bool) -> Image.Image:
    """Bezier-style silhouettes via cubic-blend of control points + smoothing."""
    img = Image.new("RGBA", (MTN_W, MTN_H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    color = palette["mid_mtn"] if near else palette["far_mtn"]

    if theme == "overworld":
        peaks = [(0, MTN_H), (90, 90), (210, 130), (340, 60), (470, 110),
                 (610, 80), (760, 120), (880, 70), (MTN_W, MTN_H)]
    elif theme == "underground":
        peaks = [(0, MTN_H), (60, 70), (140, 150), (220, 40),
                 (320, 130), (410, 50), (520, 120), (640, 30),
                 (760, 110), (880, 70), (MTN_W, MTN_H)]
    elif theme == "sky":
        peaks = [(0, MTN_H), (140, 130), (300, 90), (470, 130),
                 (640, 100), (820, 130), (MTN_W, MTN_H)]
    else:  # castle
        peaks = [(0, MTN_H), (80, 50), (180, 150), (280, 30),
                 (390, 120), (510, 20), (640, 110), (770, 40),
                 (890, 130), (MTN_W, MTN_H)]

    # Smooth between peaks with intermediate samples.
    smooth = []
    for i, (x, y) in enumerate(peaks):
        smooth.append((x, y))
        if i < len(peaks) - 1:
            nx, ny = peaks[i + 1]
            for s in range(1, 4):
                t = s / 4
                # Cosine interpolation for nicer hill shape.
                tt = (1 - math.cos(t * math.pi)) / 2
                smooth.append(
                    (int(x + (nx - x) * t), int(y + (ny - y) * tt))
                )
    if not near:
        # Push far layer up slightly so its silhouette appears behind near.
        smooth = [(x, max(0, y - 18)) for x, y in smooth]

    draw.polygon(smooth, fill=color)
    if not near:
        # Far layer: slight blur for atmospheric depth.
        img = img.filter(ImageFilter.GaussianBlur(radius=1.5))
    return img


def make_cloud(palette: dict, scale: float = 1.0) -> Image.Image:
    """Soft round-blob cloud (3-circle composite + blur)."""
    w, h = int(160 * scale), int(70 * scale)
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    base = (255, 255, 255, 235)
    # Three overlapping ellipses.
    draw.ellipse((6, 16, 76, 64), fill=base)
    draw.ellipse((40, 6,  120, 60), fill=base)
    draw.ellipse((80, 18, 152, 64), fill=base)
    return img.filter(ImageFilter.GaussianBlur(radius=3))


def make_vignette() -> Image.Image:
    """Soft radial vignette: transparent centre, dark edges."""
    w, h = SKY_W, SKY_H
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = img.load()
    cx, cy = w / 2, h / 2
    rmax = math.hypot(cx, cy)
    for y in range(h):
        for x in range(w):
            d = math.hypot(x - cx, y - cy) / rmax
            a = int(150 * max(0, (d - 0.55)) ** 1.6)
            px[x, y] = (0, 0, 0, min(150, a))
    return img.filter(ImageFilter.GaussianBlur(radius=12))


def main() -> None:
    print(f"Generating into {OUT.relative_to(ROOT)}")
    for theme, palette in THEMES.items():
        sky = make_sky(theme, palette)
        sky.save(OUT / f"sky-{theme}.png", optimize=True)

        sun = make_sun(palette)
        sun.save(OUT / f"sun-{theme}.png", optimize=True)

        far = make_mountains(theme, palette, near=False)
        far.save(OUT / f"mtn-far-{theme}.png", optimize=True)

        near = make_mountains(theme, palette, near=True)
        near.save(OUT / f"mtn-near-{theme}.png", optimize=True)

        print(f"  ✓ {theme}")

    cloud = make_cloud(THEMES["overworld"])
    cloud.save(OUT / "cloud-soft.png", optimize=True)

    cloud_big = make_cloud(THEMES["overworld"], scale=1.5)
    cloud_big.save(OUT / "cloud-big.png", optimize=True)

    vignette = make_vignette()
    vignette.save(OUT / "vignette.png", optimize=True)

    print("Done.")


if __name__ == "__main__":
    main()
