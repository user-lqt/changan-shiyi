"""Small cached textures for the workshop's soft light and polished mirror face."""
from pathlib import Path
import numpy as np
from PIL import Image, ImageFilter, ImageOps

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/images/ch1_workshop'
OUT.mkdir(parents=True, exist_ok=True)

y, x = np.mgrid[0:96, 0:512]
u, v = x / 511, (y / 95 - .5) * 2
profile = np.exp(-(v * 2.2) ** 2) * .34 + np.exp(-(v * 9) ** 2) * .26
envelope = np.clip(u * 12, 0, 1) * np.clip((1 - u) * 8, 0, 1)
rgba = np.ones((96, 512, 4), dtype=np.float32)
rgba[:, :, :3] *= (1, .88, .62)
rgba[:, :, 3] = profile * envelope
Image.fromarray((rgba * 255).astype('uint8')).save(OUT / 'light-ribbon.png')

y, x = np.mgrid[0:192, 0:192]
distance = np.sqrt(((x - 95.5) / 96) ** 2 + ((y - 95.5) / 96) ** 2)
rgba = np.ones((192, 192, 4), dtype=np.float32)
rgba[:, :, 3] = np.maximum(0, np.exp(-distance ** 2 * 5) - np.exp(-5))
Image.fromarray((rgba * 255).astype('uint8')).save(OUT / 'light-halo.png')

size = 384
y, x = np.mgrid[0:size, 0:size]
xx, yy = (x - size / 2) / (size / 2), (y - size / 2) / (size / 2)
radius = np.hypot(xx, yy)
rng = np.random.default_rng(761)
brush = rng.normal(0, .007, (size, size))
reflection = Image.open(ROOT / 'assets/images/workshop.png').convert('RGB')
reflection = ImageOps.mirror(reflection.crop((50, 90, 1000, 1000))).resize((size, size)).filter(ImageFilter.GaussianBlur(12))
metal = np.asarray(reflection, dtype=np.float32) / 255 * .25
shade = np.clip(.54 - xx * .10 - yy * .11, .15, .85)
metal += shade[..., None] * np.array((.88, .83, .59))
metal += (np.exp(-((xx + yy * .7 + .3) / .18) ** 2) * .20)[..., None]
metal += brush[..., None]
rim = np.clip((radius - .91) / .09, 0, 1)[..., None]
metal = metal * (1 - rim) + np.array((.42, .35, .20)) * rim
alpha = np.clip((1 - radius) * size / 2, 0, 1)
rgba = np.dstack((np.clip(metal, 0, 1), alpha))
Image.fromarray((rgba * 255).astype('uint8')).save(OUT / 'mirror-face.png')
print('Saved light ribbon, radial halo and softly reflected bronze mirror face.')
