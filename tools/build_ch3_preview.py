"""Build a small looping preview using the three sections recorded in Godot."""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
paths = sorted((ROOT / "tmp/ch3-dance-frames").glob("[0-9][0-9][0-9].png"))
frames = [Image.open(path).convert("RGB").resize((800, 500), Image.Resampling.LANCZOS) for path in paths]
if not frames:
    raise RuntimeError("Record --stage=ch3_dance_record first")
target = ROOT / "docs/screenshots/v0.4/ch3-dance-preview"
frames[0].save(target.with_suffix(".webp"), save_all=True, append_images=frames[1:], duration=80, loop=0, quality=82, method=4)
sheet = Image.new("RGB", (800 * 3, 500))
for i, index in enumerate([8, 48, 84]):
    sheet.paste(frames[min(index, len(frames)-1)], (i * 800, 0))
palette = sheet.quantize(colors=192)
small = [f.resize((640, 400), Image.Resampling.LANCZOS).quantize(palette=palette, dither=Image.Dither.NONE) for f in frames]
small[0].save(target.with_suffix(".gif"), save_all=True, append_images=small[1:], duration=80, loop=0, disposal=1)
sheet.resize((1920, 400), Image.Resampling.LANCZOS).save(ROOT / "docs/screenshots/v0.4/ch3-sections.jpg", quality=92)
print("Saved", len(frames), "viewport frames as GIF, WebP and section overview")
