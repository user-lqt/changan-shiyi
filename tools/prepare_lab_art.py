"""Prepare the AI laboratory images for Godot; retain the original generated PNGs."""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "output/imagegen/epilogue"
DESTINATION = ROOT / "assets/images/lab"
ASSETS = {
    "lab-window-night.png": "window-night.jpg",
    "lab-archive-cabinet.png": "archive-cabinet.jpg",
    "lab-scanner-fascia.png": "scanner-fascia.jpg",
    "lab-conservation-board.png": "conservation-board.jpg",
}


if __name__ == "__main__":
    DESTINATION.mkdir(parents=True, exist_ok=True)
    for source, target in ASSETS.items():
        with Image.open(SOURCE / source) as picture:
            picture.convert("RGB").save(DESTINATION / target, quality=94)
        print(target)
