"""Synthesise the three cue sounds that replaced the old Windows-TTS narration clips.

  intro.wav     prologue scan start: a rising hum with a soft shimmer (about 4 s)
  revealed.wav  ch1 wall reveal: bronze-mirror chime cluster with a long tail (about 3 s)
  complete.wav  ch4 / ch5 success: a pentatonic bell arpeggio (about 2.5 s)
Usage: python tools/build_cue_sfx.py
"""
import pathlib
import wave

import numpy as np

SR = 22050
OUT = pathlib.Path(__file__).resolve().parent.parent / "assets" / "audio"


def bell(f, t, decay):
    # Inharmonic partials give a bronze, bell-like tone.
    s = np.zeros_like(t)
    for ratio, amp in [(1.0, 1.0), (2.76, 0.45), (5.4, 0.22), (8.93, 0.1)]:
        s += amp * np.sin(2 * np.pi * f * ratio * t) * np.exp(-t * decay * ratio ** 0.5)
    return s


def write(name, s):
    s = s / (np.abs(s).max() + 1e-9) * 0.8
    pcm = (s * 32767).astype(np.int16)
    with wave.open(str(OUT / name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print("wrote", name, "%.1fs" % (len(s) / SR))


def intro():
    t = np.arange(int(SR * 4.0)) / SR
    f = 110 + 220 * (t / 4.0) ** 2
    hum = np.sin(2 * np.pi * np.cumsum(f) / SR) + 0.4 * np.sin(4 * np.pi * np.cumsum(f) / SR)
    env = np.clip(t / 2.5, 0, 1) * np.clip((4.0 - t) / 0.6, 0, 1)
    rng = np.random.default_rng(3)
    shimmer = np.convolve(rng.standard_normal(len(t)), np.ones(6) / 6, "same") * np.clip((t - 1.5) / 2.5, 0, 1) * 0.15
    return (hum * 0.6 + shimmer) * env


def revealed():
    t = np.arange(int(SR * 3.2)) / SR
    s = np.zeros_like(t)
    for i, f in enumerate([1046.5, 1318.5, 1568.0, 2093.0]):
        d = int(i * 0.09 * SR)
        s[d:] += bell(f, t[: len(t) - d], 1.6) * (0.9 - i * 0.12)
    return s


def complete():
    t = np.arange(int(SR * 2.6)) / SR
    s = np.zeros_like(t)
    for i, f in enumerate([523.25, 659.25, 783.99, 1046.5, 1318.5]):
        d = int(i * 0.12 * SR)
        s[d:] += bell(f, t[: len(t) - d], 2.0)
    return s


if __name__ == "__main__":
    write("intro.wav", intro())
    write("revealed.wav", revealed())
    write("complete.wav", complete())
