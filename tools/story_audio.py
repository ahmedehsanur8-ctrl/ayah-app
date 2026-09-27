#!/usr/bin/env python3
"""Creates Sahaba story MP3s with the ElevenLabs API (free plan friendly).

Usage (run by .github/workflows/story-audio.yml):
  python3 tools/story_audio.py check     # voice name + remaining credits only
  python3 tools/story_audio.py sample    # create ONE story MP3
  python3 tools/story_audio.py generate  # create as many as the credits allow

The MP3s are saved in assets/story_audio/<id>.mp3 (mono, 64 kbps) and bundled
in the app. Rules:
  * Never regenerate a story that already has an MP3 in assets/story_audio/.
  * Check the remaining character credits before every story and stop when
    the next story does not fit, so the monthly limit is never exceeded.
Environment: ELEVENLABS_API_KEY, GITHUB_STEP_SUMMARY (optional). Needs ffmpeg.
"""
import json
import os
import subprocess
import sys
import tempfile
import urllib.error
import urllib.request
from pathlib import Path

VOICE_ID = "YyFoWJwI20bOlOPfwy6X"
MODEL_ID = "eleven_v3"
API = "https://api.elevenlabs.io/v1"
ROOT = Path(__file__).resolve().parent.parent
STORIES = ROOT / "assets" / "stories.json"
AUDIO_DIR = ROOT / "assets" / "story_audio"


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
        if "missing_permissions" in detail:
            detail += ("\nFix: in ElevenLabs > Developers > API Keys, edit the key and allow "
                       "Text to Speech (Access), Voices (Read) and User (Read).")
        raise RuntimeError(f"ElevenLabs {e.code} for {path}: {detail}") from None
    return content if raw else json.loads(content)


def remaining_credits():
    sub = api("/user/subscription")
    used, limit = int(sub.get("character_count", 0)), int(sub.get("character_limit", 0))
    return limit - used, used, limit, sub.get("tier", "?")


def story_text(s):
    """What is read aloud: title, story and lesson (not the source line)."""
    return f"{s['companion']}। {s['title']}।\n\n{s['body']}\n\nশিক্ষা: {s['lesson']}"


def to_mono_64k(mp3: bytes, target: Path):
    """Re-encode to mono 64 kbps so the bundled files keep the app small."""
    with tempfile.NamedTemporaryFile(suffix=".mp3") as src:
        src.write(mp3)
        src.flush()
        subprocess.run(
            ["ffmpeg", "-loglevel", "error", "-y", "-i", src.name,
             "-ac", "1", "-b:a", "64k", "-ar", "44100", str(target)],
            check=True,
        )


def summary(lines):
    text = "\n".join(lines)
    print(text)
    path = os.environ.get("GITHUB_STEP_SUMMARY")
    if path:
        with open(path, "a", encoding="utf-8") as f:
            f.write(text + "\n")


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "check"

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
    AUDIO_DIR.mkdir(parents=True, exist_ok=True)
    existing = {p.name for p in AUDIO_DIR.glob("*.mp3")}
    todo = [s for s in stories if f"{s['id']}.mp3" not in existing]

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
        target = AUDIO_DIR / f"{s['id']}.mp3"
        to_mono_64k(audio, target)
        made.append(s["id"])
        print(f"created {target.name} ({len(text)} characters, {target.stat().st_size} bytes)")

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
