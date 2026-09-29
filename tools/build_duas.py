#!/usr/bin/env python3
"""Builds assets/duas.json from dua-list.md and tools/dua_content.py.

* Every item of sections 1–15 of dua-list.md becomes one dua, in list order,
  with the list's source and grade. Section 16 (the exclude list) is ignored.
* Quranic duas: Arabic from the app's bundled Tanzil text and Bangla from the
  app's bundled Quran translation (Zakaria), unchanged; no উচ্চারণ.
* Hadith duas: Arabic from tools/dua_content.py, replaced line by line with
  HadeethEnc.com's exact text when that line is found inside a HadeethEnc
  hadith (tools/data/hadeethenc_ar.json.gz, made by hadeethenc_arabic.py).
* Every dua is marked needs_review (a scholar checks them before release).

Also writes tools/data/dua_report.txt (counts, R items, Arabic not confirmed).
"""
import gzip
import json
import re
import runpy
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LIST = ROOT / "dua-list.md"
OUT = ROOT / "assets" / "duas.json"
REPORT = ROOT / "tools" / "data" / "dua_report.txt"
HADEETHENC = ROOT / "tools" / "data" / "hadeethenc_ar.json.gz"

BN = str.maketrans("0123456789", "০১২৩৪৫৬৭৮৯")
AR = str.maketrans("0123456789", "٠١٢٣٤٥٦٧٨٩")

GRADES = {
    "S": "সহিহ",
    "H": "হাসান",
    "Q": "কুরআন",
    "A": "সাহাবি/তাবেয়ির বাণী",
    "R": "মতভেদপূর্ণ (আলেমের যাচাই প্রয়োজন)",
}

UCCHARON_NOTE = "উচ্চারণ শুধু সহায়ক; সঠিক পড়ার জন্য আরবি ও অডিও অনুসরণ করুন"

BOOKS = [
    ("an-Nasa'i al-Kubra", "আস-সুনানুল কুবরা (নাসায়ি)"),
    ("an-Nasa'i", "সুনান নাসায়ি"),
    ("al-Adab al-Mufrad", "আল-আদাবুল মুফরাদ"),
    ("Abu Dawud", "সুনান আবু দাউদ"),
    ("Ibn Majah", "সুনান ইবনে মাজাহ"),
    ("Ibn Hibban", "সহিহ ইবনে হিব্বান"),
    ("Bukhari", "সহিহ বুখারি"),
    ("Muslim", "সহিহ মুসলিম"),
    ("Tirmidhi", "জামে তিরমিজি"),
    ("Ahmad", "মুসনাদে আহমাদ"),
    ("al-Hakim", "মুসতাদরাকে হাকিম"),
    ("at-Tabarani", "তাবারানি"),
]
SPECIAL = {
    "Muwatta (Ibn az-Zubayr)": "মুয়াত্তা মালিক (আবদুল্লাহ ইবনুয যুবাইর রা.-এর আমল)",
    "Bukhari (al-Hasan)": "সহিহ বুখারি, কিতাবুল জানায়িজ (হাসান বসরি রহ.-এর বাণী)",
    "an-Nawawi, al-Adhkar": "ইমাম নববি, আল-আযকার",
}

# English notes in list titles → Bangla.
TITLE_NOTES = {
    "(after Fajr)": "(ফজরের পর)", "(evening)": "(সন্ধ্যায়)", "(night)": "(রাতে)",
    "(turning at night)": "(রাতে পাশ ফেরার সময়)", "(fear in sleep)": "(ঘুমে ভয় পেলে)",
    "(waking)": "(ঘুম থেকে উঠে)", "(after wudu)": "(উযুর পর)",
}


def surah_names_bn():
    dart = (ROOT / "lib" / "models" / "surah_names.dart").read_text(encoding="utf-8")
    block = dart[dart.index("["):dart.index("];")]
    names = re.findall(r"'([^']+)'", block)
    assert len(names) == 114, len(names)
    return names


SURAH_BN = surah_names_bn()


def source_bn(src):
    src = src.strip()
    if src in SPECIAL:
        return SPECIAL[src]
    out, book = [], None
    for part in [p.strip() for p in src.split(",")]:
        m = re.fullmatch(r"(\d+):(\d+)(?:-(\d+))?", part)
        if m:
            s = int(m[1])
            out.append(f"সূরা {SURAH_BN[s - 1]} {part}".translate(BN))
            continue
        if re.fullmatch(r"\d+", part) and book:
            out[-1] += f", {part.translate(BN)}"
            continue
        for en, bn in BOOKS:
            if part.startswith(en):
                book = bn
                num = part[len(en):].strip()
                out.append(f"{bn} {num.translate(BN)}".strip())
                break
        else:
            raise ValueError(f"unknown source: {part!r} in {src!r}")
    return "; ".join(out)


def parse_list():
    sections, cur = [], None
    for line in LIST.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        m = re.match(r"^(\d+)\.\s+(.+)$", line)
        if m:
            n = int(m[1])
            if n > 15:
                break
            cur = {"n": n, "title": m[2].strip(), "items": []}
            sections.append(cur)
            continue
        if not cur or not line:
            continue
        if cur["n"] == 15:
            for ref in [r.strip() for r in line.split(",") if r.strip()]:
                cur["items"].append({"title": ref, "source": ref, "grade": "Q", "times": "1"})
            continue
        parts = [p.strip() for p in line.split("|")]
        if len(parts) < 3:
            continue
        cur["items"].append({
            "title": parts[0], "source": parts[1], "grade": parts[2],
            "times": parts[3] if len(parts) > 3 else "",
        })
    # The title of section 15 carries a note in English; keep the Bangla part.
    for s in sections:
        s["title"] = re.sub(r"\s*\(.*\)\s*$", "", s["title"])
    return sections


# ------------------------------------------------------------------- Quran

def load_quran():
    meta = json.loads((ROOT / "assets" / "quran" / "meta.json").read_text(encoding="utf-8"))
    arabic = gzip.decompress((ROOT / "assets" / "quran" / "arabic.txt.gz").read_bytes()) \
        .decode("utf-8").split("\n")
    bn = json.loads(gzip.decompress(
        (ROOT / "assets" / "quran" / "bn_zakaria.json.gz").read_bytes()).decode("utf-8"))
    starts = {s["n"]: (s["start"], s["ayahs"]) for s in meta["surahs"]}
    zak = next(t for t in meta["translations"] if t["id"] == "bn_zakaria")
    return arabic, bn["verses"], starts, zak["name"]


ARABIC, BANGLA, STARTS, TRANSLATOR = load_quran()
BASMALA = ARABIC[0]


def no_marks(s):
    """Bangla without footnote markers like [১] (the footnotes aren't shown here)."""
    return re.sub(r"\s*\[[০-৯0-9]+\]", "", s).strip()


def ayahs(s, a, b):
    start, count = STARTS[s]
    assert 1 <= a <= b <= count, (s, a, b)
    ar, bn = [], []
    for v in range(a, b + 1):
        t = ARABIC[start + v - 1]
        if v == 1 and s not in (1, 9) and t.startswith(BASMALA + " "):
            t = t[len(BASMALA) + 1:]
        ar.append(f"{t} ﴿{str(v).translate(AR)}﴾")
        bn.append(f"({str(v).translate(BN)}) {no_marks(BANGLA[start + v - 1][0])}")
    return " ".join(ar), " ".join(bn)


def quran_text(spec):
    """'2:255' | '2:285-286' | '112,113,114' | '1' → (arabic, bangla, refs)."""
    parts = [p.strip() for p in spec.split(",")]
    if all(re.fullmatch(r"\d+", p) for p in parts):
        ar, bn, refs = [], [], []
        for p in parts:
            s = int(p)
            a, b = ayahs(s, 1, STARTS[s][1])
            head = f"সূরা {SURAH_BN[s - 1]}"
            if s != 1:
                ar.append(f"{BASMALA}\n{a}")
            else:
                ar.append(a)
            bn.append(f"{head}: {b}")
            refs.append({"surah": s, "from": 1, "to": STARTS[s][1]})
        return "\n\n".join(ar), "\n\n".join(bn), refs
    m = re.fullmatch(r"(\d+):(\d+)(?:-(\d+))?", spec)
    s, a = int(m[1]), int(m[2])
    b = int(m[3]) if m[3] else a
    ar, bn = ayahs(s, a, b)
    return ar, bn, [{"surah": s, "from": a, "to": b}]


# -------------------------------------------------------------- HadeethEnc

MARKS = re.compile("[ؐ-ًؚ-ٰٟۖ-ۭـ]")
FOLD = {"أ": "ا", "إ": "ا", "آ": "ا", "ٱ": "ا", "ى": "ي", "ة": "ه", "ؤ": "و", "ئ": "ي", "ء": ""}


def folded(text):
    """Arabic letters only (no marks, spaces or punctuation), with a map back."""
    out, pos = [], []
    for i, c in enumerate(text):
        if MARKS.match(c) or not ("ء" <= c <= "ي" or c in FOLD or c == "ٱ"):
            continue
        c = FOLD.get(c, c)
        if not c:
            continue
        out.append(c)
        pos.append(i)
    return "".join(out), pos


def load_hadeethenc():
    if not HADEETHENC.exists():
        return []
    data = json.loads(gzip.decompress(HADEETHENC.read_bytes()).decode("utf-8"))
    rows = []
    for hid, h in sorted(data.items(), key=lambda kv: int(kv[0])):
        text = h.get("ar") or ""
        f, pos = folded(text)
        rows.append((hid, text, f, pos))
    return rows


HADITHS = load_hadeethenc()


def from_hadeethenc(line):
    """HadeethEnc's exact text for [line], or None when it is not found."""
    f, _ = folded(line)
    if len(f) < 10:
        return None
    for hid, text, hf, pos in HADITHS:
        i = hf.find(f)
        if i < 0:
            continue
        start, end = pos[i], pos[i + len(f) - 1] + 1
        while end < len(text) and MARKS.match(text[end]):
            end += 1
        exact = text[start:end].strip()
        # Skip matches broken by a narrator's remark or quotation marks.
        if re.search(r"[«»()\[\]\-]", exact):
            continue
        return hid, exact
    return None


def verify(ar):
    """Replaces each line found on HadeethEnc; returns (text, ids, missing lines)."""
    lines, ids, missing = [], [], []
    for line in ar.split("\n"):
        hit = from_hadeethenc(line) if HADITHS else None
        if hit:
            ids.append(hit[0])
            lines.append(hit[1])
        else:
            if len(folded(line)[0]) >= 10:
                missing.append(line)
            lines.append(line)
    return "\n".join(lines), ids, missing


# -------------------------------------------------------------------- main

def repeat_of(times, c):
    t = times.strip()
    if c.get("steps"):
        return sum(n for n, _, _ in c["steps"])
    if c.get("repeat"):
        return c["repeat"]
    m = re.match(r"^(\d+)", t)
    return int(m[1]) if m else None


def main():
    content = runpy.run_path(str(ROOT / "tools" / "dua_content.py"))
    C, Q15 = content["C"], content["Q15"]
    sections = parse_list()
    assert [s["n"] for s in sections] == list(range(1, 16)), [s["n"] for s in sections]
    duas, report_missing, unsure, r_items = [], [], [], []
    matched = 0
    hadith_count = 0
    for sec in sections:
        for i, item in enumerate(sec["items"], 1):
            key = f"{sec['n']}.{i}"
            grade = item["grade"]
            if grade not in GRADES:
                raise ValueError(f"{key}: grade {grade!r}")
            if sec["n"] == 15:
                title, when = Q15[item["source"]]
                c = {"quran": item["source"], "title": title, "when": when}
            else:
                if key not in C:
                    raise KeyError(f"no content for {key}: {item['title']}")
                c = C[key]
            title = c.get("title") or item["title"]
            for en, bn in TITLE_NOTES.items():
                title = title.replace(en, bn)
            d = {
                "id": f"{sec['n']:02d}-{i:02d}",
                "section": sec["n"],
                "title_bn": title,
                "when_bn": c.get("when", ""),
                "arabic": "",
                "bangla_meaning": "",
                "uccharon": "",
                "source_ref": source_bn(item["source"]),
                "grade": grade,
                "grade_bn": GRADES[grade],
                "repeat_count": repeat_of(item["times"], c),
                "repeat_note": "অথবা ১০০ বার" if "or 100" in item["times"] else "",
                "steps": [{"count": n, "arabic": a, "label_bn": l} for n, a, l in c.get("steps", [])],
                "fadilah_bn": c.get("fad", ""),
                "needs_review": True,
                "review_reason": "আলেমদের মধ্যে মতভেদ আছে (R)" if grade == "R" else "",
                "athar": grade == "A",
                "period": c.get("period", ""),
                "evening": None,
                "quran": [],
                "open_surahs": c.get("surahs", []),
                "info": bool(c.get("info")),
                "arabic_source": "",
                "hadeethenc_ids": [],
                "translator_bn": "",
                "note_bn": c.get("note", ""),
            }
            if c.get("quran"):
                ar, bn, refs = quran_text(c["quran"])
                d.update(arabic=ar, bangla_meaning=bn, quran=refs,
                         arabic_source="tanzil", translator_bn=TRANSLATOR)
            else:
                hadith_count += 1
                ar, ids, missing = verify(c.get("ar", ""))
                if c.get("henc"):
                    # Taken from this HadeethEnc hadith by hand (a narrator's
                    # remark or a variant note inside the dua was left out).
                    ids, missing = [str(c["henc"])], []
                d.update(arabic=ar, bangla_meaning=c.get("bn", ""), uccharon=c.get("uc", ""))
                d["hadeethenc_ids"] = ids
                d["arabic_source"] = "hadeethenc" if ids and not missing else (
                    "mixed" if ids else ("app" if ar else ""))
                if ids and not missing:
                    matched += 1
                if missing:
                    report_missing.append(f"{d['id']} {title}")
                if c.get("ev"):
                    ev_ar, ev_ids, ev_missing = verify(c["ev"]["ar"])
                    d["evening"] = {"arabic": ev_ar, "bangla_meaning": c["ev"]["bn"],
                                    "uccharon": c["ev"]["uc"]}
                    d["hadeethenc_ids"] += ev_ids
            if c.get("unsure"):
                unsure.append(f"{d['id']} {title}: {c['unsure']}")
            if grade == "R":
                r_items.append(f"{d['id']} {title}")
            if not d["info"] and not d["arabic"] and not d["open_surahs"]:
                raise ValueError(f"{key}: no Arabic")
            if grade != "Q" and not d["quran"] and d["arabic"] and not d["uccharon"] and not d["info"]:
                raise ValueError(f"{key}: no উচ্চারণ")
            duas.append(d)

    out = {
        "generatedAt": datetime.now(timezone.utc).replace(microsecond=0).isoformat(),
        "uccharon_note": UCCHARON_NOTE,
        "credit": "দোয়ার আরবি পাঠ: কুরআন ও সহিহ হাদিস গ্রন্থসমূহ; কিছু হাদিস HadeethEnc.com থেকে। "
                  "বাংলা অর্থ ও উচ্চারণ: অ্যাপ টিম (আলেম কর্তৃক যাচাই সাপেক্ষে)।",
        "sections": [{"n": s["n"], "title_bn": s["title"], "count": len(s["items"])}
                     for s in sections],
        "duas": duas,
    }
    OUT.write_text(json.dumps(out, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")

    grades = {g: sum(1 for d in duas if d["grade"] == g) for g in GRADES}
    lines = [
        f"duas: {len(duas)} (hadith/other {hadith_count}, Quran {grades['Q']})",
        f"grades: {grades}",
        f"HadeethEnc hadiths loaded: {len(HADITHS)}",
        f"hadith duas with all Arabic lines taken from HadeethEnc: {matched}",
        "",
        f"R items ({len(r_items)}):", *r_items, "",
        f"Arabic not found on HadeethEnc, kept as written from the classical source "
        f"({len(report_missing)}):", *report_missing, "",
        f"Marked unsure in the content ({len(unsure)}):", *unsure,
    ]
    REPORT.parent.mkdir(parents=True, exist_ok=True)
    REPORT.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("\n".join(lines[:6]))


if __name__ == "__main__":
    main()
