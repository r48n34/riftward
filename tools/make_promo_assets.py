"""Builds the RIFTWARD advertisement/promo image set from real in-engine captures.

Usage:
    python tools/make_promo_assets.py

Outputs (release/promo/):
    hero_1920x1080.png       gameplay + wordmark        (X/Twitter, Reddit, itch banner)
    vista_1920x1080.png      world vista + lockup       (wide / YouTube thumbnail safe)
    og_1200x630.png          link-preview card          (Discord, X, itch embed)
    square_1080x1080.png     square social              (Instagram, Reddit square)
    vertical_1080x1920.png   stories / shorts           (TikTok, Reels, Shorts)
    grid_1080x1080.png       four-feature grid          (scroll-stopping summary)
    biome_1920x1080.png      verdant biome + line
    raw/                     untouched captures, renamed for upload

Everything is composed from captures already produced by the game, so no invented
content ever appears in an advert.
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "release" / "promo"
RAW = OUT / "raw"

FONTS = ROOT / "assets" / "fonts"
INK = (6, 10, 12)
PAPER = (240, 247, 245)
MINT = (94, 226, 196)
DIM = (168, 190, 186)

HERO = ROOT / "captures" / "qa_exfil_ship.png"          # FPS + dropship + squad, dusk
VISTA = ROOT / "features" / "world" / "preview_shots" / "shot_00_overview.png"
VERDANT = ROOT / "features" / "world" / "preview_shots" / "shot_04_exfil_pad.png"
COMBAT = ROOT / "tests" / "artifacts" / "deployment.png"

# HUD sits in the outer bands of every gameplay capture; crop inside it.
CROP = (0.26, 0.21, 0.78, 0.74)

UI = ROOT / "ui" / "_screenshots"

RAW_SOURCES = [
    (HERO, "gameplay_01_exfil_dusk.png"),
    (ROOT / "captures" / "qa_hud_aim_sight.png", "gameplay_02_ads.png"),
    (ROOT / "captures" / "qa_enemy_health_bar.png", "gameplay_03_combat.png"),
    (COMBAT, "gameplay_04_deployment.png"),
    (VISTA, "world_01_overview.png"),
    (ROOT / "features" / "world" / "preview_shots" / "shot_05_ashen_canyon.png", "world_02_ashen_canyon.png"),
    (VERDANT, "world_03_verdant_pad.png"),
    (ROOT / "features" / "world" / "preview_shots" / "shot_02_warden_outpost.png", "world_04_outpost.png"),
]


# --------------------------------------------------------------------------- type
def font(name: str, size: int, weight: int = 0) -> ImageFont.FreeTypeFont:
    path = FONTS / name
    f = ImageFont.truetype(str(path), size)
    if weight:
        try:
            f.set_variation_by_axes([weight])
        except Exception:
            pass
    return f


def sora(size: int, weight: int = 700) -> ImageFont.FreeTypeFont:
    return font("Sora/Sora-Variable.ttf", size, weight)


def inter(size: int, weight: int = 400) -> ImageFont.FreeTypeFont:
    return font("Inter/Inter-Variable.ttf", size, weight)


def mono(size: int) -> ImageFont.FreeTypeFont:
    return font("JetBrainsMono/JetBrainsMono-Regular.ttf", size)


def tracked(draw: ImageDraw.ImageDraw, xy, text: str, f: ImageFont.FreeTypeFont, fill, tracking: float,
            anchor: str = "ls") -> float:
    """Draw text with letter-spacing. Returns total width."""
    x, y = xy
    for ch in text:
        draw.text((x, y), ch, font=f, fill=fill, anchor=anchor)
        x += draw.textlength(ch, font=f) + tracking
    return x - xy[0] - tracking


def text_width(draw, text, f, tracking: float = 0.0) -> float:
    return sum(draw.textlength(c, font=f) for c in text) + tracking * max(len(text) - 1, 0)


# --------------------------------------------------------------------------- image
def fill(src: Path, size, focus=(0.5, 0.5), wash=0.20, crop=None):
    w, h = size
    img = Image.open(src).convert("RGB")
    if crop:
        img = img.crop((round(img.width * crop[0]), round(img.height * crop[1]),
                        round(img.width * crop[2]), round(img.height * crop[3])))
    scale = max(w / img.width, h / img.height)
    img = img.resize((max(w, round(img.width * scale)) + 1, max(h, round(img.height * scale)) + 1), Image.LANCZOS)
    left = round((img.width - w) * focus[0])
    top = round((img.height - h) * focus[1])
    img = img.crop((left, top, left + w, top + h))
    return Image.blend(img, Image.new("RGB", (w, h), INK), wash)


def scrim(img, direction="bottom", strength=0.95, start=0.32, power=1.5):
    w, h = img.size
    mask = Image.new("L", (1, h if direction in ("bottom", "top") else w), 0)
    n = mask.height if mask.width == 1 else mask.width
    for i in range(n):
        t = i / max(n - 1, 1)
        if direction == "top":
            t = 1.0 - t
        v = min(1.0, max(0.0, (t - start) / max(1.0 - start, 0.001)) ** power)
        if mask.width == 1:
            mask.putpixel((0, i), int(255 * v * strength))
        else:
            mask.putpixel((i, 0), int(255 * v * strength))
    mask = mask.resize((w, h))
    return Image.composite(Image.new("RGB", (w, h), INK), img, mask)


def vignette(img, strength=0.55):
    w, h = img.size
    m = Image.new("L", (w, h), 0)
    ImageDraw.Draw(m).ellipse([-w * 0.30, -h * 0.40, w * 1.30, h * 1.40], fill=255)
    m = m.filter(ImageFilter.GaussianBlur(round(min(w, h) * 0.10)))
    if strength < 1.0:
        m = m.point(lambda v: int(255 - (255 - v) * strength))
    return Image.composite(img, Image.new("RGB", (w, h), INK), m)


def save(img, name):
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / name
    img.save(path, optimize=True)
    print(f"  {name:26s} {img.width}x{img.height}  {path.stat().st_size // 1024} KB")


# --------------------------------------------------------------------------- assets
def hero():
    w, h = 1920, 1080
    img = scrim(fill(HERO, (w, h), focus=(0.5, 0.5), wash=0.14, crop=CROP), "bottom", 1.0, 0.52, 2.2)
    img = scrim(img, "top", 0.35, 0.86, 1.6)
    d = ImageDraw.Draw(img)

    pad = round(w * 0.052)
    kicker = inter(21, 600)
    title = sora(126, 700)
    tag = inter(34, 400)
    micro = mono(18)

    tracked(d, (pad, h - 214), "FIRST-PERSON EXTRACTION SHOOTER", kicker, MINT, 5)
    tracked(d, (pad, h - 96), "RIFTWARD", title, PAPER, round(126 * 0.035))
    d.text((pad, h - 34), "Drop into the Reach. Build what survives.", font=tag, fill=(212, 226, 222), anchor="ls")

    d.text((w - pad, h - 34), "WINDOWS  ·  FREE  ·  SINGLEPLAYER", font=micro, fill=DIM, anchor="rs")
    return img


def vista():
    w, h = 1920, 1080
    img = scrim(fill(VISTA, (w, h), focus=(0.5, 0.5), wash=0.10), "bottom", 0.88, 0.52, 1.8)
    img = scrim(img, "top", 0.55, 0.70, 1.6)
    d = ImageDraw.Draw(img)
    pad = round(w * 0.052)
    tracked(d, (pad, h - round(h * 0.085)), "RIFTWARD", sora(84, 700), PAPER, 3)
    d.text((pad, h - round(h * 0.045)), "1.8 km of seeded alien frontier. No safe route.", font=inter(34), fill=(206, 222, 218), anchor="ls")
    return img


def og():
    w, h = 1200, 630
    img = scrim(fill(VISTA, (w, h), focus=(0.5, 0.45), wash=0.14), "bottom", 0.94, 0.34, 1.6)
    d = ImageDraw.Draw(img)
    pad = round(w * 0.06)
    tracked(d, (pad, h - round(h * 0.14)), "RIFTWARD", sora(76, 700), PAPER, 3)
    d.text((pad, h - round(h * 0.075)), "Drop into the Reach. Build what survives.", font=inter(28), fill=(206, 222, 218), anchor="ls")
    return img


def square():
    w, h = 1080, 1080
    img = scrim(fill(HERO, (w, h), focus=(0.5, 0.5), wash=0.16, crop=CROP), "bottom", 1.0, 0.55, 2.0)
    img = scrim(img, "top", 0.30, 0.88, 1.6)
    d = ImageDraw.Draw(img)
    pad = round(w * 0.075)
    tracked(d, (pad, h - 186), "RIFTWARD", sora(104, 700), PAPER, 3)
    d.text((pad, h - 96), "Extract. Or lose it.", font=sora(42, 600), fill=MINT, anchor="ls")
    d.text((pad, h - 40), "FIRST-PERSON EXTRACTION SHOOTER", font=mono(16), fill=DIM, anchor="ls")
    return img


def vertical():
    w, h = 1080, 1920
    img = scrim(fill(HERO, (w, h), focus=(0.5, 0.45), wash=0.18, crop=CROP), "bottom", 1.0, 0.55, 1.8)
    img = scrim(img, "top", 0.55, 0.84, 1.6)
    d = ImageDraw.Draw(img)
    pad = round(w * 0.075)
    tracked(d, (pad, round(h * 0.115)), "RIFTWARD", sora(88, 700), PAPER, 3)

    tracked(d, (pad, h - 300), "GREED", sora(84, 700), PAPER, 4)
    tracked(d, (pad, h - 212), "VERSUS", sora(84, 700), MINT, 4)
    tracked(d, (pad, h - 124), "THE COLLAPSE", sora(84, 700), PAPER, 4)
    d.text((pad, h - 52), "18 minutes. One dropship. No second chance.", font=inter(28), fill=(206, 222, 218), anchor="ls")
    return img


def biome():
    w, h = 1920, 1080
    img = scrim(fill(VERDANT, (w, h), focus=(0.5, 0.45), wash=0.10), "bottom", 0.90, 0.48, 1.7)
    img = scrim(img, "top", 0.40, 0.80, 1.4)
    d = ImageDraw.Draw(img)
    pad = round(w * 0.052)
    tracked(d, (pad, h - round(h * 0.10)), "THREE BIOMES. FOUR MAPS.", sora(68, 700), PAPER, 2)
    d.text((pad, h - round(h * 0.055)), "Verdant Basin · Ashen Canyons · Glass Flats", font=inter(32), fill=(206, 222, 218), anchor="ls")
    return img


def grid():
    s = 1080
    pad, gutter = 44, 8
    img = Image.new("RGB", (s, s), INK)
    d = ImageDraw.Draw(img)

    tiles = [
        (UI / "02_hub.png", "CONTRACTS", "18 minutes, four difficulty tiers"),
        (UI / "05_skills.png", "DISCIPLINES", "12 abilities, 4 ultimates"),
        (UI / "06_squad.png", "WARDENS", "4 companions, 2 active"),
        (UI / "07_outpost.png", "OUTPOST", "8 modules, 3 tiers each"),
    ]
    tracked(d, (pad, pad + 34), "RIFTWARD", sora(40, 700), PAPER, 2)
    d.text((s - pad, pad + 34), "WHAT'S IN THE BUILD", font=mono(17), fill=MINT, anchor="rs")

    top = pad + 70
    cell = (s - pad * 2 - gutter) // 2
    tile_h = cell - 108
    for i, (src, label, sub) in enumerate(tiles):
        cx = pad + (i % 2) * (cell + gutter)
        cy = top + (i // 2) * (tile_h + 108 + gutter)
        img.paste(fill(src, (cell, tile_h), focus=(0.5, 0.15), wash=0.06), (cx, cy))
        d = ImageDraw.Draw(img)
        d.text((cx, cy + tile_h + 34), label, font=sora(30, 600), fill=PAPER, anchor="ls")
        d.text((cx, cy + tile_h + 68), sub, font=inter(21), fill=DIM, anchor="ls")
    return img


def raw():
    RAW.mkdir(parents=True, exist_ok=True)
    for src, name in RAW_SOURCES:
        if not src.exists():
            print(f"  ! missing {src.name}")
            continue
        Image.open(src).save(RAW / name, optimize=True)
    print(f"  raw/                     {len(list(RAW.glob('*.png')))} captures")


README_MEDIA = ROOT / "media"
README_FILES = [
    (OUT / "hero_1920x1080.png", "hero.png", 1600),
    (OUT / "vista_1920x1080.png", "vista.png", 1600),
    (RAW / "gameplay_01_exfil_dusk.png", "gameplay.png", 1600),
    (RAW / "world_01_overview.png", "world.png", 1600),
    (OUT / "grid_1080x1080.png", "grid.png", 1080),
]


def readme_media():
    """Git-tracked copies for README embedding (release/ is git-ignored)."""
    README_MEDIA.mkdir(parents=True, exist_ok=True)
    for src, name, max_w in README_FILES:
        if not src.exists():
            print(f"  ! missing {src.name}")
            continue
        img = Image.open(src).convert("RGB")
        if img.width > max_w:
            img = img.resize((max_w, round(img.height * max_w / img.width)), Image.LANCZOS)
        target = README_MEDIA / name
        img.save(target, optimize=True)
        print(f"  media/{name:21s} {img.width}x{img.height}  {target.stat().st_size // 1024} KB")


def main() -> int:
    print("Building promo set from in-engine captures:")
    save(hero(), "hero_1920x1080.png")
    save(vista(), "vista_1920x1080.png")
    save(og(), "og_1200x630.png")
    save(square(), "square_1080x1080.png")
    save(vertical(), "vertical_1080x1920.png")
    save(biome(), "biome_1920x1080.png")
    save(grid(), "grid_1080x1080.png")
    raw()
    print("Readme media (tracked):")
    readme_media()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
