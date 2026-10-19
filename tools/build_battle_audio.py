"""Battle music + combat SFX (first pass, procedural, no samples).

Style: "古风 × 东方 Project" — a fast (160 BPM) driving beat with a syncopated synth bass,
pipa-like tremolo arpeggios and an erhu-like lead with slides, in D minor pentatonic
(D F G A C) so it sounds Chinese, but with the busy melodic runs typical of Touhou boss themes.
Run: python tools/build_battle_audio.py
"""
import sys
from pathlib import Path
import numpy as np

sys.path.insert(0, str(Path(__file__).parent))
from build_audio_lib import SR, save, tt, lowpass, highpass, reverb, zheng, bell, place, wood_tock  # noqa: E402

rng = np.random.default_rng(1600)
BPM = 160
BEAT = 60 / BPM
BAR = BEAT * 4


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)


# D minor pentatonic around D4 (62): D F G A C
PENTA = [50, 53, 55, 57, 60, 62, 65, 67, 69, 72, 74, 77, 79, 81]


def erhu(freq, dur, gain=0.5, slide_from=None):
    """Bowed string: sawtooth-ish partials, slow attack, vibrato that grows, optional slide."""
    t = tt(dur)
    f = np.full_like(t, freq)
    if slide_from:
        k = np.minimum(t / 0.08, 1)
        f = slide_from + (freq - slide_from) * k
    vib = 1 + 0.006 * np.sin(2 * np.pi * 6.0 * t) * np.minimum(t / 0.25, 1)
    ph = 2 * np.pi * np.cumsum(f * vib) / SR
    y = sum(np.sin(ph * n) / n ** 1.1 for n in range(1, 9))
    env = np.minimum(t / 0.04, 1) * np.minimum((dur - t) / 0.05, 1).clip(0, 1)
    return lowpass(y * env * gain, 3800)


def pipa(freq, dur, gain=0.3):
    """Tremolo plucks (轮指)."""
    out = np.zeros(int(dur * SR))
    n = max(1, int(dur / 0.055))
    for i in range(n):
        place(out, zheng(freq, 0.25, gain * (0.8 + 0.2 * rng.random()), bright=1.6), i * 0.055)
    return out


def kick():
    t = tt(0.3)
    return np.sin(2 * np.pi * (50 + 110 * np.exp(-t * 30)) * t) * np.exp(-t * 9)


def snare():
    t = tt(0.22)
    return highpass(rng.normal(0, 1, len(t)), 1200) * np.exp(-t * 18) * 0.6 + np.sin(2 * np.pi * 190 * t) * np.exp(-t * 25) * 0.5


def hat(open_=False):
    t = tt(0.2 if open_ else 0.05)
    return highpass(rng.normal(0, 1, len(t)), 7000) * np.exp(-t * (14 if open_ else 80)) * 0.35


def bass(freq, dur):
    t = tt(dur)
    y = np.sign(np.sin(2 * np.pi * freq * t)) * 0.5 + np.sin(2 * np.pi * freq * t)
    return lowpass(y * np.exp(-t * 4) * np.minimum(t / 0.004, 1), 900) * 0.5


# ---------------------------------------------------------------- song structure (16 bars, loops)
BARS = 16
song = np.zeros(int(BARS * BAR * SR) + SR)
# chord roots per bar: Dm  Bb  C  Am | Dm Bb C A | Gm C F Dm | Bb C Dm Dm
roots = [38, 34, 36, 33, 38, 34, 36, 33, 31, 36, 29, 38, 34, 36, 38, 38]
for b in range(BARS):
    t0 = b * BAR
    # drums: kick on 1 and 3 (+ syncopation), snare on 2 and 4, eighth hats
    for k in [0, 1.5, 2, 3.5] if b % 4 != 3 else [0, 1, 2, 2.5, 3, 3.5]:
        place(song, kick() * 0.9, t0 + k * BEAT)
    for s in [1, 3]:
        place(song, snare() * 0.7, t0 + s * BEAT)
    for h in range(8):
        place(song, hat(h % 2 == 1 and h == 7), t0 + h * BEAT / 2)
    # syncopated bass (eighths)
    r = midi(roots[b])
    for i, step in enumerate([0, 0, 12, 0, 7, 0, 12, 7]):
        place(song, bass(r * 2 ** (step / 12), BEAT / 2 * 0.9), t0 + i * BEAT / 2)
    # pipa tremolo on the chord fifth every half bar
    for h in range(2):
        place(song, pipa(midi(roots[b] + 24 + (7 if h else 0)), BEAT * 1.8, 0.12), t0 + h * BEAT * 2)

# lead melody: (bar, beat, penta index, beats, slide)
MELODY = []
phrase_a = [(0, 0, 8, 1.5), (0, 1.5, 9, 0.5), (0, 2, 10, 1), (0, 3, 9, 0.5), (0, 3.5, 8, 0.5),
            (1, 0, 7, 2), (1, 2, 8, 0.5), (1, 2.5, 7, 0.5), (1, 3, 6, 1),
            (2, 0, 5, 0.5), (2, 0.5, 6, 0.5), (2, 1, 7, 0.5), (2, 1.5, 8, 0.5), (2, 2, 9, 1), (2, 3, 10, 1),
            (3, 0, 11, 3), (3, 3, 10, 0.5), (3, 3.5, 9, 0.5)]
phrase_b = [(0, 0, 10, 1), (0, 1, 11, 0.5), (0, 1.5, 12, 0.5), (0, 2, 11, 1), (0, 3, 10, 1),
            (1, 0, 9, 0.5), (1, 0.5, 10, 0.5), (1, 1, 9, 0.5), (1, 1.5, 8, 0.5), (1, 2, 7, 2),
            (2, 0, 8, 0.25), (2, 0.25, 9, 0.25), (2, 0.5, 10, 0.25), (2, 0.75, 11, 0.25), (2, 1, 12, 1.5), (2, 2.5, 11, 0.5), (2, 3, 10, 1),
            (3, 0, 8, 4)]
for base, ph in [(0, phrase_a), (4, phrase_a), (8, phrase_b), (12, phrase_b)]:
    for bar, beat, idx, beats in ph:
        MELODY.append((base + bar, beat, idx, beats))
prev = None
for bar, beat, idx, beats in MELODY:
    f = midi(PENTA[idx])
    slide = midi(PENTA[idx - 1]) if beats >= 1 and prev is not None and prev != idx and rng.random() < 0.5 else None
    place(song, erhu(f, beats * BEAT * 0.98, 0.42, slide), bar * BAR + beat * BEAT)
    # octave-up bell doubling on strong notes
    if beats >= 1:
        place(song, bell(f * 2, 1.2, 0.08), bar * BAR + beat * BEAT)
    prev = idx

song = song[:int(BARS * BAR * SR)]
song = reverb(song, 0.22, loop=True)
save('battle', song, 0.8, loop=True)

# ---------------------------------------------------------------- combat / debate SFX
t = tt(0.06)
save('shoot', highpass(rng.normal(0, 1, len(t)), 3000) * np.exp(-t * 60) + np.sin(2 * np.pi * 1800 * t) * np.exp(-t * 80) * 0.3, 0.4)

t = tt(0.6)
hit = np.sin(2 * np.pi * (300 - 220 * t) * t) * np.exp(-t * 5) + lowpass(rng.normal(0, 1, len(t)), 1500) * np.exp(-t * 8)
save('hit', hit, 0.8)

t = tt(0.08)
save('graze', np.sin(2 * np.pi * 2600 * t) * np.exp(-t * 50), 0.3)

t = tt(1.4)
sweep = np.sin(2 * np.pi * np.cumsum(200 + 1600 * t) / SR) * np.exp(-t * 2.2)
bomb = sweep + lowpass(rng.normal(0, 1, len(t)), 2500) * np.exp(-t * 3) * 0.6
place(bomb, bell(880, 1.3, 0.6), 0.05)
save('bomb', reverb(bomb, 0.3), 0.85)

# 看破! — gong hit + rising whoosh + chord stab
t = tt(1.6)
obj = np.zeros(len(t))
whoosh = highpass(rng.normal(0, 1, int(0.25 * SR)), 1500) * np.linspace(0, 1, int(0.25 * SR)) ** 2
place(obj, whoosh * 0.6, 0)
gong = sum(np.sin(2 * np.pi * f * tt(1.3)) * np.exp(-tt(1.3) * d) * a for f, d, a in [(110, 1.5, 1), (167, 2.2, .6), (231, 2.8, .4), (339, 3.5, .3)])
place(obj, gong, 0.22)
for f in [293.66, 349.23, 440.0, 587.33]:
    place(obj, erhu(f, 0.6, 0.25), 0.24)
save('objection', reverb(obj, 0.3), 0.9)

b2 = bell(659.25, 2.0)
place(b2, bell(987.77, 1.5, 0.3), 0)
save('bell', reverb(b2, 0.4), 0.7)
print('Created battle loop (%.1f s) and 6 combat / debate sounds.' % (BARS * BAR))
