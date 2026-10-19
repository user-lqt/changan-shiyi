"""Derive matching lunar-phase sprites from the game's existing AI moon painting."""
from pathlib import Path
import math
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "assets/images/ch7_battle"


def main():
    source = Image.open(ART / "moon.png").convert("RGBA")
    # Crop the transparent padding rather than distorting the lunar disc.
    source = source.crop(source.getchannel("A").getbbox())
    side = max(source.size)
    square = Image.new("RGBA", (side, side))
    square.alpha_composite(source, ((side - source.width) // 2, (side - source.height) // 2))
    square = square.resize((224, 224), Image.Resampling.LANCZOS)
    for phase, name in enumerate(("new", "half", "full")):
        disc = square.copy()
        pixels = disc.load()
        for y in range(224):
            for x in range(224):
                nx, ny = (x - 111.5) / 111.5, (y - 111.5) / 111.5
                r, g, b, a = pixels[x, y]
                edge = max(0.0, min(1.0, (math.hypot(nx, ny) - 0.94) / 0.045))
                light = 1.0 if phase == 2 else (0.12 if phase == 0 else 0.11 + 0.89 * max(0.0, min(1.0, (nx + 0.025) / 0.065)))
                if phase == 0:
                    light = max(light, edge * 0.7)
                pixels[x, y] = (int(r * light), int(g * light), int(b * light), a)
        canvas = Image.new("RGBA", (256, 256))
        halo = Image.new("RGBA", (256, 256))
        halo.paste((176, 204, 222, 75), (16, 16, 240, 240), disc.getchannel("A"))
        canvas.alpha_composite(halo.filter(ImageFilter.GaussianBlur(6)))
        canvas.alpha_composite(disc, (16, 16))
        canvas.resize((128, 128), Image.Resampling.LANCZOS).save(ART / f"phase-{name}.png")
        print(f"Saved phase-{name}.png")


if __name__ == "__main__":
    main()
