"""Original procedural audio for 镜照工坊. No network, no external samples.

Run:  python tools/build_audio.py   (needs numpy)
Outputs mono 16-bit WAV files into assets/audio/.
"""
from pathlib import Path
import wave
import numpy as np

OUT = Path(__file__).resolve().parents[1] / 'assets/audio'
OUT.mkdir(parents=True, exist_ok=True)
SR = 32000
rng = np.random.default_rng(731)


def save(name, data, peak=0.85, loop=False):
    data = np.asarray(data, dtype=float).copy()
    if loop:
        # crossfade the tail into the head so the loop has no seam
        xf = int(0.8 * SR)
        ramp = np.linspace(0, 1, xf)
        data[:xf] = data[:xf] * ramp + data[-xf:] * (1 - ramp)
        data = data[:-xf]
    else:
        # short fade-out avoids a click at the end of one-shot sounds
        f = min(len(data) // 4, int(0.012 * SR))
        data[-f:] *= np.linspace(1, 0, f)
    m = np.max(np.abs(data)) or 1.0
    data = data / m * peak
    with wave.open(str(OUT / (name + '.wav')), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((np.clip(data, -1, 1) * 32767).astype('<i2').tobytes())


def tt(duration):
    return np.arange(int(duration * SR)) / SR


def lowpass(x, cutoff):
    """One-pole low-pass filter."""
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def highpass(x, cutoff):
    return x - lowpass(x, cutoff)


def reverb(x, mix=0.3, length=1.6, loop=False):
    """Cheap Schroeder-style reverb: parallel feedback combs + allpass.
    With loop=True the tail wraps around so a looping track stays seamless."""
    pad = 0 if loop else int(length * SR)
    src = np.concatenate([x, np.zeros(pad)])
    wet = np.zeros_like(src)
    n = len(src)
    for delay_ms, g in [(29.7, .80), (37.1, .78), (41.1, .76), (43.7, .74)]:
        d = int(delay_ms * SR / 1000)
        buf = src.copy()
        # iterate block-wise: y[i] = x[i] + g*y[i-d]
        passes = 3 if loop else 1
        y = np.zeros(n)
        for _ in range(passes):
            for start in range(0, n, d):
                end = min(start + d, n)
                prev = y[start - d:end - d] if start >= d else (y[n - d + start:n - d + end] if loop else 0)
                y[start:end] = buf[start:end] + g * prev
        wet += y
    wet = lowpass(wet / 4, 4200)
    return src * (1 - mix) + wet * mix


def env(t, attack=0.005, decay=1.0):
    return np.minimum(t / attack, 1) * np.exp(-t / decay)


def zheng(freq, duration=3.0, gain=1.0, bright=1.0):
    """Plucked-string tone loosely modelled on a guzheng: bright attack, slow decay, slight pitch bend."""
    t = tt(duration)
    bend = 1 + 0.004 * np.exp(-t * 6)
    y = np.zeros_like(t)
    for n in range(1, 9):
        y += np.sin(2 * np.pi * freq * n * bend * t + n) * np.exp(-t * (0.9 + n * 0.9 / bright)) / n ** 1.3
    noise = rng.normal(0, 1, len(t)) * np.exp(-t * 90) * 0.15
    return (y + noise) * gain * np.minimum(t / 0.004, 1)


def bell(freq, duration=3.0, gain=1.0):
    """Bronze bell / chime with inharmonic partials."""
    t = tt(duration)
    y = np.zeros_like(t)
    for ratio, amp, dec in [(1, 1, 1.6), (2.76, .5, .9), (5.40, .28, .5), (8.93, .16, .3), (0.5, .25, 2.2)]:
        y += amp * np.sin(2 * np.pi * freq * ratio * t) * np.exp(-t / dec)
    return y * gain * np.minimum(t / 0.002, 1)


def place(dst, src, at):
    s = int(at * SR)
    e = min(len(dst), s + len(src))
    if e > s:
        dst[s:e] += src[:e - s]


def wood_tock(freq=900, duration=0.12):
    t = tt(duration)
    y = np.sin(2 * np.pi * freq * t) * np.exp(-t * 60) + 0.5 * np.sin(2 * np.pi * freq * 2.3 * t) * np.exp(-t * 90)
    y += rng.normal(0, 1, len(t)) * np.exp(-t * 300) * 0.4
    return y


# ---------------------------------------------------------------- interaction sounds
save('click', wood_tock(1100, .1), .55)
save('hover', highpass(wood_tock(2400, .05), 800), .22)

paper = highpass(rng.normal(0, 1, int(.55 * SR)), 1500)
t = tt(.55)
paper *= (0.4 + 0.6 * np.abs(np.sin(t * 23))) * np.minimum(t / .04, 1) * np.exp(-t * 4)
note = lowpass(paper, 6000)
place(note, zheng(587.33, .5, .25), .05)
save('note', note, .6)

pickup = bell(880, 2.2)
place(pickup, bell(1318.5, 1.8, .45), .07)
save('pickup', reverb(pickup, .3), .7)

place_snd = np.zeros(int(1.6 * SR))
place(place_snd, lowpass(rng.normal(0, 1, int(.06 * SR)), 900) * 2, 0)
place(place_snd, bell(392, 1.5, .8), .01)
place(place_snd, wood_tock(300, .2) * .8, 0)
save('place', reverb(place_snd, .25), .75)

t = tt(.22)
grind = lowpass(rng.normal(0, 1, len(t)), 700) * np.sin(np.pi * t / .22) ** 2
grind += wood_tock(520, .22) * .35
save('rotate', grind, .5)

dial = wood_tock(700, .14)
place(dial, wood_tock(1250, .08) * .6, .045)
save('dial', dial, .55)

t = tt(.5)
err = (np.sin(2 * np.pi * 110 * t) + .6 * np.sin(2 * np.pi * 116.5 * t)) * env(t, .005, .12)
place(err, (np.sin(2 * np.pi * 98 * tt(.4)) * env(tt(.4), .005, .1)), .13)
save('error', lowpass(err, 1200), .6)

# reveal: soft swell + rising pentatonic chimes
reveal = np.zeros(int(4.2 * SR))
t = tt(2.0)
swell = sum(np.sin(2 * np.pi * f * t) for f in (293.66, 440, 587.33)) * np.sin(np.pi * t / 2.0) ** 2 * 0.25
place(reveal, swell, 0)
for i, f in enumerate([587.33, 659.25, 783.99, 880, 1174.66]):
    place(reveal, bell(f, 2.4, .5), .35 + i * .16)
save('reveal', reverb(reveal, .4), .75)

# unlock: three mechanical clicks then a resolving chime
unlock = np.zeros(int(3.6 * SR))
for i in range(3):
    place(unlock, wood_tock(600 + i * 120, .12) * 1.2, i * .13)
place(unlock, lowpass(rng.normal(0, 1, int(.25 * SR)), 500) * np.hanning(int(.25 * SR)) * .8, .42)
for i, f in enumerate([392, 587.33, 783.99]):
    place(unlock, bell(f, 2.6, .55), .62 + i * .09)
save('unlock', reverb(unlock, .35), .75)

# win: short guzheng phrase over bells
win = np.zeros(int(6.5 * SR))
for i, f in enumerate([293.66, 329.63, 392, 440, 587.33, 659.25, 587.33]):
    place(win, zheng(f, 3, .7), i * .22)
place(win, bell(587.33, 4, .5), 1.55)
place(win, bell(880, 4, .3), 1.6)
for f in (146.83, 220, 293.66):
    place(win, zheng(f, 4.5, .45, .6), 1.55)
save('win', reverb(win, .4), .8)

# ---------------------------------------------------------------- ambient music (seamless 48 s loop)
DUR = 48.0
music = np.zeros(int(DUR * SR))
t = tt(DUR)
# D gong pentatonic: D E F# A B
scale = [293.66, 329.63, 369.99, 440.0, 493.88, 587.33, 659.25, 739.99]
phrases = [
    [(0, 5), (1.2, 3), (2.4, 4), (4.0, 3), (6.0, 1)],
    [(0, 0), (1.0, 1), (2.0, 3), (3.6, 4), (4.4, 3), (6.0, 2)],
    [(0, 7), (1.4, 5), (2.2, 6), (3.2, 4), (5.0, 3)],
    [(0, 3), (1.2, 4), (2.4, 1), (3.6, 0), (6.2, 0)],
]
for p, phrase in enumerate(phrases):
    base = p * 12.0
    for at, idx in phrase:
        place(music, zheng(scale[idx], 4.0, .32), base + at)
        if rng.random() < .35:  # occasional grace-note echo an octave lower
            place(music, zheng(scale[idx] / 2, 3.0, .12), base + at + .6)
# low drone with slow breathing
for f, g in [(73.42, .07), (110.0, .045), (146.83, .03)]:
    music += g * np.sin(2 * np.pi * f * t + 0.5 * np.sin(2 * np.pi * t / DUR * 2)) * (0.75 + 0.25 * np.sin(2 * np.pi * t / DUR * 4))
# wrap the note tails so the loop is seamless
music = reverb(music, .35, loop=True)
save('ambient', music, .7, loop=True)

# ---------------------------------------------------------------- light rain loop (24 s)
RD = 24.0
n = int(RD * SR)
rain = lowpass(highpass(rng.normal(0, 1, n), 400), 3500) * .25
t = tt(RD)
rain *= 0.8 + 0.2 * np.sin(2 * np.pi * t / RD * 3)
for _ in range(420):  # droplets on eaves
    at = rng.uniform(0, RD - .05)
    f = rng.uniform(1800, 4200)
    d = tt(.03)
    place(rain, np.sin(2 * np.pi * f * d) * np.exp(-d * 180) * rng.uniform(.1, .5), at)
for _ in range(14):  # slower heavy drips from the roof
    at = rng.uniform(0, RD - .2)
    d = tt(.18)
    place(rain, np.sin(2 * np.pi * (700 - 900 * d) * d) * np.exp(-d * 30) * .6, at)
save('rain', rain, .5, loop=True)

print('Created interaction sounds, a ~47 s ambient loop and a ~23 s rain loop.')
