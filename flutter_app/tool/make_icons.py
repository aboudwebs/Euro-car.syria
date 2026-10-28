#!/usr/bin/env python3
"""Generates the launcher icons from the EURO logo artwork (branding/source/euro_icon_source.jpg).

Developer tool: needs Pillow and NumPy (`pip install pillow numpy`). The generated files are committed under
branding/, so building the app does not need either; run this only to change the icon:

    python3 tool/make_icons.py [path/to/artwork.jpg]

The artwork is a dark rounded tile (a smooth blue-to-black gradient) carrying the silver "E", the gold orbit and the
word EURO, photographed on a light backdrop with a soft shadow. The tool

  1. cuts the tile out of the backdrop,
  2. fits a smooth model of the tile's gradient (a cubic polynomial) to the pixels that are not part of the logo,
  3. recovers the logo as a layer with transparency (where the picture differs from the gradient),

and writes:

  * mipmap-*/ic_launcher.png            legacy icons (Android 7 and older): the tile itself, rounded corners kept
  * drawable-xxxhdpi/ic_launcher_foreground.png   adaptive icon layer 1: the logo, scaled into the 66 dp safe circle
  * drawable-xxxhdpi/ic_launcher_background.png   adaptive icon layer 2: the gradient, extended past the tile
  * mipmap-anydpi-v26/ic_launcher.xml   the adaptive icon (Android 8+) that ties the two layers together
  * branding/icon_1024.png              full-bleed square master for store listings
  * values/euro_colors.xml and the launch background (unchanged: the dark launch screen)

Everything is deterministic: the same artwork always produces the same files.
"""

from __future__ import annotations

import pathlib
import random
import sys

import numpy as np
from PIL import Image, ImageFilter

ROOT = pathlib.Path(__file__).resolve().parent.parent
SOURCE = ROOT / "branding" / "source" / "euro_icon_source.jpg"
OUT = ROOT / "branding"
RES = OUT / "android" / "res"

RESAMPLE = getattr(Image, "Resampling", Image)

# --- reading the artwork ------------------------------------------------------------------------------------------
TILE_LUMINANCE = 100  # pixels darker than this belong to the tile; the backdrop and its shadow are lighter
TILE_BLUE = 40  # so do bluish pixels up to TILE_BRIGHTEST: the lit rim of the tile is brighter than TILE_LUMINANCE but blue,
TILE_BRIGHTEST = 200  # while the backdrop and its shadow are neutral grey
TILE_RADIUS_RATIO = 0.25  # corner radius of the tile as a share of its width (only used to keep clear of the edge)
EDGE_MARGIN = 40  # pixels next to the tile's edge are not used to fit the gradient: the edge carries a thin light bevel
LOGO_MARGIN = 110  # the logo is searched for at least this far inside the edge (the bevel is brighter than the gradient
#                    model near the rounded corners and would otherwise be mistaken for logo)

# --- the gradient model -------------------------------------------------------------------------------------------
POLY_DEGREE = 3
FIT_SHRINK = 4  # the fit runs on a copy shrunk by this factor (the gradient is smooth, this only saves time)
LOGO_DIFFERENCE = 10  # a shrunk pixel this far from the model is logo, not gradient
LOGO_GROW = 7  # and so is everything within this many shrunk pixels of it (soft shadows around the logo)
FIT_ROUNDS = 6

# --- logo transparency --------------------------------------------------------------------------------------------
ALPHA_LOW = 6  # a pixel closer than this to the gradient is fully transparent
ALPHA_HIGH = 36  # a pixel further than this is fully opaque

# --- Android ------------------------------------------------------------------------------------------------------
LAYER_DP = 108  # adaptive icon layers are 108 x 108 dp ...
SAFE_RADIUS_DP = 33  # ... and whatever must never be cropped stays inside a circle of 66 dp
LAYER_SCALE = 6  # pixels per dp of the committed layers (xxxhdpi is 4; the extra detail keeps the Android 12 splash crisp)
LEGACY_SIZES = (("mdpi", 48), ("hdpi", 72), ("xhdpi", 96), ("xxhdpi", 144), ("xxxhdpi", 192))
MASTER_SIZE = 1024
DITHER_SEED = 20241028


# ----------------------------------------------------------------------------------------------------------------
# geometry of the tile
# ----------------------------------------------------------------------------------------------------------------


def tile_distance(x, y, width, height, radius):
    """Signed distance (negative inside) from (x, y) to the tile's rounded rectangle."""
    qx = np.abs(x - width / 2.0) - (width / 2.0 - radius)
    qy = np.abs(y - height / 2.0) - (height / 2.0 - radius)
    outside = np.hypot(np.maximum(qx, 0.0), np.maximum(qy, 0.0))
    return outside + np.minimum(np.maximum(qx, qy), 0.0) - radius


def clamp_to_tile(x, y, width, height, radius, inset):
    """Moves points that lie outside the tile (inset by `inset`) onto its border, so the gradient model is only ever
    evaluated where it was fitted and simply continues the colour of the nearest edge beyond that."""
    half_w, half_h = width / 2.0 - inset, height / 2.0 - inset
    corner = max(radius - inset, 1.0)
    dx, dy = x - width / 2.0, y - height / 2.0
    qx = np.clip(dx, -(half_w - corner), half_w - corner)
    qy = np.clip(dy, -(half_h - corner), half_h - corner)
    ex, ey = dx - qx, dy - qy
    dist = np.hypot(ex, ey)
    keep = np.where(dist > corner, corner / np.maximum(dist, 1e-9), 1.0)
    return width / 2.0 + qx + ex * keep, height / 2.0 + qy + ey * keep


# ----------------------------------------------------------------------------------------------------------------
# step 1: the tile
# ----------------------------------------------------------------------------------------------------------------


def luminance(rgb):
    return rgb @ np.array([0.2126, 0.7152, 0.0722], dtype=np.float32)


def load_tile(path):
    """Returns the tile cropped from the artwork: its RGB pixels (float32, H x W x 3) and a filled mask (H x W)."""
    pixels = np.asarray(Image.open(path).convert("RGB"), dtype=np.float32)
    brightness = luminance(pixels)
    bluish = (pixels[..., 2] - pixels[..., 0] > TILE_BLUE) & (brightness < TILE_BRIGHTEST)
    dark = (brightness < TILE_LUMINANCE) | bluish
    rows = np.flatnonzero(dark.any(axis=1))
    cols = np.flatnonzero(dark.any(axis=0))
    if rows.size == 0 or cols.size == 0:
        raise SystemExit("make_icons.py: no dark tile found in the artwork")
    top, bottom, left, right = rows[0], rows[-1] + 1, cols[0], cols[-1] + 1
    tile = pixels[top:bottom, left:right]
    dark = dark[top:bottom, left:right]
    # The tile is convex, so every row is one run: fill from its first to its last dark pixel (this also covers the
    # bright logo, which is not dark).
    first = dark.argmax(axis=1)
    last = dark.shape[1] - 1 - dark[:, ::-1].argmax(axis=1)
    columns = np.arange(dark.shape[1])[None, :]
    filled = (columns >= first[:, None]) & (columns <= last[:, None]) & dark.any(axis=1)[:, None]
    return tile, filled


def tile_alpha(filled):
    """Soft outline of the tile for the legacy icons (a little inside the edge, where the backdrop still bleeds in)."""
    image = Image.fromarray((filled * 255).astype(np.uint8))
    image = image.filter(ImageFilter.MinFilter(5)).filter(ImageFilter.GaussianBlur(1.0))
    return np.asarray(image, dtype=np.float32) / 255.0


# ----------------------------------------------------------------------------------------------------------------
# step 2: the gradient model
# ----------------------------------------------------------------------------------------------------------------

_TERMS = [(i, j) for i in range(POLY_DEGREE + 1) for j in range(POLY_DEGREE + 1 - i)]


def polynomial_basis(x, y, width, height):
    u = 2.0 * np.asarray(x, dtype=np.float64) / width - 1.0
    v = 2.0 * np.asarray(y, dtype=np.float64) / height - 1.0
    return np.stack([u**i * v**j for i, j in _TERMS], axis=-1)


def fit_gradient(tile, filled, radius):
    """Least-squares fit of the tile's gradient, ignoring the logo (found again after every round)."""
    height, width = filled.shape
    small_w, small_h = width // FIT_SHRINK, height // FIT_SHRINK
    small = np.asarray(
        Image.fromarray(tile.astype(np.uint8)).resize((small_w, small_h), RESAMPLE.BOX), dtype=np.float32
    )
    xs = (np.arange(small_w) + 0.5) * (width / small_w)
    ys = (np.arange(small_h) + 0.5) * (height / small_h)
    grid_x, grid_y = np.meshgrid(xs, ys)
    basis = polynomial_basis(grid_x, grid_y, width, height)
    inner = tile_distance(grid_x, grid_y, width, height, radius) < -EDGE_MARGIN
    sample = inner & (luminance(small) < 90)
    coef = None
    rms = 0.0
    for _ in range(FIT_ROUNDS):
        design = basis[sample]
        coef = np.stack(
            [np.linalg.lstsq(design, small[..., c][sample].astype(np.float64), rcond=None)[0] for c in range(3)], axis=-1
        )
        model = basis @ coef
        off = np.abs(small - model).max(axis=-1) > LOGO_DIFFERENCE
        grown = Image.fromarray((off * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(2 * LOGO_GROW + 1))
        sample = inner & ~(np.asarray(grown) > 0)
        rms = float(np.sqrt(((small - model) ** 2)[sample].mean()))
    return coef, rms


def gradient_at(coef, x, y, width, height, radius):
    """The gradient colour (float, ... x 3) at tile coordinates; points beyond the tile continue its edge colour."""
    x, y = clamp_to_tile(x, y, width, height, radius, EDGE_MARGIN)
    out = np.empty(np.shape(x) + (3,), dtype=np.float32)
    flat_x, flat_y, flat_out = np.reshape(x, -1), np.reshape(y, -1), out.reshape(-1, 3)
    step = 200_000
    for start in range(0, flat_x.size, step):
        basis = polynomial_basis(flat_x[start : start + step], flat_y[start : start + step], width, height)
        flat_out[start : start + step] = np.clip(basis @ coef, 0.0, 255.0)
    return out


# ----------------------------------------------------------------------------------------------------------------
# step 3: the logo layer
# ----------------------------------------------------------------------------------------------------------------


def logo_alpha(tile, coef, radius):
    """Opacity of every tile pixel: 0 where it matches the gradient, 1 where it is clearly something else."""
    height, width, _ = tile.shape
    ys, xs = np.mgrid[0:height, 0:width]
    gradient = gradient_at(coef, xs + 0.5, ys + 0.5, width, height, radius)
    difference = np.abs(tile - gradient).max(axis=-1)
    t = np.clip((difference - ALPHA_LOW) / (ALPHA_HIGH - ALPHA_LOW), 0.0, 1.0)
    alpha = t * t * (3.0 - 2.0 * t)
    # The bevel along the tile's edge is part of the tile, not of the logo.
    alpha[tile_distance(xs + 0.5, ys + 0.5, width, height, radius) > -LOGO_MARGIN] = 0.0
    return alpha.astype(np.float32)


def _circle_from_two(a, b):
    return ((a[0] + b[0]) / 2.0, (a[1] + b[1]) / 2.0, np.hypot(a[0] - b[0], a[1] - b[1]) / 2.0)


def _circle_from_three(a, b, c):
    d = 2.0 * (a[0] * (b[1] - c[1]) + b[0] * (c[1] - a[1]) + c[0] * (a[1] - b[1]))
    if abs(d) < 1e-9:
        circles = [_circle_from_two(a, b), _circle_from_two(a, c), _circle_from_two(b, c)]
        return max(circles, key=lambda circle: circle[2])
    ux = ((a[0] ** 2 + a[1] ** 2) * (b[1] - c[1]) + (b[0] ** 2 + b[1] ** 2) * (c[1] - a[1]) + (c[0] ** 2 + c[1] ** 2) * (a[1] - b[1])) / d
    uy = ((a[0] ** 2 + a[1] ** 2) * (c[0] - b[0]) + (b[0] ** 2 + b[1] ** 2) * (a[0] - c[0]) + (c[0] ** 2 + c[1] ** 2) * (b[0] - a[0])) / d
    return (ux, uy, np.hypot(a[0] - ux, a[1] - uy))


def enclosing_circle(points):
    """Smallest circle holding all points (randomised incremental algorithm; the order is fixed, so it is repeatable)."""
    pts = list(points)
    random.Random(7).shuffle(pts)
    cx, cy, r = pts[0][0], pts[0][1], 0.0

    def outside(p, circle):
        return np.hypot(p[0] - circle[0], p[1] - circle[1]) > circle[2] + 1e-7

    circle = (cx, cy, r)
    for i, p in enumerate(pts):
        if outside(p, circle):
            circle = (p[0], p[1], 0.0)
            for j in range(i):
                q = pts[j]
                if outside(q, circle):
                    circle = _circle_from_two(p, q)
                    for k in range(j):
                        s = pts[k]
                        if outside(s, circle):
                            circle = _circle_from_three(p, q, s)
    return circle


def logo_circle(alpha):
    """Smallest circle around the visible logo (tile coordinates), found from the outline pixels of each row/column."""
    solid = alpha >= 0.5
    points = []
    for index in np.flatnonzero(solid.any(axis=1)):
        xs = np.flatnonzero(solid[index])
        points += [(xs[0] + 0.5, index + 0.5), (xs[-1] + 0.5, index + 0.5)]
    for index in np.flatnonzero(solid.any(axis=0)):
        ys = np.flatnonzero(solid[:, index])
        points += [(index + 0.5, ys[0] + 0.5), (index + 0.5, ys[-1] + 0.5)]
    return enclosing_circle(points)


# ----------------------------------------------------------------------------------------------------------------
# rendering
# ----------------------------------------------------------------------------------------------------------------


def logo_image(tile, alpha):
    """The logo as an RGBA image (tile pixels, transparency from `alpha`)."""
    rgba = np.dstack([tile.astype(np.uint8), np.rint(alpha * 255.0).astype(np.uint8)])
    return Image.fromarray(rgba)


def render_window(logo, coef, tile_size, radius, window, size, rng):
    """Renders the square `window` = (left, top, side) of tile coordinates at `size` px: the gradient (extended past the
    tile) with the logo on top. Returns (rgb uint8, logo RGBA image of that window)."""
    width, height = tile_size
    left, top, side = window
    # Logo: padded with transparency so the window may reach past the tile, then resampled with a proper filter.
    pad = int(np.ceil(max(-left, -top, left + side - width, top + side - height, 0))) + 4
    padded = Image.new("RGBA", (width + 2 * pad, height + 2 * pad), (0, 0, 0, 0))
    padded.paste(logo, (pad, pad))
    layer = padded.resize((size, size), RESAMPLE.LANCZOS, box=(left + pad, top + pad, left + pad + side, top + pad + side))
    # Gradient: evaluated directly at the output resolution.
    centres = (np.arange(size) + 0.5) * (side / size)
    grid_x, grid_y = np.meshgrid(left + centres, top + centres)
    gradient = gradient_at(coef, grid_x, grid_y, width, height, radius)
    gradient = gradient + rng.random(gradient.shape, dtype=np.float32) - 0.5  # dither: hides banding in the dark ramp
    return np.clip(np.rint(gradient), 0, 255).astype(np.uint8), layer


def over(background_rgb, layer):
    """Composites an RGBA layer over an RGB background (both uint8) and returns RGB uint8."""
    rgba = np.asarray(layer, dtype=np.float32)
    a = rgba[..., 3:4] / 255.0
    out = rgba[..., :3] * a + background_rgb.astype(np.float32) * (1.0 - a)
    return np.clip(np.rint(out), 0, 255).astype(np.uint8)


def save_png(array_or_image, path):
    path.parent.mkdir(parents=True, exist_ok=True)
    image = array_or_image if isinstance(array_or_image, Image.Image) else Image.fromarray(array_or_image)
    image.save(path, optimize=True)


def write_text(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def main() -> None:
    source = pathlib.Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else SOURCE
    rng = np.random.default_rng(DITHER_SEED)

    tile, filled = load_tile(source)
    height, width, _ = tile.shape
    radius = TILE_RADIUS_RATIO * width
    coef, rms = fit_gradient(tile, filled, radius)
    alpha = logo_alpha(tile, coef, radius)
    cx, cy, r = logo_circle(alpha)
    logo = logo_image(tile, alpha)
    print(f"tile {width}x{height} px, gradient fit error {rms:.2f} levels, logo circle r={r:.0f} px at ({cx:.0f}, {cy:.0f})")

    # Legacy icons: the tile as it is, on a transparent square (the tile is a little taller than wide).
    side = max(width, height)
    square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    legacy = np.dstack([tile.astype(np.uint8), np.rint(tile_alpha(filled) * 255.0).astype(np.uint8)])
    square.paste(Image.fromarray(legacy), ((side - width) // 2, (side - height) // 2))
    for folder, size in LEGACY_SIZES:
        save_png(square.resize((size, size), RESAMPLE.LANCZOS), RES / f"mipmap-{folder}" / "ic_launcher.png")

    # Adaptive icon: both layers share one geometry, the logo's circle sits in the middle and fills the safe zone.
    layer_px = LAYER_DP * LAYER_SCALE
    px_per_source = SAFE_RADIUS_DP * LAYER_SCALE / r
    window_side = layer_px / px_per_source
    window = (cx - window_side / 2.0, cy - window_side / 2.0, window_side)
    background_rgb, foreground = render_window(logo, coef, (width, height), radius, window, layer_px, rng)
    save_png(foreground, RES / "drawable-xxxhdpi" / "ic_launcher_foreground.png")
    save_png(background_rgb, RES / "drawable-xxxhdpi" / "ic_launcher_background.png")

    # Full-bleed square master: the tile's own proportions, corners filled with the gradient.
    master_window = (0.0, (height - width) / 2.0, float(width))
    master_rgb, master_logo = render_window(logo, coef, (width, height), radius, master_window, MASTER_SIZE, rng)
    save_png(over(master_rgb, master_logo), OUT / "icon_1024.png")

    write_text(
        RES / "mipmap-anydpi-v26" / "ic_launcher.xml",
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@drawable/ic_launcher_background"/>\n'
        '    <foreground android:drawable="@drawable/ic_launcher_foreground"/>\n'
        "</adaptive-icon>\n",
    )
    write_text(
        RES / "values" / "euro_colors.xml",
        '<?xml version="1.0" encoding="utf-8"?>\n'
        "<resources>\n"
        '    <color name="euro_launch_background">#07090E</color>\n'
        "</resources>\n",
    )
    for name in ("drawable", "drawable-v21"):
        write_text(
            RES / name / "launch_background.xml",
            '<?xml version="1.0" encoding="utf-8"?>\n'
            '<layer-list xmlns:android="http://schemas.android.com/apk/res/android">\n'
            '    <item android:drawable="@color/euro_launch_background"/>\n'
            "</layer-list>\n",
        )
    print(f"icons written under {OUT}")


if __name__ == "__main__":
    main()
