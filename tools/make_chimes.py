#!/usr/bin/env python3
"""Makes the two gentle reminder sounds (own work, generated here, no licence
needed): res/raw/reminder_chime.wav and res/raw/reminder_bell.wav."""
import math
import struct
import wave
from pathlib import Path

RAW = Path(__file__).resolve().parent.parent / "android" / "app" / "src" / "main" / "res" / "raw"
RATE = 22050


def bell(freq, start, dur, amp, partials=((1, 1.0), (2.0, 0.35), (3.01, 0.15), (4.2, 0.06)), decay=3.2):
    """(start, samples) of a soft bell-like tone."""
    n = int(dur * RATE)
    out = []
    for i in range(n):
        t = i / RATE
        attack = min(1.0, t / 0.012)
        env = attack * math.exp(-decay * t)
        v = sum(a * math.sin(2 * math.pi * freq * m * t) * math.exp(-decay * (m - 1) * 0.6 * t)
                for m, a in partials)
        out.append(amp * env * v)
    return int(start * RATE), out


def render(notes, total, path):
    buf = [0.0] * int(total * RATE)
    for start, samples in notes:
        for i, v in enumerate(samples):
            if start + i < len(buf):
                buf[start + i] += v
    peak = max(abs(v) for v in buf) or 1.0
    # Fade the end and normalise to a gentle level.
    fade = int(0.3 * RATE)
    for i in range(fade):
        buf[-1 - i] *= i / fade
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(v / peak * 0.6 * 32767)) for v in buf))
    print(path, path.stat().st_size)


RAW.mkdir(parents=True, exist_ok=True)
# Chime: three soft descending notes (E6, C6, G5).
render([bell(1318.5, 0.0, 2.2, 1.0), bell(1046.5, 0.35, 2.2, 0.9), bell(784.0, 0.7, 2.4, 0.9)],
       3.3, RAW / "reminder_chime.wav")
# Bell: a slow, low singing-bowl tone struck twice.
bowl = ((1, 1.0), (2.76, 0.4), (5.4, 0.12))
render([bell(392.0, 0.0, 3.0, 1.0, bowl, decay=1.4), bell(392.0, 1.6, 3.0, 0.7, bowl, decay=1.4)],
       4.8, RAW / "reminder_bell.wav")
