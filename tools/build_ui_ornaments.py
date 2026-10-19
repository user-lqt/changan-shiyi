"""Extract compact transparent ornaments from the approved GPT-image2 atlas."""
from pathlib import Path
import numpy as np
from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parent.parent
source = Image.open(ROOT / "output/imagegen/ui-tang-ornaments.png").convert("RGB")
out = ROOT / "assets/images/ui"
out.mkdir(parents=True, exist_ok=True)
names = ["corner_tl", "mirror_seal", "grape_flourish", "cloud_rule", "jade_tassel", "moon_lotus"]
for index, name in enumerate(names):
    x, y = index % 3 * 512, index // 3 * 512
    rgb = np.asarray(source.crop((x, y, x + 512, y + 512))).astype(float)
    alpha = np.clip((rgb.max(axis=2) - 12) / 26, 0, 1)
    rgba = np.dstack((np.clip(rgb / np.maximum(alpha[..., None], 0.001), 0, 255), alpha * 255)).astype("uint8")
    image = Image.fromarray(rgba)
    image = image.crop(image.getbbox())
    image.thumbnail((320, 320), Image.Resampling.LANCZOS)
    image.save(out / (name + ".png"))
    if name == "corner_tl":
        ImageOps.mirror(image).save(out / "corner_tr.png")
        ImageOps.flip(image).save(out / "corner_bl.png")
        ImageOps.flip(ImageOps.mirror(image)).save(out / "corner_br.png")
    print(name, image.size)
