"""Make compact GIF previews from real Godot viewport frames and capture timings."""
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
for kind in ("success", "retort"):
    source = ROOT / f"tmp/ch2-{kind}-frames"
    timestamps = json.loads((source / "timing.json").read_text())["frame_times_ms"]
    frames = []
    for path in sorted(source.glob("[0-9][0-9][0-9].png")):
        with Image.open(path) as image:
            frames.append(image.convert("RGB").resize((960, 600), Image.Resampling.LANCZOS))
    durations = [max(20, min(250, end - start)) for start, end in zip(timestamps, timestamps[1:])]
    durations.append(700)
    webp = ROOT / f"docs/screenshots/v0.4/ch2-{kind}-preview.webp"
    frames[0].save(
        webp, save_all=True, append_images=frames[1:], duration=durations,
        loop=0, quality=80, method=4,
    )
    small = [image.resize((640, 400), Image.Resampling.LANCZOS) for image in frames[::2]]
    palette = small[min(10, len(small) - 1)].quantize(colors=128)
    quantized = [image.quantize(palette=palette, dither=Image.Dither.NONE) for image in small]
    gif_durations = [sum(durations[i:i + 2]) for i in range(0, len(durations), 2)]
    target = ROOT / f"docs/screenshots/v0.4/ch2-{kind}-preview.gif"
    quantized[0].save(
        target, save_all=True, append_images=quantized[1:], duration=gif_durations,
        loop=0, optimize=True, disposal=1,
    )
    print(f"Saved {webp.name}: {len(frames)} frames, {webp.stat().st_size:,} bytes")
    print(f"Saved {target.name}: {len(small)} frames, {target.stat().st_size:,} bytes")
