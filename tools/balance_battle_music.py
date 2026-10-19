"""Balance chapter-seven music while retaining a narrower stereo image.

Needs NumPy and FFmpeg on PATH. Original OGGs are backed up outside exported
resources; reruns always use those originals to avoid repeated lossy encoding.
"""
from pathlib import Path
import hashlib
import json
import subprocess

import numpy as np


ROOT = Path(__file__).resolve().parents[1]
AUDIT = ROOT / "tmp/audio-balance"
ORIGINALS = AUDIT / "originals"
SAMPLE_RATE = 44100
STEREO_WIDTH = 0.35
PEAK_CEILING_DBFS = -2.0


def decode(path):
    pcm = subprocess.check_output([
        "ffmpeg", "-v", "error", "-i", str(path), "-f", "f32le",
        "-acodec", "pcm_f32le", "-ac", "2", "-ar", str(SAMPLE_RATE), "-",
    ])
    return np.frombuffer(pcm, dtype="<f4").reshape(-1, 2)


def stats(audio):
    rms = np.sqrt(np.mean(audio.astype(np.float64) ** 2, axis=0))
    window_balance = []
    for start in range(0, len(audio), SAMPLE_RATE * 5):
        block = audio[start:start + SAMPLE_RATE * 5]
        levels = np.sqrt(np.mean(block.astype(np.float64) ** 2, axis=0))
        if min(levels) > 1e-4:
            window_balance.append(float(20 * np.log10(levels[0] / levels[1])))
    return {
        "samples": len(audio),
        "duration_seconds": len(audio) / SAMPLE_RATE,
        "rms_dbfs": (20 * np.log10(rms)).tolist(),
        "left_minus_right_db": float(20 * np.log10(rms[0] / rms[1])),
        "sample_peak_dbfs": float(20 * np.log10(np.abs(audio).max())),
        "channel_correlation": float(np.corrcoef(audio.T)[0, 1]),
        "five_second_balance_range_db": [min(window_balance), max(window_balance)],
        "five_second_p95_absolute_balance_db": float(np.percentile(np.abs(window_balance), 95)),
    }


def main():
    ORIGINALS.mkdir(parents=True, exist_ok=True)
    (AUDIT / ".gdignore").write_text("", encoding="utf-8")
    report = []
    for name in ["stage7", "boss7"]:
        target = ROOT / "assets/audio" / (name + ".ogg")
        original = ORIGINALS / target.name
        if not original.exists():
            with original.open("xb") as backup:
                backup.write(target.read_bytes())
        audio = decode(original)
        mid = audio.mean(axis=1)
        side = (audio[:, 0] - audio[:, 1]) * (0.5 * STEREO_WIDTH)
        balanced = np.stack([mid + side, mid - side], axis=1)
        original_power = np.mean(audio.astype(np.float64) ** 2)
        channel_rms = np.sqrt(np.mean(balanced.astype(np.float64) ** 2, axis=0))
        gains = np.sqrt(original_power) / channel_rms
        balanced *= gains
        peak_gain = min(1.0, 10 ** (PEAK_CEILING_DBFS / 20) / np.abs(balanced).max())
        balanced *= peak_gain
        candidate = AUDIT / (name + "-balanced.ogg")
        subprocess.run([
            "ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ar", str(SAMPLE_RATE),
            "-ac", "2", "-i", "pipe:0", "-c:a", "libvorbis", "-q:a", "6",
            "-metadata", "comment=Channel-balanced, stereo width 35 percent", str(candidate),
        ], input=balanced.astype("<f4").tobytes(), check=True)
        encoded = decode(candidate)
        before, after = stats(audio), stats(encoded)
        assert len(encoded) == len(audio), "Audio duration changed"
        assert abs(after["left_minus_right_db"]) < 0.1, "Channels remain unbalanced"
        assert after["sample_peak_dbfs"] <= -1.0, "Insufficient peak headroom"
        assert after["five_second_p95_absolute_balance_db"] < before["five_second_p95_absolute_balance_db"]
        assert after["channel_correlation"] < 0.999, "Stereo image was lost"
        target.write_bytes(candidate.read_bytes())
        report.append({
            "file": target.relative_to(ROOT).as_posix(),
            "original_sha256": hashlib.sha256(original.read_bytes()).hexdigest(),
            "output_sha256": hashlib.sha256(target.read_bytes()).hexdigest(),
            "stereo_width": STEREO_WIDTH,
            "channel_gains": gains.tolist(),
            "shared_peak_gain": float(peak_gain),
            "before": before, "after": after,
        })
    (AUDIT / "verification.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
