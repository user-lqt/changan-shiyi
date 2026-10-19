"""Reuse the boss's established half-hidden face as the tower mirror reflection."""
from pathlib import Path

import numpy as np
from PIL import Image, ImageEnhance

ROOT = Path(__file__).resolve().parents[1]
source = Image.open(ROOT / "assets/images/boss_mirror.png").convert("RGBA")
portrait = source.crop((245, 225, 655, 635)).resize((512, 512), Image.Resampling.LANCZOS)
portrait = ImageEnhance.Color(portrait).enhance(.55)
a = np.asarray(portrait).copy()
y, x = np.mgrid[0:512, 0:512]
radius = np.sqrt(((x - 255.5) / 256) ** 2 + ((y - 255.5) / 256) ** 2)
feather = np.clip((.98 - radius) / .16, 0, 1)
feather = feather * feather * (3 - 2 * feather)
a[..., 3] = (a[..., 3] * feather).astype(np.uint8)
Image.fromarray(a).save(ROOT / "assets/images/tower/spirit_reflection.png", optimize=True)
print("Prepared 512px reflection from the existing boss portrait; eyes remain hidden.")
