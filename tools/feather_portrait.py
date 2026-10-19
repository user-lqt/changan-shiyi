"""Cut out a portrait that came back on a dark glowing background (no chroma key possible).

Used for 镜魅, who is only ever drawn over the dark night battle field: dark pixels fade to
transparent (dark hair over a dark field looks the same), the soft glow stays as a faint
moonlight aura, and a wide elliptical feather removes the frame edges.
Usage: python tools/feather_portrait.py <src.png> <dst.png> [target_height]
"""
import sys

import numpy as np
from PIL import Image

src, dst = sys.argv[1], sys.argv[2]
target_h = int(sys.argv[3]) if len(sys.argv) > 3 else 0
img = Image.open(src).convert("RGB")
a = np.asarray(img).astype(np.float32) / 255.0
h, w = a.shape[:2]
yy, xx = np.mgrid[0:h, 0:w]
d = np.sqrt(((xx - w * 0.5) / (w * 0.5)) ** 2 + ((yy - h * 0.5) / (h * 0.5)) ** 2)
ellipse = np.clip((1.0 - d) / 0.3, 0.0, 1.0)
bright = a.max(axis=2)
# Figure pixels are bright or saturated; the backdrop glow is a dim, flat grey.
sat = bright - a.min(axis=2)
body = np.clip((bright - 0.22) / 0.25, 0.0, 1.0)
colour = np.clip((sat - 0.06) / 0.12, 0.0, 1.0)
alpha = ellipse * np.clip(np.maximum(body, colour) * 0.95 + 0.05, 0.0, 1.0)
alpha = np.where(bright < 0.12, 0.0, alpha)
out = np.dstack([a, alpha]) * 255.0
res = Image.fromarray(out.astype(np.uint8))
if target_h:
    res = res.resize((int(w * target_h / h), target_h), Image.LANCZOS)
res.save(dst)
print("saved", dst, res.size)
