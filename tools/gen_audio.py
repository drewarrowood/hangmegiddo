"""Generate soft Egyptian ambient + battle SFX for Hang Megiddo (no numpy)."""
import wave, math, struct, os, random

OUT = os.path.join(os.path.dirname(__file__), "..", "godot", "audio")
os.makedirs(OUT, exist_ok=True)
SR = 22050
random.seed(1457)


def write_wav(path, samples, sr=SR):
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        frames = bytearray()
        for s in samples:
            v = max(-1.0, min(1.0, s))
            frames += struct.pack("<h", int(v * 32767))
        w.writeframes(frames)
    print(os.path.basename(path), f"{len(samples)/sr:.2f}s")


def env_adsr(i, n, a=0.02, d=0.1, s=0.6, r=0.2):
    t = i / max(n, 1)
    if t < a:
        return t / max(a, 1e-6)
    if t < a + d:
        return 1.0 - (1.0 - s) * ((t - a) / max(d, 1e-6))
    if t < 1.0 - r:
        return s
    return s * max(0.0, (1.0 - t) / max(r, 1e-6))


def tone(freq, dur, vol=0.2, kind="sin", a=0.02, d=0.08, s=0.5, r=0.15):
    n = int(SR * dur)
    out = []
    for i in range(n):
        t = i / SR
        e = env_adsr(i, n, a, d, s, r)
        ph = 2 * math.pi * freq * t
        if kind == "sin":
            v = math.sin(ph)
        elif kind == "pluck":
            v = math.sin(ph) * math.exp(-t * 3.5)
            e = 1.0
        else:
            v = math.sin(ph) + 0.3 * math.sin(2 * ph)
        out.append(v * e * vol)
    return out


def mix(*tracks):
    n = max(len(t) for t in tracks)
    out = [0.0] * n
    for tr in tracks:
        for i, s in enumerate(tr):
            out[i] += s
    m = max(1e-6, max(abs(x) for x in out))
    if m > 0.95:
        out = [x * 0.95 / m for x in out]
    return out


def pad(seq, n):
    if len(seq) >= n:
        return seq[:n]
    return seq + [0.0] * (n - len(seq))


def noise_burst(dur, vol=0.3, decay=8.0):
    n = int(SR * dur)
    return [(random.random() * 2 - 1) * vol * math.exp(-(i / SR) * decay) for i in range(n)]


# Soft Egyptian-ish ambient (gentle, cat-friendly)
scale = [196.0, 220.0, 261.63, 293.66, 329.63, 392.0, 440.0]
dur = 48.0
n = int(SR * dur)
amb = [0.0] * n
for f, vol in [(98.0, 0.04), (147.0, 0.03), (196.0, 0.025)]:
    for i in range(n):
        t = i / SR
        amb[i] += math.sin(2 * math.pi * f * t) * vol * (0.85 + 0.15 * math.sin(t * 0.2))
beat = 0.85
t = 0.0
while t < dur - 1.5:
    f = random.choice(scale)
    pl = tone(f, 1.4, vol=0.07, kind="pluck")
    start = int(t * SR)
    for j, s in enumerate(pl):
        if start + j < n:
            amb[start + j] += s
    if random.random() < 0.35:
        pl2 = tone(f * 1.5, 1.2, vol=0.04, kind="pluck")
        for j, s in enumerate(pl2):
            if start + j < n:
                amb[start + j] += s
    t += beat * random.choice([1, 1, 2, 0.5])
t = 2.0
while t < dur - 2:
    f = random.choice(scale[2:])
    fl = tone(f, 1.8, vol=0.05, kind="sin", a=0.15, d=0.2, s=0.55, r=0.4)
    start = int(t * SR)
    for j, s in enumerate(fl):
        if start + j < n:
            amb[start + j] += s * (0.7 + 0.3 * math.sin(j / SR * 3))
    t += random.uniform(2.5, 4.5)
for i in range(n):
    amb[i] += (random.random() * 2 - 1) * 0.008 * (0.5 + 0.5 * math.sin(i / SR * 0.3))
m = max(abs(x) for x in amb)
amb = [x * 0.55 / m for x in amb]
write_wav(os.path.join(OUT, "ambient_egypt.wav"), amb)


def horse():
    parts = []
    for _ in range(6):
        thud = tone(90 + random.random() * 20, 0.08, vol=0.35, kind="sin", a=0.005, d=0.02, s=0.2, r=0.05)
        nse = noise_burst(0.06, 0.2, 25)
        parts.append(pad(mix(thud, nse), int(0.12 * SR)))
        parts.append([0.0] * int(0.05 * SR))
    sn = noise_burst(0.25, 0.25, 6)
    sn = [s * (0.5 + 0.5 * math.sin(i / SR * 40)) for i, s in enumerate(sn)]
    parts.append(sn)
    out = []
    for p in parts:
        out.extend(p)
    return out


write_wav(os.path.join(OUT, "sfx_horse.wav"), horse())


def wheels():
    n = int(SR * 1.2)
    out = []
    for i in range(n):
        t = i / SR
        rumble = math.sin(2 * math.pi * 55 * t) * 0.15
        click = 0.0
        if int(t * 14) != int((t - 1 / SR) * 14):
            click = (random.random() * 2 - 1) * 0.35
        wood = (random.random() * 2 - 1) * 0.08 * (0.5 + 0.5 * math.sin(t * 30))
        out.append((rumble + click + wood) * math.exp(-t * 0.4))
    return out


write_wav(os.path.join(OUT, "sfx_wheels.wav"), wheels())


def bow():
    n = int(SR * 0.55)
    out = []
    f0 = 420
    for i in range(n):
        t = i / SR
        v = math.sin(2 * math.pi * f0 * t) * math.exp(-t * 9)
        v += 0.4 * math.sin(2 * math.pi * f0 * 2.01 * t) * math.exp(-t * 12)
        if t < 0.03:
            v += (random.random() * 2 - 1) * 0.25 * (1 - t / 0.03)
        out.append(v * 0.45)
    return out


write_wav(os.path.join(OUT, "sfx_bow.wav"), bow())


def grunt():
    n = int(SR * 0.4)
    out = []
    f = 140 + random.random() * 40
    for i in range(n):
        t = i / SR
        v = math.sin(2 * math.pi * f * t) * math.exp(-t * 7)
        v += (random.random() * 2 - 1) * 0.15 * math.exp(-t * 12)
        f *= 0.998
        out.append(v * 0.5)
    return out


write_wav(os.path.join(OUT, "sfx_grunt.wav"), grunt())


def scream():
    n = int(SR * 0.7)
    out = []
    for i in range(n):
        t = i / SR
        f = 380 + 200 * math.sin(t * 8) + t * 120
        v = math.sin(2 * math.pi * f * t)
        v += 0.3 * (random.random() * 2 - 1)
        out.append(v * 0.35 * math.exp(-t * 2.2) * (1 if t > 0.02 else t / 0.02))
    return out


write_wav(os.path.join(OUT, "sfx_scream.wav"), scream())


def clash():
    n = int(SR * 0.35)
    out = []
    for i in range(n):
        t = i / SR
        v = math.sin(2 * math.pi * 800 * t) * math.exp(-t * 20)
        v += math.sin(2 * math.pi * 1200 * t) * math.exp(-t * 25) * 0.5
        v += (random.random() * 2 - 1) * 0.4 * math.exp(-t * 18)
        out.append(v * 0.4)
    return out


write_wav(os.path.join(OUT, "sfx_clash.wav"), clash())
write_wav(os.path.join(OUT, "sfx_ui.wav"), tone(523.25, 0.2, vol=0.12, kind="pluck"))
ch = mix(
    pad(tone(261.63, 0.5, 0.12, "sin", 0.01, 0.1, 0.4, 0.3), int(0.6 * SR)),
    pad([0] * int(0.12 * SR) + tone(329.63, 0.5, 0.1, "sin", 0.01, 0.1, 0.4, 0.3), int(0.7 * SR)),
    pad([0] * int(0.24 * SR) + tone(392.0, 0.7, 0.1, "sin", 0.01, 0.1, 0.4, 0.4), int(0.95 * SR)),
)
write_wav(os.path.join(OUT, "sfx_victory.wav"), ch)
print("done", OUT)
