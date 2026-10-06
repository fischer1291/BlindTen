#!/usr/bin/env python3
"""Synthesizes the reel's 60 s backing track: 120 BPM, Am–F–C–G.

Pure standard library and deterministic, so the track is our own and needs no
license. The structure follows the cut in shots.json: a sparse intro, the beat
for the explanation, the full groove for the montage and the TV part, a
one-bar break for the drumroll (44–46 s), the drop on DEAD ON and an outro
under the end card.

    python3 marketing/reel60/music.py out.wav
"""
import math
import random
import struct
import sys
import wave

RATE = 44100
BPM = 120
BEAT = 60 / BPM
BAR = 4 * BEAT
LENGTH = 60.0

CHORDS = [  # Am, F, C, G as (bass root, chord tones)
    (110.00, (220.00, 261.63, 329.63)),
    (87.31, (174.61, 220.00, 261.63)),
    (65.41, (261.63, 329.63, 392.00)),
    (98.00, (196.00, 246.94, 293.66)),
]

rng = random.Random(10)
mix = [0.0] * int(LENGTH * RATE)


def add(samples, at, gain=1.0):
    start = int(at * RATE)
    for i, s in enumerate(samples):
        j = start + i
        if j >= len(mix):
            break
        mix[j] += s * gain


def kick():
    n = int(0.28 * RATE)
    out, phase = [], 0.0
    for i in range(n):
        t = i / RATE
        freq = 45 + 75 * math.exp(-t * 28)
        phase += 2 * math.pi * freq / RATE
        out.append(math.sin(phase) * math.exp(-t * 9))
    return out


def clap():
    n = int(0.22 * RATE)
    out, prev = [], 0.0
    for i in range(n):
        t = i / RATE
        noise = rng.uniform(-1, 1)
        hp = noise - prev  # crude high-pass
        prev = noise
        env = sum(math.exp(-(t - d) * 60) for d in (0, 0.012, 0.024) if t >= d) / 3 + 0.4 * math.exp(-t * 18)
        out.append(hp * env * 0.6)
    return out


def hat(open_=False):
    n = int((0.18 if open_ else 0.05) * RATE)
    out, prev = [], 0.0
    for i in range(n):
        noise = rng.uniform(-1, 1)
        out.append((noise - prev) * math.exp(-i / RATE * (14 if open_ else 70)) * 0.35)
        prev = noise
    return out


def bass(freq, length):
    n = int(length * RATE)
    out = []
    for i in range(n):
        t = i / RATE
        x = 2 * math.pi * freq * t
        tone = math.sin(x) + 0.35 * math.sin(2 * x) + 0.15 * math.sin(3 * x)
        out.append(tone * min(1, t * 200) * math.exp(-t * 4) * 0.55)
    return out


def pluck(freqs, length=0.32):
    n = int(length * RATE)
    out = []
    for i in range(n):
        t = i / RATE
        v = 0.0
        for f in freqs:
            p = (f * t) % 1.0
            v += (4 * abs(p - 0.5) - 1) + 0.3 * math.sin(2 * math.pi * 2 * f * t)
        out.append(v / len(freqs) * math.exp(-t * 9) * 0.5)
    return out


def riser(length):
    n = int(length * RATE)
    out, prev = [], 0.0
    for i in range(n):
        noise = rng.uniform(-1, 1)
        out.append((noise - prev) * (i / n) ** 2 * 0.5)
        prev = noise
    return out


KICK, CLAP, HAT, OPEN_HAT = kick(), clap(), hat(), hat(open_=True)


def section(bar):
    start = bar * BAR
    if start < 4:
        return "intro"
    if start < 16:
        return "explain"
    if start < 44:
        return "groove"
    if start < 46:
        return "break"
    if start < 52:
        return "drop"
    return "outro"


for bar in range(int(LENGTH / BAR)):
    t0 = bar * BAR
    root, tones = CHORDS[bar % 4]
    part = section(bar)
    if part == "break":
        add(riser(BAR), t0, 0.6)
        continue
    full = part in ("groove", "drop")
    for step in range(8):  # eighth notes
        t = t0 + step * BEAT / 2
        on_beat = step % 2 == 0
        if part != "intro" and on_beat and not (part == "outro" and step % 4):
            add(KICK, t, 1.0 if full else 0.8)
        if full and step in (2, 6):
            add(CLAP, t, 0.9)
        if part != "outro":
            add(OPEN_HAT if (full and not on_beat and step == 7) else HAT, t, 0.7 if on_beat else 1.0)
        if part in ("explain", "groove", "drop"):
            add(bass(root, BEAT / 2), t, 0.9)
        if not on_beat or part in ("intro", "outro"):
            add(pluck(tones), t, 0.55 if full else 0.45)

# Fade out under the end card.
fade_start = int(57.5 * RATE)
for i in range(fade_start, len(mix)):
    mix[i] *= max(0.0, 1 - (i - fade_start) / (len(mix) - fade_start))

peak = max(abs(s) for s in mix) or 1.0
with wave.open(sys.argv[1] if len(sys.argv) > 1 else "music.wav", "wb") as f:
    f.setnchannels(1)
    f.setsampwidth(2)
    f.setframerate(RATE)
    f.writeframes(b"".join(struct.pack("<h", int(s / peak * 0.85 * 32767)) for s in mix))
