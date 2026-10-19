"""Prepare the approved chapter-seven player sprite, preserving generated alpha."""
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage


ROOT = Path(__file__).resolve().parents[1]
source = ROOT / "output/imagegen/ch7/player-sprite-keyed.png"
target = ROOT / "assets/images/player_su.png"
image = Image.open(source).convert("RGBA")
pixels = np.array(image)
alpha = pixels[..., 3]
labels, count = ndimage.label(alpha > 32)
if not count:
    raise ValueError("Player image has no visible foreground")
sizes = np.bincount(labels.ravel())
sizes[0] = 0
body = labels == sizes.argmax()
# Keep the original antialiasing around the body; discard detached stray pixels.
keep = ndimage.binary_dilation(body, iterations=3)
pixels[..., 3] = np.where(keep, alpha, 0)
sprite = Image.fromarray(pixels)
bounds = sprite.getchannel("A").getbbox()
sprite = sprite.crop(bounds)
sprite.thumbnail((112, 240), Image.Resampling.LANCZOS)
canvas = Image.new("RGBA", (128, 256))
canvas.alpha_composite(sprite, ((128 - sprite.width) // 2, (256 - sprite.height) // 2))
canvas.save(target, optimize=True)
print(f"Prepared {target.name}: {canvas.size}, body {sprite.size}, alpha preserved")
