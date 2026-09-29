#!/usr/bin/env python3
"""Saves the Arabic text of every Bangla hadith on HadeethEnc.com.

The dua builder (tools/build_duas.py) uses it to take a hadith dua's Arabic
exactly as HadeethEnc writes it, when the dua is found inside one of these
hadiths. Writes tools/data/hadeethenc_ar.json.gz:
  {"<id>": {"ar": hadeeth_ar, "attribution_ar": ..., "grade_ar": ...,
            "attribution": ..., "grade": ..., "title": ...}}
Only ids that are not in the file yet are downloaded.
"""
import gzip
import io
import json
import sys
import time
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
INDEX = ROOT / "tools" / "data" / "hadeethenc_bn_index.json"
OUT = ROOT / "tools" / "data" / "hadeethenc_ar.json.gz"
API = "https://hadeethenc.com/api/v1/hadeeths/one/?language=bn&id="
UA = "AyahReminderContentFetcher/1.0 (+https://github.com/ahmedehsanur8-ctrl/ayah-app)"


def fetch(i):
    last = None
    for n in range(4):
        try:
            req = urllib.request.Request(API + str(i), headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=60) as r:
                j = json.loads(r.read().decode("utf-8"))
            return str(i), {
                "ar": j.get("hadeeth_ar", ""),
                "attribution_ar": j.get("attribution_ar", ""),
                "grade_ar": j.get("grade_ar", ""),
                "attribution": j.get("attribution", ""),
                "grade": j.get("grade", ""),
                "title": j.get("title", ""),
            }
        except Exception as e:  # noqa: BLE001
            last = e
            time.sleep(2 * (n + 1))
    print(f"  failed {i}: {last}", file=sys.stderr)
    return str(i), None


def main():
    ids = [row["id"] for row in json.loads(INDEX.read_text(encoding="utf-8"))]
    have = {}
    if OUT.exists():
        have = json.loads(gzip.decompress(OUT.read_bytes()).decode("utf-8"))
    todo = [i for i in ids if str(i) not in have]
    print(f"{len(ids)} hadiths, {len(have)} saved, {len(todo)} to fetch")
    with ThreadPoolExecutor(max_workers=6) as pool:
        for n, (i, row) in enumerate(pool.map(fetch, todo), 1):
            if row and row["ar"]:
                have[i] = row
            if n % 200 == 0:
                print(f"  {n}/{len(todo)}")
    buf = io.BytesIO()
    with gzip.GzipFile(fileobj=buf, mode="wb", compresslevel=9, mtime=0) as f:
        f.write(json.dumps(have, ensure_ascii=False, sort_keys=True).encode("utf-8"))
    OUT.write_bytes(buf.getvalue())
    print(f"saved {len(have)} hadiths ({len(buf.getvalue())} bytes)")


if __name__ == "__main__":
    main()
