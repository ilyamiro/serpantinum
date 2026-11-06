#!/usr/bin/env python3
"""Synthesizes the pet's sound effects into src/pet/sounds/ (stdlib only).

Meows are additive harmonics shaped by moving vowel formants ("m-i-a-o-w").
The purr is band-passed noise pulsed at ~25 Hz so it is audible on laptop speakers.
"""
import math
import os
import random
import struct
import wave

SR = 44100
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "src", "pet", "sounds")


def write(name, samples, peak=0.55):
    m = max(1e-9, max(abs(s) for s in samples))
    g = peak / m
    fade = int(SR * 0.004)
    n = len(samples)
    frames = bytearray()
    for i, s in enumerate(samples):
        e = 1.0
        if i < fade:
            e = i / fade
        elif i > n - fade:
            e = max(0.0, (n - i) / fade)
        v = max(-1.0, min(1.0, s * g * e))
        frames += struct.pack("<h", int(v * 32767))
    with wave.open(os.path.join(OUT, name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(bytes(frames))
    print(f"  {name}: {n / SR:.2f}s")


def interp(points, t):
    if t <= points[0][0]:
        return points[0][1]
    for (t0, v0), (t1, v1) in zip(points, points[1:]):
        if t <= t1:
            k = (t - t0) / max(1e-9, t1 - t0)
            k = k * k * (3 - 2 * k)
            return v0 + (v1 - v0) * k
    return points[-1][1]


def formant_gain(f, formants):
    g = 0.0
    for fc, bw, amp in formants:
        g += amp / (1.0 + ((f - fc) / (bw * 0.5)) ** 2)
    return g


def voice(dur, f0pts, f1pts, f2pts, amppts, roll=0.0, rollpts=None, breath=0.03, seed=1):
    rnd = random.Random(seed)
    n = int(SR * dur)
    out = [0.0] * n
    phase = 0.0
    vib_rate = 5.0 + rnd.random()
    for i in range(n):
        t = i / n
        f0 = interp(f0pts, t) * (1.0 + 0.012 * math.sin(2 * math.pi * vib_rate * i / SR))
        phase += 2 * math.pi * f0 / SR
        f1 = interp(f1pts, t)
        f2 = interp(f2pts, t)
        forms = ((f1, 160.0, 1.0), (f2, 240.0, 0.6), (f2 * 1.45 + 500.0, 420.0, 0.16))
        s = 0.0
        k = 1
        while k <= 22 and k * f0 < 9500:
            s += formant_gain(k * f0, forms) / (k ** 0.55) * math.sin(k * phase)
            k += 1
        s += breath * (rnd.random() * 2.0 - 1.0)
        a = interp(amppts, t)
        if roll > 0.0:
            depth = interp(rollpts, t) if rollpts else 1.0
            a *= 1.0 - depth * 0.75 * (0.5 + 0.5 * math.cos(2 * math.pi * roll * i / SR))
        out[i] = s * a
    return out


class Biquad:
    def __init__(self, kind, fc, q):
        w0 = 2 * math.pi * fc / SR
        alpha = math.sin(w0) / (2 * q)
        cw = math.cos(w0)
        if kind == "bp":
            b0, b1, b2 = alpha, 0.0, -alpha
        elif kind == "lp":
            b0, b1, b2 = (1 - cw) / 2, 1 - cw, (1 - cw) / 2
        else:
            b0, b1, b2 = (1 + cw) / 2, -(1 + cw), (1 + cw) / 2
        a0, a1, a2 = 1 + alpha, -2 * cw, 1 - alpha
        self.b = (b0 / a0, b1 / a0, b2 / a0)
        self.a = (a1 / a0, a2 / a0)
        self.z = [0.0, 0.0, 0.0, 0.0]

    def __call__(self, x):
        b0, b1, b2 = self.b
        a1, a2 = self.a
        x1, x2, y1, y2 = self.z
        y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        self.z = [x, x1, y, y1]
        return y


def purr(dur=1.7, seed=7):
    rnd = random.Random(seed)
    n = int(SR * dur)
    bp1 = Biquad("bp", 260.0, 0.9)
    bp2 = Biquad("bp", 520.0, 1.2)
    out = [0.0] * n
    breaths = ((0.02, 0.78, 25.0, 0.8), (0.86, 1.66, 27.5, 1.0))
    ph = 0.0
    for i in range(n):
        t = i / SR
        a = 0.0
        rate = 25.0
        for b0, b1, r, lvl in breaths:
            if b0 <= t <= b1:
                k = (t - b0) / (b1 - b0)
                a = lvl * math.sin(math.pi * k) ** 0.7
                rate = r
        ph += 2 * math.pi * rate / SR
        pulse = (0.5 + 0.5 * math.cos(ph)) ** 6
        noise = rnd.random() * 2.0 - 1.0
        tone = math.sin(2 * math.pi * 130.0 * t) + 0.5 * math.sin(2 * math.pi * 260.0 * t)
        s = bp1(noise) * 1.6 + bp2(noise) * 0.6 + tone * 0.12
        out[i] = s * pulse * a
    return out


def crunch(dur, seed, fc=2600.0):
    rnd = random.Random(seed)
    n = int(SR * dur)
    bp = Biquad("bp", fc, 1.1)
    out = [0.0] * n
    for i in range(n):
        t = i / SR
        e = math.exp(-t * 55.0)
        grit = 1.0 if rnd.random() < 0.35 else 0.3
        s = bp(rnd.random() * 2.0 - 1.0) * grit * e
        s += 0.35 * math.sin(2 * math.pi * 190.0 * t) * math.exp(-t * 70.0)
        out[i] = s
    return out


def chomp():
    gap = [0.0] * int(SR * 0.07)
    return crunch(0.11, 3) + gap + crunch(0.10, 4, 2300.0) + gap + crunch(0.09, 5, 2900.0)


def thud(dur=0.16, seed=9):
    rnd = random.Random(seed)
    n = int(SR * dur)
    lp = Biquad("lp", 900.0, 0.7)
    out = [0.0] * n
    ph = 0.0
    for i in range(n):
        t = i / SR
        f = 70.0 + 230.0 * math.exp(-t * 30.0)
        ph += 2 * math.pi * f / SR
        s = math.sin(ph) * math.exp(-t * 26.0)
        s += 0.5 * math.sin(2.0 * ph) * math.exp(-t * 34.0)
        s += 0.4 * lp(rnd.random() * 2.0 - 1.0) * math.exp(-t * 90.0)
        out[i] = s
    return out


def pop(dur=0.09):
    n = int(SR * dur)
    out = [0.0] * n
    ph = 0.0
    for i in range(n):
        t = i / SR
        f = 520.0 + 1100.0 * (t / dur) ** 0.6
        ph += 2 * math.pi * f / SR
        out[i] = math.sin(ph) * math.exp(-t * 32.0) * min(1.0, t * 900.0)
    return out


def main():
    os.makedirs(OUT, exist_ok=True)
    print("writing to", os.path.normpath(OUT))
    write("meow.wav", voice(
        0.58,
        [(0.0, 540), (0.32, 830), (0.7, 700), (1.0, 500)],
        [(0.0, 320), (0.15, 470), (0.45, 880), (0.75, 620), (1.0, 360)],
        [(0.0, 1500), (0.15, 2300), (0.45, 1750), (0.75, 1150), (1.0, 820)],
        [(0.0, 0.0), (0.06, 0.35), (0.16, 1.0), (0.68, 0.9), (1.0, 0.0)],
        seed=1))
    write("mew.wav", voice(
        0.34,
        [(0.0, 760), (0.35, 1060), (0.75, 900), (1.0, 760)],
        [(0.0, 380), (0.25, 560), (0.6, 840), (1.0, 520)],
        [(0.0, 2000), (0.25, 2450), (0.6, 1800), (1.0, 1300)],
        [(0.0, 0.0), (0.1, 0.6), (0.22, 1.0), (0.7, 0.8), (1.0, 0.0)],
        seed=2))
    write("mrrp.wav", voice(
        0.42,
        [(0.0, 400), (0.55, 470), (0.85, 650), (1.0, 720)],
        [(0.0, 420), (0.6, 520), (1.0, 640)],
        [(0.0, 1250), (0.6, 1400), (1.0, 1950)],
        [(0.0, 0.0), (0.08, 0.8), (0.7, 0.9), (0.9, 1.0), (1.0, 0.0)],
        roll=26.0, rollpts=[(0.0, 1.0), (0.62, 1.0), (0.78, 0.0), (1.0, 0.0)],
        breath=0.05, seed=3), peak=0.45)
    write("purr.wav", purr(), peak=0.5)
    write("chomp.wav", chomp(), peak=0.45)
    write("thud.wav", thud(), peak=0.5)
    write("pop.wav", pop(), peak=0.4)


if __name__ == "__main__":
    main()
