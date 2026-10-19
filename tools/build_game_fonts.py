"""Bundle open Noto Chinese fonts, subset to project text, with static display weights."""
from pathlib import Path
import urllib.request

from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont

ROOT = Path(__file__).resolve().parents[1]
text = "".join(path.read_text(encoding="utf-8-sig") for path in (ROOT / "scripts").rglob("*.gd"))
text += "".join(chr(c) for c in range(32, 127)) + "〇○●①②③④⑤⑥⑦⑧⑨⑩→←↑↓·—…？！：；，。、“”‘’（）《》【】「」"
for source, target, weight, family, license_slug in [
    ("NotoSansSC-VF.ttf", "body-sc.ttf", 460, "Changan UI Sans", "notosanssc"),
    ("NotoSerifSC-VF.ttf", "display-sc.ttf", 500, "Changan Literary Serif", "notoserifsc"),
]:
    font = instantiateVariableFont(TTFont(Path("C:/Windows/Fonts") / source), {"wght": weight}, inplace=True)
    options = subset.Options()
    options.name_IDs = [0, 1, 2, 3, 4, 5, 6, 13, 14]
    options.name_legacy = True
    options.name_languages = [0x409]
    worker = subset.Subsetter(options=options)
    worker.populate(text=text)
    worker.subset(font)
    for name_id, value in [(1, family), (2, "Regular"), (4, family), (6, family.replace(" ", ""))]:
        font["name"].setName(value, name_id, 3, 1, 0x409)
    path = ROOT / "assets/fonts" / target
    font.save(path)
    license_path = ROOT / "assets/fonts" / f"{license_slug}-OFL.txt"
    if not license_path.exists():
        with urllib.request.urlopen(f"https://raw.githubusercontent.com/google/fonts/main/ofl/{license_slug}/OFL.txt", timeout=30) as response:
            license_path.write_bytes(response.read())
    print(target, path.stat().st_size, "bytes", "weight", weight)

brush_source = Path("C:/Users/lenovo/AppData/Local/Microsoft/Windows/Fonts/演示流云楷.ttf")
brush = TTFont(brush_source)
options = subset.Options()
options.name_IDs = [0, 1, 2, 3, 4, 5, 6, 13, 14]
options.name_legacy = True
worker = subset.Subsetter(options=options)
worker.populate(text=text)
worker.subset(brush)
brush.save(ROOT / "assets/fonts/brush-sc.ttf")
print("brush-sc.ttf", (ROOT / "assets/fonts/brush-sc.ttf").stat().st_size, "bytes")
