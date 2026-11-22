#!/usr/bin/env python3
"""Generate assets/audio/ambient/wind_loop.wav — original procedural wind + distant birds.

Used under the final memorial card (STORY.md: "ambient wind/nature audio only — no
music"). Pure stdlib so it runs anywhere:  python3 -I tools/gen_ambient_wind.py
The output loops seamlessly (tail is crossfaded into the head).
"""
import math, random, struct, wave, os, sys

RATE = 22050
LOOP_S = 24.0
XFADE_S = 2.0
random.seed(1971)  # deterministic

n_loop = int(RATE * LOOP_S)
n_x = int(RATE * XFADE_S)
n = n_loop + n_x

def gust(t):
    # slow, irregular swell of the wind (periods that divide LOOP_S keep it loopable-ish)
    return (0.55 + 0.25 * math.sin(2 * math.pi * t / 12.0)
            + 0.12 * math.sin(2 * math.pi * t / 4.8 + 1.3)
            + 0.08 * math.sin(2 * math.pi * t / 2.0 + 0.4))

out = [0.0] * n
low = 0.0; mid = 0.0; mid2 = 0.0
for i in range(n):
    t = i / RATE
    w = random.uniform(-1.0, 1.0)
    low += 0.012 * (w - low)            # deep rumble
    mid += 0.08 * (w - mid)             # airy body
    mid2 += 0.08 * (mid - mid2)
    g = gust(t)
    out[i] = 2.2 * low * (0.6 + 0.4 * g) + 0.9 * (mid - mid2) * g * g

# A few distant bird calls (two-note chirps), quiet
for start in (3.1, 3.4, 9.7, 15.2, 15.45, 20.6):
    f0 = random.uniform(2600, 3600)
    for k in range(int(0.11 * RATE)):
        i = int(start * RATE) + k
        if i >= n_loop:
            break
        tt = k / RATE
        env = math.sin(math.pi * tt / 0.11) ** 2
        f = f0 + 900 * tt / 0.11
        out[i] += 0.05 * env * math.sin(2 * math.pi * f * tt)

# Crossfade tail into head for a seamless loop
for k in range(n_x):
    a = k / n_x
    out[k] = out[k] * a + out[n_loop + k] * (1 - a)
out = out[:n_loop]

peak = max(abs(v) for v in out) or 1.0
scale = 0.6 / peak
path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio", "ambient", "wind_loop.wav")
with wave.open(path, "wb") as wf:
    wf.setnchannels(1); wf.setsampwidth(2); wf.setframerate(RATE)
    wf.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, v * scale)) * 32767)) for v in out))
print("wrote", os.path.normpath(path), n_loop, "frames")
