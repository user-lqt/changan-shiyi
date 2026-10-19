"""Crop the approved four-cell evidence illustration into runtime card art."""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
source = ROOT / "output/imagegen/ch2-evidence-atlas.png"
with Image.open(source) as image:
    image = image.convert("RGB")
    cell_w, cell_h = image.width // 2, image.height // 2
    for index, name in enumerate(("shard", "ledger", "bundle", "gong")):
        x, y = (index % 2) * cell_w, (index // 2) * cell_h
        cropped = image.crop((x, y, x + cell_w, y + cell_h))
        output = ROOT / f"assets/images/evidence_{name}.png"
        cropped.save(output, optimize=True)
        print(f"Saved {output.name}: {cropped.width} x {cropped.height}")
