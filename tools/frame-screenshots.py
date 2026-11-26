"""Ham ekran görüntülerini App Store tanıtım görsellerine çevirir (1290x2796, 6.9" iPhone için geçerli boyut).

Üstte büyük başlık (appstore/metadata.json > screenshots.captions), altta çerçeveli oyun görüntüsü.
Kullanım: python frame-screenshots.py <ham klasör> <çıktı klasörü>
"""
import json
import pathlib
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = pathlib.Path(__file__).resolve().parent.parent
META = json.loads((ROOT / "appstore" / "metadata.json").read_text(encoding="utf-8"))
W, H = 1290, 2796
INK = (31, 26, 23)
CREAM = (246, 236, 214)
RED = (195, 43, 35)
GOLD = (217, 165, 49)
LANG_DIRS = {"en-US": "en", "tr": "tr"}
FONT_CANDIDATES = [
    "/System/Library/Fonts/Supplemental/Georgia Bold.ttf",
    "/Library/Fonts/Georgia Bold.ttf",
    "C:/Windows/Fonts/georgiab.ttf",
]


def font(size):
    for path in FONT_CANDIDATES:
        if pathlib.Path(path).exists():
            return ImageFont.truetype(path, size)
    raise SystemExit("Georgia Bold bulunamadı")


def wrap(draw, text, fnt, width):
    lines, line = [], ""
    for word in text.split():
        trial = (line + " " + word).strip()
        if draw.textlength(trial, font=fnt) <= width or not line:
            line = trial
        else:
            lines.append(line)
            line = word
    lines.append(line)
    return lines


def sunburst(img, center, color, rays=28):
    draw = ImageDraw.Draw(img, "RGBA")
    import math
    r = 3000
    for i in range(rays):
        if i % 2:
            continue
        a0 = 2 * math.pi * i / rays
        a1 = 2 * math.pi * (i + 1) / rays
        draw.polygon([center, (center[0] + r * math.cos(a0), center[1] + r * math.sin(a0)),
                      (center[0] + r * math.cos(a1), center[1] + r * math.sin(a1))], fill=color)


def upper(text, locale):
    """Türkçede i -> İ, ı -> I (Python'un upper() işlevi i'yi I yapar)."""
    if locale.startswith("tr"):
        text = text.replace("i", "İ").replace("ı", "I")
    return text.upper()


def frame(raw_path, caption, out_path):
    canvas = Image.new("RGB", (W, H), RED)
    sunburst(canvas, (W // 2, 330), (255, 255, 255, 26))
    draw = ImageDraw.Draw(canvas)

    # Başlık: en çok 3 satır, sığana kadar küçülür.
    size = 112
    while True:
        fnt = font(size)
        lines = wrap(draw, caption, fnt, W - 160)
        if len(lines) <= 3 or size <= 70:
            break
        size -= 6
    line_h = int(size * 1.15)
    top = 120 + (3 - len(lines)) * line_h // 2
    for i, line in enumerate(lines):
        y = top + i * line_h
        tw = draw.textlength(line, font=fnt)
        x = (W - tw) / 2
        draw.text((x + 6, y + 7), line, font=fnt, fill=INK)
        draw.text((x, y), line, font=fnt, fill=CREAM, stroke_width=4, stroke_fill=INK)

    # Oyun görüntüsü: yuvarlak köşeli, kalın mürekkep çerçeve, gölge.
    shot = Image.open(raw_path).convert("RGB")
    shot_w = 1010
    shot_h = int(shot.height * shot_w / shot.width)
    shot = shot.resize((shot_w, shot_h), Image.LANCZOS)
    sx, sy = (W - shot_w) // 2, 560
    radius = 70
    mask = Image.new("L", (shot_w, shot_h), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, shot_w, shot_h), radius, fill=255)
    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle((sx + 18, sy + 24, sx + shot_w + 18, sy + shot_h + 24), radius + 14,
                                             fill=(0, 0, 0, 110))
    shadow = shadow.filter(ImageFilter.GaussianBlur(18))
    canvas.paste(shadow, (0, 0), shadow)
    border = 16
    draw = ImageDraw.Draw(canvas)
    draw.rounded_rectangle((sx - border, sy - border, sx + shot_w + border, sy + shot_h + border), radius + border,
                           fill=INK)
    draw.rounded_rectangle((sx - border + 6, sy - border + 6, sx + shot_w + border - 6, sy + shot_h + border - 6),
                           radius + border - 6, outline=GOLD, width=4)
    canvas.paste(shot, (sx, sy), mask)
    canvas.save(out_path, "PNG", optimize=True)


def main():
    raw_root, out_root = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
    scenes = META["screenshots"]["scenes"]
    for locale, captions in META["screenshots"]["captions"].items():
        lang = LANG_DIRS[locale]
        out_dir = out_root / locale
        out_dir.mkdir(parents=True, exist_ok=True)
        for index, (scene, caption) in enumerate(zip(scenes, captions), start=1):
            raw = raw_root / lang / f"{index:02d}-{scene}.png"
            if not raw.exists():
                print(f"eksik: {raw}")
                continue
            out = out_dir / f"{index:02d}-{scene}.png"
            frame(raw, upper(caption, locale), out)
            print(f"{out} ({W}x{H})")


if __name__ == "__main__":
    main()
