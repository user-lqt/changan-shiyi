"""Removes a chroma-green background from a character portrait and crops it to the figure.

Usage: python -I tools/key_portrait.py <in.png> <out.png> [height]
Background connected to the border is keyed, plus enclosed near-pure-green gaps; pale green
props held by the character (e.g. a celadon shard) survive. Edges get a soft alpha and green spill removal.
"""
import sys
import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

src, dst = sys.argv[1], sys.argv[2]
target_h = int(sys.argv[3]) if len(sys.argv) > 3 else 0

im = Image.open(src).convert("RGB")
a = np.asarray(im).astype(np.float32)
r, g, b = a[..., 0], a[..., 1], a[..., 2]
# Greenness: how far green dominates the other two channels.
green = g - np.maximum(r, b)
strong = green > 70
# Keep only background regions touching the border.
labels, _ = ndimage.label(strong)
border = set(np.unique(np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]]))) - {0}
bg = np.isin(labels, list(border))
# Enclosed gaps (under an arm, between fingers) are keyed too when they are near-pure screen
# green; pale props such as celadon are much less saturated and stay.
pure = (g > 200) & (r < 90) & (b < 90)
for lab in set(np.unique(labels)) - border - {0}:
    region = labels == lab
    if pure[region].mean() > 0.6:
        bg |= region
bg = ndimage.binary_closing(bg, iterations=2)
# Soft edge: fade alpha across a thin band around the background.
inside = ndimage.distance_transform_edt(~bg)
soft = np.clip((green - 20) / 50.0, 0, 1)
alpha = np.where(bg, 0.0, 1.0)
band = (inside < 3) & ~bg
alpha[band] = 1.0 - soft[band]
alpha = np.asarray(Image.fromarray((alpha * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.7))).astype(np.float32) / 255
alpha[bg & (inside == 0)] = 0
# Spill suppression near the edge only.
near = inside < 6
lim = np.maximum(r, b)
g2 = np.where(near & (g > lim), lim + (g - lim) * 0.25, g)
rgba = np.dstack([r, g2, b, alpha * 255]).clip(0, 255).astype(np.uint8)
out = Image.fromarray(rgba)
bbox = out.split()[3].point(lambda v: 255 if v > 8 else 0).getbbox()
out = out.crop((max(0, bbox[0] - 4), max(0, bbox[1] - 4), min(out.width, bbox[2] + 4), min(out.height, bbox[3] + 4)))
if target_h and out.height > target_h:
    out = out.resize((round(out.width * target_h / out.height), target_h), Image.LANCZOS)
out.save(dst, optimize=True)
print("KEYED", dst, out.size)
