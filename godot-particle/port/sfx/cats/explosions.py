# explosions: the hit recipe every landing sound follows (references/sound.md, rule 3).
import numpy as np
from synth import *  # noqa: F401,F403


def small_explosion_parts(take=1):
    """hit (the white flash and shock rings), body (fireball and smoke column), tail (brands and rocks landing, embers)."""
    rng = np.random.default_rng(take)
    hit = blank(0.6)
    place(hit, boom(0.6, 300 * rng.uniform(0.9, 1.1), 46, 1.0, take), 0)
    place(hit, blip(NOTE(84), 0.08, 0.125, 0.25, 30), 0)
    t = T(1.8)
    b = noise(len(t), 14, seed=take + 3) * steps(decay(t, 1.6) * 0.45)
    b += tri(70 * decay(t, 0.8) + 40) * steps(decay(t, 1.2) * 0.35)
    body = stereo(b)
    tail = blank(3.6)
    for at in sorted(rng.uniform(0.0, 1.4, 5)):    # rocks landing: stone knocks, each its own size (same draws as before)
        sd = int(rng.integers(1, 99))
        place(tail, stone_hit(0.2 + 0.3 * (sd % 7) / 6, sd, 0.3), at, rng.uniform(-0.8, 0.8))
    for _ in range(14):
        place(tail, tick(rng.uniform(0.05, 0.14), int(rng.integers(1, 99))), rng.uniform(0.5, 3.2), rng.uniform(-0.6, 0.6))
    return hit, body, tail


def small_explosion(m, take=1):
    hit, body, tail = small_explosion_parts(take)
    full = blank(m["duration"])
    place(full, hit[:, 0], 0, -0.05)
    place(full, hit[:, 1], 0, 0.05)
    place(full, body[:, 0], 0.05)
    place(full, tail[:, 0], 0.9)
    return Sound(full, {"hit": hit, "body": body, "tail": tail},
                 "crack + dropping thump at the flash (t 0), rumbling body, rocks landing as stone knocks, embers")


# ------------------------------------------------------------------ helpers shared by the explosions (and fire.py)
def pan_x(m, x, k=1.0):
    """Pan of a point x px right of the effect's origin: where it sits across the canvas, -1 .. 1 (k narrows it)."""
    w, ox = m["size"][0], m["origin"][0]
    return float(np.clip((ox + x - w / 2) / (w / 2) * k, -1, 1))


def seed_of(m, take=0):
    return int(m.get("options", {}).get("seed", 1)) * 101 + take


def burst(secs, rate, vol, k, seed=1, short=False):
    """A noise burst that decays: the crack, a pop, a spit."""
    t = T(secs)
    return noise(len(t), rate, short=short, seed=seed) * steps(decay(t, k) * vol)


def rumble(secs, vol, k=1.6, seed=1, rate=14, low=70, low_vol=0.35):
    """The small-explosion body: low-rate noise and a triangle sagging under it, both dying away."""
    t = T(secs)
    b = noise(len(t), rate, seed=seed) * steps(decay(t, k) * vol)
    if low_vol:                                    # the sagging tone is a blast's; low_vol 0 leaves noise only
        b += tri(low * decay(t, 0.8) + 40) * steps(decay(t, k * 0.75) * low_vol)
    return b


def thump(f0=300, f1=46, secs=0.5, vol=0.5, k=7):
    """A pulse whose pitch drops fast: the weight of a blast only (explosions, shockwaves; sound.md rule 2). Anything
    else that lands takes its weight from its material (synth.material_hit, `thud` for stone and earth)."""
    t = T(secs)
    return pulse(f1 + (f0 - f1) * decay(t, 9), 0.5) * steps(decay(t, k) * vol)


def clank(f, vol=0.3, seed=1, secs=0.3):
    """Steel hitting the floor: two pulse partials at a non-musical ratio and a metallic noise smack."""
    s = blip(f, secs, 0.125, vol, 13) + blip(f * 1.37, secs, 0.5, vol * 0.5, 18)
    return s + noise(len(s), 1, short=True, seed=seed) * steps(decay(T(secs), 45) * vol * 1.2)


def clink(f, vol=0.25, seed=1):
    """A small metal can on the floor: short, high, mostly the smack."""
    s = blip(f, 0.12, 0.125, vol * 0.6, 30)
    return s + noise(len(s), 0, short=True, seed=seed) * steps(decay(T(0.12), 60) * vol)


def thud(vol=0.3, seed=1, low=110):
    """Earth or stone landing (a rock, a clod): the stone's dry knock and gritty crunch (synth stone_hit) over a short
    low-rate noise knock for its mass; no pitch that drops. `low` (kept for callers) sets the size: lower is bigger."""
    w = float(np.clip((150 - low) / 70, 0.1, 1.0))
    t = T(0.06 + 0.08 * w)
    s = stone_hit(w, seed, vol)
    s[: len(t)] += noise(len(t), 12, seed=seed + 3) * steps(decay(t, 45 - 15 * w)) * vol * 0.6
    return s


def whump(vol=0.3, seed=1, weight=0.5):
    """Fire catching, gas lighting, smoke gushing: not a blast, so a low noise 'whoomp' opening from rumble toward a
    rush, with no tone under it."""
    secs = 0.15 + 0.25 * weight
    t = T(secs)
    rate = np.round(np.interp(t, [0, secs], [14, 8 - 3 * weight])).astype(int)
    return noise(len(t), rate, seed=seed) * steps(np.minimum(1, t / 0.012) * decay(t, 12 - 6 * weight)) * vol


def tear(secs=0.35, vol=0.3, seed=1):
    """Steel tearing open: a short-mode (metallic) noise rip sliding down in rate, a shrieking inharmonic pair bending
    down a little under it (high, never a low drop)."""
    t = T(secs)
    u = t / secs
    env = np.minimum(1, t / 0.01) * (1 - u) ** 1.5
    rip = noise(len(t), np.round(1 + 6 * u).astype(int), short=True, seed=seed) * steps(env)
    f = 1100 * np.random.default_rng(seed).uniform(0.9, 1.1) * (1 - 0.3 * u)
    shriek = (pulse(f, 0.125) + 0.6 * pulse(f * 1.37, 0.25)) * steps((1 - u) ** 2) * 0.25
    return (rip + shriek) * vol


def airbang(vol=0.9, seed=1, rate=5, echo=0.14):
    """A shell bursting high in the air: a sharp crack opening into a bright noise bang, no ground under it and no
    pitch drop; a quieter airy echo of it a beat later."""
    t = T(0.3)
    bang = noise(len(t), np.where(t < 0.025, 0, rate), seed=seed) * steps(decay(t, 14))
    out = np.zeros(int(round((0.3 + echo) * SR)))
    out[: len(bang)] += bang
    j = int(round(echo * SR))
    e = noise(len(t), rate + 2, seed=seed + 1) * steps(decay(t, 11)) * 0.28
    out[j:j + len(e)] += e[: len(out) - j]
    return out * vol


def spit(vol=0.15, seed=1, secs=0.06):
    """Fire spitting through a gap, a fuse spark: a tiny hiss."""
    return burst(secs, int(seed % 2), vol, 45, seed)


def wash(secs, r0, r1, vol, attack=0.08, k=2.0, seed=1):
    """A rush of air (smoke gushing, a surge): noise whose rate moves r0 -> r1, fast in, dying away."""
    t = T(secs)
    rate = np.round(np.interp(t, [0, secs], [r0, r1])).astype(int)
    env = np.clip(t / attack, 0, 1) * decay(np.maximum(t - attack, 0), k) * vol
    return noise(len(t), rate, seed=seed) * steps(env)


def landings(rng, n, vy, vx, y0=-2.0, drag=0.4, bounce=0.3, t0=0.0, life=4.0):
    """When thrown bits hit the floor, on the effect's own physics (core/sim.js Bits at 120 Hz, gravity 950): a list of
    (t, x, speed). vy, vx: (lo, hi) launch ranges (vy positive = up, vx sign drawn at random)."""
    out = []
    dt = 1 / 120
    for _ in range(n):
        x, y = 0.0, y0
        u = -rng.uniform(*vy)
        v = rng.uniform(*vx) * rng.choice((-1, 1))
        t = 0.0
        while t < life:
            t += dt
            u += 950 * dt
            v -= v * drag * dt
            u -= u * drag * dt
            x += v * dt
            y += u * dt
            if y >= 0 and u > 0:
                out.append((t0 + t, x, u))
                y = -0.01
                if bounce > 0 and u > 70:
                    u, v = -u * bounce, v * 0.7
                else:
                    break
    return sorted(out)


def fizz(secs, rate_per_s, vol, seed=1, hurry_from=None, hurry=0.0, hiss=0.06):
    """A burning fuse or a rocket's tail: a thin hiss with spark crackles at the effect's spawn rate (per second),
    quicker over the last stretch if hurry_from is given. The hiss sits under the NES's lowest volume step (1/15), so
    it is a level-1 channel turned down in the mix rather than quantized away."""
    rng = np.random.default_rng(seed)
    t = T(secs)
    out = noise(len(t), 0, seed=seed) * hiss
    at = 0.0
    while True:
        r = rate_per_s * (1 + (hurry if hurry_from is not None and at > hurry_from else 0))
        at += rng.exponential(1 / r)
        if at >= secs:
            break
        c = spit(vol * rng.uniform(0.5, 1), int(rng.integers(1, 99)), 0.03)
        j = int(at * SR)
        out[j:j + len(c)] += c[: len(out) - j]
    return out


def mix(m, *cues):
    """The full play on the effect's clock: each (stereo part, at seconds) mixed in; it runs at least the effect's
    duration, rings on while anything sounds (at most RING past it, faded), trailing silence trimmed."""
    end = max(at + len(p) / SR for p, at in cues)
    full = blank(max(m["duration"], end))
    for p, at in cues:
        i = int(round(at * SR))
        full[i:i + len(p)] += p[: len(full) - i]
    loud = np.nonzero(np.abs(full).max(1) > 2e-4)[0]
    n = max(int(round(m["duration"] * SR)), loud[-1] + 1 if len(loud) else 0)
    cap = int(round((m["duration"] + RING) * SR))
    if n > cap:
        n = cap
        full[n - int(0.2 * SR): n] *= np.linspace(1, 0, int(0.2 * SR))[:, None]
    return full[:n]


def panned(st, p):
    """A centred stereo part moved to pan p (its two channels summed, then panned)."""
    out = blank(len(st) / SR)
    place(out, (st[:, 0] + st[:, 1]) / np.sqrt(2), 0, p)
    return out


RING = 1.45   # make.py lets a one-shot ring 1.5 s past its end


# ------------------------------------------------------------------ the effects
def big_explosion(m, take=1):
    """Three detonations a beat apart (t 0 on the floor, 0.13 at x -17, 0.25 at x 15 in the air): the first a deep
    blast on the ground, the two in the air each their own crack and a shorter, higher blast (their own seeds and
    sizes, so the three never sound alike); the body (fireball and mushrooming column) rumbles for 3 s; heavy rocks
    (vy 280..560) land as stone knocks from about 0.6 s, burning brands as wood toks; then sparse embers."""
    s = seed_of(m, take)
    rng = np.random.default_rng(s)
    hit = blank(1.0)
    place(hit, boom(0.9, 280 * rng.uniform(0.92, 1.08), 40, 0.85, s), 0)
    place(hit, thump(160, 32, 0.9, 0.25, 4), 0.02)
    place(hit, blip(NOTE(84), 0.08, 0.125, 0.25, 30), 0)
    for at, x, secs, f0, f1, v in ((0.13, -17, 0.45, 370, 58, 0.47), (0.25, 15, 0.32, 450, 72, 0.4)):
        sd = s + int(at * 100)
        place(hit, boom(secs, f0 * rng.uniform(0.92, 1.08), f1, v, sd), at, pan_x(m, x, 2))
    body = stereo(rumble(3.4, 0.5, 1.0, s + 3, 14, 60, 0.4) + rumble(3.4, 0.12, 0.8, s + 4, 11, 90, 0.0))
    tail = blank(4.6)
    for at, x, sp in landings(rng, 26, (280, 560), (30, 150), -4, 0.3, 0.3):
        big = sp > 300
        place(tail, thud(0.32 if big else 0.16, int(rng.integers(1, 99)), 90 if big else 140), at, pan_x(m, x))
    for at, x, sp in landings(rng, 14, (110, 330), (40, 220), -9, 0.5, 0.0):
        sd = int(rng.integers(1, 99))
        place(tail, wood_hit(0.15 + 0.2 * (sd % 5) / 4, sd, 0.2), at, pan_x(m, x))
    for _ in range(24):
        place(tail, tick(rng.uniform(0.04, 0.12), int(rng.integers(1, 99))), rng.uniform(1.0, 4.4), rng.uniform(-0.7, 0.7))
    full = mix(m, (hit, 0), (body, 0.05), (tail, 0))
    return Sound(full, {"hit": hit, "body": body, "tail": tail},
                 "3 detonations (0 deep on the ground, 0.13 and 0.25 shorter and higher in the air), 3 s rumble, rocks "
                 "landing as stone knocks from ~0.6 s, brands as wood toks, embers")


def nuke(m, take=1):
    """The blinding frame (t 0): a white crack and the deepest drop (boom at LIFT 0.07); the shock shell and the base
    surge racing to the canvas edges (0.07 .. ~1.2): a rush of air splitting left and right; the rolling cap: a long
    rumble that swells slowly (no beat) for ~5 s; afterwinds drawn in along the floor (0.9 .. 4.6); grit falling."""
    s = seed_of(m, take)
    rng = np.random.default_rng(s)
    hit = blank(1.4)
    place(hit, burst(0.06, 0, 0.9, 30, s), 0)
    place(hit, boom(1.2, 240 * rng.uniform(0.95, 1.05), 30, 0.85, s + 1), 0.05)
    t = T(1.4)                                     # under it the slowest, deepest drop of the set, sinking for a second
    place(hit, pulse(26 + 130 * decay(t, 2.2), 0.5) * steps(decay(t, 2.5) * 0.3), 0.08)
    # the surge: one rush per side, panned outward as it races to the edges
    surge = blank(1.6)
    for side in (-1, 1):
        w = wash(1.5, 4, 11, 0.32, 0.12, 2.2, s + 2 + side)
        n = len(w)
        pan = side * np.linspace(0.15, 0.85, n)
        surge[:n, 0] += w * np.sqrt((1 - pan) / 2)
        surge[:n, 1] += w * np.sqrt((1 + pan) / 2)
    t = T(8.6)
    swell = 0.8 + 0.2 * np.interp(t, np.linspace(0, 8.6, 12), rng.uniform(-1, 1, 12))
    fade = 1 - np.clip((t - 5.9) / 2.6, 0, 1) ** 1.5          # the cap fades out 6.0 .. 8.3
    b = noise(len(t), 15, seed=s + 5) * steps((0.14 + 0.86 * decay(t, 0.75)) * fade * swell * 0.5)
    b += noise(len(t), 13, seed=s + 6) * steps(decay(t, 0.9) * swell * 0.18)
    b += tri(55 * decay(t, 0.5) + 30) * steps((0.2 + 0.8 * decay(t, 0.6)) * fade * 0.4)
    body = stereo(b)
    t = T(3.9)
    wind = noise(len(t), 9, seed=s + 7) * steps(np.sin(np.pi * t / 3.9) ** 1.5 * (0.6 + 0.4 * np.interp(t, np.linspace(0, 3.9, 7), rng.uniform(0, 1, 7))) * 0.09)
    tail = blank(5.0)
    for at, x, sp in landings(rng, 18, (150, 380), (20, 160), -1, 0.4, 0.0):
        place(tail, tick(0.12, int(rng.integers(1, 99)), short=False), at, pan_x(m, x))
    for _ in range(18):
        place(tail, tick(rng.uniform(0.03, 0.08), int(rng.integers(1, 99))), rng.uniform(0.8, 4.8), rng.uniform(-0.7, 0.7))
    winds = blank(len(wind) / SR)
    place(winds, wind, 0, -0.3)
    place(winds, wind[::-1].copy(), 0, 0.3)
    full = mix(m, (hit, 0), (surge, 0.07), (body, 0.1), (winds, 0.9), (tail, 0))
    return Sound(full, {"hit": hit, "surge": surge, "body": body, "tail": tail},
                 "white crack (0) + deepest drop (0.05), base surge rushing out L/R, ~5 s rolling rumble, afterwinds, grit")


def barrel_explosion(m, take=1):
    """start (0 .. BLOW 0.8): the drum strains: flame spitting from the seam at the effect's rate (6 + 30 k^2 per s, so
    quicker as it goes), the steel shuddering harder, a low groan gliding up; hit at BLOW: the blast with the drum's
    steel tearing; body: the fuel fireball roaring up; tail: 9 staves clanging down (~0.25 .. 0.7 s after), the lid
    (thrown up at 430..480 px/s) clanging down ~1.0 s after and bouncing once, burning fuel splashing, embers."""
    s = seed_of(m, take)
    rng = np.random.default_rng(s)
    BLOW = 0.8
    t = T(BLOW)
    k = t / BLOW
    shake = noise(len(t), 8, short=True, seed=s) * steps(k ** 2 * 0.12)
    groan = pulse(62 * (1 + 0.5 * k ** 2) * (1 + 0.01 * np.sin(2 * np.pi * 11 * t)), 0.125) * steps(k ** 1.5 * 0.08)
    start = stereo(shake + groan)
    at = 0.0
    while True:
        at += rng.exponential(1 / (6 + 30 * (at / BLOW) ** 2))
        if at >= BLOW - 0.02:
            break
        place(start, spit(0.1 + 0.15 * at / BLOW, int(rng.integers(1, 99)), 0.08), at, rng.choice((-0.15, 0.15)))
    hit = blank(0.9)
    place(hit, material_hit("blast", 0.75, s + 1, 0.95), 0)
    place(hit, clank(NOTE(52) * rng.uniform(0.95, 1.05), 0.3, s + 2, 0.5), 0)      # the drum's steel bursting...
    place(hit, tear(0.35, 0.3, s + 9), 0.01)                                     # ...and tearing open along the seam
    t = T(2.0)
    b = noise(len(t), np.where(t < 0.6, 10, 13), seed=s + 3) * steps(np.clip(t / 0.05, 0, 1) * decay(t, 1.4) * 0.45)
    b += tri(75 * decay(t, 0.8) + 40) * steps(decay(t, 1.2) * 0.35)
    body = stereo(b)
    tail = blank(3.6)
    for (ta, x, sp) in landings(rng, 9, (100, 300), (60, 260), -12, 0.5, 0.35):
        if sp > 90:
            place(tail, clank(rng.uniform(380, 620), min(0.22, sp / 1200), int(rng.integers(1, 99)), 0.22), ta, pan_x(m, x))
    lx = rng.uniform(-40, 40) * 0.85
    lid = landings(rng, 1, (430, 480), (0, 0), -22, 0.0, 0.3)
    for i, (ta, _, sp) in enumerate(lid[:2]):     # it lands, bounces once (> 160 px/s) and lands flat
        place(tail, clank(NOTE(57) * rng.uniform(0.97, 1.03), 0.3 if i == 0 else 0.16, s + 7 + i, 0.45), ta, pan_x(m, lx))
    for (ta, x, sp) in landings(rng, 14, (120, 290), (20, 280), -2, 0.5, 0.0):
        place(tail, spit(0.12, int(rng.integers(1, 99)), 0.05), ta, pan_x(m, x))
    for _ in range(10):
        place(tail, tick(rng.uniform(0.04, 0.1), int(rng.integers(1, 99))), rng.uniform(0.8, 3.4), rng.uniform(-0.6, 0.6))
    full = mix(m, (start, 0), (hit, BLOW), (body, BLOW + 0.04), (tail, BLOW))
    return Sound(full, {"start": start, "hit": hit, "body": body, "tail": tail},
                 "seam spitting faster + steel shudder + low groan rising (0-0.8), blast with the drum's steel bursting "
                 "and tearing at 0.8, "
                 "fuel roar, staves and the lid clanging down, fuel splashes, embers")


def grenade(m, take=1):
    """The lob on the effect's physics (lobbed from x -140, gravity 900, bounce 0.36): a heavy clink at 0.575 (x -43),
    a lighter one at 0.867 (x -4), a faint roll after; the fuse fizzing all along, spitting quicker over its last
    0.5 s, a rattle as it shudders (last 0.45 s); hit at BLOW 1.62 (x ~41): a small sharp blast (metallic crack, a
    short high drop), shrapnel whizzing out both ways and pinging off things; body: a small fireball; tail: casing bits
    clinking down, grit, embers."""
    s = seed_of(m, take)
    rng = np.random.default_rng(s)
    BLOW = 1.62
    start = stereo(fizz(BLOW, 24, 0.05, s, BLOW - 0.5, 2.0, 0.018), pan_x(m, 0))
    place(start, clink(NOTE(79), 0.32, s + 1), 0.575, pan_x(m, -43))
    place(start, clink(NOTE(80), 0.14, s + 2), 0.867, pan_x(m, -4))
    t = T(BLOW - 0.95)
    roll = noise(len(t), 11, seed=s + 3) * steps(decay(t, 2.4) * 0.07)
    place(start, roll, 0.95, pan_x(m, 25))
    t = T(0.45)
    rattle = noise(len(t), 6, short=True, seed=s + 4) * steps((t / 0.45) ** 1.5 * 0.08)
    place(start, rattle, BLOW - 0.45, pan_x(m, 41))
    hit = blank(0.7)
    place(hit, boom(0.4, 420 * rng.uniform(0.92, 1.08), 70, 0.8, s + 5), 0)       # small and sharp: short, high drop
    place(hit, burst(0.04, 0, 0.45, 60, s + 6, short=True), 0)
    for side in (-1, 1):
        for j in range(2):
            z = whoosh(0.12, 0, 3, 0.18, s + 10 + j + side)
            at = 0.01 + rng.uniform(0, 0.05)
            pz = side * rng.uniform(0.4, 0.8)
            place(hit, z, at, pz)
            place(hit, metal_hit(0.05 + 0.1 * j, s + 20 + 2 * j + side, 0.1), at + 0.05 + 0.03 * j, pz)    # shrapnel pinging
    body = stereo(rumble(1.2, 0.35, 2.2, s + 7, 13, 70, 0.25))
    tail = blank(2.6)
    for at, x, sp in landings(rng, 10, (120, 300), (40, 200), -3, 0.4, 0.3):
        if sp > 80:
            place(tail, clink(rng.uniform(900, 1400), min(0.14, sp / 2000), int(rng.integers(1, 99))), at, pan_x(m, 41 + x))
    for _ in range(10):
        place(tail, tick(rng.uniform(0.04, 0.1), int(rng.integers(1, 99))), rng.uniform(0.3, 2.4), pan_x(m, 41 + rng.uniform(-80, 80)))
    p = pan_x(m, 41)
    full = mix(m, (start, 0), (panned(hit, p), BLOW), (panned(body, p), BLOW + 0.04), (tail, BLOW))
    return Sound(full, {"start": start, "hit": hit, "body": body, "tail": tail},
                 "clinks on the bounces (0.575, 0.867), roll, fuse fizz quickening, rattle; sharp small blast at 1.62 "
                 "with shrapnel whizzing out and pinging, small fireball rumble, bits landing")


def dirt_explosion(m, take=1):
    """A buried charge: hit at t 0 is muffled earth, not a boom (the crack under the floor: a darker noise heaving, the
    ground's own knock and crunch, no pitch drop) and the soil whooshes up (the fountain); body: a short low noise
    rumble; tail: 30 clods (vy 200..430, drag 0.35, bounce 0.25) landing as earth knocks from about 0.35 s, panned by
    where they land, grit sprinkling down after."""
    s = seed_of(m, take)
    rng = np.random.default_rng(s)
    hit = blank(0.7)
    t = T(0.6)
    place(hit, noise(len(t), np.where(t < 0.04, 5, 14), seed=s) * steps(decay(t, 5) * 0.9), 0)
    place(hit, thud(0.8, s + 3, 80), 0)
    place(hit, whoosh(0.45, 6, 10, 0.3, s + 1), 0.02)
    body = stereo(rumble(1.4, 0.35, 2.0, s + 2, 14, 60, 0.0))
    tail = blank(3.0)
    for at, x, sp in landings(rng, 30, (170, 430), (20, 240), -2, 0.35, 0.25):
        if sp > 80:
            place(tail, thud(min(0.3, sp / 1300), int(rng.integers(1, 99)), 90 + 60 * rng.random()), at, pan_x(m, x))
    for _ in range(40):
        at = 0.5 + rng.gamma(2.0, 0.25)
        place(tail, tick(rng.uniform(0.03, 0.08), int(rng.integers(1, 99)), short=False), at, rng.uniform(-0.5, 0.5))
    full = mix(m, (hit, 0), (body, 0.04), (tail, 0))
    return Sound(full, {"hit": hit, "body": body, "tail": tail},
                 "muffled earth heave + ground knock and crunch + soil whoosh (0), short noise rumble, clods landing as "
                 "earth knocks from ~0.35 s, grit")


def cartoon_pow(m, take=1):
    """start (0 .. IN 0.05): the star punching in, a quick rush; hit at IN: a cartoon pop, not a blast: a fat crack, the
    pop's quick upward blip and puff, and a tone springing up that wobbles as the star shudders (cos 40 t, dying
    e^-6t); the letters drop in silently (no ticks: four in a row would be a rhythm); at GO 0.66 it squeezes and snaps
    away: a short upward zip, little stars scattering (sparkle ticks)."""
    s = seed_of(m, take)
    rng = np.random.default_rng(s)
    IN, GO = 0.05, 0.66
    start = stereo(whoosh(IN + 0.02, 4, 1, 0.3, s))
    hit = blank(0.5)
    place(hit, burst(0.05, 1, 0.8, 40, s + 1), 0)
    place(hit, material_hit("pop", 1.0, s + 2, 1.0), 0)
    t = T(0.35)
    f = (170 + 330 * (1 - decay(t, 25))) * (1 + 0.12 * np.cos(t * 40) * decay(t, 6))
    place(hit, pulse(f, 0.5) * steps(decay(t, 7) * 0.55), 0)
    rel = blank(0.4)
    t = T(0.12)
    place(rel, pulse(300 * (4 ** (t / 0.12)), 0.125) * steps((1 - t / 0.12) * 0.16), 0)
    for _ in range(7):
        place(rel, tick(rng.uniform(0.05, 0.1), int(rng.integers(1, 99))), rng.uniform(0.04, 0.3), rng.uniform(-0.6, 0.6))
    full = mix(m, (start, 0), (hit, IN), (rel, GO))
    return Sound(full, {"start": start, "hit": hit, "release": rel},
                 "rush in (0-0.05), fat crack + cartoon pop springing up and wobbling at 0.05, zip + star sparkles as "
                 "it snaps away (0.66)")


def implosion(m, take=1):
    """start (0 .. SUCK 0.8): everything rushing in: noise climbing from rumble to hiss and swelling faster and faster,
    a thin glide rising under it, then cut dead at 0.8 with a dull 'thup' as the void closes (a low noise puff, no
    pitch); the beat of stillness (0.8 .. 1.02) is silent; hit at STILL 1.02: a pop, not a boom (bright crack, the
    pop's upward blip and puff) and a short fizz."""
    s = seed_of(m, take)
    SUCK, STILL = 0.8, 1.02
    t = T(SUCK)
    u = t / SUCK
    rate = np.round(13 - 12 * u ** 1.5).astype(int)
    env = (0.05 + 0.95 * u ** 3) * 0.22
    suck = noise(len(t), rate, seed=s) * steps(env)
    suck += pulse(120 * 8 ** (u ** 2), 0.125) * steps(env * 0.3)
    start = stereo(suck)
    place(start, burst(0.08, 12, 0.4, 40, s + 3), SUCK - 0.005)
    hit = blank(0.5)
    place(hit, burst(0.04, 0, 1.0, 55, s + 1), 0)
    place(hit, material_hit("pop", 0.6, s + 4, 0.9), 0)
    place(hit, burst(0.35, 2, 0.12, 9, s + 2, short=True), 0.03)
    full = mix(m, (start, 0), (hit, STILL))
    return Sound(full, {"start": start, "hit": hit},
                 "inward rush climbing rumble->hiss (0-0.8), cut with a dull noise thup, silence, pop at 1.02")


def plasma_explosion(m, take=1):
    """Energy, no smoke (rule 3: glides and buzzes): hit at t 0, a metallic crack and the energy hit (a zap gliding
    down, a noise whoomp), no pitch-dropping boom; body: an electric buzz while the arcs crackle (they are re-struck
    every 1/18 s and run out by 0.85: snaps on a random subset of those strikes, panned at random); tail: the shell's
    sparkles (0.12 .. 0.9) thinning."""
    s = seed_of(m, take)
    rng = np.random.default_rng(s)
    hit = blank(0.6)
    place(hit, material_hit("energy", 0.9, s, 1.2), 0)
    place(hit, burst(0.05, 1, 0.5, 50, s + 1, short=True), 0)
    t = T(0.9)
    left = 1 - np.clip((t - 0.15) / 0.7, 0, 1) ** 2
    f = 58 * (1 + 0.04 * np.interp(t, np.linspace(0, 0.9, 30), rng.uniform(-1, 1, 30)))
    buzz = pulse(f, 0.125) * steps(left * 0.13) + noise(len(t), 6, short=True, seed=s + 2) * steps(left * 0.06)
    body = stereo(buzz)
    for k in range(int(0.85 * 18)):
        at = k / 18
        if rng.random() < 0.55 * (1 - at / 0.85) + 0.1:
            place(body, burst(0.03, int(rng.integers(0, 3)), 0.3 * (1 - at), 80, int(rng.integers(1, 99)), short=True),
                  at + rng.uniform(0, 0.015), rng.uniform(-0.5, 0.5))
    tail = blank(1.4)
    for _ in range(22):
        at = rng.uniform(0.12, 1.0)
        place(tail, tick(0.1 * (1.1 - at), int(rng.integers(1, 99))), at, rng.uniform(-0.7, 0.7))
    full = mix(m, (hit, 0), (body, 0), (tail, 0))
    return Sound(full, {"hit": hit, "body": body, "tail": tail},
                 "metallic crack + energy hit (downward zap, whoomp) at 0, electric buzz and arc snaps until 0.85, "
                 "sparkles thinning")


def star_pops(buf, rng, m, n, t_rng, x_reach, vol):
    """Stars crackling out: n little white pops between t_rng, panned where the stars died."""
    for _ in range(n):
        at = rng.uniform(*t_rng)
        c = burst(rng.uniform(0.015, 0.03), int(rng.integers(0, 3)), vol * rng.uniform(0.6, 1), 120,
                  int(rng.integers(1, 99)), short=bool(rng.random() < 0.3))
        place(buf, c, at, pan_x(m, rng.uniform(-x_reach, x_reach)))


def firework_burst(m, take=1):
    """start (0 .. RISE 0.42): the shell climbing and slowing: a fizz of gold sparks (50 per s) and a thin whistle gliding
    up as it slows; hit at RISE: the bang high in the air (a sharp crack and bright bang, a short airy echo, no ground
    and no pitch drop); tail:
    the stars crackle out in white pops: the inner shell (26 stars, lives 1.0..1.4) at 1.42..2.0, the outer (66, lives
    1.35..1.9) at 1.77..2.5, wider; glitter after."""
    s = seed_of(m, take)
    rng = np.random.default_rng(s)
    RISE = 0.42
    t = T(RISE)
    up = 1 - (1 - t / RISE) ** 3
    start = stereo(fizz(RISE, 50, 0.07, s, None, 0, 0.035))
    place(start, pulse(700 + 500 * up, 0.125) * steps((0.3 + 0.7 * t / RISE) * 0.06), 0)
    hit = blank(0.9)
    place(hit, burst(0.05, 0, 0.9, 45, s + 1), 0)
    place(hit, airbang(0.75, s + 2, 5, 0.14), 0)
    tail = blank(2.6)
    star_pops(tail, rng, m, 60, (1.0, 1.58), 45, 0.14)
    star_pops(tail, rng, m, 150, (1.35, 2.08), 90, 0.12)
    for _ in range(16):
        place(tail, tick(rng.uniform(0.02, 0.06), int(rng.integers(1, 99))), rng.uniform(1.7, 2.6), rng.uniform(-0.7, 0.7))
    full = mix(m, (start, 0), (hit, RISE), (tail, RISE))
    return Sound(full, {"start": start, "hit": hit, "tail": tail},
                 "shell fizz + whistle gliding up (0-0.42), sharp air bang + echo at 0.42, stars crackling out "
                 "1.42-2.5 (wide), glitter")


def firework_rocket(m, take=1):
    """start (t 0): ignition, a short whoosh and a spray of sparks; the climb (0 .. FLY 1.05): the tail fizzing (90 sparks
    per s), thinning as it climbs away; hit at FLY: the bang high in the air (crack, a darker bang than the burst's,
    a longer echo, no pitch drop); body: the heavy gold fronds sizzling on their trails;
    tail: 9 fronds (lives 1.8..2.15) crackle out at their tips, 4 pops each, at 2.85..3.4, spread wide."""
    s = seed_of(m, take)
    rng = np.random.default_rng(s)
    FLY = 1.05
    start = blank(FLY)
    place(start, whoosh(0.22, 3, 0, 0.2, s), 0)
    for _ in range(6):
        place(start, tick(rng.uniform(0.06, 0.12), int(rng.integers(1, 99))), rng.uniform(0, 0.12), rng.uniform(-0.5, 0.5))
    t = T(FLY)
    away = 1 - 0.55 * (t / FLY) ** 2
    f = fizz(FLY, 90, 0.05, s + 1, None, 0, 0.0)
    f += noise(len(t), np.where(t < 0.4, 1, 2), seed=s + 2) * steps(np.clip(t / 0.05, 0, 1) * 0.07)
    start += stereo(f * away)
    hit = blank(0.9)
    place(hit, burst(0.05, 0, 0.9, 45, s + 3), 0)
    place(hit, airbang(0.75, s + 4, 4, 0.19), 0)
    t = T(1.9)
    body = stereo(noise(len(t), 0, seed=s + 5) * steps(np.clip(t / 0.1, 0, 1) * decay(t, 1.2) * 0.06))
    tail = blank(2.6)
    for _ in range(9):
        x = rng.uniform(-140, 140)
        die = FLY + rng.uniform(1.8, 2.15)
        for _ in range(4):
            c = burst(rng.uniform(0.015, 0.03), int(rng.integers(0, 3)), rng.uniform(0.12, 0.2), 120, int(rng.integers(1, 99)))
            place(tail, c, die - FLY + rng.uniform(0, 0.2), pan_x(m, x + rng.uniform(-5, 5)))
    full = mix(m, (start, 0), (hit, FLY), (body, FLY), (tail, FLY))
    return Sound(full, {"start": start, "hit": hit, "body": body, "tail": tail},
                 "ignition whoosh, climbing fizz fading up (0-1.05), air bang + echo at 1.05, frond sizzle, tip "
                 "crackles 2.85-3.4")


def smoke_bomb(m, take=1):
    """The canister on the effect's physics (thrown from the left, gravity 900, bounce 0.38, resting on the anchor): a
    clink at 0.454 (x -59), a lighter one at 0.729 (x -32), a faint roll; the fuse sizzling (26 + 50 * hurry sparks per s,
    hurry over its last 0.4 s); hit at POP 0.95: a soft pop and a hiss (no fire, no blast: a dull crack, the pop's
    blip and puff, gas hissing out); body: the smoke gushing out, rollers sliding out low to both sides (a rush of air splitting L/R); the canister, jolted up at
    95 px/s, clinks down at ~1.16; then the cloud billows silently."""
    s = seed_of(m, take)
    rng = np.random.default_rng(s)
    POP, cx = 0.95, -16.6
    start = stereo(fizz(POP, 26, 0.1, s, POP - 0.4, 1.9, 0.03), pan_x(m, cx))
    place(start, clink(NOTE(81), 0.28, s + 1), 0.454, pan_x(m, -58.8))
    place(start, clink(NOTE(82), 0.12, s + 2), 0.729, pan_x(m, -32))
    t = T(POP - 0.83)
    place(start, noise(len(t), 10, short=True, seed=s + 3) * steps(decay(t, 6) * 0.04), 0.83, pan_x(m, -22))
    hit = blank(0.5)
    place(hit, burst(0.04, 4, 0.85, 45, s + 4), 0)
    place(hit, material_hit("pop", 0.3, s + 9, 0.6), 0)
    place(hit, burst(0.3, 1, 0.3, 9, s + 10), 0.02)                               # the gas hissing out
    body = blank(2.0)
    place(body, wash(1.6, 3, 7, 0.45, 0.06, 2.4, s + 5), 0)
    for side in (-1, 1):
        w = wash(1.4, 5, 9, 0.18, 0.15, 1.8, s + 6 + side)
        pan = side * np.linspace(0.1, 0.7, len(w))
        body[: len(w), 0] += w * np.sqrt((1 - pan) / 2)
        body[: len(w), 1] += w * np.sqrt((1 + pan) / 2)
    place(body, clink(NOTE(80), 0.09, s + 8), 0.21, pan_x(m, cx))
    full = mix(m, (start, 0), (hit, POP), (body, POP + 0.02))
    return Sound(full, {"start": start, "hit": hit, "body": body},
                 "clinks on the bounces (0.454, 0.729), fuse sizzle quickening, soft pop + hiss at 0.95, smoke gushing "
                 "out L/R, canister clink ~1.16, then silence while the cloud billows")


SOUNDS = {
    "small-explosion": small_explosion,
    "big-explosion": big_explosion,
    "nuke": nuke,
    "barrel-explosion": barrel_explosion,
    "grenade": grenade,
    "dirt-explosion": dirt_explosion,
    "cartoon-pow": cartoon_pow,
    "implosion": implosion,
    "plasma-explosion": plasma_explosion,
    "firework-burst": firework_burst,
    "firework-rocket": firework_rocket,
    "smoke-bomb": smoke_bomb,
}
