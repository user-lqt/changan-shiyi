"""Key and align the eight generated Mina poses without replacing her dialogue portrait."""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[1]
source = Image.open(ROOT / "output/imagegen/ch3-mina-turn-sheet.png").convert("RGB")
w, h = source.size
contact = Image.new("RGB", (4 * 300, 2 * 450), "#172321")
for index in range(8):
    x, y = index % 4, index // 4
    tile = source.crop((x * w // 4, y * h // 2, (x + 1) * w // 4, (y + 1) * h // 2))
    rgb = np.asarray(tile).astype(np.float32)
    # Strong separation between magenta screen and the red/teal/gold costume.
    distance = np.maximum.reduce((rgb[..., 1], 255 - rgb[..., 0], 255 - rgb[..., 2]))
    alpha = np.clip((distance - 22) / 60, 0, 1)
    magenta = np.minimum(rgb[..., 0], rgb[..., 2]) - rgb[..., 1]
    alpha = np.minimum(alpha, 1 - np.clip((magenta - 15) / 65, 0, 1))
    solid = alpha > 0.98
    _, nearest = ndimage.distance_transform_edt(~solid, return_indices=True)
    clean = rgb[nearest[0], nearest[1]]
    rgb = rgb * alpha[..., None] + clean * (1 - alpha[..., None])
    rgba = np.concatenate((rgb, (alpha * 255)[..., None]), axis=2).astype(np.uint8)
    pose = Image.fromarray(rgba)
    # The supplied sheet repeats a right-facing view in these two slots.
    if index in (6, 7):
        pose = pose.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    bounds = pose.getbbox()
    if bounds is None:
        raise RuntimeError(f"Empty pose {index}")
    cropped = pose.crop(bounds)
    scale = min(680 / cropped.height, 500 / cropped.width)
    cropped = cropped.resize((round(cropped.width * scale), round(cropped.height * scale)), Image.Resampling.LANCZOS)
    frame = Image.new("RGBA", (560, 720))
    frame.alpha_composite(cropped, ((560 - cropped.width) // 2, 704 - cropped.height))
    frame.save(ROOT / f"assets/images/mi_dance_{index}.png")
    preview = frame.resize((300, 386), Image.Resampling.LANCZOS)
    contact.paste(preview, (x * 300, y * 450 + 35), preview)
    ImageDraw.Draw(contact).text((x * 300 + 14, y * 450 + 12), f"POSE {index + 1:02d}", fill="#dfbf7e")
target = ROOT / "docs/screenshots/v0.4/ch3-dance-poses.jpg"
contact.save(target, quality=92)
print("Saved 8 aligned transparent dance poses and", target.name)
