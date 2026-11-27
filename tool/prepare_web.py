#!/usr/bin/env python3
"""Apply EURO branding and iPhone home-screen metadata to the generated Flutter Web project."""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
WEB = ROOT / "web"
SOURCE_ICON = ROOT / "branding" / "icon_1024.png"
MANIFEST = WEB / "manifest.json"
INDEX = WEB / "index.html"


def main() -> None:
    if not SOURCE_ICON.is_file() or not MANIFEST.is_file() or not INDEX.is_file():
        raise SystemExit("prepare_web.py: generated web project or EURO master icon is missing")

    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    manifest.update(
        {
            "name": "Euro Parts",
            "short_name": "Euro Parts",
            "start_url": "/app/",
            "scope": "/app/",
            "display": "standalone",
            "background_color": "#0b1315",
            "theme_color": "#0b1315",
            "description": "Euro Parts - قطع غيار السيارات",
            "orientation": "portrait-primary",
            "prefer_related_applications": False,
        }
    )
    manifest["icons"] = [
        {"src": "icons/Icon-192.png", "sizes": "192x192", "type": "image/png", "purpose": "any"},
        {"src": "icons/Icon-512.png", "sizes": "512x512", "type": "image/png", "purpose": "any"},
        {"src": "icons/Icon-maskable-192.png", "sizes": "192x192", "type": "image/png", "purpose": "maskable"},
        {"src": "icons/Icon-maskable-512.png", "sizes": "512x512", "type": "image/png", "purpose": "maskable"},
    ]
    MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\\n", encoding="utf-8")

    with Image.open(SOURCE_ICON) as source:
        image = source.convert("RGBA")
        for size, name in (
            (192, "Icon-192.png"),
            (512, "Icon-512.png"),
            (192, "Icon-maskable-192.png"),
            (512, "Icon-maskable-512.png"),
        ):
            target = WEB / "icons" / name
            target.parent.mkdir(parents=True, exist_ok=True)
            image.resize((size, size), Image.Resampling.LANCZOS).save(target, format="PNG")
        image.resize((64, 64), Image.Resampling.LANCZOS).save(WEB / "favicon.png", format="PNG")

    html = INDEX.read_text(encoding="utf-8")
    html = html.replace('content="A new Flutter project."', 'content="Euro Parts - قطع غيار السيارات"')
    html = html.replace('content="euro_cars"', 'content="Euro Parts"')
    html = html.replace("<title>euro_cars</title>", "<title>Euro Parts</title>")
    if 'name="theme-color"' not in html:
        html = html.replace('<meta charset="UTF-8">', '<meta charset="UTF-8">\\n  <meta name="theme-color" content="#0b1315">')
    INDEX.write_text(html, encoding="utf-8")


if __name__ == "__main__":
    main()
