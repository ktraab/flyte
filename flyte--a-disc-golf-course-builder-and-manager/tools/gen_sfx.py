#!/usr/bin/env python3
"""Generate the disc impact sounds in assets/audio/sfx/ — original, procedural.

  chains.wav  disc hits the chains and drops into the tray
  tree.wav    woody thunk + leaf rustle
  rock.wav    hard clack (rocks, basket rim/pole)
  splash.wav  disc lands in water

Pure stdlib, deterministic:  python3 -I tools/gen_sfx.py
"""
import math, os, random, struct, wave

RATE = 22050
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio", "sfx")


def blank(sec):
    return [0.0] * int(RATE * sec)


def add_tone(buf, start, freq, amp, decay, dur=None):
    """Exponentially decaying sine (decay = seconds to ~37%)."""
    i0 = int(start * RATE)
    n = int((dur or decay * 6) * RATE)
    for k in range(n):
        i = i0 + k
        if i >= len(buf):
            break
        t = k / RATE
        buf[i] += amp * math.exp(-t / decay) * math.sin(2 * math.pi * freq * t)


def add_noise(buf, start, dur, amp, attack, decay, lp=1.0, hp=0.0, rng=None):
    """Filtered noise burst. lp/hp are one-pole coefficients (1.0 = no lowpass)."""
    rng = rng or random
    i0 = int(start * RATE)
    low = 0.0; prev = 0.0; hpo = 0.0
    for k in range(int(dur * RATE)):
        i = i0 + k
        if i >= len(buf):
            break
        t = k / RATE
        env = min(1.0, t / max(attack, 1e-4)) * math.exp(-t / decay)
        w = rng.uniform(-1, 1)
        low += lp * (w - low)
        hpo = low - prev if hp > 0 else low
        prev = low
        buf[i] += amp * env * (hpo if hp > 0 else low)


def write(name, buf, gain=0.9):
    peak = max(1e-6, max(abs(x) for x in buf))
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name)
    with wave.open(path, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(RATE)
        # short fade-out so nothing clicks at the end
        n = len(buf); fade = int(0.02 * RATE)
        frames = bytearray()
        for i, x in enumerate(buf):
            f = 1.0 if i < n - fade else (n - i) / fade
            frames += struct.pack("<h", int(max(-1, min(1, x / peak * gain * f)) * 32767))
        w.writeframes(bytes(frames))
    print("wrote", os.path.relpath(path))


def chains():
    rng = random.Random(1971)
    buf = blank(0.95)
    add_tone(buf, 0.0, 160, 0.35, 0.05)           # disc into the tray: dull metal thump
    add_tone(buf, 0.0, 310, 0.18, 0.04)
    t = 0.0
    while t < 0.75:                                # chain links clinking, thinning out
        for f in (rng.uniform(2400, 3400), rng.uniform(4100, 5600), rng.uniform(6200, 7600)):
            add_tone(buf, t, f, rng.uniform(0.05, 0.16) * (1 - t / 0.9), rng.uniform(0.012, 0.03))
        t += rng.uniform(0.012, 0.05) * (1 + t * 3)
    add_noise(buf, 0.0, 0.5, 0.06, 0.002, 0.12, lp=0.9, hp=1, rng=rng)
    write("chains.wav", buf)


def tree():
    rng = random.Random(1972)
    buf = blank(0.6)
    add_tone(buf, 0.0, 180, 0.6, 0.045)            # trunk/branch knock
    add_tone(buf, 0.0, 430, 0.3, 0.03)
    add_noise(buf, 0.0, 0.08, 0.5, 0.001, 0.02, lp=0.35, rng=rng)
    add_noise(buf, 0.03, 0.55, 0.22, 0.03, 0.14, lp=0.8, hp=1, rng=rng)   # leaves
    write("tree.wav", buf)


def rock():
    rng = random.Random(1973)
    buf = blank(0.35)
    for f, a, d in ((1250, 0.4, 0.025), (2130, 0.3, 0.018), (3370, 0.2, 0.012), (240, 0.4, 0.03)):
        add_tone(buf, 0.0, f, a, d)
    add_noise(buf, 0.0, 0.05, 0.4, 0.0005, 0.008, lp=0.7, rng=rng)
    write("rock.wav", buf)


def splash():
    rng = random.Random(1974)
    buf = blank(0.9)
    add_noise(buf, 0.0, 0.85, 0.7, 0.004, 0.16, lp=0.25, rng=rng)        # body of water
    add_noise(buf, 0.0, 0.4, 0.3, 0.002, 0.06, lp=0.9, hp=1, rng=rng)    # spray
    for _ in range(9):                                                   # droplets
        add_tone(buf, rng.uniform(0.12, 0.7), rng.uniform(900, 1800), 0.08, 0.015)
    write("splash.wav", buf)


if __name__ == "__main__":
    chains(); tree(); rock(); splash()
