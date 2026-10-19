"""Extract chest layers from the workshop painting and synthesize a short wind cue.

No network or new generated artwork: the animation retains the original painted chest.
Run with Python + Pillow, NumPy and SciPy.
"""
from pathlib import Path
import wave

import numpy as np
from PIL import Image, ImageFilter
from scipy.signal import butter, sosfilt

ROOT = Path(__file__).resolve().parents[1]
source = Image.open(ROOT / "assets/images/workshop.png").convert("RGB")
ratio = max(1074 / source.width, 604 / source.height)
crop_w, crop_h = 1074 / ratio, 604 / ratio
ox, oy = (source.width - crop_w) / 2, (source.height - crop_h) / 2
for name, rect in {
    "ch1_casket_front": (948, 484, 1092, 532),
    "ch1_casket_lid": (948, 461, 1092, 482),
}.items():
    x1, y1, x2, y2 = rect
    box = (
        round(ox + (x1 - 38) / ratio), round(oy + (y1 - 170) / ratio),
        round(ox + (x2 - 38) / ratio), round(oy + (y2 - 170) / ratio),
    )
    image = source.crop(box)
    image = image.resize((image.width * 3, image.height * 3), Image.Resampling.LANCZOS)
    image = image.filter(ImageFilter.UnsharpMask(radius=1.1, percent=65, threshold=4))
    image.save(ROOT / f"assets/images/{name}.png")
    print(f"Saved {name}.png")

sr = 32000
t = np.arange(round(sr * 2.4)) / sr
rng = np.random.default_rng(491)
noise = rng.standard_normal(len(t))
wind = sosfilt(butter(3, [140, 2200], btype="bandpass", fs=sr, output="sos"), noise)
envelope = np.minimum(t / 0.45, 1) * np.exp(-np.maximum(t - 0.6, 0) * 2.6)
wind = wind * envelope * (0.65 + 0.35 * np.sin(t * 7 + np.sin(t * 3)))
wind += np.sin(2 * np.pi * (160 * t + 12 * np.sin(t * 2))) * envelope * 0.025
wind *= np.minimum(t / 0.03, 1) * np.minimum((2.4 - t) / 0.08, 1)
wind = wind / max(abs(wind).max(), 1e-9) * 0.7
with wave.open(str(ROOT / "assets/audio/wind.wav"), "wb") as wav:
    wav.setnchannels(1)
    wav.setsampwidth(2)
    wav.setframerate(sr)
    wav.writeframes((wind * 32767).astype("<i2").tobytes())
print("Saved wind.wav")
