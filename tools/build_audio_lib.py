"""Shared synthesis helpers (imported by build_audio.py and build_battle_audio.py)."""
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


