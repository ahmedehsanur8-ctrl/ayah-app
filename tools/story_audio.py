#!/usr/bin/env python3
"""Creates Sahaba story MP3s with the ElevenLabs API (free plan friendly).

Usage (run by .github/workflows/story-audio.yml):
  python3 tools/story_audio.py check              # voice name + remaining credits only
  python3 tools/story_audio.py sample <outdir>    # create ONE story MP3
  python3 tools/story_audio.py generate <outdir>  # create as many as the credits allow

Rules:
  * Never regenerate a story that already has an MP3 (names listed in
    $EXISTING_FILE, one per line, e.g. "s01.mp3").
  * Check the remaining character credits before every story and stop when
    the next story does not fit, so the monthly limit is never exceeded.
Environment: ELEVENLABS_API_KEY, EXISTING_FILE (optional), GITHUB_STEP_SUMMARY (optional).
"""
import json
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path

VOICE_ID = "YyFoWJwI20bOlOPfwy6X"
MODEL_ID = "eleven_v3"
API = "https://api.elevenlabs.io/v1"
ROOT = Path(__file__).resolve().parent.parent
STORIES = ROOT / "assets" / "stories.json"


def api(path, body=None, raw=False):
    key = os.environ.get("ELEVENLABS_API_KEY", "").strip()
    if not key:
        sys.exit("ERROR: the GitHub secret ELEVENLABS_API_KEY is missing.")
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(
        API + path,
        data=data,
        headers={"xi-api-key": key, "Content-Type": "application/json",
                 "Accept": "audio/mpeg" if raw else "application/json"},
        method="POST" if body is not None else "GET",
    )
    try:
        with urllib.request.urlopen(req, timeout=300) as r:
            content = r.read()
    except urllib.error.HTTPError as e:
        detail = e.read().decode("utf-8", "replace")[:600]
        raise RuntimeError(f"ElevenLabs {e.code} for {path}: {detail}") from None
    return content if raw else json.loads(content)


def remaining_credits():
    sub = api("/user/subscription")
    used, limit = int(sub.get("character_count", 0)), int(sub.get("character_limit", 0))
    return limit - used, used, limit, sub.get("tier", "?")


def story_text(s):
    """What is read aloud: title, story and lesson (not the source line)."""
    return f"{s['companion']}। {s['title']}।\n\n{s['body']}\n\nশিক্ষা: {s['lesson']}"


def summary(lines):
    text = "\n".join(lines)
    print(text)
    path = os.environ.get("GITHUB_STEP_SUMMARY")
    if path:
        with open(path, "a", encoding="utf-8") as f:
            f.write(text + "\n")


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "check"
    out = Path(sys.argv[2]) if len(sys.argv) > 2 else ROOT / "story-audio-out"

    voice = api(f"/voices/{VOICE_ID}")
    remaining, used, limit, tier = remaining_credits()
    lines = [
        "## ElevenLabs story audio",
        f"- Voice ID `{VOICE_ID}` works. Voice name: **{voice.get('name', '?')}** "
        f"(category: {voice.get('category', '?')})",
        f"- Plan: {tier}. Credits used {used} of {limit}; **{remaining} left** this month.",
    ]
    if mode == "check":
        summary(lines)
        return

    stories = json.loads(STORIES.read_text(encoding="utf-8"))["stories"]
    existing = set()
    ef = os.environ.get("EXISTING_FILE")
    if ef and Path(ef).exists():
        existing = {l.strip() for l in Path(ef).read_text().splitlines() if l.strip()}
    todo = [s for s in stories if f"{s['id']}.mp3" not in existing]
    out.mkdir(parents=True, exist_ok=True)

    made, skipped_for_credits = [], []
    limit_count = 1 if mode == "sample" else len(todo)
    for s in todo:
        if len(made) >= limit_count:
            break
        text = story_text(s)
        remaining, *_ = remaining_credits()
        if len(text) > remaining:
            skipped_for_credits.append(s["id"])
            break  # keep the story order; the rest wait for next month
        audio = api(
            f"/text-to-speech/{VOICE_ID}?output_format=mp3_44100_128",
            {"text": text, "model_id": MODEL_ID},
            raw=True,
        )
        (out / f"{s['id']}.mp3").write_bytes(audio)
        made.append(s["id"])
        print(f"created {s['id']}.mp3 ({len(text)} characters, {len(audio)} bytes)")

    remaining, used, limit, _ = remaining_credits()
    have = len(existing) + len(made)
    lines += [
        f"- Created this run: **{len(made)}** ({', '.join(made) or 'none'})",
        f"- Stories with audio: **{have} of {len(stories)}**; still without audio: "
        f"**{len(stories) - have}**",
        f"- Credits left after this run: {remaining} of {limit}",
    ]
    if skipped_for_credits:
        lines.append(f"- Stopped at {skipped_for_credits[0]}: not enough credits left this month. "
                     "Run again after your credits reset.")
    summary(lines)


if __name__ == "__main__":
    main()
