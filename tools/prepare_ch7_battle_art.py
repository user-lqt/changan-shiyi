"""Prepare chapter-seven AI artwork, preserving source images and generated alpha.

The generation prompts and originals live in output/imagegen/ch7-battle-v2.
Only cropped, resized game textures are written to assets/images/ch7_battle.
"""
from pathlib import Path
import json

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "output/imagegen/ch7-battle-v2"
DEST = ROOT / "assets/images/ch7_battle"
SPRITES = ["crane", "diver", "lantern", "spirit", "wisp", "bell"]


def cutout(source: Image.Image) -> Image.Image:
    image = source.convert("RGBA")
    pixels = np.asarray(image).astype(np.float32)
    original_alpha = pixels[..., 3] / 255.0
    if np.mean(original_alpha < 0.05) > 0.2:
        # Preserve genuine alpha if the provider returned it.
        alpha = original_alpha
    else:
        r, g, b = (pixels[..., i] for i in range(3))
        greenness = g - np.maximum(r, b)
        alpha = np.clip((100.0 - greenness) / 80.0, 0.0, 1.0)
        # Remove the green contribution from antialiased edge pixels.
        pixels[..., 1] = np.where(alpha < 0.99, np.minimum(g, np.maximum(r, b)), g)
    mask = alpha > 0.25
    labels, count = ndimage.label(mask)
    if not count:
        raise ValueError("An enemy cell contains no visible sprite")
    sizes = np.bincount(labels.ravel())
    sizes[0] = 0
    keep_ids = np.flatnonzero(sizes >= max(12, sizes.max() * 0.003))
    keep = ndimage.binary_dilation(np.isin(labels, keep_ids), iterations=3)
    alpha *= keep
    pixels[..., 3] = alpha * 255.0
    output = Image.fromarray(np.clip(pixels, 0, 255).astype(np.uint8))
    bbox = Image.fromarray((alpha > 0.07).astype(np.uint8) * 255).getbbox()
    if not bbox:
        raise ValueError("An enemy cell became empty after keying")
    margin = 6
    crop = (max(0, bbox[0] - margin), max(0, bbox[1] - margin),
            min(output.width, bbox[2] + margin), min(output.height, bbox[3] + margin))
    output = output.crop(crop)
    output.thumbnail((296, 296), Image.Resampling.LANCZOS)
    return output


def moon_cutout(source: Image.Image) -> Image.Image:
    source = source.convert("RGB")
    luminance = np.asarray(source.convert("L"))
    labels, _ = ndimage.label(luminance > 35)
    sizes = np.bincount(labels.ravel())
    sizes[0] = 0
    mask = ndimage.binary_fill_holes(labels == sizes.argmax())
    yy, xx = np.where(mask)
    if len(xx) < source.width * source.height * 0.15:
        raise ValueError("Could not find the full lunar disc")
    centre = ((xx.min() + xx.max()) / 2, (yy.min() + yy.max()) / 2)
    radius = max(xx.max() - xx.min(), yy.max() - yy.min()) / 2
    y, x = np.indices(luminance.shape)
    alpha = np.clip(radius + 0.5 - np.hypot(x - centre[0], y - centre[1]), 0, 1)
    moon = source.convert("RGBA")
    moon.putalpha(Image.fromarray((alpha * 255).astype(np.uint8)))
    box = (round(centre[0] - radius - 3), round(centre[1] - radius - 3),
           round(centre[0] + radius + 4), round(centre[1] + radius + 4))
    moon = moon.crop(box)
    moon.thumbnail((616, 616), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (640, 640))
    canvas.alpha_composite(moon, ((640 - moon.width) // 2, (640 - moon.height) // 2))
    return canvas


def main() -> None:
    DEST.mkdir(parents=True, exist_ok=True)
    manifest = {"model": "gpt-image-2", "artwork": []}
    for name in ["rooftop-night", "bell-gallery-night", "mirror-realm-night"]:
        image = Image.open(SOURCE / f"{name}.png").convert("RGB")
        image.save(DEST / f"{name}.jpg", quality=94, subsampling=0)
        manifest["artwork"].append({"file": f"{name}.jpg", "size": image.size})
    moon = moon_cutout(Image.open(SOURCE / "full-moon.png"))
    moon.save(DEST / "moon.png", optimize=True)
    manifest["artwork"].append({"file": "moon.png", "size": moon.size})
    atlas = Image.open(SOURCE / "enemy-sprites.png")
    w, h = atlas.size
    for i, name in enumerate(SPRITES):
        x, y = i % 2, i // 2
        sprite = cutout(atlas.crop((round(x * w / 2), round(y * h / 3),
                                   round((x + 1) * w / 2), round((y + 1) * h / 3))))
        sprite.save(DEST / f"{name}.png", optimize=True)
        manifest["artwork"].append({"file": f"{name}.png", "size": sprite.size})
    (SOURCE / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    preview = Image.new("RGB", (1200, 800), "#0a1321")
    draw = ImageDraw.Draw(preview)
    for i, name in enumerate(SPRITES):
        sprite = Image.open(DEST / f"{name}.png")
        cx, cy = 200 + (i % 3) * 400, 200 + (i // 3) * 400
        preview.paste(sprite, (cx - sprite.width // 2, cy - sprite.height // 2), sprite)
        draw.text((cx - 35, cy + 165), name, fill="#dbc78a")
    preview.save(SOURCE / "sprite-preview.jpg", quality=95)
    print(json.dumps(manifest, ensure_ascii=False))


if __name__ == "__main__":
    main()
