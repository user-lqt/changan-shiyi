"""Prepare the generated prop, portrait, map sprites and poetry card for the game."""
from pathlib import Path
import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "art/oct19-refresh"
OUT = ROOT / "assets/images"


def cutout(path):
    image = Image.open(path).convert("RGBA")
    pixels = np.array(image).astype(np.float32)
    r, g, b = (pixels[..., i] for i in range(3))
    magenta = np.minimum(r, b) - g
    background = (magenta > 65) & (r > 110) & (b > 110)
    alpha = np.minimum(pixels[..., 3], np.clip((65 - magenta) / 45, 0, 1) * 255)
    # Remove chroma spill on the silhouette, retain the original generated alpha.
    edge = ndimage.distance_transform_edt(~background) < 4
    pixels[..., 0] = np.where(edge & (r > g + 40), np.minimum(r, g + 45), r)
    pixels[..., 2] = np.where(edge & (b > g + 30), np.minimum(b, g + 25), b)
    pixels[..., 3] = alpha
    return Image.fromarray(pixels.clip(0, 255).astype("uint8"))


def save_trimmed(image, target, limit):
    box = image.getchannel("A").point(lambda a: 255 if a > 16 else 0).getbbox()
    image = image.crop(box)
    image.thumbnail(limit, Image.Resampling.LANCZOS)
    target.parent.mkdir(parents=True, exist_ok=True)
    image.save(target, optimize=True)
    print(target.relative_to(ROOT), image.size)


def main():
    lamp = cutout(ART / "lamp-original.png")
    # Split the flame from the bowl so it can lean towards the hidden shard.
    body = lamp.copy()
    a = np.array(body)
    a[:407, :, 3] = 0
    body = Image.fromarray(a)
    save_trimmed(body, OUT / "ch1_workshop/bronze-oil-lamp.png", (512, 360))
    flame = lamp.crop((179, 250, 256, 411))
    save_trimmed(flame, OUT / "ch1_workshop/oil-flame.png", (100, 200))
    save_trimmed(cutout(ART / "barkeep-original.png"), OUT / "npc_jiujia.png", (700, 1200))
    sheet = cutout(ART / "map-original.png")
    w, h = sheet.size
    for i, chapter in enumerate(["ch1", "ch2", "ch3", "ch4", "ch5", "ch6", "ch7", "finale"]):
        cell = sheet.crop((i % 4 * w // 4, i // 4 * h // 2, (i % 4 + 1) * w // 4, (i // 4 + 1) * h // 2))
        save_trimmed(cell, OUT / f"map/{chapter}.png", (430, 430))
    save_trimmed(cutout(ART / "poetry-ui-original.png"), OUT / "ui/poetry-card.png", (512, 880))


if __name__ == "__main__":
    main()
