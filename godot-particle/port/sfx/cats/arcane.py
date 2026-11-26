# arcane: energy without notes (rule 1): fizzing hum and crackles on the effect's own beats.
import numpy as np
from synth import *  # noqa: F401,F403


def spell_charge(m, seed=1, low=False):
    """Loop: energy held in the hand. A fizzing hum that swells each time one of the four rings lands on the orb
    (t = k*D/4 + 0.5, the original's beats), a soft crackle at each landing. release: a downward glide and a whoosh."""
    secs = m["duration"]
    t = T(secs + X)
    land = [(k * secs / 4 + 0.5) % secs for k in range(4)]
    since = np.min([np.mod(t - a, secs) for a in land], axis=0)
    pump = 0.55 + 0.45 * np.exp(-since / 0.12)
    base = 130 if low else 175
    hum = pulse(base * (1 + 0.015 * np.sin(2 * np.pi * 7 * t)), 0.125) * steps(pump * 0.07)
    fizz = noise(len(t), 9 if low else 5, seed=seed) * steps(pump * 0.1)
    buf = stereo(hum + fizz)
    for k, a in enumerate(land):
        place(buf, tick(0.12, 20 + k), a, (-0.4, 0.4)[k % 2])
    rel = blank(0.5)
    place(rel, whoosh(0.35, 2, 9, 0.5, seed), 0)
    place(rel, blip(base * 4, 0.3, 0.25, 0.22, 7, slide=-0.7), 0)
    loop = wrap(buf, secs)
    return Sound(loop, {"loop": loop, "release": rel, "build": stereo(charge(0.9, seed=seed, f0=base, f1=base * 5))},
                 "fizzing hum pumped by the 4 ring landings; release when thrown; build = a one-shot charge")


SOUNDS = {"spell-charge": spell_charge}


# ------------------------------------------------------------------ helpers (shared with cats/holy.py)
# Magic here is energy, so the voices are noise and glides, never notes (rule 1): a gather is noise climbing from rumble
# to hiss with a thin glide rising under it, a pop is a crack and a short high zap flicking down, light is bright noise
# glittering. Where a hit lands, its weight is what is struck (synth.material_hit, sound.md rule 2): a spell landing is
# energy, glass shatters, the floor knocks; never the blast's pitch-dropping thump.
from cats.explosions import pan_x, burst, star_pops, panned                      # noqa: E402
from cats.impacts import (crack, knock, ring, air, fly, st, put, mix, out, hits_of,  # noqa: E402
                          windup_of, seed_of)
from cats.fire import crackle, moving                                           # noqa: E402

TAU = 2 * np.pi


class JsRng:
    """The original's Rng (src/core/math.js, mulberry32): replays the effect's own draws, so event times and places
    (where a star lands, when a rune pops) are the ones on screen."""

    def __init__(self, seed):
        self.s = (int(seed) & 0xFFFFFFFF) or 1

    def next(self):
        self.s = (self.s + 0x6D2B79F5) & 0xFFFFFFFF
        t = self.s
        t = ((t ^ (t >> 15)) * (t | 1)) & 0xFFFFFFFF
        t ^= (t + (((t ^ (t >> 7)) * (t | 61)) & 0xFFFFFFFF)) & 0xFFFFFFFF
        return ((t ^ (t >> 14)) & 0xFFFFFFFF) / 4294967296

    def range(self, a, b):
        return a + (b - a) * self.next()

    def int(self, a, b):
        return int(np.floor(self.range(a, b + 1)))

    def chance(self, p):
        return self.next() < p


def glitter(secs, env, rate=0, seed=1, depth=0.6, short=False):
    """Light as sound: bright noise whose level jumps at random every 60 Hz frame, so it sparkles instead of hissing.
    env: a number or an array as long as T(secs)."""
    t = T(secs)
    rng = np.random.default_rng(seed)
    f = (1 - depth * rng.random(len(t) // (SR // 60) + 1)).repeat(SR // 60)[: len(t)]
    env = np.broadcast_to(env, t.shape) * f
    top = env.max() if len(env) and env.max() > 0 else 1.0
    return noise(len(t), rate, short, seed) * steps(env / top) * top     # 16 steps of its own: quiet ones don't drop out


def sweep(f0, f1, secs, env, duty=0.125, shape=None):
    """A thin tone gliding f0 -> f1 (exponential, or along shape(u) 0..1): energy moving, never a note."""
    t = T(secs)
    u = np.clip(t / secs, 0, 1)
    k = shape(u) if shape else u
    env = np.broadcast_to(env, t.shape)
    top = env.max() if len(env) and env.max() > 0 else 1.0
    return pulse(f0 * (f1 / f0) ** k, duty) * steps(env / top) * top


def gather(secs, vol, seed, r0=10, r1=1, f0=220, f1=900, p=2.0, ticks=10, rng=None, spread=0.5):
    """Energy rushing in to a point: noise climbing rumble -> hiss and swelling faster and faster, a thin glide rising
    under it, streak ticks getting denser (stereo: the ticks come from all round)."""
    t = T(secs)
    u = t / secs
    env = (0.08 + 0.92 * u ** p) * vol
    sig = noise(len(t), np.round(r0 + (r1 - r0) * u ** 1.3).astype(int), seed=seed) * steps(env)
    sig += pulse(f0 * (f1 / f0) ** u, 0.125) * steps(env * 0.28)
    out_ = stereo(sig)
    rng = rng or np.random.default_rng(seed)
    for at in np.sort(rng.random(ticks) ** 0.55) * secs * 0.97:
        place(out_, tick(vol * rng.uniform(0.3, 0.6), int(rng.integers(1, 99))), at, rng.uniform(-spread, spread))
    return out_


def struck(material, weight, seed, vol, delay=0.012):
    """The weight of what a hit strikes (synth.material_hit: energy, glass, stone ...), just after the hit's own crack
    (sound.md rule 2: a bright crack, then the weight) (mono)."""
    return np.concatenate([np.zeros(int(delay * SR)), material_hit(material, weight, seed, vol)])


def pop(vol, seed, f0=560, f1=110, rate=0, short=False, fizz=0.0):
    """A small magic pop: a bright crack and a short zap flicking down from 2 f0 to 3 f1 (energy's own voice, high and
    60 ms: no low drop, that is a blast's), with an optional sparkle fizz after."""
    s = np.zeros(int(0.35 * SR)) if fizz else np.zeros(0)
    c = crack(0.03, rate, vol, 80, seed, short)
    t = T(0.06)
    f = 2 * f0 * (0.94 + 0.12 * np.random.default_rng(seed).random())
    d = pulse(np.interp(t, [0, 0.06], [f, max(3 * f1, 300)]), 0.25) * steps(decay(t, 45) * vol * 0.45)
    parts = [c, d] + ([burst(0.3, 1, vol * fizz, 12, seed + 1, short=True)] if fizz else [])
    out_ = np.zeros(max(len(x) for x in parts + [s]))
    for x in parts:
        out_[: len(x)] += x
    return out_


def twinkles(buf, rng, n, t_rng, vol, pans, short_p=0.5):
    """Lights winking out (stars, sparks): n tiny high clicks at random in t_rng, panned in pans (lo, hi)."""
    for _ in range(n):
        c = burst(rng.uniform(0.008, 0.02), int(rng.integers(0, 2)), vol * rng.uniform(0.5, 1), 160,
                  int(rng.integers(1, 99)), short=bool(rng.random() < short_p))
        place(buf, c, rng.uniform(*t_rng), rng.uniform(*pans))


def env_at(t, pts):
    """A piecewise-linear envelope through (time, level) points."""
    a = np.array(pts, float)
    return np.interp(t, a[:, 0], a[:, 1])


# ------------------------------------------------------------------ silent: steady things with no noise of their own
def arcane_orb(m):
    return Silent("an orb floating in place, rings and motes turning round it: an idle glow, a silent thing stays "
                  "silent (rule 2)")


def portal(m):
    return Silent("a rift standing open, swirling and pulling motes in, nothing changing: a steady thing with no noise "
                  "of its own stays silent (rule 2); an opening/closing one-shot belongs to the game's own moment")


def rune_circle(m):
    return Silent("a rune circle turning on the floor: a steady glow, silent (rule 2)")


# ------------------------------------------------------------------ arcane beam (loop)
def arcane_beam(m):
    """Loop (1.2 s): a held beam is energy, so a buzz (rule 5): a low pulse hum beating against a detuned copy and
    wobbling with the beam's width (8 swells a loop), a hiss at the hand's flare (x 15), and at the end (x 183) a
    sizzle with the spark fountain crackling, swelling a little as the target is pushed (act hits 0.1, 0.7).
    start = the windup (0.62 s): a gather into the hand, then the beam igniting (a crack and a zap racing out along it).
    stop = the beam cut: the hum sagging away and the end fizzing out."""
    s = seed_of(m)
    rng = np.random.default_rng(s)
    D = m["duration"]
    HX, EX = 15, 15 + 168
    ph, pe, pm = pan_x(m, HX, 0.8), pan_x(m, EX, 0.8), pan_x(m, (HX + EX) / 2, 0.8)
    t = T(D + X)
    u = t / D
    wob = np.sin(TAU * 8 * u)
    push = 1.0
    for th, k in zip([h for h, _ in hits_of(m)], (0.35, 0.25)):
        push = push + k * np.exp(-np.mod(t - th, D) / 0.12)
    f = 88 * (1 + 0.015 * wob)
    hum = pulse(f, 0.125) * steps(0.2 + 0.03 * wob) + pulse(f + 3.1, 0.125) * steps(np.full(len(t), 0.13))
    core = noise(len(t), 2, seed=s) * steps(0.1 + 0.02 * wob)
    flare = noise(len(t), 0, seed=s + 1) * steps(0.1 + 0.03 * np.sin(TAU * 10 * u))
    end = noise(len(t), 4, short=False, seed=s + 2) * steps(np.minimum(1, 0.13 * push))
    buf = stereo(hum + core, pm)
    place(buf, flare, 0, ph)
    place(buf, end, 0, pe)
    crackle(buf, rng, 34, (0.0, D - 0.035), 0.22, (pe - 0.15, min(1, pe + 0.05)), short=True)
    loop = wrap(buf, D)
    w = windup_of(m, 0.62)
    start = blank(w + 0.35)
    put(start, panned(gather(w, 0.22, s + 3, 11, 4, 150, 520, ticks=8, spread=0.2), ph), 0)
    put(start, st([crack(0.04, 1, 0.7, 60, s + 4, True), sweep(1700, 220, 0.14, decay(T(0.14), 12) * 0.3)], ph), w)
    put(start, st(air(0.2, 1, 3, 0.35, s + 5, "fall"), (ph, pe)), w + 0.01)
    t = T(0.45)
    stop = st([pulse(88 * 0.5 ** (t / 0.3), 0.125) * steps(decay(t, 9) * 0.3),
               noise(len(t), 2, seed=s + 6) * steps(decay(t, 12) * 0.25)], pm)
    put(stop, st(burst(0.35, 4, 0.25, 10, s + 7), pe), 0)
    return out(loop, {"loop": loop, "start": start, "stop": stop},
               "buzzing hum wobbling 8x a loop, hiss at the hand, sizzle + spark crackle at the end swelling on the "
               "pushes (0.1, 0.7); start = gather + ignition zap; stop = hum sagging, end fizzing out", 0.23)


# ------------------------------------------------------------------ arcane missiles
def arcane_missiles(m):
    """start (windup 0.52): a quiet gather in the hand. Each of the 5 bolts leaves the hand (0.05 + 0.1 i) with a soft
    'fwip' (noise only), then flies as a whirring hiss that climbs and swells as it speeds up (150 + 560 age^2 px/s),
    panned from the hand (x 15) to the target (x 152). Each lands on its act hit (0.77, 0.85, 0.95, 1.08) as a pop, its
    sparkle after the 0.02 hit-stop; the last (1.2, hit-stop 0.07, shake) is a full small hit: crack and energy's weight
    (a spell landing: a zap gliding down, a noise whoomp), a short sparkle after the freeze. Sparks and stars
    wink out after each."""
    s = seed_of(m)
    rng = np.random.default_rng(s)
    HX, TX = 15, 152
    ph, pt = pan_x(m, HX, 0.8), pan_x(m, TX, 0.8)
    hits = hits_of(m)
    start = panned(gather(windup_of(m, 0.52), 0.14, s, 12, 5, 160, 420, ticks=6, spread=0.2), ph)
    cast = blank(1.3)
    for i, (th, _) in enumerate(hits):
        t0 = 0.05 + 0.1 * i
        g = rng.uniform(0.75, 1)
        put(cast, st(air(0.07, 3, 0, 0.16 * g, s + 10 + i, "fall"), ph), t0)
        d = th - t0
        t = T(d)
        a = t / d
        sp = (150 + 560 * t ** 2) / (150 + 560 * d ** 2)
        sig = noise(len(t), np.round(6 - 5 * sp).astype(int), seed=s + 20 + i) * steps((0.12 + 0.88 * sp) * 0.1 * g)
        sig += pulse(300 * (1 + 2.2 * sp) * (1 + 0.04 * np.sin(TAU * 4.1 * t + i)), 0.125) * steps(sp * 0.035 * g)
        moving(cast, sig, t0, ph + (pt - ph) * a ** 1.4)
    parts = [(cast, 0)]
    hit = None
    for i, (th, fz) in enumerate(hits):
        p = pt + rng.uniform(-0.05, 0.05)
        last = i == len(hits) - 1
        if last:
            hit_last = st([crack(0.05, 1, 0.9, 50, s + 30), struck("energy", 0.55 * rng.uniform(0.9, 1.1), s + 131, 0.75)], p)
            body = st(burst(0.4, 1, 0.16, 8, s + 32, short=True), p)
            parts += [(hit_last, th), (body, th + fz)]
        else:
            h = st(pop(0.6 * rng.uniform(0.85, 1), s + 40 + i, 600 * rng.uniform(0.9, 1.1), 120, i % 2, bool(i % 2)), p)
            hit = h if hit is None else hit
            parts += [(h, th), (st(burst(0.22, 1, 0.12, 14, s + 50 + i, short=True), p), th + fz)]
    tail = blank(1.4)
    for i, (th, fz) in enumerate(hits):
        twinkles(tail, rng, 8 if i == len(hits) - 1 else 3, (th + 0.12, th + 0.5), 0.12, (pt - 0.25, pt + 0.2))
    parts.append((tail, 0))
    full = mix(parts, m["duration"])
    return out(full, {"start": start, "cast": cast, "hit": hit, "hit_last": hit_last, "body": body},
               "gather (windup); 5 soft fwips at the launches, whirring hisses swelling and panning hand->target; pops on "
               "the hits 0.77/0.85/0.95/1.08, a full small energy hit at 1.2, its sparkle after the 0.07 hit-stop", 0.68)


# ------------------------------------------------------------------ blink in / blink out
def blink_in(m):
    """Bits spiral in (0 .. LINE 0.26): a gather, noise climbing to hiss and swelling, streak ticks denser; the point of
    light opens into a line (0.26 .. 0.36: a thin zip up) and the line into the silhouette (.. 0.48: bright noise
    widening across the stereo); hit at ARRIVE 0.48 (the act's hit, hit-stop 0.03, the caster lands crouched): a crack,
    energy's weight (light setting down) and the feet's light knock on the floor; after the freeze the caster cools out of the white (0.42 s): a sparkling fizz and the outline crackling,
    thinning; the 30 stars and 12 floor sparks wink out after."""
    s = seed_of(m)
    rng = np.random.default_rng(s)
    LINE, GROW, OPEN = 0.26, 0.1, 0.12
    (th, fz), = hits_of(m)
    p = pan_x(m, 0)
    start = blank(th)
    put(start, panned(gather(LINE, 0.3, s, 10, 2, 260, 1100, ticks=14, rng=rng), p), 0)
    put(start, st(sweep(1100, 2600, GROW, decay(T(GROW), 8) * 0.12), p), LINE)
    t = T(GROW + OPEN)
    u = t / (GROW + OPEN)
    open_ = glitter(GROW + OPEN, 0.2 + 0.15 * u, 0, s + 1, 0.4)
    moving(start, open_ * 0.7, LINE, p - 0.6 * u ** 2)
    moving(start, open_ * 0.7, LINE, p + 0.6 * u ** 2)
    hit = st([crack(0.04, 1, 0.75, 60, s + 2), struck("energy", 0.35 * rng.uniform(0.9, 1.1), s + 141, 0.6),
              struck("stone", 0.15, s + 142, 0.3, 0.02), burst(0.1, 0, 0.3, 35, s + 3, short=True)], p)
    body = st(glitter(0.45, decay(T(0.45), 7) * 0.26, 1, s + 4, 0.7), p)
    for i in range(12):
        a = 0.42 * (i / 12) ** 0.8
        put(body, st(tick(0.16 * (1 - i / 14), int(rng.integers(1, 99))), p + rng.uniform(-0.2, 0.2)), a)
    tail = blank(1.0)
    twinkles(tail, rng, 12, (0.1, 0.4), 0.14, (p - 0.5, p + 0.5))
    twinkles(tail, rng, 18, (0.4, 0.88), 0.11, (p - 0.4, p + 0.4))
    full = mix([(start, 0), (hit, th), (body, th + fz), (tail, th)], m["duration"])
    return out(full, {"start": start, "hit": hit, "body": body, "tail": tail},
               "gather rushing in (0-0.26), zip as the line opens, bright noise widening (0.36-0.48); crack + energy + "
               "feet's knock on arrival (0.48), sparkling cool-out after the 0.03 hit-stop, stars winking out", 0.65)


def blink_out(m):
    """Gathering (0 .. OUT 0.32): the outline crackles thicker (its density 0.25 + 0.65 k) over a fizz climbing to hiss;
    the white flash at OUT: a zap; squeezed into a line and collapsing (0.32 .. POP 0.52): a thin zip racing up while
    it shrinks; POP 0.52: a sharp pop and a short fizz; the 18 sparks and 14 stars wink out after, the 110 bits drift
    off silently."""
    s = seed_of(m)
    rng = np.random.default_rng(s)
    OUT, POP = 0.32, 0.52
    p = pan_x(m, 0)
    t = T(OUT)
    k = t / OUT
    g = noise(len(t), np.round(8 - 7 * k ** 1.2).astype(int), seed=s) * steps((0.1 + 0.9 * k ** 2) * 0.2)
    g += pulse(200 * 3.5 ** k, 0.125) * steps(k ** 2 * 0.05)
    start = blank(POP)
    put(start, st(g, p), 0)
    at = 0.0
    while True:                                     # crackles at the outline's own density, thicker as it gathers
        at += rng.exponential(1 / (20 + 60 * at / OUT))
        if at >= OUT:
            break
        put(start, st(tick(0.06 + 0.12 * at / OUT, int(rng.integers(1, 99))), p + rng.uniform(-0.25, 0.25)), at)
    put(start, st([crack(0.03, 0, 0.6, 70, s + 1, True), burst(0.08, 2, 0.2, 40, s + 2)], p), OUT)
    d = POP - OUT
    t = T(d)
    q = t / d
    put(start, st([pulse(500 * 6 ** (q ** 2), 0.125) * steps(0.13 * (1 - 0.6 * q)),
                   noise(len(t), 1, seed=s + 3) * steps(0.16 * (1 - q) ** 1.5)], p), OUT + 0.02)
    hit = st([crack(0.035, 0, 0.85, 60, s + 4), struck("energy", 0.2 * rng.uniform(0.9, 1.1), s + 151, 0.5),
              burst(0.3, 2, 0.12, 10, s + 5, short=True)], p)
    tail = blank(1.0)
    twinkles(tail, rng, 10, (0.05, 0.4), 0.15, (p - 0.6, p + 0.6))
    twinkles(tail, rng, 12, (0.35, 0.9), 0.1, (p - 0.4, p + 0.4))
    full = mix([(start, 0), (hit, POP), (tail, POP)], m["duration"])
    return out(full, {"start": start, "hit": hit, "tail": tail},
               "outline crackling denser over a rising fizz (0-0.32), zap at the flash (0.32), zip up as it squeezes, "
               "sharp pop at 0.52, sparks winking out", 0.64)


# ------------------------------------------------------------------ magic circle cast
def magic_circle_cast(m):
    """The circle draws itself (pens 0.04 .. 0.48 running both ways round from the front, the inner ring 0.3 .. 0.6,
    the star 0.52 .. 0.88): a quiet scratch of light following the pens across the stereo. The 8 runes ignite one by
    one (0.9 .. 1.3, round the ring): each a small crackle where it sits. The chase light speeds up round the ring to
    the flash (0.9 .. 1.52): a charge, noise and a glide climbing, crackles denser. FLASH 1.52, the column fires up:
    crack, energy's weight (a zap gliding down, a noise whoomp), an upward rush, the floor rings rushing out both sides. The column stands (.. BREAK 2.42): a bright
    roaring hiss; BREAK: it bursts into glints (a sparkle burst, stars winking out over a second) and the runes go out
    one by one (2.62 + 0.08 k) as soft pops."""
    s = seed_of(m)
    rng = np.random.default_rng(s)
    R, R2, RI, RR = 40, 35, 24, 30
    FLASH, BREAK = 1.52, 2.42
    etch = blank(0.9)
    for (a, b), rad in (((0.04, 0.42), R), ((0.1, 0.48), R2)):
        t = T(b - a)
        q = t / (b - a)
        for side in (-1, 1):
            sig = glitter(b - a, 0.09, 1, s + rad + side, 0.8)
            moving(etch, sig, a, np.array([pan_x(m, side * rad * np.sin(np.pi * v)) for v in q[::64]]).repeat(64))
    t = T(0.3)
    moving(etch, glitter(0.3, 0.1, 1, s + 3, 0.8), 0.3, np.array([pan_x(m, RI * np.sin(TAU * v)) for v in (t / 0.3)[::64]]).repeat(64))
    put(etch, st(glitter(0.36, 0.1, 1, s + 4, 0.8), pan_x(m, 0)), 0.52)
    runes = blank(0.5)
    for k in range(8):
        g = -np.pi / 2 + (k + 0.5) * TAU / 8
        c = burst(0.035, int(rng.integers(0, 2)), rng.uniform(0.22, 0.32), 70, s + 10 + k, short=bool(k % 2))
        place(runes, c, k * 0.4 / 7 + rng.uniform(-0.012, 0.012) + 0.012, pan_x(m, np.cos(g) * RR))
    charge_ = stereo(charge(FLASH - 0.9, 11, 1, 200, 900, 0.36, s + 5))
    hit = st([crack(0.05, 0, 0.85, 45, s + 6), struck("energy", 0.7 * rng.uniform(0.92, 1.05), s + 161, 0.7),
              air(0.35, 6, 0, 0.35, s + 7, "fall")], 0)
    put(hit, st(air(0.5, 2, 7, 0.22, s + 8), (-0.2, -0.8)) + st(air(0.5, 2, 7, 0.22, s + 9), (0.2, 0.8)), 0.02)
    L = BREAK + 0.55 - FLASH
    t = T(L)
    lvl = env_at(t, [(0, 1.0), (0.07, 0.8), (BREAK - FLASH, 0.7), (BREAK - FLASH + 0.25, 0.4), (L, 0)])
    body = st([glitter(L, lvl * 0.26, 1, s + 11, 0.35), noise(len(t), 7, seed=s + 12) * steps(lvl * 0.12),
               pulse(70 * (1 + 0.02 * np.sin(TAU * 6 * t)), 0.125) * steps(lvl * 0.07)], 0)
    tail = blank(1.5)
    put(tail, st(burst(0.3, 1, 0.3, 10, s + 13, short=True), 0), 0)
    twinkles(tail, rng, 34, (0.05, 1.1), 0.12, (-0.25, 0.25))
    for k in range(8):
        g = -np.pi / 2 + (k + 0.5) * TAU / 8
        place(tail, pop(0.16 * rng.uniform(0.7, 1), s + 20 + k, 700, 200, 1, True), 0.2 + k * 0.08 + rng.uniform(-0.02, 0.02),
              pan_x(m, np.cos(g) * RR))
    full = mix([(etch, 0), (runes, 0.9), (charge_, 0.9), (hit, FLASH), (body, FLASH), (tail, BREAK)], m["duration"])
    return out(full, {"start": etch, "runes": runes, "charge": charge_, "hit": hit, "body": body, "tail": tail},
               "pen scratch of light following the drawing (0.04-0.88), 8 rune crackles (0.9-1.3), charge to the flash, "
               "crack + energy + upward rush at 1.52, column hiss, glint burst at 2.42, runes popping out", 0.6)


# ------------------------------------------------------------------ mana burst
def mana_burst(m):
    """Energy rushes into a point (0 .. GATHER 0.22): a short gather; the nova at 0.22 (magic, not an explosion): crack,
    energy's weight (a zap gliding down, a noise whoomp) and a rush out to both sides, a sparkling fizz after; the 9 runes flung out round it pop one after another where they stopped (their
    own times and places, the original's draws: 0.64 + 0.065 i + jitter), each a small crack and zap."""
    s = seed_of(m)
    rng = np.random.default_rng(s)
    GATHER = 0.22
    J = JsRng(s)
    runes = []
    for i in range(9):
        a = i / 9 * TAU + J.range(-0.25, 0.25) - np.pi / 2
        sp = J.range(150, 210)
        popt = GATHER + 0.42 + i * 0.065 + J.range(0, 0.05)
        J.range(0, TAU)
        vx = np.cos(a) * sp
        runes.append((popt, vx / 4.2 * (1 - np.exp(-4.2 * (popt - GATHER)))))
    start = gather(GATHER, 0.3, s, 10, 2, 240, 900, ticks=12, rng=rng, spread=0.6)
    hit = st([crack(0.045, 0, 0.9, 55, s + 1), struck("energy", 0.75 * rng.uniform(0.92, 1.05), s + 171, 0.75)], 0)
    put(hit, st(air(0.3, 1, 6, 0.25, s + 2), (-0.2, -0.8)) + st(air(0.3, 1, 6, 0.25, s + 3), (0.2, 0.8)), 0.01)
    body = st(glitter(0.6, decay(T(0.6), 5) * 0.24, 1, s + 4, 0.6), 0)
    pops = blank(1.2)
    for i, (at, x) in enumerate(runes):
        place(pops, pop(0.42 * rng.uniform(0.8, 1), s + 10 + i, 640 * rng.uniform(0.9, 1.1), 150, i % 2, bool(i % 2)),
              at - GATHER, pan_x(m, x))
        twinkles(pops, rng, 2, (at - GATHER + 0.08, at - GATHER + 0.4), 0.09, (pan_x(m, x) - 0.15, pan_x(m, x) + 0.15))
    full = mix([(start, 0), (hit, GATHER), (body, GATHER + 0.02), (pops, GATHER)], m["duration"])
    return out(full, {"start": start, "hit": hit, "body": body, "pops": pops},
               "gather (0-0.22), energy nova with a rush out both ways at 0.22, sparkle fizz, 9 rune pops 0.64-1.2 where each "
               "rune stopped", 0.58)


# ------------------------------------------------------------------ star fall
def star_fall(m):
    """11 stars on the original's own draws (where they land, when: t0 + T, big or small): each falls as a hiss that
    swells on its slanted path (pan from where it starts, 0.38 * h left of its mark, to the mark), then lands with a
    crack and a small zap (big ones heavier: energy's weight and a dry knock of the floor) and a few sparks ticking."""
    s = seed_of(m)
    rng = np.random.default_rng(s)
    J = JsRng(s)
    N, SPREAD, H = 11, 46, 124
    xs = [-SPREAD + (i + J.range(0.2, 0.8)) * 2 * SPREAD / N for i in range(N)]
    for i in range(N - 1, 0, -1):
        j = J.int(0, i)
        xs[i], xs[j] = xs[j], xs[i]
    stars = []
    for i, x in enumerate(xs):
        J.range(-3, 2)
        h = H * J.range(0.85, 1)
        t0 = 0.04 + i * 0.105 + J.range(0, 0.05)
        Tf = J.range(0.3, 0.4)
        big = J.chance(0.35)
        J.range(0, TAU)
        stars.append((t0, Tf, x, x - h * 0.38, big))
    full_parts, streak, land, land_big = [], None, None, None
    for i, (t0, Tf, x, sx, big) in enumerate(stars):
        t = T(Tf)
        q = t / Tf
        e = q * (0.35 + 0.65 * q)
        sig = noise(len(t), np.round(1 + 3 * e).astype(int), seed=s + i) * steps((0.15 + 0.85 * e ** 1.5) * (0.2 if big else 0.14))
        b = blank(Tf)
        moving(b, sig, 0, np.array([pan_x(m, sx + (x - sx) * v) for v in e[::64]]).repeat(64))
        full_parts.append((b, t0))
        streak = streak if streak is not None else b
        p = pan_x(m, x)
        if big:
            h_ = st([crack(0.04, 0, 0.75, 60, s + 20 + i), struck("energy", 0.3 * rng.uniform(0.85, 1.15), s + 180 + i, 0.5),
                     struck("stone", 0.25 * rng.uniform(0.8, 1.2), s + 200 + i, 0.3, 0.02)], p)
            land_big = land_big if land_big is not None else h_
        else:
            h_ = st(pop(0.55, s + 20 + i, 520 * rng.uniform(0.9, 1.1), 110, 0), p)
            land = land if land is not None else h_
        tw = blank(0.6)
        twinkles(tw, rng, 4 if big else 3, (0.15, 0.5), 0.12, (p - 0.15, p + 0.15))
        full_parts += [(h_, t0 + Tf), (tw, t0 + Tf)]
    full = mix(full_parts, m["duration"])
    return out(full, {"streak": streak, "land": land, "land_big": land_big},
               "11 falling hisses swelling and panning down their slant, each landing on its own time and place with a "
               "crack + small zap (big ones energy + a floor knock), sparks ticking", 0.63)


# ------------------------------------------------------------------ time stop
def time_stop(m):
    """The clock springs open (0 .. 0.3): a bright 'shwing', a glide flicking up. The second hand ticks on the
    original's 8 slowing ticks (0.36 .. 1.49): a dry clock click each, panned where the hand points; under them time
    runs down: a low hum and a whirr sagging in pitch with the flow (1 - (t-0.3)/1.45)^1.6, to nothing at FREEZE 1.75,
    where a cold glassy crack sets in and everything is silent. CRACK 2.2 .. 2.38: glass crackling faster; SHATTER
    2.42: the face bursts (crack, glass's own weight: a crisp crack and high tinks, shatter noise, a glassy ring); 64 shards and 10 chunks land on their own
    flights (gravity 0.9, drag 0.5, bounce 0.25) as glass tinkles and knocks; the cold vapour lifts silently."""
    s = seed_of(m)
    rng = np.random.default_rng(s)
    OPEN, FREEZE, CRACK, SHATTER, CY, RC = 0.3, 1.75, 2.2, 2.42, -42, 26
    TICKS = [0.36, 0.46, 0.57, 0.7, 0.85, 1.03, 1.24, 1.49]
    start = blank(FREEZE)
    put(start, st([air(0.3, 2, 0, 0.25, s, "fall"), sweep(500, 1900, 0.2, decay(T(0.2), 10) * 0.16,
                   shape=lambda u: 1 - (1 - u) ** 3), crack(0.02, 0, 0.35, 120, s + 1, True)], 0), 0)
    t = T(FREEZE - OPEN)
    flow = np.maximum(0, 1 - t / (FREEZE - OPEN)) ** 1.6
    # full-scale envelopes, turned down after steps(): quantized at their real level they would drop out early
    hum = pulse(36 + 150 * flow, 0.125) * steps(np.minimum(1, t / 0.15) * (0.25 + 0.75 * flow)) * 0.09
    hum += noise(len(t), np.round(3 + 10 * (1 - flow)).astype(int), seed=s + 2) * steps(np.minimum(1, t / 0.15) * flow) * 0.08
    put(start, st(hum, 0), OPEN)
    for i, tk in enumerate(TICKS):
        a = -np.pi / 2 + (i + 1) * TAU / 12
        c = noise(int(0.02 * SR), 1, True, s + 10 + i) * steps(decay(T(0.02), 200) * 0.45)
        c[: int(0.004 * SR)] += pulse(np.full(int(0.004 * SR), 2600.0), 0.125) * 0.2
        put(start, st(c, pan_x(m, np.cos(a) * (RC - 4))), tk)
    freeze = st([crack(0.03, 0, 0.55, 90, s + 20, True), ring(2900, 0.5, 0.13, 7, 13, 1.41)], 0)
    cr = blank(SHATTER - CRACK)
    for i in range(14):
        at = (SHATTER - CRACK - 0.02) * (i / 14) ** 0.7
        place(cr, tick(0.08 + 0.14 * i / 14, int(rng.integers(1, 99))), at, rng.uniform(-0.15, 0.15))
    hit = st([crack(0.05, 0, 0.95, 50, s + 21, True), struck("glass", 0.7 * rng.uniform(0.92, 1.08), s + 221, 0.6),
              burst(0.5, 1, 0.3, 7, s + 22, short=True), ring(3300, 0.4, 0.1, 8, 17, 1.37)], 0)
    body = st(air(0.9, 4, 8, 0.07, s + 24, "fall"), 0)
    tail = blank(1.6)
    ix, iy = rng.uniform(-6, 6), rng.uniform(-6, 6)
    for i in range(74):
        chunk = i >= 64
        a, d = rng.uniform(0, TAU), rng.uniform(0, RC * (0.6 if chunk else 1))
        x, y = np.cos(a) * d, CY + np.sin(a) * d
        sp = rng.uniform(40, 110 if chunk else 140)
        dx, dy = x - ix, y - CY - iy
        l = np.hypot(dx, dy) or 1
        vx, vy = dx / l * sp + rng.uniform(-25, 25), dy / l * sp * 0.7 - rng.uniform(60 if chunk else 40, 130 if chunk else 120)
        for at, v, xx in fly(vx, vy, x, y, 1.0 if chunk else 0.9, 0.4 if chunk else 0.5, 0.3 if chunk else 0.25,
                             rng.uniform(0.9, 1.15) if chunk else rng.uniform(0.8, 1.15)):
            a_ = min(1.0, v / 260)
            if a_ < 0.1:
                continue
            if chunk:
                c = knock(0.2 * a_, int(rng.integers(1, 99)), 6, 0.05, 60) + blip(rng.uniform(1300, 1900), 0.05, 0.125, 0.06 * a_, 60)[: int(0.05 * SR)]
            else:
                c = blip(rng.uniform(2300, 4300), 0.06, 0.125, 0.06 * a_, 55)
                c[: int(0.02 * SR)] += noise(int(0.02 * SR), 0, True, int(rng.integers(1, 99))) * steps(decay(T(0.02), 120) * 0.08 * a_)
            place(tail, c, at, pan_x(m, xx))
    full = mix([(start, 0), (freeze, FREEZE), (cr, CRACK), (hit, SHATTER), (body, SHATTER + 0.02), (tail, SHATTER)],
               m["duration"])
    return out(full, {"start": start, "freeze": freeze, "crack": cr, "hit": hit, "body": body, "tail": tail},
               "shwing as it opens, 8 dry ticks slowing over a hum/whirr sagging to nothing; cold glass crack at the "
               "freeze (1.75), silence, crackling 2.2-2.38, shatter at 2.42, shards tinkling down", 0.66)


SOUNDS.update({
    "arcane-beam": arcane_beam,
    "arcane-missiles": arcane_missiles,
    "arcane-orb": arcane_orb,
    "blink-in": blink_in,
    "blink-out": blink_out,
    "magic-circle-cast": magic_circle_cast,
    "mana-burst": mana_burst,
    "portal": portal,
    "rune-circle": rune_circle,
    "star-fall": star_fall,
    "time-stop": time_stop,
})
