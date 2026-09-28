#!/usr/bin/env python3
"""Downloads the full Quran for the app's Quran section.

Text is copied exactly as the sources return it, never edited.

  * Arabic            : Tanzil.net, Uthmani script (+ surah / juz metadata)
  * Bangla, bundled   : QuranEnc.com, Dr. Abu Bakr Muhammad Zakaria (bengali_zakaria),
                        with his footnotes
  * Bangla, download  : QuranEnc.com, Rowwad Translation Center (bengali_rwwad)
                        Tanzil.net, Muhiuddin Khan (bn.bengali)
                        Tanzil.net, Zohurul Hoque (bn.hoque)

Writes
  assets/quran/meta.json          surahs, juz starts, source / licence info
  assets/quran/arabic.txt.gz      6236 lines, Tanzil Uthmani
  assets/quran/bn_zakaria.json.gz {"verses": [[translation, footnotes], ...]}
  build/quran-data/*.json.gz      the downloadable translations (uploaded to the
                                  "quran-data" GitHub release by the workflow)
  tools/data/quran_report.txt     counts, versions and a few sample lines
"""
import gzip
import io
import json
import re
import sys
import time
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "assets" / "quran"
DIST = ROOT / "build" / "quran-data"
REPORT = ROOT / "tools" / "data" / "quran_report.txt"

TANZIL_TEXT_URL = (
    "https://tanzil.net/pub/download/index.php?"
    "marks=true&sajdah=true&rub=false&tatweel=true&quranType=uthmani"
    "&outType=txt-2&agree=true"
)
TANZIL_META_URL = "https://tanzil.net/res/text/metadata/quran-data.js"
QURANENC_API = "https://quranenc.com/api/v1"
UA = "AyahReminderContentFetcher/1.0 (+https://github.com/ahmedehsanur8-ctrl/ayah-app)"
TOTAL = 6236

# id -> how to get it. "bundled" ones go into the APK, the others are downloads.
TRANSLATIONS = [
    {"id": "bn_zakaria", "source": "quranenc", "key": "bengali_zakaria", "bundled": True,
     "name": "ড. আবু বকর মুহাম্মাদ যাকারিয়া", "nameEn": "Dr. Abu Bakr Muhammad Zakaria"},
    {"id": "bn_rwwad", "source": "quranenc", "key": "bengali_rwwad", "bundled": False,
     "name": "রোয়াদ অনুবাদ কেন্দ্র", "nameEn": "Rowwad Translation Center"},
    {"id": "bn_muhiuddin", "source": "tanzil", "key": "bn.bengali", "bundled": False,
     "name": "মুহিউদ্দীন খান", "nameEn": "Muhiuddin Khan"},
    {"id": "bn_hoque", "source": "tanzil", "key": "bn.hoque", "bundled": False,
     "name": "জহুরুল হক", "nameEn": "Zohurul Hoque"},
]

log = []


def say(msg):
    print(msg)
    log.append(msg)


def fetch(url, tries=5):
    last = None
    for i in range(tries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=90) as r:
                return r.read().decode("utf-8")
        except Exception as e:  # noqa: BLE001
            last = e
            print(f"  retry {i + 1} for {url}: {e}", file=sys.stderr)
            time.sleep(2 * (i + 1))
    raise RuntimeError(f"could not download {url}: {last}")


def write_gz(path, data: bytes):
    path.parent.mkdir(parents=True, exist_ok=True)
    buf = io.BytesIO()
    # mtime=0 so an unchanged text gives an identical file (no empty commits).
    with gzip.GzipFile(fileobj=buf, mode="wb", compresslevel=9, mtime=0) as f:
        f.write(data)
    path.write_bytes(buf.getvalue())
    return len(buf.getvalue())


# ------------------------------------------------------------------ Tanzil

def load_arabic():
    raw = fetch(TANZIL_TEXT_URL)
    verses, header = {}, []
    for line in raw.splitlines():
        if not line.strip():
            continue
        if line.startswith("#"):
            header.append(line)
            continue
        parts = line.split("|", 2)
        if len(parts) == 3 and parts[0].isdigit():
            verses[(int(parts[0]), int(parts[1]))] = parts[2]
    if len(verses) != TOTAL:
        raise RuntimeError(f"Tanzil text has {len(verses)} verses, expected {TOTAL}")
    return verses, "\n".join(header)


def load_meta():
    js = fetch(TANZIL_META_URL)
    block = js[js.index("QuranData.Sura"):]
    block = block[:block.index("];")]
    surahs = []
    for m in re.finditer(
        r"\[\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*'([^']*)'\s*,\s*\"([^\"]*)\"\s*,"
        r"\s*'([^']*)'\s*,\s*'([^']*)'",
        block,
    ):
        surahs.append({
            "n": len(surahs) + 1,
            "start": int(m.group(1)),
            "ayahs": int(m.group(2)),
            "order": int(m.group(3)),
            "ar": m.group(5),
            "tr": m.group(6),
            "en": m.group(7),
            "type": m.group(8),
        })
    if len(surahs) != 114:
        raise RuntimeError(f"parsed {len(surahs)} surahs from Tanzil metadata")
    jblock = js[js.index("QuranData.Juz"):]
    jblock = jblock[:jblock.index("];")]
    juz = [[int(a), int(b)] for a, b in re.findall(r"\[\s*(\d+)\s*,\s*(\d+)\s*\]", jblock)]
    juz = juz[:30]
    if len(juz) != 30:
        raise RuntimeError(f"parsed {len(juz)} juz from Tanzil metadata")
    return surahs, juz


def load_tanzil_translation(key):
    last = None
    for url in (f"https://tanzil.net/trans/?transID={key}&type=txt-2",
                f"https://tanzil.net/trans/{key}",
                f"https://tanzil.net/trans/?transID={key}&type=txt"):
        try:
            raw = fetch(url, tries=3)
        except Exception as e:  # noqa: BLE001
            last = e
            continue
        header, lines = [], []
        for line in raw.splitlines():
            if line.startswith("#"):
                header.append(line)
            elif line.strip():
                lines.append(line)
        numbered = {}
        for line in lines:
            parts = line.split("|", 2)
            if len(parts) == 3 and parts[0].isdigit() and parts[1].isdigit():
                numbered[(int(parts[0]), int(parts[1]))] = parts[2]
        if len(numbered) == TOTAL:
            say(f"{key}: {url} (numbered lines)")
            return numbered, "\n".join(header), url
        if len(lines) == TOTAL and not numbered:
            say(f"{key}: {url} (one line per ayah)")
            return lines, "\n".join(header), url
        last = f"{url}: {len(lines)} lines, {len(numbered)} numbered"
        say(f"  {last}")
    raise RuntimeError(f"Tanzil translation {key}: {last}")


# ---------------------------------------------------------------- QuranEnc

def quranenc_info(key):
    """The QuranEnc list entry (title, version, last_update) for [key]."""
    for url in (f"{QURANENC_API}/translations/list/bn",
                f"{QURANENC_API}/translations/list/bn?localization=en",
                f"{QURANENC_API}/translations/list?language=bn",
                f"{QURANENC_API}/translations/list/ben",
                f"{QURANENC_API}/translations/list/bengali",
                f"{QURANENC_API}/translations/list?page=2",
                f"{QURANENC_API}/translations/list?limit=1000",
                f"{QURANENC_API}/translations/list?per_page=1000",
                f"{QURANENC_API}/translations/list"):
        try:
            data = json.loads(fetch(url, tries=3))
        except Exception as e:  # noqa: BLE001
            say(f"  {url}: {e}")
            continue
        items = data.get("translations", []) if isinstance(data, dict) else data
        for t in items:
            if isinstance(t, dict) and t.get("key") == key:
                return t
        say(f"  {url}: {key} not in {len(items)} entries; languages: "
            f"{sorted({str(t.get('language_iso_code')) for t in items if isinstance(t, dict)})[:80]}")
    # The translation's own page shows the version ("Version: 1.0.x") and title.
    for lang in ("en", "bn"):
        url = f"https://quranenc.com/{lang}/browse/{key}"
        try:
            html = fetch(url, tries=2)
        except Exception as e:  # noqa: BLE001
            say(f"  {url}: {e}")
            continue
        text = re.sub(r"\s+", " ", re.sub(r"<[^>]+>", " ", html))
        i = text.lower().find("version")
        if i < 0:
            i = text.find("সংস্করণ")
        say(f"  {url}: ...{text[max(0, i - 200):i + 200] if i >= 0 else text[:300]}...")
        for near in re.finditer(r"(?:[Vv]ersion|সংস্করণ|إصدار|الإصدار)", text):
            say(f"    near: {text[near.start():near.start() + 80]}")
        m = re.search(r"(?:[Vv]ersion|সংস্করণ|إصدار|الإصدار)\D{0,60}?(\d+(?:\.\d+){1,3})", text)
        t = re.search(r"<title>\s*(.*?)\s*</title>", html, re.S)
        if m:
            return {"key": key, "version": m.group(1),
                    "title": re.sub(r"\s+", " ", t.group(1)) if t else ""}
    return {"key": key}


def load_quranenc(key, surahs):
    out = {}
    for s in surahs:
        res = json.loads(fetch(f"{QURANENC_API}/translation/sura/{key}/{s['n']}"))
        if s["n"] == 1:
            say(f"  {key} sura response keys: {list(res)}; "
                f"{ {k: v for k, v in res.items() if k != 'result'} }")
        for v in res["result"]:
            if v.get("sura") is None:
                continue
            out[(int(v["sura"]), int(v["aya"]))] = (
                v.get("translation") or "", (v.get("footnotes") or "").strip())
    if len(out) != TOTAL:
        raise RuntimeError(f"QuranEnc {key}: {len(out)} verses, expected {TOTAL}")
    return out


# -------------------------------------------------------------------- main

def ordered(surahs):
    return [(s["n"], a) for s in surahs for a in range(1, s["ayahs"] + 1)]


def main():
    surahs, juz = load_meta()
    order = ordered(surahs)
    assert len(order) == TOTAL, len(order)
    arabic, tanzil_header = load_arabic()
    for k in order:
        if k not in arabic:
            raise RuntimeError(f"Arabic missing {k}")
    size = write_gz(ASSETS / "arabic.txt.gz", "\n".join(arabic[k] for k in order).encode())
    say(f"arabic.txt.gz: {size} bytes")

    translations = []
    for t in TRANSLATIONS:
        info = {k: t[k] for k in ("id", "name", "nameEn", "bundled", "source", "key")}
        if t["source"] == "quranenc":
            q = quranenc_info(t["key"])
            info.update({
                "title": q.get("title", ""),
                "description": q.get("description", ""),
                "version": q.get("version", ""),
                "lastUpdate": q.get("last_update", ""),
                "url": f"https://quranenc.com/bn/browse/{t['key']}",
                "publisher": "QuranEnc.com",
            })
            verses = load_quranenc(t["key"], surahs)
            rows = [list(verses[k]) for k in order]
        else:
            verses, header, url = load_tanzil_translation(t["key"])
            rows = [[verses[k]] for k in order] if isinstance(verses, dict) else [[v] for v in verses]
            info.update({
                "url": f"https://tanzil.net/trans/{t['key']}",
                "downloadedFrom": url,
                "publisher": "Tanzil.net",
                "licenseHeader": header,
                "terms": "Tanzil translations are for non-commercial use only, "
                         "with the source indicated.",
            })
        notes = sum(1 for r in rows if len(r) > 1 and r[1])
        body = json.dumps({"info": info, "verses": rows}, ensure_ascii=False,
                          separators=(",", ":")).encode()
        if t["bundled"]:
            size = write_gz(ASSETS / f"{t['id']}.json.gz", body)
        else:
            size = write_gz(DIST / f"{t['id']}.json.gz", body)
        info["size"] = size
        translations.append(info)
        say(f"{t['id']}: {len(rows)} verses, {notes} with footnotes, {size} bytes gz, "
            f"version {info.get('version', '')!r}")
        say(f"  2:255 = {rows[order.index((2, 255))][0][:160]}")

    meta = {
        "generatedAt": datetime.now(timezone.utc).replace(microsecond=0).isoformat(),
        "total": TOTAL,
        "surahs": surahs,
        "juz": juz,
        "arabic": {
            "name": "Tanzil Quran Text", "type": "Uthmani", "url": "https://tanzil.net",
            "licenseHeader": tanzil_header,
            "version": (re.search(r"Version ([\d.]+)", tanzil_header) or [None, ""])[1],
        },
        "translations": translations,
    }
    ASSETS.mkdir(parents=True, exist_ok=True)
    (ASSETS / "meta.json").write_text(
        json.dumps(meta, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    REPORT.parent.mkdir(parents=True, exist_ok=True)
    samples = [f"{s}:{a} {arabic[(s, a)]}" for s, a in [(1, 1), (2, 1), (2, 255), (9, 1), (114, 6)]]
    REPORT.write_text("\n".join(log + samples) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
