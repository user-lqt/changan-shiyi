"""Tang-inspired brick pagoda at chapter 4's temple approach.

One static GLB, front +Z, with a detailed first storey and light upper tiers.
The steps start beyond the playable goal tile; the route stays at ground level.
"""
import math
from build_night_detail import Scene, PALETTE, rotation

PALETTE.update({
    'pagoda_brick': ('b3a38a', .98, 0),
    'pagoda_trim': ('bfb49d', .94, 0),
    'pagoda_joint': ('776d5e', 1, 0),
    'pagoda_stone': ('929787', .97, 0),
    'pagoda_dark': ('252c2b', 1, 0),
})


def quad(m, points, material):
    m.add(points, [(0, 1, 2), (0, 2, 3)], material)


def front_strip(m, x0, x1, y0, y1, z, material='pagoda_joint'):
    quad(m, [(x0, y0, z), (x1, y0, z), (x1, y1, z), (x0, y1, z)], material)


def arch(m, radius, spring, z, width=.12, depth=.22):
    # True open arch, including the intrados and exposed stone voussoirs.
    count = 15
    for i in range(count):
        a = math.pi * i / count + .009
        b = math.pi * (i + 1) / count - .009
        points = [(r * math.cos(t), spring + r * math.sin(t), zz)
                  for zz in (z, z - depth) for r, t in
                  ((radius, a), (radius + width, a), (radius + width, b), (radius, b))]
        faces = [(0, 1, 2), (0, 2, 3), (4, 6, 5), (4, 7, 6)]
        for j in range(4):
            k = (j + 1) % 4
            faces.extend([(j, 4 + j, k), (k, 4 + j, 4 + k)])
        m.add(points, faces, 'pagoda_trim')


def cornice(m, width, y):
    for dy, extra, height in [(0, .08, .09), (.09, .20, .08), (.17, .35, .07), (.24, .27, .05)]:
        m.box((width + extra, height, width + extra), (0, y + dy + height / 2, 0), 'pagoda_trim', .018)
    for side in [-1, 1]:
        for col in range(11):
            at = (col - 5) * width / 12
            m.box((.10, .08, .09), (at, y - .045, side * width / 2), 'pagoda_trim', .008)
            m.box((.09, .08, .10), (side * width / 2, y - .045, at), 'pagoda_trim', .008)


def build():
    scene = Scene()
    _, m = scene.node('CienPagoda')
    for width, height, y in [(4.9, .12, .06), (4.68, .10, .17), (4.45, .12, .28)]:
        m.box((width, height, width), (0, y, 0), 'pagoda_stone', .025)
    # Three separate treads, with a generous landing before the threshold.
    for i in range(3):
        height = .11 * (i + 1)
        m.box((1.62, height, .32), (0, height / 2, 3.0 - .30 * i), 'pagoda_trim', .012)
    m.box((1.62, .33, .55), (0, .165, 2.0), 'pagoda_trim', .014)
    for sign in [-1, 1]:
        m.box((.15, .22, 1.12), (sign * .9, .22, 2.63), 'pagoda_stone', .025,
              rotation(x=sign * 0.0))
        m.lathe([(.13, .34), (.14, .38), (.10, .43), (.08, .61), (.11, .66), (0, .74)],
                'pagoda_trim', (sign * 1.82, 0, 1.82), segments=12)

    width = 3.9
    half = width / 2
    floor, top, spring, radius = .34, 2.55, 1.45, .62
    # Pier and back/side walls leave an actual recessed doorway.
    for sign in [-1, 1]:
        m.box((half - radius, top - floor, .30), (sign * (half + radius) / 2, (top + floor) / 2, half - .15), 'pagoda_brick', .012)
        m.box((.30, top - floor, width), (sign * (half - .15), (top + floor) / 2, 0), 'pagoda_brick', .012)
    m.box((width, top - floor, .30), (0, (top + floor) / 2, -half + .15), 'pagoda_brick', .012)
    # Curved underside of the spandrel, built segment by segment above the arch.
    for i in range(20):
        x0 = -radius + 2 * radius * i / 20
        x1 = -radius + 2 * radius * (i + 1) / 20
        y0 = spring + math.sqrt(max(0, radius * radius - x0 * x0))
        y1 = spring + math.sqrt(max(0, radius * radius - x1 * x1))
        quad(m, [(x0, y0, half), (x1, y1, half), (x1, top, half), (x0, top, half)], 'pagoda_brick')
        quad(m, [(x0, y0, half - .30), (x0, y0, half), (x1, y1, half), (x1, y1, half - .30)], 'pagoda_trim')
    arch(m, radius, spring, half + .025)
    for sign in [-1, 1]:
        m.box((.13, spring - floor, .25), (sign * (radius + .065), (spring + floor) / 2, half - .06), 'pagoda_trim', .01)
        m.box((.14, top - floor, .12), (sign * (half - .08), (top + floor) / 2, half + .035), 'pagoda_trim', .012)
    # Door leaves sit back inside the opening, preserving the stone reveal.
    m.box((1.25, 1.78, .05), (0, 1.23, half - .43), 'pagoda_dark', .005)
    for sign in [-1, 1]:
        for col in range(4):
            x = sign * (.075 + col * .145)
            m.box((.135, 1.32, .045), (x, 1.0, half - .38), 'timber', .004)
            for y in [.59, 1.0, 1.42]:
                m.ellipsoid((.016, .016, .012), (x, y, half - .345), 'bronze', rings=4, segments=6)
        m.ring(.055, .009, 'bronze', (sign * .11, 1.03, half - .32), rotation(x=math.pi / 2), segments=16, sides=5)
    # Quiet geometric brick courses: only the facade needs individual joints.
    for row in range(12):
        y = floor + .17 * (row + 1)
        spans = [(-half + .15, -.76), (.76, half - .15)] if y < 2.15 else [(-half + .15, half - .15)]
        for left, right in spans:
            front_strip(m, left, right, y, y + .008, half + .004)
            count = math.ceil((right - left) / .34)
            for col in range(count):
                x = left + (col + (.5 if row % 2 else 0)) * .34
                if left + .03 < x < right - .03:
                    front_strip(m, x, x + .008, y - .16, y, half + .005)
        for sign in [-1, 1]:
            x = sign * (half + .004)
            quad(m, [(x, y, -half + .12), (x, y, half - .12), (x, y + .008, half - .12), (x, y + .008, -half + .12)], 'pagoda_joint')
    cornice(m, width, top)
    # Upper storeys use broad silhouettes; detail is concentrated at eye level.
    y = top + .29
    for storey in range(6):
        w = 3.52 - storey * .29
        height = .61 - storey * .035
        m.box((w, height, w), (0, y + height / 2, 0), 'pagoda_brick', .014)
        if storey < 3:
            for sign in [-1, 1]:
                front_strip(m, -.20, .20, y + .16, y + height - .09, sign * (w / 2 + .008), 'pagoda_dark')
            for side in [-1, 1]:
                quad(m, [(side * (w / 2 + .008), y + .15, -.18), (side * (w / 2 + .008), y + height - .1, -.18),
                         (side * (w / 2 + .008), y + height - .1, .18), (side * (w / 2 + .008), y + .15, .18)], 'pagoda_dark')
        for dy, extra in [(height, .12), (height + .07, .27)]:
            m.box((w + extra, .07, w + extra), (0, y + dy + .035, 0), 'pagoda_trim', .012)
        y += height + .14
    m.lathe([(0, 0), (.31, 0), (.35, .08), (.23, .16), (.16, .23), (.12, .41), (0, .52)], 'bronze', (0, y, 0), segments=16)
    # Plaque frame; the Chinese lettering is a crisp Label3D in the game.
    m.box((1.35, .31, .08), (0, 2.30, half + .07), 'endgrain', .018)
    for yy in [2.155, 2.445]:
        m.box((1.31, .018, .018), (0, yy, half + .12), 'bronze', .002)
    for xx in [-.65, .65]:
        m.box((.018, .29, .018), (xx, 2.30, half + .12), 'bronze', .002)
    scene.save('pagoda_base')


if __name__ == '__main__':
    build()
