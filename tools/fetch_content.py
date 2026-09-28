#!/usr/bin/env python3
"""Downloads all app content and writes assets/content.json.

Sources (text is copied exactly as the sources return it, never edited):
  * Arabic Quran text : Tanzil.net, Uthmani script
  * Bangla ayah text  : QuranEnc.com API, Abu Bakr Zakaria translation
  * Hadith (ar/bn/explanation): HadeethEnc.com API

Usage:
  python3 tools/fetch_content.py index   # list every Bangla hadith on HadeethEnc
  python3 tools/fetch_content.py details # full text of ids in tools/hadith_candidates.txt
  python3 tools/fetch_content.py build   # write assets/content.json

The list of ayahs and hadiths comes from ayah-app-content-list.md; the moods
(with full surahs) come from mood-content.md.
Which HadeethEnc hadith matches each sunnah.com reference is recorded by hand
in tools/hadith_map.json (null = not on HadeethEnc, so it is skipped).
"""
import json
import re
import sys
import time
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LIST_FILE = ROOT / "ayah-app-content-list.md"
MOOD_FILE = ROOT / "mood-content.md"
MAP_FILE = ROOT / "tools" / "hadith_map.json"
DATA_DIR = ROOT / "tools" / "data"
OUT_FILE = ROOT / "assets" / "content.json"

TANZIL_TEXT_URL = (
    "https://tanzil.net/pub/download/index.php?"
    "marks=true&sajdah=true&rub=false&tatweel=true&quranType=uthmani"
    "&outType=txt-2&agree=true"
)
TANZIL_META_URL = "https://tanzil.net/res/text/metadata/quran-data.js"
QURANENC_API = "https://quranenc.com/api/v1"
QURANENC_KEY = "bengali_zakaria"  # Abu Bakr Zakaria, Bangla
HADEETHENC_API = "https://hadeethenc.com/api/v1"
UA = "AyahReminderContentFetcher/1.0 (+https://github.com/ahmedehsanur8-ctrl/ayah-app)"

PLACEHOLDER = "[ডাউনলোড করা যায়নি — এই লেখাটি পরে যোগ করতে হবে]"


def fetch(url, tries=5):
    last = None
    for i in range(tries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=60) as r:
                return r.read().decode("utf-8")
        except Exception as e:  # noqa: BLE001
            last = e
            print(f"  retry {i + 1} for {url}: {e}", file=sys.stderr)
            time.sleep(2 * (i + 1))
    raise RuntimeError(f"could not download {url}: {last}")


def fetch_json(url):
    return json.loads(fetch(url))


# ---------------------------------------------------------------- list file

def parse_list():
    text = LIST_FILE.read_text(encoding="utf-8")
    ayah_cats, hadith_themes = [], []
    section = None
    for line in text.splitlines():
        line = line.strip()
        if line.upper().startswith("AYAH LIST"):
            section = "ayah"
            continue
        if line.upper().startswith("HADITH LIST"):
            section = "hadith"
            continue
        if section == "ayah":
            m = re.match(r"^(\d+)\.\s*(.+?)\s*\((.+?)\)\s*:\s*(.+)$", line)
            if not m:
                continue
            refs = []
            for s, a, b in re.findall(r"(\d+):(\d+)(?:-(\d+))?", m.group(4)):
                refs.append((int(s), int(a), int(b) if b else int(a)))
            ayah_cats.append({"id": f"A{m.group(1)}", "name": m.group(2),
                              "nameEn": m.group(3), "refs": refs})
        elif section == "hadith":
            m = re.match(r"^(H\d+)\.\s*(.+?)\s*:\s*(.+)$", line)
            if not m:
                continue
            refs = [r.strip() for r in m.group(3).split(",") if r.strip()]
            hadith_themes.append({"id": m.group(1), "name": m.group(2), "refs": refs})
    return ayah_cats, hadith_themes


def parse_moods():
    """Moods from mood-content.md: ayah refs, full surahs and hadith refs.
    A hadith marked (H) needs a scholar to check its grade."""
    if not MOOD_FILE.exists():
        return []
    moods, cur = [], None
    for line in MOOD_FILE.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        m = re.match(r"^(\d+)\.\s*\S+\s+(.+?)\s*\((.+?)\)\s*$", line)
        if m:
            cur = {"id": f"M{m.group(1)}", "name": m.group(2), "nameEn": m.group(3),
                   "ayahs": [], "surahs": [], "hadiths": []}
            moods.append(cur)
            continue
        if not cur or ":" not in line:
            continue
        key, rest = line.split(":", 1)
        key = key.strip().lower()
        if key == "ayahs":
            for s_, a, b in re.findall(r"(\d+):(\d+)(?:-(\d+))?", rest):
                cur["ayahs"].append((int(s_), int(a), int(b) if b else int(a)))
        elif key == "surahs":
            cur["surahs"] = [int(n) for n in re.findall(r"(\d+)\s+[A-Za-z]", rest)]
        elif key == "hadith":
            for part in rest.split(","):
                check = "(H)" in part
                ref = re.sub(r"\(.*?\)", "", part).strip()
                if ref:
                    cur["hadiths"].append({"ref": ref, "check": check})
    return moods


# ---------------------------------------------------------------- index

def hadeethenc_all(language):
    """Returns {id: title} for every hadith available in `language`."""
    cats = fetch_json(f"{HADEETHENC_API}/categories/list/?language={language}")
    out = {}
    for c in cats:
        page = 1
        while True:
            q = urllib.parse.urlencode({"language": language, "category_id": c["id"],
                                        "page": page, "per_page": 100})
            res = fetch_json(f"{HADEETHENC_API}/hadeeths/list/?{q}")
            for h in res.get("data", []):
                out[str(h["id"])] = h.get("title", "")
            meta = res.get("meta", {})
            if int(meta.get("current_page", page)) >= int(meta.get("last_page", page)):
                break
            page += 1
    return out


def cmd_index():
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    print("Listing Bangla hadiths on HadeethEnc ...")
    bn = hadeethenc_all("bn")
    print(f"  {len(bn)} Bangla hadiths")
    ar = hadeethenc_all("ar")
    print(f"  {len(ar)} Arabic hadiths")
    rows = [{"id": int(i), "title_ar": ar.get(i, ""), "title_bn": t}
            for i, t in bn.items()]
    rows.sort(key=lambda r: r["id"])
    (DATA_DIR / "hadeethenc_bn_index.json").write_text(
        json.dumps(rows, ensure_ascii=False, indent=0), encoding="utf-8")
    # Keep one full sample so the response format is visible in the repo.
    if rows:
        sample = fetch_json(f"{HADEETHENC_API}/hadeeths/one/?language=bn&id={rows[0]['id']}")
        (DATA_DIR / "hadeethenc_sample.json").write_text(
            json.dumps(sample, ensure_ascii=False, indent=1), encoding="utf-8")
    try:
        tr = quranenc_translation_info()
    except Exception as e:  # noqa: BLE001
        tr = {"error": str(e)}
    (DATA_DIR / "quranenc_bn_translations.json").write_text(
        json.dumps(tr, ensure_ascii=False, indent=1), encoding="utf-8")
    cmd_details()


def cmd_details():
    """Saves full text of the hadiths listed in tools/hadith_candidates.txt,
    so a person can check which one matches a reference."""
    ids_file = ROOT / "tools" / "hadith_candidates.txt"
    if not ids_file.exists():
        return
    ids = re.findall(r"\d+", ids_file.read_text())
    out = []
    for i in ids:
        h = fetch_json(f"{HADEETHENC_API}/hadeeths/one/?language=bn&id={i}")
        out.append({k: h.get(k) for k in ("id", "attribution", "attribution_ar", "grade",
                                          "hadeeth_ar", "hadeeth")})
    (DATA_DIR / "hadeethenc_candidates.json").write_text(
        json.dumps(out, ensure_ascii=False, indent=1), encoding="utf-8")


# ---------------------------------------------------------------- build

BN_DIGITS = str.maketrans("0123456789", "০১২৩৪৫৬৭৮৯")
AR_DIGITS = str.maketrans("0123456789", "٠١٢٣٤٥٦٧٨٩")


def load_tanzil():
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
    if len(verses) != 6236:
        raise RuntimeError(f"Tanzil text has {len(verses)} verses, expected 6236")
    return verses, "\n".join(header)


def load_surah_names():
    """Parses Tanzil's quran-data.js for surah names (Arabic + transliteration)."""
    js = fetch(TANZIL_META_URL)
    block = js[js.index("QuranData.Sura"):]
    block = block[:block.index("];")]
    names = {}
    n = 0
    for m in re.finditer(r"\[\s*\d+\s*,\s*\d+\s*,\s*\d+\s*,\s*\d+\s*,\s*'([^']*)'\s*,\s*\"([^\"]*)\"\s*,\s*'([^']*)'", block):
        n += 1
        names[n] = {"ar": m.group(1), "tr": m.group(2), "en": m.group(3)}
    if len(names) != 114:
        raise RuntimeError(f"parsed {len(names)} surah names from Tanzil metadata")
    return names


def quranenc_translation_info():
    """Info (incl. version) of the Bangla Abu Bakr Zakaria translation."""
    seen = []
    for url in (f"{QURANENC_API}/translations/list/bn",
                f"{QURANENC_API}/translations/list?language=bn",
                f"{QURANENC_API}/translations/list/bn?localization=bn",
                f"{QURANENC_API}/translations/list/bengali",
                f"{QURANENC_API}/translations/list/ben",
                f"{QURANENC_API}/translations/list/bn?localization=en",
                f"{QURANENC_API}/translations/list?localization=bn",
                f"{QURANENC_API}/translations/list"):
        try:
            tr = fetch_json(url)
        except Exception as e:  # noqa: BLE001
            seen.append(f"{url}: {e}")
            continue
        items = tr.get("translations", []) if isinstance(tr, dict) else tr
        for t in items:
            if t.get("key") == QURANENC_KEY:
                return t
        keys = [t.get("key") for t in items]
        langs = sorted({str(t.get("language_iso_code")) for t in items})
        seen.append(f"{url}: {len(keys)} keys, bengali: {[k for k in keys if 'beng' in str(k)]}, "
                    f"languages: {langs}, top-level: {list(tr)[:5] if isinstance(tr, dict) else ''}")
    # Fallback: the translation's page on QuranEnc shows its version number.
    for lang in ("en", "bn", "ar"):
        url = f"https://quranenc.com/{lang}/browse/{QURANENC_KEY}"
        try:
            html = fetch(url, tries=2)
        except Exception as e:  # noqa: BLE001
            seen.append(f"{url}: {e}")
            continue
        m = re.search(r"(?:Version|الإصدار|সংস্করণ)[^0-9]{0,80}?(\d+(?:\.\d+){1,3})", html)
        t = re.search(r"<title>\s*(.*?)\s*</title>", html, re.S)
        if m:
            return {"key": QURANENC_KEY, "version": m.group(1),
                    "title": re.sub(r"\s+", " ", t.group(1)) if t else "",
                    "versionSource": url}
        seen.append(f"{url}: no version found (page length {len(html)})")
    raise RuntimeError(f"{QURANENC_KEY} not found in the QuranEnc translation list. "
                       + " | ".join(seen))


def build_ayahs(ayah_cats, problems, extra_surahs=()):
    try:
        tanzil, tanzil_header = load_tanzil()
    except Exception as e:  # noqa: BLE001
        problems.append(f"Tanzil Arabic text: {e}")
        tanzil, tanzil_header = {}, ""
    try:
        surah_names = load_surah_names()
    except Exception as e:  # noqa: BLE001
        problems.append(f"Tanzil surah names: {e}")
        surah_names = {}
    try:
        info = quranenc_translation_info()
    except Exception as e:  # noqa: BLE001
        problems.append(f"QuranEnc translation info: {e}")
        info = {"key": QURANENC_KEY}
    if info.get("key") != QURANENC_KEY:
        raise RuntimeError(f"wrong QuranEnc translation: {info.get('key')}")

    needed = sorted({s for c in ayah_cats for s, _, _ in c["refs"]} | set(extra_surahs))
    qe = {}
    for s in needed:
        try:
            res = fetch_json(f"{QURANENC_API}/translation/sura/{info['key']}/{s}")
            for v in res["result"]:
                qe[(int(v["sura"]), int(v["aya"]))] = v
        except Exception as e:  # noqa: BLE001
            problems.append(f"QuranEnc surah {s}: {e}")

    def make(s, a, b, cat_id, cat_name, item_id=None):
        ar_parts, bn_parts, notes = [], [], []
        missing = False
        for v in range(a, b + 1):
            ar = tanzil.get((s, v))
            q = qe.get((s, v))
            if ar is None or q is None:
                missing = True
                problems.append(f"Ayah {s}:{v} missing ({'Arabic' if ar is None else ''}"
                                f"{' Bangla' if q is None else ''})")
            ar_parts.append({"n": v, "text": ar if ar is not None else PLACEHOLDER})
            bn_parts.append({"n": v, "text": q["translation"] if q else PLACEHOLDER})
            if q and (q.get("footnotes") or "").strip():
                notes.append(q["footnotes"].strip())
        name = surah_names.get(s, {})
        ref = f"{s}:{a}" if a == b else f"{s}:{a}-{b}"
        return {
            "id": item_id or (f"a-{s}-{a}" + ("" if a == b else f"-{b}")),
            "type": "ayah",
            "categoryId": cat_id,
            "category": cat_name,
            "reference": ref,
            "referenceBn": ref.translate(BN_DIGITS),
            "surah": s,
            "ayahStart": a,
            "ayahEnd": b,
            "surahNameAr": name.get("ar", ""),
            "surahNameEn": name.get("tr", ""),
            "arabicVerses": ar_parts,
            "banglaVerses": bn_parts,
            "note": "\n\n".join(notes),
            "placeholder": missing,
        }

    def verse_count(s):
        return max((v for (ss, v) in tanzil if ss == s), default=0)

    items = [make(s, a, b, c["id"], c["name"]) for c in ayah_cats for s, a, b in c["refs"]]
    self_make = make
    return items, self_make, verse_count, {
        "tanzil": {"name": "Tanzil Quran Text", "type": "Uthmani",
                   "url": "https://tanzil.net", "licenseHeader": tanzil_header,
                   # Tanzil text files start verse 1 of each surah (except 1 and 9)
                   # with this basmala; the app shows it on its own line.
                   "basmala": tanzil.get((1, 1), "")},
        "quranenc": {"name": "QuranEnc.com", "url": "https://quranenc.com",
                     "key": info.get("key"), "title": info.get("title", ""),
                     "version": info.get("version", ""),
                     "lastUpdate": info.get("last_update", "")},
    }


MAPPING = json.loads(MAP_FILE.read_text(encoding="utf-8")) if MAP_FILE.exists() else {}
_hadith_cache = {}


def hadith_id(ref):
    return "h-" + re.sub(r"[^a-z0-9]+", "-", ref.lower()).strip("-")


def make_hadith(ref, hid, cat_id, cat_name, problems):
    if hid not in _hadith_cache:
        try:
            _hadith_cache[hid] = fetch_json(f"{HADEETHENC_API}/hadeeths/one/?language=bn&id={hid}")
        except Exception as e:  # noqa: BLE001
            problems.append(f"HadeethEnc {ref} (id {hid}): {e}")
            _hadith_cache[hid] = None
    h = _hadith_cache[hid]
    return {
        "id": hadith_id(ref),
        "type": "hadith",
        "categoryId": cat_id,
        "category": cat_name,
        "reference": ref,
        "hadeethencId": int(hid),
        "attribution": (h or {}).get("attribution", ""),
        "grade": (h or {}).get("grade", ""),
        "arabic": (h or {}).get("hadeeth_ar") or PLACEHOLDER,
        "bangla": (h or {}).get("hadeeth") or PLACEHOLDER,
        "note": (h or {}).get("explanation") or "",
        "placeholder": h is None,
    }


def build_hadiths(themes, problems):
    items, skipped = [], []
    for t in themes:
        for ref in t["refs"]:
            hid = MAPPING.get(ref)
            if not hid:
                skipped.append({"reference": ref, "theme": t["name"],
                                "reason": "not found on HadeethEnc"})
                continue
            items.append(make_hadith(ref, hid, t["id"], t["name"], problems))
    return items, skipped


def build_moods(moods, items, make_ayah, verse_count, problems):
    """Mood lists point at item ids. Items that are not already in a topic go
    into moodItems (categoryId ""), so topics and daily rotation stay the same."""
    by_id = {i["id"]: i for i in items}
    extra, out, skipped, check = {}, [], [], set()
    for m in moods:
        ayahs, surahs, hadiths = [], [], []
        for s, a, b in m["ayahs"]:
            iid = f"a-{s}-{a}" + ("" if a == b else f"-{b}")
            if iid not in by_id and iid not in extra:
                extra[iid] = make_ayah(s, a, b, "", "")
            ayahs.append(iid)
        for s in m["surahs"]:
            iid = f"s-{s}"
            if iid not in extra:
                n = verse_count(s)
                if n == 0:
                    problems.append(f"Surah {s}: no verses")
                    continue
                it = make_ayah(s, 1, n, "", "", item_id=iid)
                it["fullSurah"] = True
                extra[iid] = it
            surahs.append(iid)
        for h in m["hadiths"]:
            hid = MAPPING.get(h["ref"])
            if not hid:
                skipped.append({"reference": h["ref"], "theme": m["name"],
                                "reason": "not found on HadeethEnc"})
                continue
            iid = hadith_id(h["ref"])
            if iid not in by_id and iid not in extra:
                extra[iid] = make_hadith(h["ref"], hid, "", "", problems)
            if h["check"]:
                check.add(iid)
            if iid not in hadiths:
                hadiths.append(iid)
        out.append({"id": m["id"], "name": m["name"], "nameEn": m["nameEn"],
                    "ayahs": ayahs, "surahs": surahs, "hadiths": hadiths})
    for it in list(items) + list(extra.values()):
        if it["id"] in check:
            it["gradeCheck"] = True
    return out, list(extra.values()), skipped


def cmd_build():
    ayah_cats, themes = parse_list()
    moods = parse_moods()
    problems = []
    mood_surahs = {s for m in moods for s, _, _ in m["ayahs"]} | {s for m in moods for s in m["surahs"]}
    ayahs, make_ayah, verse_count, sources = build_ayahs(ayah_cats, problems, mood_surahs)
    hadiths, skipped = build_hadiths(themes, problems)
    mood_list, mood_items, mood_skipped = build_moods(moods, ayahs + hadiths, make_ayah,
                                                      verse_count, problems)
    kept_themes = {h["categoryId"] for h in hadiths}
    out = {
        "meta": {
            "generatedAt": datetime.now(timezone.utc).isoformat(timespec="seconds"),
            "sources": {**sources, "hadeethenc": {"name": "HadeethEnc.com",
                                                  "url": "https://hadeethenc.com"}},
            "skippedHadiths": skipped,
            "skippedMoodHadiths": mood_skipped,
            "problems": problems,
        },
        "ayahCategories": [{"id": c["id"], "name": c["name"], "nameEn": c["nameEn"]}
                           for c in ayah_cats],
        "hadithThemes": [{"id": t["id"], "name": t["name"]}
                         for t in themes if t["id"] in kept_themes],
        "items": ayahs + hadiths,
        "moods": mood_list,
        "moodItems": mood_items,
    }
    OUT_FILE.parent.mkdir(parents=True, exist_ok=True)
    OUT_FILE.write_text(json.dumps(out, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"Wrote {OUT_FILE}: {len(ayahs)} ayah items, {len(hadiths)} hadith items, "
          f"{len(skipped)} hadiths skipped, {len(problems)} problems")
    for p in problems:
        print("  PROBLEM:", p)
    for s in skipped:
        print("  SKIPPED:", s["reference"])
    print(f"Moods: {len(mood_list)}, extra mood items: {len(mood_items)}, "
          f"mood hadiths skipped: {len(mood_skipped)}")
    for s in mood_skipped:
        print("  MOOD SKIPPED:", s["theme"], "-", s["reference"])


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "build"
    {"index": cmd_index, "details": cmd_details, "build": cmd_build}[cmd]()
