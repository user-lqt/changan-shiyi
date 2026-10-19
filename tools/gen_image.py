"""Generates one image through the YosHub OpenAI-Images endpoint.

Usage: python -I tools/gen_image.py <config.txt> <prompt.txt> <out.png> [size] [model]
The API key is read from the config file at call time and never printed.
"""
import base64
import json
import re
import sys
import urllib.request

cfg_path, prompt_path, out_path = sys.argv[1:4]
size = sys.argv[4] if len(sys.argv) > 4 else "1024x1536"
model = sys.argv[5] if len(sys.argv) > 5 else "gpt-image-2"

cfg = open(cfg_path, encoding="utf-8").read()
key = re.search(r"API Key[：:]\s*(\S+)", cfg).group(1)
base = re.search(r"API 地址[：:]\s*(\S+)", cfg).group(1).rstrip("/")
if "填写" in key or len(key) < 10:
    sys.exit("API key is still a placeholder")

prompt = open(prompt_path, encoding="utf-8").read().strip()
body = json.dumps({"model": model, "prompt": prompt, "n": 1, "size": size}).encode()
req = urllib.request.Request(base + "/v1/images/generations", data=body, method="POST",
                             headers={"Authorization": "Bearer " + key, "Content-Type": "application/json"})
try:
    with urllib.request.urlopen(req, timeout=600) as r:
        data = json.loads(r.read())
except urllib.error.HTTPError as e:
    sys.exit("HTTP %d: %s" % (e.code, e.read()[:400].decode("utf-8", "replace")))

item = data["data"][0]
if item.get("b64_json"):
    raw = base64.b64decode(item["b64_json"])
else:
    with urllib.request.urlopen(item["url"], timeout=300) as r:
        raw = r.read()
open(out_path, "wb").write(raw)
print("SAVED", out_path, len(raw), "bytes", "model", model)
