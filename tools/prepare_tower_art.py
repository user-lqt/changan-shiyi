"""Prepare the selected AI images for the tower, retaining the originals and prompts."""
from pathlib import Path
import shutil
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT/'output/imagegen/ch6'
DEST = ROOT/'assets/images/tower'

if __name__ == '__main__':
    DEST.mkdir(parents=True, exist_ok=True)
    source = Image.open(SOURCE/'moon-face-ai.png').convert('RGB')
    # Normalize the lunar disc diameter to match the game's spherical lighting mask.
    mask = source.convert('L').point(lambda value: 255 if value > 24 else 0)
    bounds = mask.getbbox()
    if bounds is None:
        raise ValueError('The generated Moon has no visible surface.')
    x0, y0, x1, y1 = bounds
    size = max(x1-x0, y1-y0)
    cx, cy = (x0+x1)/2, (y0+y1)/2
    source = source.crop((round(cx-size/2), round(cy-size/2), round(cx+size/2), round(cy+size/2)))
    moon = Image.new('RGB', (1024, 1024), 'black')
    moon.paste(source.resize((880, 880), Image.Resampling.LANCZOS), (72, 72))
    moon.save(DEST/'moon_face_ai.png')
    city = Image.open(SOURCE/'changan-rooftops-ai.png').convert('RGB')
    city.save(DEST/'changan_rooftops_ai.jpg', quality=94, subsampling=0)
    shutil.copyfile(ROOT/'tmp/imagegen/ch6-refinement.jsonl', SOURCE/'prompts.jsonl')
    print('Prepared AI moon face and Chang’an rooftop panorama:', DEST)
