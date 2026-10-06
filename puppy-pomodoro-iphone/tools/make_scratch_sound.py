#!/usr/bin/env python3
"""Makes App/scratch.wav: Pork's paws on the glass door (same idea as the
Safari version: short bursts of filtered noise). Used in the app and as the
notification sound."""
import math, random, struct, wave
from pathlib import Path

RATE = 44100
out = [0.0] * int(RATE * 2.4)
random.seed(7)

def burst(start, freq):
    n = int(RATE * 0.09)
    # two-pole band-pass filter over white noise
    r = 0.97
    a1, a2 = -2 * r * math.cos(2 * math.pi * freq / RATE), r * r
    y1 = y2 = 0.0
    for j in range(n):
        x = (random.random() * 2 - 1) * (1 - j / n)
        y = x - a1 * y1 - a2 * y2
        y2, y1 = y1, y
        i = start + j
        if i < len(out):
            out[i] += y * 0.05

for group in (0.0, 1.2):
    for k in range(4):
        burst(int(RATE * (group + k * 0.14)), 2400 + random.random() * 1200)

peak = max(abs(v) for v in out) or 1
path = Path(__file__).resolve().parent.parent / "App" / "scratch.wav"
with wave.open(str(path), "wb") as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(RATE)
    w.writeframes(b"".join(struct.pack("<h", int(v / peak * 0.8 * 32767)) for v in out))
print("wrote", path.name)
