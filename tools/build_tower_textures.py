"""Deterministic small material textures for the seven-storey tower."""
from pathlib import Path
import random
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets' / 'images' / 'tower'
OUT.mkdir(parents=True, exist_ok=True)
rng = random.Random(617)

brick = Image.new('RGB', (1024, 1024), '#656660')
d = ImageDraw.Draw(brick)
for row in range(8):
    for col in range(-1, 5):
        x, y = col * 256 + (128 if row % 2 else 0), row * 128
        v = rng.randrange(-8, 9)
        d.rounded_rectangle((x+3, y+3, x+253, y+125), radius=2,
                            fill=(143+v, 140+v, 128+v), outline=(154+v, 150+v, 139+v), width=2)

wood = Image.new('RGB', (1024,1024), '#78543a')
d = ImageDraw.Draw(wood)
for x in range(1024):
    v = rng.randrange(-5,6)
    for y in range(0, 1024, 4):
        xx = x+int(1.8*np.sin(y*.014+x*.13))
        d.line((xx,y,xx,y+4), fill=(121+v,84+v,57+v))
for x in (255, 511, 767, 1023): d.line((x, 0, x, 1024), fill='#493627', width=3)
for _ in range(24):
    x, y = rng.randrange(1024), rng.randrange(1024)
    d.line((x,y,x+rng.randrange(-3,4), min(1023,y+rng.randrange(50,350))), fill='#5d422e', width=1)

stone = Image.new('RGB',(1024,1024),'#73776f')
d = ImageDraw.Draw(stone)
for y in range(4):
    for x in range(4):
        v=rng.randrange(-6,7)
        d.rectangle((x*256+2,y*256+2,x*256+253,y*256+253),fill=(156+v,153+v,139+v))

noise_rng = np.random.default_rng(617)
for name, image in [('brick', brick), ('wood', wood), ('stone', stone)]:
    color = np.asarray(image).astype(float)
    color += noise_rng.normal(0, 1.9, (1024, 1024, 1))
    color = np.clip(color, 0, 255)
    Image.fromarray(color.astype('uint8')).save(OUT/f'{name}.png')
    if name in ('wood', 'stone'):
        grain = np.asarray(Image.fromarray(color.astype('uint8')).convert('L')).astype(float)
        grain = np.clip((grain-grain.mean())*1.8+224, 170, 255).astype('uint8')
        Image.fromarray(grain).convert('RGB').save(OUT/f'{name}_detail.png')
    # A wrapped normal map keeps joints and grain visible under grazing light.
    height = np.asarray(Image.fromarray(color.astype('uint8')).convert('L').filter(ImageFilter.GaussianBlur(.7))).astype(float)/255
    dx = np.roll(height, -1, axis=1)-np.roll(height, 1, axis=1)
    dy = np.roll(height, -1, axis=0)-np.roll(height, 1, axis=0)
    normal = np.stack((-dx*3, dy*3, np.ones_like(dx)), axis=2)
    normal /= np.linalg.norm(normal, axis=2, keepdims=True)
    Image.fromarray(np.clip((normal*.5+.5)*255, 0, 255).astype('uint8')).save(OUT/f'{name}_normal.png')
print('Tower albedo and normal maps written to', OUT)
