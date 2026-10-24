"""Builds RIFTWARD store art (itch.io cover) from in-game captures.

Usage:
    python tools/make_store_assets.py

Outputs:
    release/store/cover_630x500.png   itch.io cover (renders at 315x250)
    release/store/banner_1200x630.png social / page header card

All input is captured from the running game, so the art always matches the build.
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "release" / "store"
FONT_DIR = ROOT / "assets" / "fonts" / "Sora"

TITLE = "RIFTWARD"
TAGLINE = "Drop into the Reach. Build what survives."
KICKER = "FIRST-PERSON EXTRACTION SHOOTER"

HERO = ROOT / "captures" / "qa_exfil_ship.png"
ALT = ROOT / "tests" / "artifacts" / "deployment.png"

INK = (6, 10, 12)


def load_font(size: int, weight: int) -> ImageFont.FreeTypeFont:
    path = FONT_DIR / "Sora-Variable.ttf"
    font = ImageFont.truetype(str(path), size)
    if weight:
        try:
            font.set_variation_by_axes([weight])
        except Exception:  # FreeType without variable-font support
            pass
    return font


def cover(source: Path, size: tuple[int, int], name: str) -> None:
    w, h = size
    img = Image.open(source).convert("RGB")

    # Crop out the HUD bands at the frame edges, keeping the ship/beam/tower subjects.
    box = (round(img.width * 0.20), round(img.height * 0.21),
           round(img.width * 0.80), round(img.height * 0.82))
    img = img.crop(box)

    # scale to fill the card, then centre-crop
    scale = max(w / img.width, h / img.height)
    img = img.resize((max(w, round(img.width * scale)), max(h, round(img.height * scale))), Image.LANCZOS)
    left = (img.width - w) // 2
    top = (img.height - h) // 2
    img = img.crop((left, top, left + w, top + h))

    # legibility: overall wash, bottom scrim, corner vignette
    img = Image.blend(img, Image.new("RGB", (w, h), INK), 0.20)

    scrim = Image.new("L", (1, h), 0)
    for y in range(h):
        t = y / max(h - 1, 1)
        scrim.putpixel((0, y), int(255 * min(1.0, max(0.0, (t - 0.26) / 0.74) ** 1.45) * 0.99))
    img = Image.composite(Image.new("RGB", (w, h), INK), img, scrim.resize((w, h)))

    vignette = Image.new("L", (w, h), 0)
    vd = ImageDraw.Draw(vignette)
    vd.ellipse([-w * 0.35, -h * 0.45, w * 1.35, h * 1.35], fill=255)
    vignette = vignette.filter(ImageFilter.GaussianBlur(round(min(w, h) * 0.12)))
    img = Image.composite(img, Image.new("RGB", (w, h), INK), vignette)

    draw = ImageDraw.Draw(img)
    pad = round(w * 0.055)
    title_size = round(h * 0.155)
    kicker_size = max(round(h * 0.030), 9)
    tag_size = max(round(h * 0.036), 10)
    title = load_font(title_size, 700)
    kicker = load_font(kicker_size, 600)
    tag = load_font(tag_size, 400)

    # stack from the bottom: tagline, then title, then kicker + accent rule
    tag_baseline = h - pad
    title_baseline = tag_baseline - round(tag_size * 1.75)
    kicker_baseline = title_baseline - round(title_size * 1.02)

    draw.text((pad, tag_baseline), TAGLINE, font=tag, fill=(200, 218, 214), anchor="ls")

    tracking = round(title_size * 0.04)
    x = pad
    for ch in TITLE:
        draw.text((x, title_baseline), ch, font=title, fill=(240, 247, 245), anchor="ls")
        x += draw.textlength(ch, font=title) + tracking

    draw.text((pad, kicker_baseline), KICKER, font=kicker, fill=(94, 226, 196), anchor="ls")
    rule_y = kicker_baseline - round(kicker_size * 1.15)
    draw.rectangle([pad, rule_y, pad + round(w * 0.18), rule_y + max(2, round(h * 0.005))],
                   fill=(54, 132, 115))

    OUT.mkdir(parents=True, exist_ok=True)
    target = OUT / name
    img.save(target, optimize=True)
    print(f"{target.relative_to(ROOT)}  {img.width}x{img.height}  {target.stat().st_size // 1024} KB")


def main() -> int:
    source = HERO if HERO.exists() else ALT
    if not source.exists():
        print(f"No capture found at {HERO} or {ALT}", file=sys.stderr)
        return 1
    cover(source, (630, 500), "cover_630x500.png")
    cover(source, (1200, 630), "banner_1200x630.png")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
