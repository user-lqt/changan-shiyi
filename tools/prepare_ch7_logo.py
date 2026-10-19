"""Trim the generated traditional-character logo and preserve its transparent edge."""
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
image = Image.open(ROOT / "output/imagegen/ch7/mirror-moon-logo-ai.png").convert("RGBA")
alpha = image.getchannel("A")
# Ignore the almost invisible haze when sizing the emblem for the game side panel.
box = alpha.point(lambda value: 255 if value > 96 else 0).getbbox()
if not box:
    raise ValueError("Logo contains no visible foreground")
padding = 28
box = (max(0, box[0] - padding), max(0, box[1] - padding),
       min(image.width, box[2] + padding), min(image.height, box[3] + padding))
image = image.crop(box)
image.thumbnail((1024, 768), Image.Resampling.LANCZOS)
image.save(ROOT / "assets/images/ch7_mirror_moon_logo.png", optimize=True)
print(f"Prepared traditional logo: {image.size}, transparent alpha retained")
