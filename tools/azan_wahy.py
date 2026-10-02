#!/usr/bin/env python3
"""The Wahy Project adhan recordings (CC BY-NC-ND 3.0).

  python3 tools/azan_wahy.py probe   # read the recordings page, list every download
                                     # link, and record size, MD5, SHA-256 and length
                                     # of each audio file -> tools/data/wahy_probe.json
  python3 tools/azan_wahy.py fetch   # download the files named in tools/azan_wahy_choice.txt
                                     # into res/raw, byte for byte (no changes)

The licence (NoDerivatives) forbids changes, so files are saved exactly as
downloaded: no trimming, no normalising, no re-encoding.
"""
import hashlib
import html
import json
import re
import subprocess
import sys
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PAGE = "https://thewahyproject.com/2011/09/05/adhan-recordings/"
ARCHIVE = "https://web.archive.org/web/2024/" + PAGE
PROBE = ROOT / "tools" / "data" / "wahy_probe.json"
CHOICE = ROOT / "tools" / "azan_wahy_choice.txt"
RAW = ROOT / "android" / "app" / "src" / "main" / "res" / "raw"
UA = "Mozilla/5.0 (AyahReminder azan fetch; +https://github.com/ahmedehsanur8-ctrl/ayah-app)"
AUDIO = re.compile(r"\.(mp3|m4a|ogg|wav|aac|zip)(\?|$)", re.I)


def get(url, timeout=120):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.status, r.geturl(), r.headers.get("Content-Type", ""), r.read()


def links(page_html, base):
    out = []
    for href, text in re.findall(r'<a[^>]+href="([^"]+)"[^>]*>(.*?)</a>', page_html, re.S | re.I):
        out.append((urllib.parse.urljoin(base, html.unescape(href)),
                    re.sub(r"<[^>]+>", "", html.unescape(text)).strip()))
    return out


def duration(path):
    try:
        r = subprocess.run(["ffprobe", "-v", "error", "-show_entries",
                            "format=duration:format=bit_rate:stream=sample_rate,channels,codec_name",
                            "-of", "json", str(path)], capture_output=True, text=True, timeout=60)
        return json.loads(r.stdout)
    except Exception as e:  # noqa: BLE001
        return {"error": str(e)}


def describe(data):
    return {"bytes": len(data), "md5": hashlib.md5(data).hexdigest(),
            "sha256": hashlib.sha256(data).hexdigest()}


def cmd_probe():
    report = {"page": PAGE, "tries": []}
    page_html, base = None, PAGE
    for url in (PAGE, ARCHIVE):
        try:
            status, final, ctype, body = get(url, 60)
            report["tries"].append({"url": url, "status": status, "final": final, "bytes": len(body)})
            page_html, base = body.decode("utf-8", "replace"), final
            break
        except Exception as e:  # noqa: BLE001
            report["tries"].append({"url": url, "error": repr(e)})
    if page_html is None:
        report["result"] = "page unreachable"
    else:
        text = re.sub(r"\s+", " ", re.sub(r"<[^>]+>", " ", re.sub(
            r"(?is)<(script|style).*?</\1>", " ", page_html)))
        i = text.find("Adhan")
        report["page_text"] = html.unescape(text[max(0, i - 200): i + 6000])
        report["checksum_mentions"] = sorted(set(re.findall(
            r"(?i)(?:md5|sha-?1|sha-?256|checksum)[^<]{0,200}", page_html)))[:40]
        files = []
        for url, label in links(page_html, base):
            if not AUDIO.search(url) and "download" not in url.lower():
                continue
            entry = {"label": label, "url": url}
            try:
                status, final, ctype, body = get(url)
                entry.update(status=status, final=final, type=ctype, **describe(body))
                tmp = Path("/tmp") / ("probe" + Path(urllib.parse.urlparse(final).path).suffix)
                tmp.write_bytes(body)
                entry["media"] = duration(tmp)
            except Exception as e:  # noqa: BLE001
                entry["error"] = repr(e)
            files.append(entry)
            print(entry.get("status", entry.get("error")), label, url, flush=True)
        report["files"] = files
    PROBE.parent.mkdir(parents=True, exist_ok=True)
    PROBE.write_text(json.dumps(report, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=1)[:4000])


def cmd_fetch():
    """Each line: <raw name>=<url>  [md5=<expected>]  e.g. azan_nabawi=https://.../x.mp3"""
    if not CHOICE.exists():
        print("No choice file yet.")
        return
    record = {}
    for line in CHOICE.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split()
        name, url = parts[0].split("=", 1)
        expected = dict(p.split("=", 1) for p in parts[1:])
        _, final, ctype, body = get(url)
        d = describe(body)
        for k, v in expected.items():
            if d.get(k) != v.lower():
                sys.exit(f"{name}: {k} is {d.get(k)}, expected {v}")
        ext = Path(urllib.parse.urlparse(final).path).suffix.lower()
        if ext != ".mp3":
            sys.exit(f"{name}: expected an .mp3, got {ext} ({ctype})")
        out = RAW / f"{name}{ext}"
        out.write_bytes(body)  # byte for byte, unchanged
        record[name] = {"url": url, **d, "media": duration(out)}
        print(name, d)
    (ROOT / "tools" / "data" / "wahy_files.json").write_text(
        json.dumps(record, indent=1) + "\n", encoding="utf-8")


if __name__ == "__main__":
    {"probe": cmd_probe, "fetch": cmd_fetch}[sys.argv[1]]()
