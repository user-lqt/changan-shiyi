"""Apply the local AI-painted empty pedestal beneath the opening chest."""
from pathlib import Path
from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parents[1]
art = ROOT / 'art/ch1_casket'
original = Image.open(ROOT / 'assets/images/workshop.png').convert('RGB')
repair = Image.open(art / 'empty-pedestal-original.png').convert('RGB')
mask = ImageOps.invert(Image.open(art / 'empty-pedestal-mask.png').getchannel('A'))
assert original.size == repair.size == mask.size
original.paste(repair, (0, 0), mask)
original.save(ROOT / 'assets/images/ch1_workshop/workshop-open-background.png', optimize=True)
print('Saved only the locally repaired chest region.')
