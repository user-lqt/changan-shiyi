"""Reuse the restoration game's four fragment shapes in the opening laboratory.

The original lab painting contains an intact bowl. Remove those four pieces from
the painting, reconstruct the space behind them, and expose a thin ceramic edge.
The original painting and the restored epilogue remain available unchanged.
"""
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "assets/images"
original = Image.open(ART / "lab.jpg").convert("RGB")
width, height = original.size
scale = width / 1536

# Coordinates are authored against the original 1536 x 1024 painting.
def poly_mask(points):
    image = Image.new("L", original.size)
    ImageDraw.Draw(image).polygon([(x * scale, y * scale) for x, y in points], fill=255)
    return image


silhouette = poly_mask([
    (918, 602), (925, 584), (946, 578), (968, 589), (991, 578),
    (1016, 590), (1041, 577), (1067, 587), (1092, 580), (1119, 589),
    (1142, 582), (1168, 596), (1186, 591), (1205, 600), (1221, 595),
    (1215, 630), (1202, 663), (1184, 699), (1156, 729), (1127, 743),
    (1129, 751), (1107, 760), (1057, 763), (1035, 753), (1012, 743),
    (978, 727), (956, 695), (938, 652),
])
plate_mask = silhouette.filter(ImageFilter.MaxFilter(15))
source = np.asarray(original)
plate = cv2.inpaint(source, np.asarray(plate_mask), 15, cv2.INPAINT_TELEA)
holes = Image.new("L", original.size)
draw = ImageDraw.Draw(holes)
cuts = [
    [(914, 574), (991, 569), (995, 608), (982, 626), (991, 649), (966, 655), (939, 644), (927, 651), (909, 623)],
    [(1154, 576), (1234, 584), (1231, 644), (1203, 656), (1181, 646), (1168, 625), (1173, 606)],
    [(981, 665), (1007, 659), (1020, 671), (1031, 684), (1025, 704), (1031, 721), (1015, 733), (996, 717), (988, 695)],
    [(1043, 619), (1070, 610), (1099, 618), (1115, 637), (1106, 660), (1112, 678), (1090, 699), (1066, 693), (1045, 674), (1051, 650)],
]
for points in cuts:
    draw.polygon([(x * scale, y * scale) for x, y in points], fill=255)
hole = (np.asarray(holes) > 0) & (np.asarray(silhouette) > 0)
damaged = source.copy()
damaged[hole] = plate[hole]
edge = (
    np.asarray(Image.fromarray(hole.astype("uint8") * 255).filter(ImageFilter.MaxFilter(3))) > 0
) & ~hole & (np.asarray(silhouette) > 0)
damaged[edge] = (source[edge] * 0.25 + np.array([190, 166, 123]) * 0.75).astype("uint8")

# A transparent dossier model uses exactly the same four holes as the finale.
model = np.asarray(Image.open(ART / "bowl_broken.png").convert("RGBA")).copy()
model[model[..., 3] == 110, 3] = 0
Image.fromarray(model).save(ART / "bowl_damaged.png")

# The right-hand monitor must show the same incomplete model, not an intact bowl.
monitor = Image.fromarray(damaged).convert("RGBA")
screen_box = tuple(round(value * scale) for value in (1085, 348, 1301, 469))
screen_rgb = np.asarray(monitor.crop(screen_box).convert("RGB"))
channels = screen_rgb.astype(float)
old_wire = ((channels[..., 1] > channels[..., 0] * 1.3)
            & (channels[..., 2] > channels[..., 0] * 1.4)
            & (channels[..., 1] > 45)).astype("uint8") * 255
old_wire = cv2.dilate(old_wire, np.ones((3, 3), dtype="uint8"))
screen = Image.fromarray(cv2.inpaint(screen_rgb, old_wire, 3, cv2.INPAINT_TELEA)).convert("RGBA")
model_mask = model[..., 3] > 128
lines = np.zeros(model_mask.shape, dtype="uint8")
for y in range(0, lines.shape[0], 15):
    for x in range(lines.shape[1]):
        yy = int(y + 12 * np.sin(x / lines.shape[1] * np.pi))
        if yy < lines.shape[0]:
            lines[yy, x] = 155
for x in range(0, lines.shape[1], 22):
    lines[:, x:x + 1] = 155
contours = cv2.Canny((model_mask * 255).astype("uint8"), 50, 150)
lines = np.maximum(lines * model_mask, contours)
wire = np.zeros(model.shape, dtype="uint8")
wire[..., :3] = [81, 174, 192]
wire[..., 3] = lines
wire_image = Image.fromarray(wire).resize((round(192 * scale), round(97 * scale)), Image.Resampling.LANCZOS)
screen.alpha_composite(wire_image, (round(10 * scale), round(14 * scale)))
monitor.alpha_composite(screen, (round(1085 * scale), round(348 * scale)))
monitor.convert("RGB").save(ART / "lab_damaged.png")
print("Saved lab_damaged.png and bowl_damaged.png")
