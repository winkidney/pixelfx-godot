# 8-bit voices and building blocks for pixelfx sound, made the way the effects are: code, seeded, on the effect's own
# beats. Four NES-style voices (2 pulse, triangle, noise LFSR), volumes stepped 16 levels at 60 Hz frames, pitches
# snapped to the NES period table. Rules for using them: godot/skills/pixelfx-godot/references/sound.md.
import numpy as np

SR = 44100
CPU = 1789773.0


# ------------------------------------------------------------------ voices
def nes_hz(f, tri=False):
    """Snap to the frequency an NES period register can make."""
    f = np.maximum(np.asarray(f, float), 20.0)
    div = 32.0 if tri else 16.0
    p = np.clip(np.round(CPU / (div * f) - 1), 8, 2047)
    return CPU / (div * (p + 1))


def phase(f):
    return np.cumsum(np.asarray(f, float) / SR) % 1.0


def pulse(f, duty=0.5):
    return np.where(phase(nes_hz(f)) < duty, 1.0, -1.0)


def tri(f):
    ph = phase(nes_hz(f, True))
    return np.round((1 - 4 * np.abs(ph - 0.5)) * 7.5) / 7.5          # 16-step triangle, as the NES draws it


NOISE_RATES = [4, 8, 16, 32, 64, 96, 128, 160, 202, 254, 380, 508, 762, 1016, 2034, 4068]


def noise(n, rate_idx, short=False, seed=1):
    """The NES LFSR clocked at CPU / period: rate_idx 0 (hiss) .. 15 (rumble), short mode metallic. The register's
    output sequence is generated once, then read at each sample's accumulated clock count."""
    rate_idx = np.broadcast_to(np.asarray(rate_idx, int), (n,))
    clocks = np.cumsum(CPU / np.asarray(NOISE_RATES, float)[rate_idx] / SR)
    total = int(clocks[-1]) + 2 if n else 1
    tap = 6 if short else 1
    reg = (seed * 7919) & 0x7FFF or 1
    seq = np.empty(total, np.int8)
    for i in range(total):                     # only as many steps as the register is clocked
        fb = (reg ^ (reg >> tap)) & 1
        reg = (reg >> 1) | (fb << 14)
        seq[i] = reg & 1
    return np.where(seq[clocks.astype(np.int64)] == 1, 1.0, -1.0)


def steps(env):
    """Volume held per 60 Hz frame in 16 levels, as the NES envelope does."""
    env = np.clip(np.asarray(env, float), 0, 1)
    frame = SR // 60
    held = env[:: frame].repeat(frame)[: len(env)]
    return np.round(held * 15) / 15


def T(secs):
    return np.arange(int(round(secs * SR))) / SR


def place(buf, sig, at, pan=0.0, gain=1.0):
    """Mix a mono signal into a stereo buffer at `at` seconds, panned -1..1."""
    i = int(round(at * SR))
    if i >= len(buf):
        return
    s = sig[: len(buf) - i] * gain
    buf[i:i + len(s), 0] += s * np.sqrt((1 - pan) / 2)
    buf[i:i + len(s), 1] += s * np.sqrt((1 + pan) / 2)


def blank(secs):
    return np.zeros((int(round(secs * SR)), 2))


X = 0.03   # a loop is rendered this much longer and its overrun crossfaded into its start: no click at the wrap


def wrap(buf, secs):
    n, x = int(round(secs * SR)), int(round(X * SR))
    out = buf[:n].copy()
    r = np.linspace(0, 1, x)[:, None] if buf.ndim == 2 else np.linspace(0, 1, x)
    out[:x] = buf[:x] * r + buf[n:n + x] * (1 - r)
    return out


def decay(t, k):
    return np.exp(-t * k)


# ------------------------------------------------------------------ building blocks
def whoosh(secs, r0, r1, vol=0.5, seed=3):
    t = T(secs)
    rate = np.round(np.interp(t, [0, secs], [r0, r1])).astype(int)
    env = np.sin(np.pi * np.clip(t / secs, 0, 1)) * vol
    return noise(len(t), rate, seed=seed) * steps(env)


def boom(secs=0.6, f0=320, f1=48, vol=0.9, seed=5):
    t = T(secs)
    f = f1 + (f0 - f1) * decay(t, 9)
    body = pulse(f, 0.5) * steps(decay(t, 6) * vol * 0.55)
    crack = noise(len(t), np.where(t < 0.05, 2, 13), seed=seed) * steps(decay(t, 4.5) * vol)
    return body + crack


def blip(f, secs=0.12, duty=0.125, vol=0.35, k=18, slide=0.0):
    t = T(secs)
    return pulse(f * (1 + slide * t / secs), duty) * steps(decay(t, k) * vol)


def chime(notes, gap=0.05, duty=0.25, vol=0.3, k=10):
    secs = gap * len(notes) + 0.35
    out = np.zeros(int(secs * SR))
    for i, f in enumerate(notes):
        s = blip(f, 0.35, duty, vol, k)
        j = int(i * gap * SR)
        out[j:j + len(s)] += s[: len(out) - j]
    return out


def tick(vol=0.25, seed=1, short=True):
    t = T(0.04)
    return noise(len(t), 3, short=short, seed=seed) * steps(decay(t, 70) * vol)


NOTE = lambda n: 440.0 * 2 ** ((n - 69) / 12)   # MIDI note -> Hz


def charge(secs, rate0=13, rate1=3, f0=180, f1=900, vol=0.45, seed=1, crackle=True):
    """A charge that builds without notes: noise whose rate climbs (rumble -> hiss), a thin glide rising under it,
    crackles getting denser, all swelling toward the release."""
    rng = np.random.default_rng(seed)
    t = T(secs)
    u = t / secs
    rate = np.round(rate0 + (rate1 - rate0) * u).astype(int)
    swell = (0.15 + 0.85 * u ** 1.6) * vol
    out = noise(len(t), rate, seed=seed) * steps(swell * 0.6)
    out += pulse(f0 * (f1 / f0) ** u * (1 + 0.02 * np.sin(2 * np.pi * 9 * t)), 0.125) * steps(swell * 0.18)
    if crackle:
        n = int(6 + 18 * secs)
        for at in sorted(rng.uniform(0, secs, n) ** 0.6 * secs ** 0.4):        # denser toward the end
            j = int(at * SR)
            c = tick(0.05 + 0.15 * at / secs, int(rng.integers(1, 99)))
            out[j:j + len(c)] += c[: len(out) - j]
    return out


# ------------------------------------------------------------------ what an effect's sound function returns
class Silent:
    """No sound, and why (which rule: a steady thing with no noise of its own, ...)."""

    def __init__(self, why):
        self.why = why


class Sound:
    """full: stereo float array, the whole play on the effect's own clock (frame 0 = t 0). A loop is exactly one
    loop long and wraps seamlessly (render X longer and wrap()); a one-shot may ring up to 1.5 s past its duration.
    phases: the parts a game triggers ({"start", "loop", "hit", "body", "tail", "release", ...}: arrays).
    notes: one line on what it is and which beats it follows."""

    def __init__(self, full, phases=None, notes=""):
        self.full = full
        self.phases = phases or {}
        self.notes = notes


def stereo(sig, pan=0.0):
    """A mono signal as a stereo array, panned -1..1."""
    return np.stack([sig * np.sqrt((1 - pan) / 2), sig * np.sqrt((1 + pan) / 2)], 1) * np.sqrt(2)


# ------------------------------------------------------------------ material hits (references/sound.md rule 2)
# The weight under a hit comes from what is hit, not from one shared "thump". The pitch-dropping pulse thump (boom)
# belongs to explosions and blasts only. `weight` 0..1 scales size: bigger is lower, longer and louder; `seed` varies
# each one so no two hits of a scene are the same.
def _rng(seed):
    return np.random.default_rng(seed)


def _q(env, vol):
    """A 16-step envelope scaled after stepping, so quiet layers don't vanish (README pitfalls)."""
    return steps(np.clip(env, 0, 1)) * vol


def water_hit(weight=0.5, seed=1, vol=0.6):
    """Water struck or crashing down: a low noise 'whomp' (rumble rate opening up to a wash), a splash of bright
    spray, and for a plunge a short bubble 'bloop' gliding up. No tone underneath."""
    r = _rng(seed)
    secs = 0.35 + 0.6 * weight
    t = T(secs)
    rate = np.round(np.interp(t, [0, 0.04, secs], [14, 9 + 2 * weight, 6])).astype(int)
    whomp = noise(len(t), rate, seed=seed) * _q(np.exp(-t / (0.08 + 0.25 * weight)), vol * (0.6 + 0.4 * weight))
    spray = noise(len(t), np.round(np.interp(t, [0, secs], [3, 1])).astype(int), seed=seed + 1) * \
        _q(np.interp(t, [0, 0.03, secs], [0, 1, 0]) ** 1.5, vol * 0.35)
    tb = T(0.12)
    bloop = tri(np.interp(tb, [0, 0.12], [120 + 80 * r.random(), 420 + 200 * r.random()])) * _q(np.exp(-tb * 25), vol * 0.3 * weight)
    out = whomp + spray
    out[: len(bloop)] += bloop
    return out


def stone_hit(weight=0.5, seed=1, vol=0.6):
    """Stone or earth struck: a dry short knock (triangle, no long glide) and a gritty crunch."""
    r = _rng(seed)
    secs = 0.09 + 0.18 * weight
    t = T(secs)
    f = (180 - 110 * weight) * (0.9 + 0.2 * r.random())
    knock = tri(f * (1 - 0.25 * t / secs)) * _q(np.exp(-t / (0.03 + 0.06 * weight)), vol)
    crunch = noise(len(t), 4 + int(5 * weight), short=True, seed=seed) * _q(np.exp(-t * 30), vol * 0.5)
    return knock + crunch


def wood_hit(weight=0.5, seed=1, vol=0.5):
    """Wood: a hollow 'tok', short and pitched by size."""
    r = _rng(seed)
    t = T(0.08 + 0.05 * weight)
    f = (420 - 220 * weight) * (0.9 + 0.2 * r.random())
    return tri(f * np.ones(len(t))) * _q(np.exp(-t * 45), vol) + \
        noise(len(t), 2, seed=seed) * _q(np.exp(-t * 120), vol * 0.4)


def flesh_hit(weight=0.5, seed=1, vol=0.6):
    """A body struck: a mid noise smack and a very short low push, no tone that rings or glides."""
    t = T(0.1 + 0.08 * weight)
    smack = noise(len(t), 5 + int(4 * weight), seed=seed) * _q(np.exp(-t * 55), vol)
    push = tri((75 + 30 * _rng(seed).random()) * np.ones(len(t))) * _q(np.exp(-t * (40 - 20 * weight)), vol * 0.5 * weight)
    return smack + push


def metal_hit(weight=0.5, seed=1, vol=0.5):
    """Metal struck: two inharmonic pulses beating, a bright scrape; bigger rings lower and longer."""
    r = _rng(seed)
    secs = 0.18 + 0.4 * weight
    t = T(secs)
    f = (1900 - 1100 * weight) * (0.92 + 0.16 * r.random())
    ring = pulse(f * np.ones(len(t)), 0.125) + 0.6 * pulse(f * 1.414 * np.ones(len(t)), 0.25)
    ring = ring * _q(np.exp(-t / (0.05 + 0.15 * weight)), vol * 0.5)
    return ring + noise(len(t), 0, short=True, seed=seed) * _q(np.exp(-t * 60), vol * 0.5)


def glass_hit(weight=0.5, seed=1, vol=0.5):
    """Ice or glass: a crisp short-mode crack and a scatter of high tinks; no low weight."""
    r = _rng(seed)
    out = noise(int(0.06 * SR), 1, short=True, seed=seed) * _q(np.exp(-T(0.06) * 60), vol)
    out = np.concatenate([out, np.zeros(int((0.1 + 0.25 * weight) * SR))])
    for k in range(3 + int(5 * weight)):
        f = 2400 + 2600 * r.random()
        s = pulse(f * np.ones(int(0.05 * SR)), 0.125) * _q(np.exp(-T(0.05) * 70), vol * 0.25)
        j = int(r.uniform(0.005, 0.08 + 0.2 * weight) * SR)
        out[j:j + len(s)] += s[: len(out) - j]
    return out


def energy_hit(weight=0.5, seed=1, vol=0.5):
    """Energy (a bolt, a beam, a spell landing): a zap gliding down and a short buzz; weight from a noise whoomp."""
    r = _rng(seed)
    secs = 0.12 + 0.2 * weight
    t = T(secs)
    zap = pulse(np.interp(t, [0, secs], [1600 + 600 * r.random(), 220]), 0.25) * _q(np.exp(-t * 14), vol * 0.45)
    whoomp = noise(len(t), np.round(np.interp(t, [0, secs], [8, 13])).astype(int), seed=seed) * \
        _q(np.exp(-t / (0.04 + 0.1 * weight)), vol * 0.6 * (0.5 + weight))
    return zap + whoomp


def pop_hit(weight=0.5, seed=1, vol=0.5):
    """A cartoon or UI pop: a quick upward blip and a puff. Bigger is lower, longer and puffier."""
    secs = 0.05 + 0.08 * weight
    t = T(secs)
    f0 = (500 - 280 * weight) * (0.85 + 0.3 * _rng(seed).random())
    blip = pulse(np.interp(t, [0, secs], [f0, f0 * 2.5]), 0.5) * _q(np.exp(-t * (50 - 25 * weight)), vol * 0.4)
    puff = noise(len(t), 3 + int(4 * weight), seed=seed) * _q(np.exp(-t * (60 - 30 * weight)), vol * (0.3 + 0.2 * weight))
    return blip + puff


MATERIAL_HITS = {"water": water_hit, "stone": stone_hit, "earth": stone_hit, "wood": wood_hit, "flesh": flesh_hit,
                 "metal": metal_hit, "glass": glass_hit, "ice": glass_hit, "energy": energy_hit, "pop": pop_hit}


def material_hit(material, weight=0.5, seed=1, vol=0.6):
    """The hit's weight voice for what is struck; "blast" (explosions only) is the pitch-dropping boom."""
    if material == "blast":
        return boom(0.3 + 0.5 * weight, 260 + 80 * _rng(seed).random(), 40 + 20 * (1 - weight), vol, seed)
    return MATERIAL_HITS[material](weight, seed, vol)
