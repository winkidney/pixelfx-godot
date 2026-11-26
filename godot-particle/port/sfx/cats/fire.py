# fire: a steady flame makes no sound worth hearing (rule 2); moving, bursting fire does.
import numpy as np
from synth import *  # noqa: F401,F403
from cats.explosions import (pan_x, seed_of, burst, rumble, thud, whump, spit, wash, landings, mix, panned)


def torch(m):
    return Silent("a steady torch flame: silent thing stays silent (ignite one-shot only when the game lights it)")


def brazier(m):
    return Silent("a brazier burning steadily: silent thing stays silent (a flare-up one-shot only when the game stokes it)")


def campfire(m):
    return Silent("a campfire burning steadily (licks, sparks, smoke): silent thing stays silent; it is ambient, not "
                  "global environment")


def candle(m):
    return Silent("a calm candle flame: silent thing stays silent")


def spirit_flame(m):
    return Silent("a ghost flame hovering in place, an idle glow: silent thing stays silent")


# ------------------------------------------------------------------ helpers
def loop_curve(t, period, rate, rng):
    """A smooth random wobble in -1..1 that repeats every `period` (sines with whole cycles per loop), changing about
    `rate` times a second, like the original's noiseFor(D) curves."""
    k = np.arange(1, max(2, int(round(rate * period))) + 1)
    amp = rng.uniform(0.5, 1, len(k)) / np.sqrt(k)
    ph = rng.uniform(0, 2 * np.pi, len(k))
    c = sum(a * np.sin(2 * np.pi * kk * t / period + p) for a, kk, p in zip(amp, k, ph))
    return c / (np.abs(c).max() + 1e-9)


def crackle(buf, rng, n, t_rng, vol, pan_rng, short=False):
    """Fire crackling: n little pops at random in t_rng, panned in pan_rng."""
    for _ in range(n):
        c = burst(rng.uniform(0.015, 0.035), int(rng.integers(0, 4)), vol * rng.uniform(0.5, 1), 90,
                  int(rng.integers(1, 99)), short=short and rng.random() < 0.3)
        place(buf, c, rng.uniform(*t_rng), rng.uniform(*pan_rng))


def flame_loop(secs, level, rng, seed, roar_rate=10, hiss_rate=3, hiss=0.35, flick=3.0, depth=0.15):
    """The roar of moving fire, one loop long plus X: low-rate noise with a hiss over it, both swelling with a smooth
    wobble that repeats every loop; returns (mono, the wobble 0..1)."""
    t = T(secs + X)
    w = 1 - depth + depth * loop_curve(t, secs, flick, rng)
    rate = np.where(loop_curve(t, secs, 2, rng) > 0.3, roar_rate + 1, roar_rate)
    out = noise(len(t), rate, seed=seed) * steps(w * level)
    out += noise(len(t), hiss_rate, seed=seed + 1) * steps(w * level * hiss)
    return out, w


def moving(buf, sig, at, pans):
    """Place a mono signal whose pan moves (one pan per sample)."""
    i = int(round(at * SR))
    n = min(len(sig), len(buf) - i)
    p = np.clip(pans[:n], -1, 1)
    buf[i:i + n, 0] += sig[:n] * np.sqrt((1 - p) / 2)
    buf[i:i + n, 1] += sig[:n] * np.sqrt((1 + p) / 2)


# ------------------------------------------------------------------ loops: fire that moves
def fire_breath(m):
    """Loop (1.5 s): a roaring cone. The roar swells with the original's roar curve (0.85 + 0.15 noise at rate 3), a hiss
    at the lips (the white-hot jet, left where the mouth is), sparks flung out ahead crackling toward the right.
    start: the breath catching (a whoosh and a soft gas whump, no pitch); stop: the roar dying into a puff."""
    s = seed_of(m)
    rng = np.random.default_rng(s)
    D = m["duration"]
    roar, w = flame_loop(D, 0.3, rng, s, 10, 4, 0.4, 3, 0.15)
    t = T(D + X)
    jet = noise(len(t), 1, seed=s + 2) * steps(w * 0.07)
    buf = stereo(roar, pan_x(m, 60, 0.6))
    place(buf, jet, 0, pan_x(m, 6, 0.6))
    crackle(buf, rng, 14, (0.0, D - 0.04), 0.12, (pan_x(m, 20, 0.6), pan_x(m, 110, 0.6)))
    loop = wrap(buf, D)
    start = blank(0.45)
    place(start, whoosh(0.4, 9, 6, 0.4, s + 3), 0, pan_x(m, 30, 0.6))
    place(start, whump(0.3, s + 5, 0.4), 0, pan_x(m, 10, 0.6))
    t = T(0.45)
    stop = stereo(noise(len(t), np.where(t < 0.2, 10, 12), seed=s + 4) * steps(decay(t, 7) * 0.3), pan_x(m, 60, 0.6))
    g = 0.31                                       # a held attack's loop: about -27 dB
    loop, start, stop = loop * g, start * g * 1.3, stop * g * 1.3
    return Sound(loop, {"loop": loop, "start": start, "stop": stop},
                 "roaring cone swelling with the roar curve, hiss at the lips, sparks crackling ahead; start/stop")


def flamethrower(m):
    """Loop (1.6 s): a pressurised jet on the original's flow(): the hiss at the nozzle and the roar down the stream
    (flow(t - x/V), delayed toward the tip) cut out at the cough (COUGH 0.55 .. 0.71): a 'pfft', the nozzle spitting 12
    sparks and 5 blobs, then the jet re-lights with a soft gas whump and surges (+25 % at 0.75).
    start: the valve opening (a click and a rising rush); stop: the valve shut, the jet sputtering out."""
    s = seed_of(m)
    rng = np.random.default_rng(s)
    D, COUGH, LV = m["duration"], 0.55, 112 / 280

    def smooth(a, b, x):
        u = np.clip((x - a) / (b - a), 0, 1)
        return u * u * (3 - 2 * u)

    def flow(te):
        u = np.mod(te, D)
        return 1 - smooth(COUGH, COUGH + 0.04, u) * (1 - smooth(COUGH + 0.1, COUGH + 0.16, u)) + 0.25 * np.exp(-((u - COUGH - 0.2) / 0.05) ** 2)

    t = T(D + X)
    w = 0.92 + 0.08 * loop_curve(t, D, 4, rng)
    # most of the noise is the nozzle and the stream near it; the far end (flow(t - L/V)) only adds a low murmur
    hiss = noise(len(t), 1, seed=s) * steps(flow(t) * w * 0.2)
    roar = noise(len(t), 9, seed=s + 1) * steps(flow(t - 0.06) * w * 0.24)
    roar += noise(len(t), 12, seed=s + 2) * steps(flow(t - LV) * w * 0.07)
    buf = blank(D + X)
    place(buf, hiss, 0, pan_x(m, 8, 0.6))
    place(buf, roar, 0, pan_x(m, 60, 0.6))
    place(buf, burst(0.09, 3, 0.2, 30, s + 3), COUGH, pan_x(m, 4, 0.6))
    for _ in range(12):
        place(buf, tick(rng.uniform(0.04, 0.09), int(rng.integers(1, 99))), COUGH + rng.uniform(0, 0.12), pan_x(m, rng.uniform(0, 60), 0.6))
    for _ in range(5):
        place(buf, spit(0.07, int(rng.integers(1, 99)), 0.05), COUGH + rng.uniform(0.01, 0.15), pan_x(m, rng.uniform(10, 40), 0.6))
    place(buf, whump(0.24, s + 11, 0.3), COUGH + 0.12, pan_x(m, 8, 0.6))
    place(buf, burst(0.15, 6, 0.18, 14, s + 4), COUGH + 0.12, pan_x(m, 20, 0.6))
    loop = wrap(buf, D)
    start = blank(0.4)
    place(start, tick(0.25, s + 5), 0, pan_x(m, 0, 0.6))
    place(start, whoosh(0.35, 6, 1, 0.3, s + 6), 0.02, pan_x(m, 20, 0.6))
    t = T(0.4)
    stop = blank(0.5)
    place(stop, noise(len(t), 1, seed=s + 7) * steps(decay(t, 9) * 0.25), 0, pan_x(m, 8, 0.6))
    place(stop, noise(len(t), 9, seed=s + 9) * steps(decay(t, 6) * 0.24), 0, pan_x(m, 60, 0.6))
    place(stop, burst(0.08, 3, 0.4, 30, s + 8), 0.12, pan_x(m, 4, 0.6))
    place(stop, burst(0.06, 4, 0.25, 40, s + 10), 0.21, pan_x(m, 4, 0.6))
    g = 0.4                                        # a held attack's loop: about -27 dB
    loop, start, stop = loop * g, start * g * 1.3, stop * g * 1.3
    return Sound(loop, {"loop": loop, "start": start, "stop": stop},
                 "nozzle hiss + stream roar on flow(); cough at 0.55 (pfft, spat sparks), re-light whump + surge 0.67-0.75")


def fire_tornado(m):
    """Loop (2 s): a whirl of fire: a roar and a wind over it, swelling slowly with the funnel's snaking (no beat on its
    3 turns a loop), the wind's pan swaying with the spine (one sway a loop), embers ticking as they orbit past.
    start: the whirl gathering (a rising whoosh); stop: the whirl dying down."""
    s = seed_of(m)
    rng = np.random.default_rng(s)
    D = m["duration"]
    roar, w = flame_loop(D, 0.24, rng, s, 10, 5, 0.3, 1.5, 0.25)
    t = T(D + X)
    wr = np.round(4 + 1.5 * loop_curve(t, D, 1.5, rng)).astype(int)
    wind = noise(len(t), wr, seed=s + 2) * steps((0.7 + 0.3 * loop_curve(t, D, 1, rng)) * 0.1)
    buf = stereo(roar)
    moving(buf, wind, 0, 0.3 * np.sin(2 * np.pi * t / D))
    for _ in range(10):
        a = rng.uniform(0, 2 * np.pi)
        place(buf, tick(rng.uniform(0.04, 0.09), int(rng.integers(1, 99))), rng.uniform(0, D - 0.05), 0.45 * np.cos(a))
    loop = wrap(buf, D)
    start = stereo(whoosh(0.7, 12, 6, 0.3, s + 3) * np.linspace(0.4, 1, int(round(0.7 * SR))))
    stop = stereo(whoosh(0.6, 7, 12, 0.25, s + 4))
    g = 0.36                                       # a held spell's loop: about -28 dB
    loop, start, stop = loop * g, start * g, stop * g
    return Sound(loop, {"loop": loop, "start": start, "stop": stop},
                 "whirling roar + wind swaying with the spine (1 sway/loop, no beat), embers ticking; start/stop")


def fireball(m):
    """Loop (1.2 s): a fireball in flight: a fluttering roar (the original's flicker, 0.85 + 0.15 noise at rate 9) with a
    hiss of the air it cuts, motes spitting off the head. The game pans it with the flight. start: the launch whoosh
    and the fire catching (a gas whump, no pitch)."""
    s = seed_of(m)
    rng = np.random.default_rng(s)
    D = m["duration"]
    roar, _ = flame_loop(D, 0.3, rng, s, 9, 2, 0.3, 9, 0.15)
    buf = stereo(roar, 0.2)
    for _ in range(8):
        place(buf, spit(rng.uniform(0.05, 0.1), int(rng.integers(1, 99)), 0.03), rng.uniform(0, D - 0.04), rng.uniform(0, 0.4))
    loop = wrap(buf, D)
    start = blank(0.4)
    place(start, whoosh(0.3, 2, 9, 0.45, s + 2), 0)
    place(start, whump(0.24, s + 3, 0.3), 0)
    g = 0.45                                       # a projectile in flight: about -25 dB
    loop, start = loop * g, start * g * 1.4
    return Sound(loop, {"loop": loop, "start": start},
                 "fluttering roar + hiss of the flight, motes spitting; start = launch whoosh")


# ------------------------------------------------------------------ one-shots
def fire_ring(m, take=1):
    """start (the act's windup, 0 .. CHARGE 0.32): fire streaks spiralling in to the feet: a charge (noise climbing,
    a thin low glide, crackles denser), fire palette low; hit at 0.32 (white flash, freeze 0.1): the fire slammed
    into the floor, not a blast: a crack, the ground's knock and crunch, the flames bursting up in a roaring whoosh;
    body (on the effect's clock right after the hit; in an act that clock holds through the freeze): the ring
    racing out (front = 92 px * outCubic over 0.75 s): a rush splitting left/right as it spreads and slows, crackles where each ring of flames lights (reachedAt(r)); hit 2 at 0.6 (the target at
    x 70 catches): a gas whump and a sizzle on the right; tail: the rim burning down to 2.6, crackles thinning."""
    s = seed_of(m, take)
    rng = np.random.default_rng(s)
    CH, SPREAD, REACH, TX = 0.32, 0.75, 92, 70
    hits = m.get("act", {}).get("timing", {}).get("hits", [])
    start = stereo(charge(CH, 13, 6, 110, 330, 0.22, s))
    hit = blank(0.6)
    place(hit, thud(1.0, s + 1, 90), 0)
    place(hit, burst(0.05, 0, 0.4, 50, s + 2), 0)
    place(hit, wash(0.5, 9, 4, 0.6, 0.02, 4, s + 9), 0.01)
    # the ring: one rush per side, panned out with the front
    secs = SPREAD + 0.25
    t = T(secs)
    u = np.clip(t / SPREAD, 0, 1)
    env = np.clip(t / 0.03, 0, 1) * (1 - u) ** 1.3 * 0.3 + 0.05 * decay(t, 3)
    front = REACH * (1 - (1 - u) ** 3)
    body = blank(secs)
    for side in (-1, 1):
        r = np.round(7 + 4 * u).astype(int)
        moving(body, noise(len(t), r, seed=s + 3 + side) * steps(env), 0,
               np.array([pan_x(m, side * f) for f in front[:: 441]]).repeat(441)[: len(t)])
    reached = lambda d: CH + SPREAD * (1 - np.cbrt(1 - min(1, d / REACH)))
    for r in range(10, REACH + 1, 9):
        for _ in range(3):
            at = reached(r) + rng.uniform(0, 0.04) - CH
            if at < 0:
                continue
            c = burst(rng.uniform(0.015, 0.03), int(rng.integers(0, 4)), rng.uniform(0.08, 0.16), 90, int(rng.integers(1, 99)))
            place(body, c, at, pan_x(m, r * np.cos(rng.uniform(0, 2 * np.pi))))
    catch = blank(0.6)
    place(catch, burst(0.12, 5, 0.35, 22, s + 6), 0)
    place(catch, whump(0.3, s + 11, 0.4), 0)
    place(catch, burst(0.5, 1, 0.08, 5, s + 7), 0.04)
    catch = panned(catch, pan_x(m, TX))
    # the flames left burning, from the moment the front has passed most of the floor (0.6) until the rim is out
    tail = blank(2.1)
    t = T(2.0)
    place(tail, noise(len(t), 11, seed=s + 8) * steps(np.clip(t / 0.35, 0, 1) * decay(np.maximum(t - 0.35, 0), 1.8) * 0.14), 0)
    for _ in range(26):
        at = 0.3 + rng.gamma(1.5, 0.3)
        if at < 2.0:
            c = burst(rng.uniform(0.015, 0.03), int(rng.integers(0, 4)), 0.1 * (1 - at / 2.0) + 0.04, 90, int(rng.integers(1, 99)))
            place(tail, c, at, pan_x(m, REACH * np.cos(rng.uniform(0, 2 * np.pi))))
    full = mix(m, (start, 0), (hit, CH), (body, CH + 0.01), (catch, hits[1]["t"] if len(hits) > 1 else 0.6),
               (tail, CH + 0.3))
    return Sound(full, {"start": start, "hit": hit, "body": body, "catch": catch, "tail": tail},
                 "charge (no notes) 0-0.32, crack + ground knock + fire whoosh at 0.32, ring rush splitting L/R with crackles "
                 "on the lighting rings, target catching at 0.6 (right), rim burning down")


def flame_pillar(m, take=1):
    """start (0 .. ERUPT 0.55): the floor cracking and glowing: stone snaps getting denser, a rumble swelling under it,
    little licks spitting; hit at ERUPT: the floor bursting, not a blast: a crack, the ground's heavy knock and crunch
    and the column's fire whoosh up (RISE 0.12); body: the column roaring
    (0.55 .. FALL 1.95, its height wobbling), then collapsing (FALL .. GONE 2.45): the roar sinking and dying into a
    puff; tail: 18 chunks (vy 150..330) landing as stone knocks from ~0.85, grit pattering."""
    s = seed_of(m, take)
    rng = np.random.default_rng(s)
    ERUPT, FALL, GONE = 0.55, 1.95, 2.45
    t = T(ERUPT)
    u = t / ERUPT
    start = stereo(noise(len(t), 14, seed=s) * steps(u ** 2 * 0.16))
    at = 0.0
    while True:
        at += rng.exponential(1 / (4 + 30 * (at / ERUPT) ** 2))
        if at >= ERUPT - 0.02:
            break
        place(start, burst(0.03, int(rng.integers(4, 8)), 0.05 + 0.13 * at / ERUPT, 80, int(rng.integers(1, 99))), at, pan_x(m, rng.uniform(-40, 40)))
    hit = blank(0.7)
    place(hit, burst(0.05, 1, 0.6, 50, s + 6), 0)
    place(hit, thud(0.85, s + 1, 80), 0)
    place(hit, blip(NOTE(84), 0.08, 0.125, 0.2, 30), 0)
    place(hit, wash(0.5, 8, 4, 0.42, 0.04, 4, s + 2), 0.01)
    secs = GONE - ERUPT + 0.5
    t = T(secs)
    tt = t + ERUPT
    w = 0.9 + 0.1 * np.interp(tt, np.linspace(ERUPT, GONE + 0.5, 14), rng.uniform(-1, 1, 14))
    up = np.clip(t / 0.12, 0, 1)
    down = 1 - np.clip((tt - FALL) / (GONE - FALL + 0.15), 0, 1) ** 2
    rate = np.where(tt < FALL, 9, np.where(tt < FALL + 0.25, 11, 13))
    b = noise(len(t), rate, seed=s + 3) * steps(up * down * w * 0.3)
    b += noise(len(t), 3, seed=s + 4) * steps(up * down * w * 0.08 * (tt < FALL + 0.1))
    body = stereo(b)
    place(body, whoosh(0.5, 7, 11, 0.2, s + 5), FALL - ERUPT + 0.1)
    crackle(body, rng, 16, (0.1, FALL - ERUPT), 0.1, (-0.3, 0.3))
    tail = blank(2.6)
    for ta, x, sp in landings(rng, 18, (150, 330), (0, 110), -2, 0.4, 0.3):
        if sp > 70:
            place(tail, thud(min(0.26, sp / 1300), int(rng.integers(1, 99)), 120), ta, pan_x(m, x))
    for _ in range(20):
        place(tail, tick(rng.uniform(0.03, 0.07), int(rng.integers(1, 99)), short=False), 0.4 + rng.gamma(2, 0.3), rng.uniform(-0.5, 0.5))
    full = mix(m, (start, 0), (hit, ERUPT), (body, ERUPT), (tail, ERUPT))
    return Sound(full, {"start": start, "hit": hit, "body": body, "tail": tail},
                 "floor cracking denser + rumble swelling (0-0.55), crack + ground knock + fire whoosh at 0.55, roaring "
                 "column to 1.95, collapse dying by 2.45, chunks landing as stone knocks, grit")


def meteor(m, take=1):
    """start (0 .. HIT 0.62): the rock streaking in from the upper left (FROM -112, -142): a roar growing as it nears and
    gathers speed, panned along its flight; hit at HIT: a rock striking the ground, not a blast (a crack, the ground's
    heaviest knock and crunch with a low noise heave, the fire bursting out in a roaring whoosh); body: the fireball
    and column rumbling (noise, no sagging tone); tail: 28 chunks (vy 140..340) landing as stone knocks, 10 burning
    brands as wood toks, grit, embers."""
    s = seed_of(m, take)
    rng = np.random.default_rng(s)
    HIT = 0.62
    t = T(HIT)
    u = t / HIT
    k = u * u * 0.35 + u * 0.65
    near = (0.12 + 0.88 * k ** 2)
    sig = noise(len(t), np.round(7 + 3 * k).astype(int), seed=s) * steps(near * 0.32)
    sig += noise(len(t), 2, seed=s + 1) * steps(near * 0.06)
    start = blank(HIT)
    moving(start, sig, 0, np.array([pan_x(m, -112 * (1 - kk)) for kk in k[:: 441]]).repeat(441)[: len(t)])
    hit = blank(0.9)
    place(hit, burst(0.05, 0, 0.6, 45, s + 6), 0)
    place(hit, thud(0.7, s + 2, 75), 0)
    t = T(0.6)
    place(hit, noise(len(t), np.where(t < 0.03, 9, 14), seed=s + 7) * steps(decay(t, 5)) * 0.5, 0)
    place(hit, blip(NOTE(84), 0.08, 0.125, 0.25, 30), 0)
    place(hit, wash(0.6, 10, 4, 0.45, 0.03, 3.5, s + 8), 0.02)
    body = stereo(rumble(2.2, 0.7, 1.3, s + 3, 14, 70, 0.0))
    tail = blank(3.2)
    for ta, x, sp in landings(rng, 28, (140, 340), (0, 110), -3, 0.4, 0.3):
        if sp > 70:
            place(tail, thud(min(0.28, sp / 1200), int(rng.integers(1, 99)), 110), ta, pan_x(m, x))
    for ta, x, sp in landings(rng, 10, (110, 240), (60, 200), -6, 0.5, 0.0):
        sd = int(rng.integers(1, 99))
        place(tail, wood_hit(0.15 + 0.2 * (sd % 5) / 4, sd, 0.22), ta, pan_x(m, x))
    for _ in range(16):
        place(tail, tick(rng.uniform(0.04, 0.1), int(rng.integers(1, 99))), rng.uniform(0.8, 3.0), rng.uniform(-0.6, 0.6))
    full = mix(m, (start, 0), (hit, HIT), (body, HIT + 0.05), (tail, HIT))
    return Sound(full, {"start": start, "hit": hit, "body": body, "tail": tail},
                 "roar growing and panning in along the flight (0-0.62), impact at 0.62 (crack, ground knock + heave, fire "
                 "whoosh), noise rumble, chunks (stone) and brands (wood) landing, embers")


SOUNDS = {
    "torch": torch,
    "brazier": brazier,
    "campfire": campfire,
    "candle": candle,
    "spirit-flame": spirit_flame,
    "fire-breath": fire_breath,
    "flamethrower": flamethrower,
    "fire-tornado": fire_tornado,
    "fireball": fireball,
    "fire-ring": fire_ring,
    "flame-pillar": flame_pillar,
    "meteor": meteor,
}
