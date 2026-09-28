#!/usr/bin/env python3
"""Finds a freely licensed azan recording on Wikimedia Commons and bundles it.

  python3 tools/azan_audio.py list   # licence, author and length of each file in Category:Adhan
  python3 tools/azan_audio.py fetch  # download the file named in tools/azan_choice.txt

Only public-domain / CC0 / CC BY / CC BY-SA files are accepted. The chosen file
is converted to mono MP3 and saved as android/app/src/main/res/raw/azan.mp3,
with its licence details in assets/azan_license.json (shown in the credits).
"""
import json
import re
import subprocess
import sys
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CHOICE = ROOT / "tools" / "azan_choice.txt"
OUT = ROOT / "android" / "app" / "src" / "main" / "res" / "raw" / "azan.mp3"
LICENSE_OUT = ROOT / "assets" / "azan_license.json"
API = "https://commons.wikimedia.org/w/api.php"
UA = "AyahReminderAzan/1.0 (+https://github.com/ahmedehsanur8-ctrl/ayah-app)"
ALLOWED = re.compile(r"^(cc0|pd|public domain|cc[- ]by(-sa)?[- ]?\d)", re.I)


def api(**params):
    params.update(format="json", formatversion="2")
    url = f"{API}?{urllib.parse.urlencode(params)}"
    with urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": UA}), timeout=60) as r:
        return json.load(r)


def strip(html):
    return re.sub(r"<[^>]+>", "", html or "").strip()


def info(titles):
    res = api(action="query", prop="imageinfo", titles="|".join(titles),
              iiprop="url|size|mime|extmetadata|mediatype")
    out = []
    for p in res["query"]["pages"]:
        ii = (p.get("imageinfo") or [{}])[0]
        md = ii.get("extmetadata", {})
        g = lambda k: strip(md.get(k, {}).get("value", ""))  # noqa: E731
        out.append({"title": p["title"], "url": ii.get("url"), "mime": ii.get("mime"),
                    "size": ii.get("size"), "duration": ii.get("duration"),
                    "license": g("LicenseShortName"), "licenseUrl": g("LicenseUrl"),
                    "artist": g("Artist"), "credit": g("Credit"),
                    "description": g("ImageDescription")[:300],
                    "usageTerms": g("UsageTerms"), "copyrighted": g("Copyrighted")})
    return out


def cmd_list():
    members = api(action="query", list="categorymembers", cmtitle="Category:Adhan",
                  cmtype="file", cmlimit="200")["query"]["categorymembers"]
    titles = [m["title"] for m in members if re.search(r"\.(ogg|oga|mp3|wav|opus|flac|webm)$",
                                                        m["title"], re.I)]
    rows = []
    for i in range(0, len(titles), 40):
        rows += info(titles[i:i + 40])
    for r in rows:
        ok = bool(ALLOWED.match(r["license"] or ""))
        print(f"{'OK ' if ok else '-- '}{r['title']} | {r['license']} | {r['duration']}s | "
              f"{r['size']} B | by: {r['artist'][:80]} | {r['description'][:120]}")
    (ROOT / "tools" / "data").mkdir(exist_ok=True)
    (ROOT / "tools" / "data" / "azan_candidates.json").write_text(
        json.dumps(rows, ensure_ascii=False, indent=1), encoding="utf-8")


def cmd_fetch():
    if not CHOICE.exists():
        print("No tools/azan_choice.txt; nothing to fetch.")
        return
    title = CHOICE.read_text(encoding="utf-8").strip().splitlines()[0].strip()
    r = info([title])[0]
    print(json.dumps(r, ensure_ascii=False, indent=1))
    if not ALLOWED.match(r["license"] or ""):
        raise SystemExit(f"Licence '{r['license']}' is not free enough; not using {title}.")
    src = ROOT / "azan_src"
    with urllib.request.urlopen(urllib.request.Request(r["url"], headers={"User-Agent": UA}),
                                timeout=120) as resp:
        src.write_bytes(resp.read())
    OUT.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(src), "-ac", "1",
                    "-ar", "44100", "-b:a", "64k", str(OUT)], check=True)
    src.unlink()
    LICENSE_OUT.write_text(json.dumps({
        "title": r["title"], "source": f"https://commons.wikimedia.org/wiki/{urllib.parse.quote(r['title'].replace(' ', '_'))}",
        "license": r["license"], "licenseUrl": r["licenseUrl"], "author": r["artist"],
        "credit": r["credit"]}, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"Saved {OUT} ({OUT.stat().st_size} bytes)")


if __name__ == "__main__":
    {"list": cmd_list, "fetch": cmd_fetch}[sys.argv[1] if len(sys.argv) > 1 else "list"]()
