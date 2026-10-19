"""Key the generated Wen sheet, align the poses, and face him into the scene."""
from pathlib import Path
import subprocess
import sys

from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "output/imagegen"
TARGET = ROOT / "assets/images"

sheet = Image.open(SOURCE / "wen-poses-sheet.png")
names = ("explain", "recall", "offer")
poses = []
for i, name in enumerate(names):
    crop = SOURCE / f"wen-{name}-green.png"
    keyed = SOURCE / f"wen-{name}-keyed.png"
    sheet.crop((round(i * sheet.width / 3), 0, round((i + 1) * sheet.width / 3), sheet.height)).save(crop)
    subprocess.run([sys.executable, str(ROOT / "tools/key_portrait.py"), str(crop), str(keyed)], check=True)
    poses.append(Image.open(keyed).convert("RGBA"))

# The three heads and feet share a baseline; changing gestures must not shift the actor.
height = 1395
poses = [p.resize((round(p.width * height / p.height), height), Image.Resampling.LANCZOS) for p in poses]
width = max(p.width for p in poses)
for name, pose in zip(names, poses):
    canvas = Image.new("RGBA", (width, height))
    canvas.alpha_composite(pose, ((width - pose.width) // 2, 0))
    ImageOps.mirror(canvas).save(TARGET / f"npc_wen_{name}.png", optimize=True)

# Preserve the original source so rerunning the preparation cannot flip it twice.
original = SOURCE / "npc_wen-original.png"
if not original.exists():
    Image.open(TARGET / "npc_wen.png").save(original)
ImageOps.mirror(Image.open(original)).save(TARGET / "npc_wen.png", optimize=True)
print("Prepared three aligned poses and mirrored the original Wen portrait.")
