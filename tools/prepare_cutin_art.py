"""Extract generated cut-in layers and remove residual green spill at their edges."""
from pathlib import Path
import shutil
import subprocess
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[1]
for source_name, target_name in (
    ("su", "su"), ("kang", "kang"), ("title", "title"), ("retort-title", "retort_title")
):
    source = ROOT / f"output/imagegen/ch2-cutin-{source_name}.png"
    target = ROOT / f"assets/images/ch2_cutin_{target_name}.png"
    subprocess.run(
        [sys.executable, str(ROOT / "tools/key_portrait.py"), str(source), str(target), "1024"],
        check=True,
    )
    rgba = np.asarray(Image.open(target).convert("RGBA")).astype(np.float32).copy()
    red, green, blue, alpha = (rgba[..., index] for index in range(4))
    excess = green - np.maximum(red, blue)
    # Saturated screen green can remain between fine hair strands. Remove its
    # coverage, then suppress spill only on thin edges, retaining teal clothing.
    screen_green = (excess > 35) & (green > 95)
    alpha[screen_green] *= np.clip((85 - excess[screen_green]) / 50, 0, 1)
    edge_distance = ndimage.distance_transform_edt(alpha > 80)
    edge = (edge_distance < 5) & (excess > 10)
    green[edge] = np.maximum(red, blue)[edge]
    rgba[..., 1], rgba[..., 3] = green, alpha
    Image.fromarray(rgba.clip(0, 255).astype(np.uint8)).save(target, optimize=True)
    print(f"Prepared {target.name}")

shutil.copy2(
    ROOT / "output/imagegen/ch2-cutin-background.png",
    ROOT / "assets/images/ch2_cutin_background.png",
)
