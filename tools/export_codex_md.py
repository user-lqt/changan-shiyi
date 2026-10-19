"""Regenerate docs/culture/长安拾遗录-内容与出处.md from scripts/data/codex.gd.

The GDScript dictionaries in codex.gd are JSON-compatible apart from trailing commas.
Usage: python tools/export_codex_md.py
"""
import json
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "scripts/data/codex.gd"
OUT = ROOT / "docs/culture/长安拾遗录-内容与出处.md"


def block(text, name, opener, closer):
    start = text.index("const %s := %s" % (name, opener)) + len("const %s := " % name)
    depth, i = 0, start
    while True:
        c = text[i]
        if c == opener:
            depth += 1
        elif c == closer:
            depth -= 1
            if depth == 0:
                break
        i += 1
    raw = text[start:i + 1]
    raw = re.sub(r",(\s*[\]}])", r"\1", raw)
    return json.loads(raw)


def main():
    text = SRC.read_text(encoding="utf-8")
    cats = block(text, "CATEGORIES", "[", "]")
    sources = block(text, "SOURCES", "{", "}")
    entries = block(text, "ENTRIES", "[", "]")
    chars = sum(len(s[1]) for e in entries for s in e["sections"])
    out = ["# 长安拾遗录 · 内容与出处", "",
           "通关尾声后，从标题页进入。共 %d 项，正文约 %d 字；按%s四类浏览。人物条目标明历史人物或虚构设定。" % (len(entries), chars, "、".join(cats)), "",
           "文化说明是依据古籍、馆藏目录与相关研究写成的概述；配图沿用游戏美术，不作考古复原或真实文物照片使用。", ""]
    for ci, cat in enumerate(cats):
        out += ["## " + cat, ""]
        for e in entries:
            if e["category"] != ci:
                continue
            out += ["### %s · %s" % (e["title"], e["tag"]), "", "**%s**" % e["key"], ""]
            for title, body in e["sections"]:
                out += ["**%s**" % title, "", body, ""]
            out += ["出处：" + "；".join(sources[s]["title"] for s in e["sources"]), ""]
    out += ["## 阅读来源", ""]
    for s in sources.values():
        out.append("- [%s](%s)" % (s["title"], s["url"]) if s["url"] else "- " + s["title"])
    out += ["", "古籍在线文本通过维基文库公开版本核对；馆藏资料通过克利夫兰艺术博物馆公开目录核对。现代研究著作列为进一步阅读，不附未经核实的网页地址。", ""]
    OUT.write_text("\n".join(out), encoding="utf-8")
    print("wrote", OUT.relative_to(ROOT), len(entries), "entries", chars, "chars")


if __name__ == "__main__":
    main()
