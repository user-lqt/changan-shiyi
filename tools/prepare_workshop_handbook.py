"""Extract the GPT-image2 artisan notebook for tabletop compositing."""
from pathlib import Path
import shutil
import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'art/ch1_handbook/handbook-original.png'
if not SOURCE.exists():
    SOURCE = ROOT.parent / 'output/imagegen/ch1-wen-handbook.png'
OUT = ROOT / 'assets/images/ch1_workshop'
raw = Image.open(SOURCE).convert('RGB')
pixels = np.asarray(raw).astype(np.float32)
r, g, b = pixels[..., 0], pixels[..., 1], pixels[..., 2]
magenta = np.minimum(r, b) - g
background = (magenta > 65) & (r > 110) & (b > 110)
alpha = np.clip((65 - magenta) / 45, 0, 1)
alpha[background] = 0
inside = ndimage.distance_transform_edt(~background)
edge = inside < 5
pixels[..., 0] = np.where(edge & (r > g + 40), np.minimum(r, g + 50), r)
pixels[..., 2] = np.where(edge & (b > g + 30), np.minimum(b, g + 25), b)
alpha = np.asarray(Image.fromarray((alpha * 255).astype('uint8')).filter(ImageFilter.GaussianBlur(.35)))
result = Image.fromarray(np.dstack((pixels, alpha)).clip(0, 255).astype('uint8'))
box = result.getbbox()
result = result.crop((box[0] - 2, box[1] - 2, box[2] + 2, box[3] + 2))
result.thumbnail((1024, 700), Image.Resampling.LANCZOS)
OUT.mkdir(parents=True, exist_ok=True)
result.save(OUT / 'wen-handbook.png', optimize=True)
art = ROOT / 'art/ch1_handbook'
art.mkdir(parents=True, exist_ok=True)
if SOURCE.resolve() != (art / 'handbook-original.png').resolve():
    shutil.copy2(SOURCE, art / 'handbook-original.png')
if (ROOT / 'tmp/ch1-handbook-prompt.txt').exists():
    shutil.copy2(ROOT / 'tmp/ch1-handbook-prompt.txt', art / 'prompt.txt')
(art / '.gdignore').write_text('', encoding='utf-8')
print('Saved', OUT / 'wen-handbook.png', result.size)
