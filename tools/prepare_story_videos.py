"""Convert original story clips to Godot's native Ogg Theora format.

Usage: python tools/prepare_story_videos.py --ffmpeg /path/to/ffmpeg
For the opening only, add --prologue-source video/your-clip.mp4.
Newer 'v01 (2).mp4' names take priority over 'v01.mp4', and likewise V02–V04.
Keep the source resolution, frame rate and complete composition.
"""

from concurrent.futures import ThreadPoolExecutor
from hashlib import sha256
from pathlib import Path
import argparse
import json
import os
import subprocess


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "output" / "video-integration"
CLIPS = {
    "v01": "ch6/echo.ogv",
    "v02": "ch6/reveal.ogv",
    "v03": "epilogue/return.ogv",
    "v04": "epilogue/memory.ogv",
}


def probe(path):
    return json.loads(subprocess.check_output([
        "ffprobe", "-v", "error", "-show_entries",
        "format=duration:stream=codec_name,width,height,r_frame_rate,channels,sample_rate",
        "-of", "json", str(path),
    ]))


def convert(item, ffmpeg, source=None):
    clip_id, relative = item
    original = source
    if original is None:
        original = ROOT / "video" / f"{clip_id} (2).mp4"
        if not original.exists():
            original = ROOT / "video" / f"{clip_id}.mp4"
    destination = ROOT / "assets" / "videos" / relative
    temporary = OUTPUT / f"{clip_id}-1080p.ogv"
    subprocess.run([
        ffmpeg, "-hide_banner", "-loglevel", "warning", "-y",
        "-i", str(original), "-map", "0:v:0", "-map", "0:a:0?",
        "-vf", "setsar=1", "-c:v", "libtheora", "-q:v", "10",
        "-pix_fmt", "yuv420p", "-c:a", "libvorbis", "-q:a", "6",
        str(temporary),
    ], check=True)
    # A successful encode alone does not catch corrupt interframes. Decode it all.
    subprocess.run([
        ffmpeg, "-hide_banner", "-loglevel", "error", "-xerror",
        "-i", str(temporary), "-f", "null", "-",
    ], check=True)
    return {
        "source": str(original.relative_to(ROOT)),
        "source_sha256": sha256(original.read_bytes()).hexdigest(),
        "destination": str(destination.relative_to(ROOT)),
        "bytes": temporary.stat().st_size,
        "metadata": probe(temporary),
        "temporary": str(temporary),
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ffmpeg", default=os.environ.get("STORY_FFMPEG", "ffmpeg"))
    parser.add_argument("--prologue-source", type=Path)
    args = parser.parse_args()
    encoder = subprocess.check_output([args.ffmpeg, "-version"], text=True).splitlines()[0]
    OUTPUT.mkdir(parents=True, exist_ok=True)
    if args.prologue_source:
        source = args.prologue_source.resolve()
        results = [convert(("v05", "prologue/arrival.ogv"), args.ffmpeg, source)]
    else:
        with ThreadPoolExecutor(max_workers=2) as pool:
            results = list(pool.map(lambda item: convert(item, args.ffmpeg), CLIPS.items()))
    # Install only once all requested conversions succeeded.
    for result in results:
        destination = ROOT / result["destination"]
        destination.parent.mkdir(parents=True, exist_ok=True)
        os.replace(result.pop("temporary"), destination)
        result["encoder"] = encoder
        result["full_decode_verified"] = True
        print(json.dumps(result, ensure_ascii=False), flush=True)
    manifest = "prologue-video.json" if args.prologue_source else "converted-videos.json"
    (OUTPUT / manifest).write_text(
        json.dumps(results, ensure_ascii=False, indent=2) + "\n", encoding="utf-8",
    )


if __name__ == "__main__":
    main()
