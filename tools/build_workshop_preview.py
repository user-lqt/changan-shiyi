"""Assemble a small animated preview from the actual Godot viewport recordings."""
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
all_frames, all_durations = [], []
for kind in ("place", "unlock", "wind"):
    source = ROOT / f"tmp/ch1-{kind}-frames"
    times = json.loads((source / "timing.json").read_text())["frame_times_ms"]
    paths = sorted(source.glob("[0-9][0-9][0-9].png"))[:len(times)]
    frames = [Image.open(path).convert("RGB") for path in paths]
    durations = [max(20, min(250, b - a)) for a, b in zip(times, times[1:])] + [450]
    all_frames.extend(frames)
    all_durations.extend(durations)

target = ROOT / "docs/screenshots/v0.4/ch1-animation-preview"
all_frames[0].save(
    target.with_suffix(".webp"), save_all=True, append_images=all_frames[1:],
    duration=all_durations, quality=80, method=4, loop=0,
)
small = [image.resize((640, 400), Image.Resampling.LANCZOS) for image in all_frames[::2]]
# Use a shared contact-sheet palette, retaining both the warm workshop and dark wind scene.
palette_source = Image.new("RGB", (640 * 3, 400))
for i, index in enumerate([min(8, len(small) - 1), len(small) // 2, max(0, len(small) - 12)]):
    palette_source.paste(small[index], (i * 640, 0))
palette = palette_source.quantize(colors=160)
quantized = [frame.quantize(palette=palette, dither=Image.Dither.NONE) for frame in small]
durations = [sum(all_durations[i:i + 2]) for i in range(0, len(all_durations), 2)]
quantized[0].save(
    target.with_suffix(".gif"), save_all=True, append_images=quantized[1:],
    duration=durations, loop=0, optimize=True, disposal=1,
)
print(f"Saved GIF and WebP previews: {len(all_frames)} viewport frames, {sum(all_durations)/1000:.1f}s")
