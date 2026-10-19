"""Generate character voice lines with Volcengine Doubao TTS 2.0 (seed-tts-2.0).

Collects every spoken character line (narration is not voiced) from the story data and the
chapter scripts, then writes assets/voice/<md5("speaker|text")>.mp3 — the same key main.gd's
voice() computes at runtime. Existing files are skipped, so re-running only fills in new or
edited lines. 镜魅 is post-processed with ffmpeg ("镜中双声": a lowered ghost voice + echo).

The API key is read from a local file outside the project and never printed.
Usage: python tools/build_voices.py [--dry-run] [--only=speaker] [--section=epilogue]
"""
import base64
import concurrent.futures
import csv
import hashlib
import json
import os
import pathlib
import re
import subprocess
import sys
import tempfile
import urllib.error
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "voice"
KEY_FILE = pathlib.Path(r"E:\CodexWorkplace\火山引擎-语音接口.txt")
URL = "https://openspeech.bytedance.com/api/v3/tts/unidirectional"

# speaker -> (voice id, instruction for the 2.0 model, dialect)
CAST = {
    "su": ("zh_female_liuchangnv_uranus_bigtts", "你是一位二十八岁的文物修复研究员，声音成熟、沉稳、干练，可以用这样的语气说吗？", ""),
    "wen": ("zh_male_m191_uranus_bigtts", "你可以用苍老、慢悠悠、有点沙哑的老人语气说吗？", "shaanxi"),
    "kang": ("ru_male_pavel_uranus_bigtts", "你可以用热情圆滑、做生意的语气说吗？", ""),
    "mi": ("ru_female_sophie_uranus_bigtts", "你可以用明亮爽朗的语气说吗？", ""),
    "ashi": ("ICL_uranus_zh_male_yuanqishaonian_tob", "你可以用机灵活泼的少年语气说吗？", ""),
    "bai": ("zh_male_ruyayichen_uranus_bigtts", "你可以用温和儒雅、从容的语气说吗？", ""),
    "zheng": ("zh_male_aojiaobazong_uranus_bigtts", "你可以用傲慢、带点轻蔑的语气说吗？", ""),
    "boss": ("zh_female_gaolengyujie_uranus_bigtts", "你可以用空灵、缓慢、带着哀伤的语气说吗？", ""),
    "seng": ("zh_male_yuanboxiaoshu_uranus_bigtts", "你可以用平和、缓慢、慈悲的僧人语气说吗？", ""),
    "jiujia": ("zh_male_liufei_uranus_bigtts", "你可以用懒洋洋、有点不耐烦的语气说吗？", ""),
}
INNER = "你可以压低声音，用自言自语的语气说吗？"
CUTIN_CONTEXT = "你是苏晴，一位冷静干练的年轻女性。现在你突然抓住了对方证言的矛盾，请以极有决断力、干脆利落、有爆发力的舞台质问语气，高声说出这句话。字头有力，情绪坚定，不要拖长尾音，不要笑，也不要念成解说或旁白。"
BOSS_FX = ("[0:a]apad=pad_dur=1.2,asplit=2[a][b];[b]asetrate=24000*0.78,aresample=24000,adelay=70|70,volume=0.55[low];"
           "[a][low]amix=inputs=2:normalize=0,aecho=0.8:0.85:90|210|380|580:0.5|0.38|0.28|0.18,"
           "chorus=0.5:0.9:40|60|80:0.35|0.3|0.25:0.3|0.4|0.5:2|1.6|1.2,highpass=f=90,volume=1.2,asetpts=N/SR/TB")


def unescape(s):
    return s.replace('\\"', '"').replace("\\n", "\n").replace("\\\\", "\\")


def collect(section=""):
    lines = []
    market = (ROOT / "scripts/chapters/ch2_market.gd").read_text(encoding="utf-8")
    cutin_match = re.search(r'const CUTIN_VOICES := (\[[^\n]+\])', market)
    cutins = [("su", text) for text in json.loads(cutin_match.group(1))] if cutin_match else []
    if section == "ch2_cutin":
        return cutins
    story = (ROOT / "scripts/data/story.gd").read_text(encoding="utf-8")
    if section:
        blocks = list(re.finditer(r'^\t"([^"]+)": \[', story, re.M))
        selected = []
        for i, block in enumerate(blocks):
            if block.group(1) == section or block.group(1).startswith(section + "_"):
                selected.append(story[block.end():blocks[i + 1].start() if i + 1 < len(blocks) else len(story)])
        story = "\n".join(selected)
    for m in re.finditer(r'\{"w": "([a-z]+)",(?: "pose": "[a-z]+",)? "t": "((?:[^"\\]|\\.)*)"', story):
        lines.append((m.group(1), unescape(m.group(2))))
    if section:
        return list(dict.fromkeys((w, t) for w, t in lines if w not in ("narr", "event") and t.strip()))
    lines.extend(cutins)
    # Chapter 2 testimony: Su presses a phrase, Kang answers.
    for m in re.finditer(r'"weak": "((?:[^"\\]|\\.)*)".*?"press": "((?:[^"\\]|\\.)*)"', story):
        lines.append(("su", "等一下！「%s」——这是什么意思？" % unescape(m.group(1))))
        lines.append(("kang", unescape(m.group(2))))
    # Chapter 1: Wen's context hints.
    ch1 = (ROOT / "scripts/chapters/ch1_workshop.gd").read_text(encoding="utf-8")
    body = ch1[ch1.index("func _talk_wen"):]
    body = body[:body.index("\nfunc ", 10)]
    for m in re.finditer(r'line(?: :)?= "((?:[^"\\]|\\.)*)"', body):
        lines.append(("wen", unescape(m.group(1))))
    # Direct g.voice("speaker", "text") calls in chapter scripts.
    for f in (ROOT / "scripts/chapters").glob("*.gd"):
        for m in re.finditer(r'g\.voice\("([a-z]+)", "((?:[^"\\]|\\.)*)"\)', f.read_text(encoding="utf-8")):
            lines.append((m.group(1), unescape(m.group(2))))
    # Timed cinematic cues use the same speaker/text keys as story dialogue.
    film_voice = (ROOT / "scripts/core/film_voice.gd").read_text(encoding="utf-8")
    for m in re.finditer(r'"w": "([a-z]+)", "t": "((?:[^"\\]|\\.)*)"', film_voice):
        lines.append((m.group(1), unescape(m.group(2))))
    seen, out = set(), []
    for w, t in lines:
        if w in ("narr", "event") or not t.strip() or (w, t) in seen:
            continue
        seen.add((w, t))
        out.append((w, t))
    return out


def key_of(w, t):
    return hashlib.md5(("%s|%s" % (w, t)).encode("utf-8")).hexdigest()


def normalize_cutin(path):
    """Give brief stage exclamations a clear, repeatable level with peak headroom."""
    scan = subprocess.run(["ffmpeg", "-hide_banner", "-i", str(path), "-af", "volumedetect", "-f", "null", "-"],
                          check=True, capture_output=True, text=True, encoding="utf-8", errors="replace")
    peak = float(re.search(r"max_volume: ([\d.-]+) dB", scan.stderr).group(1))
    adjustment = -4.0 - peak
    if abs(adjustment) < 0.3:
        return
    with tempfile.TemporaryDirectory() as tmp:
        dst = pathlib.Path(tmp) / "cutin.mp3"
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(path), "-af", f"volume={adjustment:.2f}dB",
                        "-ar", "24000", "-ac", "1", "-b:a", "128k", str(dst)], check=True)
        path.write_bytes(dst.read_bytes())


def tts(api_key, w, t):
    voice, ctx, dialect = CAST[w]
    if w == "su" and t in ("不对！", "你露出马脚了！", "我有异议！"):
        ctx = CUTIN_CONTEXT
    spoken = t.strip()
    if spoken.startswith("（") and spoken.endswith("）"):
        ctx = INNER
    spoken = spoken.replace("（", "").replace("）", "，").strip("，")
    add = {}
    if ctx:
        add["context_texts"] = [ctx]
    if dialect:
        add["explicit_dialect"] = dialect
    body = {"user": {"uid": "changan"}, "req_params": {"text": spoken, "speaker": voice,
            "audio_params": {"format": "mp3", "sample_rate": 24000}}}
    if add:
        body["req_params"]["additions"] = json.dumps(add, ensure_ascii=False)
    req = urllib.request.Request(URL, data=json.dumps(body).encode(), method="POST", headers={
        "X-Api-Key": api_key, "X-Api-Resource-Id": "seed-tts-2.0", "Content-Type": "application/json"})
    audio = b""
    with urllib.request.urlopen(req, timeout=90) as r:
        for raw in r.read().decode("utf-8").splitlines():
            raw = raw.strip()
            if not raw:
                continue
            d = json.loads(raw)
            if d.get("data"):
                audio += base64.b64decode(d["data"])
            elif d.get("code") not in (0, 20000000, None):
                raise RuntimeError("TTS error %s %s" % (d.get("code"), d.get("message")))
    if not audio:
        raise RuntimeError("no audio returned")
    return audio


def build_one(api_key, w, t):
    dst = OUT / (key_of(w, t) + ".mp3")
    if dst.exists():
        return "skip"
    audio = tts(api_key, w, t)
    if w == "boss":
        with tempfile.TemporaryDirectory() as tmp:
            raw = pathlib.Path(tmp) / "raw.mp3"
            wav = pathlib.Path(tmp) / "raw.wav"
            raw.write_bytes(audio)
            # Decode to WAV first: filtering the MP3 directly gives broken timestamps.
            subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(raw), "-ar", "24000", "-ac", "1", str(wav)], check=True)
            subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav), "-filter_complex", BOSS_FX, "-ar", "24000", str(dst)], check=True)
    else:
        dst.write_bytes(audio)
        if w == "su" and t in ("不对！", "你露出马脚了！", "我有异议！"):
            normalize_cutin(dst)
    return "made"


def main():
    dry = "--dry-run" in sys.argv
    only = next((a.split("=", 1)[1] for a in sys.argv if a.startswith("--only=")), "")
    section = next((a.split("=", 1)[1] for a in sys.argv if a.startswith("--section=")), "")
    all_lines = collect()
    lines = [(w, t) for w, t in (collect(section) if section else all_lines) if not only or w == only]
    unknown = sorted({w for w, _ in lines if w not in CAST})
    if unknown:
        raise SystemExit("no voice cast for: " + ", ".join(unknown))
    OUT.mkdir(parents=True, exist_ok=True)
    manifest = ROOT / "docs/ai-records/voice_lines.csv"
    with manifest.open("w", encoding="utf-8-sig", newline="") as f:
        wr = csv.writer(f)
        wr.writerow(["file", "speaker", "voice", "text"])
        for w, t in all_lines:
            wr.writerow([key_of(w, t) + ".mp3", w, CAST[w][0], t])
    chars = sum(len(t) for _, t in lines)
    print("%d lines, %d characters; manifest %s" % (len(lines), chars, manifest.relative_to(ROOT)))
    if dry:
        for w in CAST:
            print("  %-7s %d" % (w, sum(1 for x, _ in lines if x == w)))
        return
    api_key = os.environ.get("VOLCENGINE_TTS_API_KEY", "")
    if not api_key:
        for ln in KEY_FILE.read_text(encoding="utf-8-sig").splitlines():
            if ln.startswith("API_KEY="):
                api_key = ln.split("=", 1)[1].strip()
    if not api_key:
        raise SystemExit("Set VOLCENGINE_TTS_API_KEY or configure the local voice API file.")
    made = skipped = failed = 0
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        jobs = {pool.submit(build_one, api_key, w, t): (w, t) for w, t in lines}
        for job in concurrent.futures.as_completed(jobs):
            w, t = jobs[job]
            try:
                r = job.result()
                made += r == "made"
                skipped += r == "skip"
            except (urllib.error.URLError, RuntimeError, subprocess.CalledProcessError) as e:
                failed += 1
                print("FAILED %s %s: %s" % (w, t[:20], e))
    print("made %d, skipped %d, failed %d" % (made, skipped, failed))
    if failed:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
