# ice: material over magic (references/sound.md, rule 5). Ice cracks (a crisp short-mode tick), glass tinkles (a tiny
# high blip at an unrelated pitch over a metallic click), chunks knock on stone; shimmer is bright noise, never a
# glockenspiel (rule 1). Ice struck has no low weight of its own (sound.md rule 2: a crisp crack and high tinks,
# synth glass_hit); only where it slams into the ground does stone's dry knock sit under it, never a falling pulse
# thump. Frost forming is crackle getting denser, cold wind is noise. A crystal that just floats there is silent
# (rule 2); freezing over and shattering are the strong moments. Every event sits on the original's beats
# (src/fx/ice/<name>.js), shards land where the effect's own physics drops them (core/sim.js Bits, ice/_lib.js Panes).
import numpy as np
from synth import *  # noqa: F401,F403
from cats.explosions import pan_x, burst
from cats.impacts import crack, rumble, ring, air, fly, st, put, S, hits_of, seed_of
from cats.fire import moving, loop_curve
from cats.arcane import JsRng, glitter, sweep, gather, twinkles, TAU
from cats.projectiles import leveled as _leveled, shot, lput, per_frame

FPS = 30
MASTER = 0.5        # make.py's master gain


def leveled(m, full, phases, notes, target, tops=None, peak=0.95):
    """projectiles.leveled (full at `target` dB RMS as make.py measures it, one gain for every phase), but never so
    loud that full peaks over `peak` after the master gain: a sharp crack over a sparse tail sits a little under its
    target instead of clipping."""
    r = _leveled(m, full, phases, notes, target, tops)
    top = np.abs(r.full).max() * MASTER
    if top > peak:
        k = peak / top
        r = Sound(r.full * k, {n: (v * k if n not in (tops or {}) else v) for n, v in r.phases.items()}, notes)
    return r


# ------------------------------------------------------------------ voices (shared with cats/shadow.py)
def q(env):
    """steps() on the envelope's own scale: quiet events keep their 16 levels instead of rounding to silence."""
    env = np.asarray(env, float)
    top = env.max() if env.size and env.max() > 0 else 1.0
    return steps(env / top) * top


def icecrack(vol=1.0, seed=1, secs=0.05):
    """Ice cracking: a crisp metallic tick, a short bright burst under it, a 20 ms chirp falling off the top."""
    t = T(secs)
    s = noise(len(t), 0, True, seed) * q(decay(t, 110))
    s += noise(len(t), 2, False, seed + 1) * q(decay(t, 60)) * 0.55
    s += pulse(2700 * (1 - 0.4 * np.minimum(1, t / 0.02)), 0.125) * q(decay(t, 150)) * 0.22
    return s * vol


def tinkle(vol=1.0, seed=1, f=3000.0):
    """A splinter of ice landing: a tiny high blip (its own random pitch, no scale) over a metallic click."""
    t = T(0.06)
    s = pulse(np.full(len(t), f), 0.125) * q(decay(t, 75)) * 0.45
    n = int(0.02 * SR)
    s[:n] += noise(n, 0, True, seed) * q(decay(T(0.02), 130))
    return s * vol


def iceknock(vol=1.0, seed=1, f=1600.0, weight=0.4):
    """A chunk of ice on stone: a hard knock, a glassy click on top and a little weight under it: the floor's dry
    triangle knock at its own fixed pitch (stone, no pitch drop)."""
    t = T(0.09)
    s = noise(len(t), 6, False, seed) * q(decay(t, 55))
    s += noise(len(t), 0, True, seed + 1) * q(decay(t, 150)) * 0.5
    s += pulse(np.full(len(t), f), 0.125) * q(decay(t, 70)) * 0.25
    if weight:
        s += tri(np.full(len(t), 120 + 60 * np.random.default_rng(seed).random())) * q(decay(t, 45)) * weight
    return s * vol


def ice_weight(w, seed, vol, secs=0.015):
    """Ice's own weight (synth glass_hit: a short-mode crack and high tinks, no low weight), just after the hit's own
    crack (sound.md rule 2: a bright crack, then the weight) (mono)."""
    return np.concatenate([np.zeros(int(secs * SR)), glass_hit(w, seed, vol)])


def spray(n, secs, vol, rng, lo=2300, hi=4300):
    """Glass spraying off a break: n tinkles crowding the start of `secs` (mono)."""
    out = np.zeros(int((secs + 0.07) * SR))
    for at in np.sort(rng.random(n) ** 1.8) * secs:
        c = tinkle(vol * rng.uniform(0.4, 1), int(rng.integers(1, 99)), rng.uniform(lo, hi))
        j = int(at * SR)
        out[j:j + len(c)] += c[: len(out) - j]
    return out


def shatter(vol, seed, rng, thump_f=360, weight=0.5):
    """Ice bursting: a crisp crack, ice's own weight (synth glass_hit: a short-mode crack and high tinks, no low
    weight: sound.md rule 2), the shatter noise in short (metallic) mode, a glassy two-partial ring and the first
    splinters spraying off (mono). weight sets its size; a lower thump_f (kept for callers) makes it a little bigger."""
    w = float(np.clip(weight * rng.uniform(0.92, 1.08) * (1.15 - thump_f / 1200), 0, 1))
    return S(icecrack(1.0, seed, 0.06), ice_weight(w, seed + 5, 0.4 + 0.4 * w),
             burst(0.5, 1, 0.32, 7, seed + 2, short=True), ring(3300 * rng.uniform(0.95, 1.05), 0.4, 0.1, 8, 17, 1.37),
             spray(9, 0.16, 0.22, rng)) * vol


def crackles(buf, rng, t0, t1, r0, r1, v0, v1, pans, short=True):
    """Frost forming, ice giving: ticks at a rate going r0 -> r1 per second (random, never a rhythm), as loud as v0 -> v1,
    each panned at random in pans (lo, hi) or by pans(u) for u 0..1 through the window."""
    at = t0
    while True:
        u = (at - t0) / (t1 - t0)
        at += rng.exponential(1 / (r0 + (r1 - r0) * u))
        if at >= t1:
            break
        u = (at - t0) / (t1 - t0)
        p = pans(u) if callable(pans) else rng.uniform(*pans)
        place(buf, tick(1.0, int(rng.integers(1, 99)), short) * (v0 + (v1 - v0) * u) * rng.uniform(0.6, 1), at, p)


def landed(buf, m, rng, lands, vol, glass=0.0, vref=220.0, lo=2300, hi=4300, f=(1300, 1900)):
    """Bits landing [(t, speed, x)]: a tinkle each (a knock when glass < the draw, for chunks), as loud as it hits."""
    for at, v, x in lands:
        a = min(1.0, v / vref)
        if a < 0.2:                                   # the tail stays sparse (rule 3): only the hard landings click
            continue
        a *= 0.65
        sd = int(rng.integers(1, 999))
        c = iceknock(vol * a, sd, rng.uniform(*f), 0.3) if rng.random() < glass else tinkle(vol * a * 0.8, sd, rng.uniform(lo, hi))
        place(buf, c, at, pan_x(m, x))


def pane_lands(vx, vy, x0, y0, g, drag, e, life, brittle):
    """A pane (ice/_lib.js Panes) thrown from (x0, y0): its hard landings (> 70 px/s) until it breaks after `brittle` of
    them (or forever if 0), then nothing. [(t, speed, x)]."""
    out = [(t, v, x) for t, v, x in fly(vx, vy, x0, y0, g, drag, e, life) if v > 70]
    return out[:brittle] if brittle else out


def shift(lands, dt):
    return [(t + dt, v, x) for t, v, x in lands]


def loop_ticks(buf, rng, n, P, vol, pans, short=True, lo=None, hi=None):
    """n faint ticks (or tinkles between lo and hi Hz) at random through a loop of period P, wrapping clean."""
    for _ in range(n):
        if lo:
            c = tinkle(vol * rng.uniform(0.5, 1), int(rng.integers(1, 99)), rng.uniform(lo, hi))
        else:
            c = tick(1.0, int(rng.integers(1, 99)), short) * vol * rng.uniform(0.5, 1)
        lput(buf, st(c, rng.uniform(*pans)), rng.uniform(0, P), P)


# ------------------------------------------------------------------ silent
def ice_crystal(m):
    return Silent("a crystal floating and turning in its own light, motes circling: an idle pickup, a steady thing with "
                  "no noise of its own stays silent (rule 2); collecting it is the game's own one-shot")


# ------------------------------------------------------------------ loops
def blizzard_vortex(m):
    """Loop (2 s): a snow tornado is moving air, so wind: a whirling roar (noise round rate 5) and a whistle over it
    (rate 1), swelling with the funnel's swirl (twice a loop) and its sway (once), the whistle's pan swaying with the
    axis; snow boiling at the foot a low rush; ice crystals carried round ticking faintly as they pass in front.
    No beat: the swells are smooth curves. start: the whirl spinning up; stop: it dying down."""
    s = seed_of(m)
    rng = np.random.default_rng(s)
    D = m["duration"]
    t = T(D + X)
    ph = t / D
    sway = np.sin(TAU * ph)
    swirl = 0.5 + 0.5 * np.sin(TAU * 2 * ph + 0.7)
    w = 0.8 + 0.12 * loop_curve(t, D, 3, rng) + 0.08 * swirl
    rate = np.round(5 + 1.4 * loop_curve(t, D, 2, rng)).astype(int)
    roar = noise(len(t), rate, seed=s) * q(w) * 0.3
    whistle = noise(len(t), np.where(swirl > 0.6, 1, 2), seed=s + 1) * q(0.55 + 0.45 * swirl) * 0.11
    foot = noise(len(t), 11, seed=s + 2) * q(0.8 + 0.2 * loop_curve(t, D, 4, rng)) * 0.12
    buf = stereo(roar + foot)
    moving(buf, whistle, 0, 0.3 * sway)
    loop_ticks(buf, rng, 14, D, 0.07, (-0.5, 0.5), lo=2400, hi=4200)
    loop = wrap(buf, D)
    t = T(0.8)
    start = stereo(noise(len(t), np.round(10 - 5 * t / 0.8).astype(int), seed=s + 3) * q((t / 0.8) ** 1.5) * 0.32)
    t = T(0.7)
    stop = stereo(noise(len(t), np.round(5 + 6 * t / 0.7).astype(int), seed=s + 4) * q((1 - t / 0.7) ** 1.6) * 0.3)
    return leveled(m, loop, {"loop": loop, "start": start, "stop": stop},
                   "whirling wind roar + whistle swelling with the swirl (2x) and sway (1x a loop), foot rush, ice crystals "
                   "ticking as they pass; start = spinning up, stop = dying down", -29)


def frost_breath(m):
    """Loop (1.2 s): a cone of icy wind blowing right: a hiss at the white-hot mouth (left, x 2) flickering with the
    jet, the gust's airy rush down the cone (x ~60) swelling and settling with its turbulence (one tile a loop, so no
    beat), a few billows breathing out, ice crystals tumbling through glinting as faint tinkles further right.
    start: the breath catching (a rush and a crackle of frost); stop: the wind dying into a puff."""
    s = seed_of(m)
    rng = np.random.default_rng(s)
    D = m["duration"]
    pm, pc = pan_x(m, 4, 0.7), pan_x(m, 60, 0.7)
    t = T(D + X)
    fl = 0.85 + 0.15 * loop_curve(t, D, 4, rng)
    jet = noise(len(t), 0, seed=s) * q(fl) * 0.12
    gust = noise(len(t), np.round(4 + loop_curve(t, D, 2, rng)).astype(int), seed=s + 1) * q(0.85 + 0.15 * loop_curve(t, D, 3, rng)) * 0.26
    buf = blank(D + X)
    place(buf, jet, 0, pm)
    place(buf, gust, 0, pc)
    for i in range(6):                                  # billows breathing out: soft airy swells, born at random
        b = air(rng.uniform(0.4, 0.6), 4, 8, 1.0, s + 10 + i) * 0.09
        lput(buf, st(b, pan_x(m, rng.uniform(30, 110), 0.7)), rng.uniform(0, D), D)
    loop_ticks(buf, rng, 9, D, 0.06, (pan_x(m, 40, 0.7), pan_x(m, 150, 0.7)), lo=2400, hi=4200)
    loop = wrap(buf, D)
    start = blank(0.45)
    place(start, air(0.4, 6, 1, 1.0, s + 3) * 0.4, 0, pc)
    crackles(start, rng, 0.0, 0.25, 30, 10, 0.16, 0.06, (pm, pc))
    t = T(0.45)
    stop = blank(0.5)
    place(stop, noise(len(t), np.round(1 + 6 * t / 0.45).astype(int), seed=s + 4) * q(decay(t, 7)) * 0.3, 0, pc)
    return leveled(m, loop, {"loop": loop, "start": start, "stop": stop},
                   "icy hiss at the mouth flickering, gust rush down the cone, billows breathing out, crystals tinkling "
                   "faintly; start = rush + frost crackle, stop = wind dying", -28)


def ice_lance(m):
    """Flight loop (0.8 s): a spear of ice cutting the air: a cold hiss of the air shearing off the point (the rings
    peel off nine times a loop, so a flutter, drawn as a per-frame wobble, never a beat), frost peeling into the wake
    as a soft rush, the 9 crystals shed each loop as faint tinkles. launch: frost cracking as the spear forms and a
    whoosh as it leaves. hit: it strikes and bursts: crack, ice tinks, shatter, splinters skittering (ice: no low
    weight)."""
    s = seed_of(m)
    rng = np.random.default_rng(s)
    P = m["duration"]
    n = int((P + X) * FPS) + 2
    flut = per_frame(rng.uniform(0.7, 1.0, n), P + X)
    t = T(P + X)
    b = noise(len(t), 1, seed=s) * q(flut) * 0.12 + noise(len(t), 6, seed=s + 1) * q(0.8 + 0.2 * loop_curve(t, P, 3, rng)) * 0.06
    buf = stereo(b)
    loop_ticks(buf, rng, 9, P, 0.05, (-0.3, 0.1), lo=2500, hi=4200)
    loop = wrap(buf, P)
    launch = blank(0.45)
    crackles(launch, rng, 0.0, 0.08, 120, 60, 0.3, 0.15, (-0.15, 0.15))
    place(launch, icecrack(0.5, s + 2), 0.0)
    place(launch, air(0.3, 3, 0, 1.0, s + 3) * 0.4, 0.04)
    hit = st(shatter(1.0, s + 4, rng, 420, 0.4), 0)
    tail = blank(0.8)
    for i in range(6):
        lands = fly(rng.uniform(-90, 60), -rng.uniform(60, 160), 0, -6, 0.85, 0.6, 0.3, 0.9)
        for at, v, x in lands:
            if v > 60:
                place(tail, tinkle(0.2 * min(1, v / 200), int(rng.integers(1, 99)), rng.uniform(2300, 4300)), at, x / 120)
    hit = shot(m, [(hit, 0), (tail, 0.0)])[: len(tail)]
    return leveled(m, loop, {"launch": launch, "loop": loop, "hit": hit},
                   "loop: cold hiss of shearing air fluttering per frame + wake rush + shed crystals tinkling; launch: frost "
                   "crackle + whoosh; hit: crack + ice burst + shatter, splinters", -30, {"launch": -20, "hit": -15})


# ------------------------------------------------------------------ freeze (status: setting in, then shattering)
def freeze(m):
    """Frost races in along the floor from both sides (0 .. SNAP 0.16): a bright crackling hiss per side, panned from
    the edges (x +-38) to the feet; it climbs the character (0.14 .. 0.62): crisp crackle getting denser over a thin
    hiss brightening and swelling (energy rising, no notes). Hit 1 at 0.62 (hit-stop 0.03) the ice takes hold: a crisp
    crack and a few high tinks (ice, no low weight); after the freeze the 13 panes snap into place (0.6 + their own offsets .. 0.91), each a
    glassy tick, their chips tinkling down. It holds, silent (a lingering status, rule 2). CRACK 2.2: a crack and chips;
    CRACK2 2.34: a louder one and the block shivering (a short-mode rattle swelling), cut dead at the white FLASH 2.46;
    hit 2 at BURST 2.52 (hit-stop 0.05): it shatters; after the freeze the burst rings out and ~36 panes and 50
    splinters land on their own flights (brittle panes break on the first landing into splinters of their own)."""
    s = seed_of(m)
    rng = np.random.default_rng(s)
    SNAP, CL0, SEAL, CRACK, CRACK2, FLASH, REACH = 0.16, 0.14, 0.6, 2.2, 2.34, 2.46, 38
    (h1, f1), (h2, f2) = hits_of(m)
    PANES = [0, 0.03, 0.05, 0.08, 0.1, 0.13, 0.15, 0.18, 0.2, 0.23, 0.25, 0.28, 0.31]
    CX = [-11, 5, 12, -14, 0, 9, -13, -2, 0, 9, -11, 3, -3]           # the panes' centroids (V, FACETS in freeze.js)
    CY = [-5, -6, -10, -17, -17, -26, -30, -29, -41, -38, -40, -45, -45]
    start = blank(h1)
    t = T(SNAP)
    u = t / SNAP
    for side in (-1, 1):
        sig = glitter(SNAP, 0.5 + 0.5 * u, 1, s + side, 0.6) * 0.13
        moving(start, sig, 0, np.array([pan_x(m, side * REACH * (1 - v)) for v in u]))
        crackles(start, rng, 0.0, SNAP, 40, 60, 0.16, 0.12, lambda v, sd=side: pan_x(m, sd * REACH * (1 - v)))
    d = h1 - CL0
    t = T(d)
    u = t / d
    hiss = noise(len(t), np.round(5 - 5 * u).astype(int), seed=s + 2) * q(0.25 + 0.75 * u ** 1.5) * 0.08
    put(start, st(hiss, 0), CL0)
    crackles(start, rng, CL0, h1 - 0.01, 25, 80, 0.08, 0.2, (-0.15, 0.15))
    hit = st([icecrack(0.8, s + 3), ice_weight(0.2, s * 7 + 503, 0.35), burst(0.1, 0, 0.25, 35, s + 4, short=True)], 0)
    seal = blank(0.7)                                     # on the effect clock from h1 + f1
    for i, (a, x, y) in enumerate(zip(PANES, CX, CY)):
        at = SEAL + a - h1 + rng.uniform(-0.006, 0.006)
        if at < 0:
            continue
        c = S(noise(int(0.03 * SR), 0, True, s + 20 + i) * q(decay(T(0.03), 120)),
              pulse(np.full(len(T(0.04)), rng.uniform(2400, 4200)), 0.125) * q(decay(T(0.04), 80)) * 0.15)
        place(seal, c * rng.uniform(0.18, 0.3), at, pan_x(m, x))
        for _ in range(3):                                # the pane's chips, thrown out from it, landing
            a_ = np.arctan2(y + 21, x) + rng.uniform(-0.7, 0.7)
            sp = rng.uniform(50, 120)
            lands = fly(np.cos(a_) * sp, np.sin(a_) * sp - 40, x, y, 0.8, 0.8, 0.3, rng.uniform(0.35, 0.7))
            landed(seal, m, rng, shift(lands, at), 0.12)
    put(seal, st(glitter(0.3, decay(T(0.3), 9), 0, s + 5, 0.7) * 0.12, 0), SEAL + 0.31 - h1 + 0.02)
    crk = blank(h2 - CRACK)
    place(crk, icecrack(0.55, s + 6), 0, pan_x(m, 0))
    for _ in range(4):
        x = rng.uniform(-14, 14)
        landed(crk, m, rng, fly(rng.uniform(-40, 40), -rng.uniform(10, 60), x, -rng.uniform(10, 40), 0.9, 0.6, 0.3, rng.uniform(0.5, 0.9)), 0.12)
    place(crk, icecrack(0.8, s + 7, 0.06), CRACK2 - CRACK, pan_x(m, 1))
    t = T(FLASH - CRACK2)
    u = t / (FLASH - CRACK2)
    shiver = noise(len(t), 7, True, s + 8) * q((0.3 + 0.7 * u) ** 2 * (0.6 + 0.4 * (np.floor(t * 40) % 2))) * 0.16
    place(crk, shiver, CRACK2 - CRACK + 0.01)
    crackles(crk, rng, CRACK2 - CRACK + 0.02, FLASH - CRACK - 0.005, 30, 110, 0.1, 0.25, (-0.2, 0.2))
    shat = st(shatter(1.0, s + 9, rng, 360, 0.55), 0)
    t = T(0.9)
    body = st([burst(0.7, 1, 0.22, 5, s + 10, short=True),
               noise(len(t), np.round(3 + 6 * t / 0.9).astype(int), seed=s + 12) * q(decay(t, 4)) * 0.1], 0)
    tail = blank(1.5)
    for _ in range(36):                                   # the block's panes, chopped, flung out from the core
        x, y = rng.uniform(-15, 15), rng.uniform(-50, -3)
        dx, dy = x, y + 21
        l = np.hypot(dx, dy) or 1
        sp = rng.uniform(40, 85)
        for at, v, xx in pane_lands(dx / l * sp + rng.uniform(-15, 15), dy / l * sp * 0.6 - rng.uniform(90, 190), x, y + 3,
                                    0.85, 0.7, 0.35, rng.uniform(1, 1.45), 1):
            place(tail, iceknock(0.12 * min(1, v / 300), int(rng.integers(1, 999)), rng.uniform(1300, 1900), 0.3), at, pan_x(m, xx))
            for _ in range(1):                            # it breaks: a splinter skips along the floor
                landed(tail, m, rng, shift(fly(rng.uniform(-50, 50), -rng.uniform(30, 100), xx, -1, 0.8, 0.6, 0.35,
                                               rng.uniform(0.4, 0.8)), at), 0.1)
    for _ in range(50):
        x, y = rng.uniform(-17, 17), rng.uniform(-52, -1)
        dx, dy = x, y + 21
        l = np.hypot(dx, dy) or 1
        sp = rng.uniform(50, 130)
        landed(tail, m, rng, fly(dx / l * sp, dy / l * sp * 0.7 - rng.uniform(60, 170), x, y, 0.85, 0.9, 0.3,
                                 rng.uniform(0.8, 1.4)), 0.13)
    b2 = h2 + f2
    full = shot(m, [(start, 0), (hit, h1), (seal, h1 + f1), (crk, CRACK), (shat, h2), (body, b2), (tail, b2)])
    return leveled(m, full, {"start": start, "hit": hit, "seal": seal, "crack": crk, "shatter": shat, "body": body,
                             "tail": tail},
                   "frost hissing in from both sides (0-0.16) and crackling up the body, denser (0.14-0.62); crisp crack at "
                   "hit 0.62, 13 panes ticking into place after the hit-stop; silent hold; cracks at 2.2 and 2.34, the block "
                   "shivering, cut at the white flash 2.46; shatter at 2.52, burst after the 0.05 hit-stop, panes and "
                   "splinters knocking and tinkling down", -23)


# ------------------------------------------------------------------ frost nova
def frost_nova(m):
    """start (0 .. CHARGE 0.42): the cold gathers: bright noise climbing to hiss and swelling, a thin glide rising
    under it, frost streaks ticking in. Hit 1 at 0.42 (hit-stop 0.1): the caster slams down: an ice crack and burst
    over the ground struck (stone's dry knock and crunch, no falling tone). After the freeze the wave runs out both ways (front 1 - (1-u)^3 over 0.62 s to x +-104, panned with it)
    and the 18 crystals punch up where it reaches them (their own sites and times, the original's draws): each an ice
    crunch, the tall inner ones heaviest; core shards (22) and each crystal's shards tinkle down. Hit 2 at 0.66: the
    target (x 76) ices over: a crackle and a crisp crack. The ice holds silently (rule 2); it melts (1.95 .. 2.65) with
    a soft sinking slush; hit 3 at 2.9: the ice skin falls off the target, a light crack and a few tinkles. Everything
    after hit 1 waits for its 0.1 s hit-stop, as the act does."""
    s = seed_of(m)
    rng = np.random.default_rng(s)
    J = JsRng(s)
    CHARGE, SPREAD, HOLD, MELT, REACH = 0.42, 0.62, 1.95, 0.7, m["options"].get("reach", 104)
    (h1, f1), (h2, _), (h3, _) = hits_of(m)
    TX = 76

    def reached(d):
        return CHARGE + SPREAD * (1 - np.cbrt(1 - min(1.0, d / REACH)))

    RINGS = [((0.15, 0.24), (24, 32), 2, 2), ((0.36, 0.52), (13, 19), 3, 1), ((0.62, 0.9), (5, 10), 4, 0)]
    W = [(10, 13), (7, 9), (4, 6)]
    sites = []
    for side in (-1, 1):
        for ri, ((q0, q1), hr, n, kids) in enumerate(RINGS):
            for i in range(n):
                qq = q0 + (q1 - q0) * (i + J.range(0.2, 0.8)) / n
                h = J.range(*hr)
                J.range(*W[ri])
                J.range(0.1, 0.28)
                for _ in range(kids):
                    J.range(0.4, 0.62), J.range(0.3, 0.5), J.range(0.35, 0.6)
                t0 = reached(qq * REACH) + J.range(0, 0.03)
                J.next()
                sites.append((side * qq * REACH, h, t0))
    start = gather(CHARGE, 0.3, s, 7, 0, 600, 2000, ticks=14, rng=rng, spread=0.6)
    hit = st([icecrack(0.9, s + 1, 0.06), np.concatenate([np.zeros(int(0.01 * SR)), material_hit("stone", 0.6 * rng.uniform(0.92, 1.08), s * 7 + 509, 0.55)]),
              ice_weight(0.7, s * 7 + 511, 0.4), burst(0.3, 1, 0.3, 12, s + 2, short=True), spray(8, 0.12, 0.2, rng)], 0)
    sh = f1                                               # the act pauses for the hit-stop: later beats come that late
    body = blank(1.2)
    t = T(SPREAD + 0.15)
    fr = 1 - (1 - np.clip(t / SPREAD, 0, 1)) ** 3
    for side in (-1, 1):
        w = noise(len(t), np.round(1 + 5 * np.clip(t / (SPREAD + 0.15), 0, 1)).astype(int), seed=s + 3 + side) * q((1 - t / (SPREAD + 0.15)) ** 1.3) * 0.3
        moving(body, w, 0, np.array([pan_x(m, side * (6 + (REACH - 6) * v)) for v in fr]))
    put(body, st(rumble(0.9, 0.32, 13, 3.5, 60, 0, s + 5), 0), 0)
    crys = blank(2.2)
    for x, h, t0 in sites:
        k = (h - 5) / 27
        at = t0 - CHARGE
        c = S(icecrack(0.5 + 0.45 * k, int(rng.integers(1, 999))), iceknock(0.25 + 0.35 * k, int(rng.integers(1, 999)),
              rng.uniform(1100, 1700), 0.5 * k), burst(0.15, 1, 0.15 + 0.15 * k, 20, int(rng.integers(1, 999)), short=True))
        place(crys, c * 0.4, at, pan_x(m, x))
        for _ in range(2 + round(h / 8)):
            a = -np.pi / 2 + rng.uniform(-1.3, 1.3)
            sp = rng.uniform(60, 200) * (0.5 + h / 40)
            landed(crys, m, rng, shift(fly(np.cos(a) * sp, np.sin(a) * sp, x + rng.uniform(-3, 3), -0.5, 0.8, 0.6, 0.3,
                                           rng.uniform(0.9, 1.6)), at), 0.11)
    for _ in range(22):
        a = rng.uniform(-np.pi, 0.25)
        sp = rng.uniform(110, 280)
        landed(crys, m, rng, fly(np.cos(a) * sp, np.sin(a) * sp, rng.uniform(-3, 3), -24, 0.7, 0.6, 0.3, rng.uniform(0.9, 1.5)), 0.12)
    pt = pan_x(m, TX)
    ice_on = blank(0.4)
    crackles(ice_on, rng, 0.0, 0.18, 90, 30, 0.22, 0.08, (pt - 0.08, pt + 0.08))
    place(ice_on, icecrack(0.5, s + 6), 0.0, pt)
    t = T(MELT)
    melt = stereo(noise(len(t), np.round(3 + 6 * t / MELT).astype(int), seed=s + 7) * q(np.sin(np.pi * t / MELT) ** 1.5) * 0.06)
    crackles(melt, rng, 0.0, MELT * 0.8, 10, 3, 0.07, 0.03, (-0.6, 0.6))
    off = blank(0.6)
    place(off, icecrack(0.35, s + 8), 0, pt)
    landed(off, m, rng, [(rng.uniform(0.15, 0.35), rng.uniform(120, 200), TX + rng.uniform(-8, 8)) for _ in range(4)], 0.12)
    full = shot(m, [(start, 0), (hit, h1), (body, h1 + f1), (crys, CHARGE + sh), (ice_on, h2 + sh),
                    (melt, HOLD + sh), (off, h3 + sh)])
    return leveled(m, full, {"start": start, "hit": hit, "body": body, "crystals": crys, "ice_on": ice_on, "melt": melt,
                             "ice_off": off},
                   "icy gather (0-0.42); slam: ice crack + stone knock + ice burst at 0.42; after the 0.1 hit-stop the wave rushes "
                   "out L/R and 18 crystals crunch up on their own sites/times, shards tinkling; target ices over (0.66); "
                   "silent hold; soft melt slush (1.95-2.65); ice skin cracks off the target (2.9)", -22)


# ------------------------------------------------------------------ ice shatter
def ice_shatter(m):
    """A block of ice takes a blow at HIT 0.26 on its left face (x -16): a crisp crack and a hard knock, the block
    jolting, 6 chips thrown back left tinkling down; cracks race over it (170 px/s); CRACK2 0.4 a second, louder crack;
    SHIVER 0.54 .. FLASH 0.62 it rattles (40 Hz shiver, a short-mode rattle swelling, crackles denser), cut dead at the
    white frame; BURST 0.68: it bursts (crack, ice tinks, shatter, ring; no low weight), flung right; the chunks (solid panes, bounce 0.38,
    brittle after 3 landings) knock down and skid, crumbling a moment after they lie still (0.25 .. 0.6 s) with a
    crunch of splinters; the 46 shards and chunks of ice tinkle and knock where they land; ice dust rolls out."""
    s = seed_of(m)
    rng = np.random.default_rng(s)
    HIT, CRACK2, SHIVER, FLASH, BURST, HX = 0.26, 0.4, 0.54, 0.62, 0.68, -16
    ph, pc = pan_x(m, HX), pan_x(m, 2)
    hit = st([icecrack(0.6, s), iceknock(0.45, s + 1, 1500, 0.7), ice_weight(0.3 * rng.uniform(0.92, 1.08), s * 7 + 521, 0.35)], ph)
    pre = blank(BURST - HIT + 0.6)
    for _ in range(6):
        a = np.pi + rng.uniform(-1, 0.8)
        sp = rng.uniform(40, 100)
        landed(pre, m, rng, fly(np.cos(a) * sp, np.sin(a) * sp - 60, HX - 1, -15, 0.85, 0.6, 0.3, rng.uniform(0.5, 0.9)), 0.14)
    crackles(pre, rng, 0.02, CRACK2 - HIT, 40, 10, 0.12, 0.05, (ph, pc))
    place(pre, icecrack(0.75, s + 2, 0.06), CRACK2 - HIT, pc)
    crackles(pre, rng, CRACK2 - HIT + 0.02, SHIVER - HIT, 30, 50, 0.08, 0.12, (ph, pc + 0.1))
    t = T(FLASH - SHIVER)
    u = t / (FLASH - SHIVER)
    shiver = noise(len(t), 7, True, s + 3) * q((0.35 + 0.65 * u) ** 2 * (0.6 + 0.4 * (np.floor(t * 40) % 2))) * 0.17
    place(pre, shiver, SHIVER - HIT, pc)
    crackles(pre, rng, SHIVER - HIT, FLASH - HIT - 0.005, 60, 140, 0.12, 0.25, (pc - 0.15, pc + 0.15))
    shat = st(shatter(1.0, s + 4, rng, 330, 0.6), pc)
    t = T(1.0)
    dust = noise(len(t), np.round(2 + 6 * t).astype(int), seed=s + 5) * q(np.minimum(1, t / 0.03) * decay(t, 3.5)) * 0.14
    body = st([burst(0.7, 1, 0.3, 5, s + 6, short=True)], pc)
    moving(body, dust, 0, np.linspace(pc, pc + 0.5, len(dust)))
    tail = blank(2.2)
    for face, n, y0, y1 in (("front", 9, -26, -2), ("top", 4, -34, -28), ("side", 5, -32, -2)):
        for _ in range(n):
            x = rng.uniform(-14, 18) if face != "side" else rng.uniform(13, 19)
            y = rng.uniform(y0, y1)
            dx, dy = x - HX, y + 15
            d = np.hypot(dx, dy) or 1
            sp = rng.uniform(50, 150) * (0.7 + 0.3 * (1 - d / 40))
            lands = pane_lands(dx / d * sp * 0.9 + rng.uniform(40, 110), dy / d * sp * 0.4 - rng.uniform(60, 200), x, y + 4,
                               0.9, 0.5, 0.38, rng.uniform(1.5, 1.9), 3)
            for i, (at, v, xx) in enumerate(lands):
                if v < 100 and i:
                    continue
                place(tail, iceknock(0.2 * min(1, v / 300), int(rng.integers(1, 999)), rng.uniform(1100, 1700), 0.45), at, pan_x(m, xx))
                if v >= 100:
                    landed(tail, m, rng, shift(fly(rng.uniform(-35, 45), -rng.uniform(30, 100), xx, -1, 0.8, 0.6, 0.35, 0.6), at), 0.1)
            if lands and len(lands) < 3:                  # it lies still a moment, then crumbles
                at, _, xx = lands[-1]
                cr = at + rng.uniform(0.3, 0.7)
                c = blank(0.2)
                crackles(c, rng, 0.0, 0.12, 120, 60, 0.12, 0.05, (pan_x(m, xx) - 0.05, pan_x(m, xx) + 0.05))
                put(tail, c, cr)
                landed(tail, m, rng, shift(fly(rng.uniform(-35, 45), -rng.uniform(30, 100), xx, -1, 0.8, 0.6, 0.35, 0.6), cr), 0.08)
    for _ in range(46):
        x, y = rng.uniform(-15, 19), -rng.uniform(1, 33)
        dx, dy = x - HX, y + 15
        d = np.hypot(dx, dy) or 1
        sp = rng.uniform(60, 200)
        chunk = rng.random() < 0.15
        lands = fly(dx / d * sp * 0.8 + rng.uniform(20, 90), dy / d * sp * 0.4 - rng.uniform(60, 240), x, y, 0.85, 0.6, 0.32,
                    rng.uniform(0.8, 1.4))
        landed(tail, m, rng, lands, 0.16 if chunk else 0.12, glass=1.0 if chunk else 0.0)
    full = shot(m, [(hit, HIT), (pre, HIT), (shat, BURST), (body, BURST + 0.02), (tail, BURST)])
    return leveled(m, full, {"hit": hit, "crack": pre, "shatter": shat, "body": body, "tail": tail},
                   "crack + hard knock on the left face (0.26), chips tinkling, second crack (0.4), the block rattling "
                   "(0.54) cut at the white flash (0.62); shatter at 0.68 flung right, chunks knocking/skidding and "
                   "crumbling, splinters tinkling, ice dust rolling out", -21)


# ------------------------------------------------------------------ ice spikes
def ice_spikes(m):
    """The cast at START 0.04: a puff at the hand (x 4). The frost line races right (0.04 .. 0.48, eased out to x 172):
    a bright crackling hiss whose pan follows its head, slowing; each cluster (the original's draws: 7 of them,
    heights cresting past the middle) bursts up as the line reaches it: an ice crunch as heavy as it is tall (the
    crest the heaviest, the ground it breaks through knocking under it), its shards spraying and tinkling down. They stand silently. TREMBLE
    1.2: a shiver along the line (rattle swelling), chips falling; cut at the white FLASH 1.36; SHATTER 1.42: every
    blade breaks at once: a crack and ice tinks, a shatter at each cluster across the stereo; the pieces topple and knock
    down, crumbling a moment later; splinters tinkle."""
    s = seed_of(m)
    rng = np.random.default_rng(s)
    J = JsRng(s)
    START, RUN, TREMBLE, FLASH, SHATTER = 0.04, 0.44, 1.2, 1.36, 1.42
    REACH, HH = m["options"].get("reach", 172), m["options"].get("height", 56)

    def reached(x):
        return START + RUN * (1 - (1 - np.clip(x / REACH, 0, 1)) ** (1 / 1.7))

    clusters = []
    x = 10.0
    while x < REACH - 2:
        qq = x / REACH
        H = HH * (0.28 + 0.72 * np.exp(-(((qq - 0.64) / 0.3) ** 2))) * J.range(0.88, 1.06)
        J.range(0.2, 0.34)
        J.range(0.35, 0.6)
        bh = H * J.range(0.5, 0.7)
        J.range(0.4, 0.6)
        J.range(0.02, 0.05)
        if J.chance(0.5):
            J.range(0.35, 0.6)
        if J.chance(0.7):
            J.range(0.32, 0.58)
        blades = [H, bh]
        if H > 14:
            J.range(0.35, 0.55)
            blades.append(H * J.range(0.24, 0.4))
            J.range(0, 0.12)
            J.range(0.03, 0.07)
        clusters.append((x, H, reached(x) + 0.012, blades))
        x += J.range(20, 26)
    crest = max(c[1] for c in clusters)
    start = blank(0.6)
    place(start, air(0.25, 3, 7, 1.0, s, "fall") * 0.25, 0.0, pan_x(m, 4))
    t = T(RUN)
    u = t / RUN
    head = 1 - (1 - u) ** 1.7
    sig = glitter(RUN, (1 - 0.5 * u) * (np.minimum(1, t / 0.02)), 1, s + 1, 0.6) * 0.1
    moving(start, sig, START, np.array([pan_x(m, REACH * v) for v in head]))
    crackles(start, rng, START, START + RUN, 70, 25, 0.12, 0.06,
             lambda v: pan_x(m, REACH * (1 - (1 - v) ** 1.7)))
    rise = blank(1.4)
    for x, H, t0, blades in clusters:
        k = H / crest
        p = pan_x(m, x)
        c = S(icecrack(0.35 + 0.45 * k, int(rng.integers(1, 999))), iceknock(0.2 + 0.4 * k, int(rng.integers(1, 999)),
              rng.uniform(1100, 1700), 0.6 * k), burst(0.18, 1, 0.12 + 0.18 * k, 16, int(rng.integers(1, 999)), short=True))
        if H == crest:
            c = S(c, material_hit("stone", 0.45, s * 7 + 527, 0.5))
        place(rise, c, t0, p)
        for _ in range(3 + round(H / 8)):
            a = -np.pi / 2 + rng.uniform(-1.1, 1.0)
            sp = rng.uniform(60, 190) * (0.45 + H / 44)
            landed(rise, m, rng, shift(fly(np.cos(a) * sp + 25, np.sin(a) * sp, x + rng.uniform(-3, 3), -1, 0.8, 0.6, 0.3,
                                           rng.uniform(0.6, 1.1)), t0), 0.1)
    trem = blank(SHATTER - TREMBLE + 0.6)
    t = T(FLASH - TREMBLE)
    u = t / (FLASH - TREMBLE)
    for x, H, _, _ in clusters:
        r = noise(len(t), 7, True, int(rng.integers(1, 999))) * q((0.3 + 0.7 * u) ** 2 * (0.6 + 0.4 * (np.floor(t * 40 + x) % 2))) * 0.1 * (0.5 + 0.5 * H / crest)
        place(trem, r, 0, pan_x(m, x))
        for _ in range(2):
            landed(trem, m, rng, fly(rng.uniform(-20, 20), -rng.uniform(0, 30), x + rng.uniform(-4, 4), -rng.uniform(4, H * 0.8),
                                     0.8, 0.5, 0.3, rng.uniform(0.3, 0.6)), 0.07)
    hit = blank(0.8)
    put(hit, st([crack(0.05, 0, 0.7, 50, s + 2, True), ice_weight(0.8 * rng.uniform(0.92, 1.08), s * 7 + 531, 0.5)],
                pan_x(m, REACH * 0.55)), 0)
    for x, H, _, _ in clusters:
        place(hit, shatter(0.35 + 0.4 * H / crest, int(rng.integers(1, 999)), rng, 400, 0.2), rng.uniform(0, 0.012), pan_x(m, x))
    t = T(0.8)
    body = blank(0.8)
    for x, H, _, _ in clusters:
        place(body, noise(len(t), np.round(1 + 5 * t / 0.8).astype(int), True, int(rng.integers(1, 999))) * q(decay(t, 5)) * 0.06 * H / crest, 0, pan_x(m, x))
    tail = blank(1.6)
    for x, H, _, blades in clusters:
        for bh in blades:
            n = 1 + (bh > 9) + (bh > 22)
            for j in range(n):
                y = -bh * (j + 0.5) / n
                up = np.clip(-y / 40, 0, 1)
                lands = pane_lands(rng.uniform(-25, 60), -rng.uniform(40, 130) * (0.5 + up), x + rng.uniform(-3, 3), y,
                                   0.9, 0.6, 0.3, rng.uniform(1, 1.4), 2 if bh > 30 else 1)
                for at, v, xx in lands:
                    if v < 110:
                        continue
                    place(tail, iceknock(0.18 * min(1, v / 300), int(rng.integers(1, 999)), rng.uniform(1100, 1700), 0.4), at, pan_x(m, xx))
                    landed(tail, m, rng, shift(fly(rng.uniform(-45, 45), -rng.uniform(30, 100), xx, -1, 0.8, 0.6, 0.35, 0.6), at), 0.08)
                if lands:
                    at, _, xx = lands[-1]
                    c = blank(0.2)
                    crackles(c, rng, 0.0, 0.1, 120, 60, 0.1, 0.04, (pan_x(m, xx) - 0.04, pan_x(m, xx) + 0.04))
                    put(tail, c, at + rng.uniform(0.12, 0.4))
            for _ in range(int(2 + bh / 7)):
                yy = -bh * rng.random()
                landed(tail, m, rng, fly(rng.uniform(-60, 90), -rng.uniform(60, 230), x + rng.uniform(-2, 2), yy - 0.5, 0.9, 0.6,
                                         0.3, rng.uniform(0.7, 1.3)), 0.1, glass=0.15)
    full = shot(m, [(start, 0), (rise, 0), (trem, TREMBLE), (hit, SHATTER), (body, SHATTER + 0.02), (tail, SHATTER)])
    return leveled(m, full, {"start": start, "rise": rise, "tremble": trem, "hit": hit, "body": body, "tail": tail},
                   "cast puff (0.04), frost line crackling right with its head (0.04-0.48), 7 ice crunches as the clusters "
                   "burst up (crest heaviest), shards tinkling; silent stand; shiver 1.2 cut at the white flash 1.36; "
                   "shatter along the line at 1.42, pieces knocking down and crumbling", -22)


# ------------------------------------------------------------------ icicle fall
def icicle_fall(m):
    """DRIP 0.16: a drop of meltwater falls from the tip and lands (~0.46): one soft wet 'plip'. TREMBLE 0.3 .. SNAP
    0.6: the icicle shivers (18 Hz), a faint creaking rattle swelling, frost sifting (a thin hiss). SNAP 0.6: it cracks
    off its root: a sharp ice crack high up, 7 chips falling and tinkling 0.35 s later. It drops (FREE 0.64 .. IMPACT
    0.944, gravity 950 over 44 px): a short rush of air climbing to hiss. IMPACT: it stabs the floor and bursts (crack,
    ice tinks, shatter, the floor's small dry knock under it); the pieces (bounce 0.35, brittle after 2) knock and
    skid away both ways and crumble; 52 splinters and chunks tinkle and knock down; frost dust rolls out."""
    s = seed_of(m)
    rng = np.random.default_rng(s)
    DRIP, TREMBLE, SNAP, ROOT, LEN = 0.16, 0.3, 0.6, -80, 36
    FREE = SNAP + 0.04
    IMPACT = FREE + np.sqrt(2 * (-ROOT - LEN) / 950)
    (dt_, _, _), = fly(0, 20, 0.5, ROOT + LEN + 1, 0.9, 0, 0, 1.2)[:1]
    start = blank(IMPACT)
    t = T(0.05)
    plip = S(noise(len(t), 5, False, s) * q(decay(t, 90)) * 0.5, pulse(900 * (1 + 1.2 * t / 0.05), 0.25) * q(decay(t, 60)) * 0.25)
    place(start, plip * 0.3, DRIP + dt_, 0)
    t = T(SNAP - TREMBLE)
    u = t / (SNAP - TREMBLE)
    rattle = noise(len(t), 8, True, s + 1) * q((0.2 + 0.8 * u) ** 2 * (0.55 + 0.45 * (np.floor(t * 36) % 2))) * 0.07
    rattle += noise(len(t), 1, False, s + 2) * q(0.4 + 0.6 * u) * 0.035
    place(start, rattle, TREMBLE, 0)
    crackles(start, rng, TREMBLE + 0.05, SNAP, 6, 20, 0.04, 0.09, (-0.1, 0.1))
    snap = blank(1.2)
    place(snap, S(icecrack(0.85, s + 3, 0.06), burst(0.12, 0, 0.25, 30, s + 4, short=True)), 0, 0)
    for _ in range(7):
        a = rng.uniform(0, TAU)
        sp = rng.uniform(30, 110)
        landed(snap, m, rng, fly(np.cos(a) * sp, np.sin(a) * sp - 20, rng.uniform(-4, 4), ROOT + 2, 0.8, 0.8, 0.3,
                                 rng.uniform(0.5, 0.9)), 0.12)
    d = IMPACT - FREE
    t = T(d)
    u = t / d
    place(snap, noise(len(t), np.round(6 - 5 * u).astype(int), seed=s + 5) * q(u ** 1.5) * 0.16, FREE - SNAP, 0)
    hit = st(S(shatter(1.0, s + 6, rng, 340, 0.6), material_hit("stone", 0.2, s * 7 + 541, 0.3)), 0)
    t = T(1.0)
    body = st([burst(0.6, 1, 0.2, 6, s + 7, short=True)], 0)
    dust = noise(len(t), np.round(2 + 6 * t).astype(int), seed=s + 9) * q(np.minimum(1, t / 0.03) * decay(t, 3.5)) * 0.1
    moving(body, dust * 0.7, 0, np.linspace(0, -0.4, len(dust)))
    moving(body, noise(len(t), np.round(2 + 6 * t).astype(int), seed=s + 10) * q(np.minimum(1, t / 0.03) * decay(t, 3.5)) * 0.07,
           0, np.linspace(0, 0.4, len(dust)))
    tail = blank(1.6)
    for i in range(8):
        y = -LEN * (i + 0.5) / 8
        low = np.clip(-y / LEN, 0, 1)
        side = -1 if i % 2 else 1
        lands = pane_lands(side * rng.uniform(30, 110) + rng.uniform(-15, 15), -rng.uniform(70, 200) * (0.4 + low), side * 2, y,
                           0.9, 0.6, 0.35, rng.uniform(1, 1.4), 2)
        for at, v, xx in lands:
            if v < 100:
                continue
            place(tail, iceknock(0.2 * min(1, v / 300), int(rng.integers(1, 999)), rng.uniform(1100, 1700), 0.45), at, pan_x(m, xx))
            landed(tail, m, rng, shift(fly(rng.uniform(-45, 45), -rng.uniform(30, 100), xx, -1, 0.8, 0.6, 0.35, 0.6), at), 0.09)
        if len(lands) == 1:
            at, _, xx = lands[-1]
            c = blank(0.2)
            crackles(c, rng, 0.0, 0.1, 120, 60, 0.1, 0.04, (pan_x(m, xx) - 0.04, pan_x(m, xx) + 0.04))
            put(tail, c, at + rng.uniform(0.15, 0.45))
    for _ in range(52):
        a = -np.pi / 2 + rng.uniform(-1.25, 1.25)
        sp = rng.uniform(60, 230)
        chunk = rng.random() < 0.15
        landed(tail, m, rng, fly(np.cos(a) * sp, np.sin(a) * sp, rng.uniform(-3, 3), -rng.uniform(1, 10), 0.85, 0.6, 0.32,
                                 rng.uniform(0.6, 1.2)), 0.15 if chunk else 0.11, glass=1.0 if chunk else 0.0)
    full = shot(m, [(start, 0), (snap, SNAP), (hit, IMPACT), (body, IMPACT + 0.02), (tail, IMPACT)])
    return leveled(m, full, {"start": start, "snap": snap, "hit": hit, "body": body, "tail": tail},
                   "a drip plips (~0.46), the icicle shivers with a faint creak (0.3-0.6), cracks off its root (0.6), chips "
                   "tinkle, a rush as it drops; it stabs and shatters at 0.944, pieces knock/skid/crumble, splinters", -22)


# ------------------------------------------------------------------ snowflake burst
def snowflake_burst(m):
    """The cold gathers (0 .. POP 0.16): a short gather, bright noise climbing to hiss over a thin glide. POP 0.16: a
    cold pop: a crisp crack and a few high tinks (ice, no low weight), a sparkling fizz (bright noise glittering, short-mode) as the ring of
    frost runs out. The 9 flakes spin out and drift down silently (snow makes no sound); while they're flying, each
    twinkle (the original's draws: tw0 + tw (1/4 + k) of its life) is a faint glint, panned where the flake is; they
    settle and melt in silence."""
    s = seed_of(m)
    rng = np.random.default_rng(s)
    J = JsRng(s)
    POP, CY, N = 0.16, -48, m["options"].get("count", 9)
    SIZES = [2, 0, 1, 0, 2, 0, 1, 0, 1]
    flakes = []
    for i in range(N):
        z = SIZES[i % 9]
        r = J.range(9.5, 11.5) if z == 2 else J.range(6, 7.5) if z == 1 else J.range(3, 4.5)
        a = i / N * TAU + J.range(-0.3, 0.3) + 0.4
        sp = J.range(80, 120) * (1.4 - r / 14)
        J.range(0, TAU), J.next(), J.range(7, 12), J.next(), J.range(0.4, 1)     # rot, w0, w1
        for _ in range(J.int(1, 3)):
            J.range(0.2, 0.8), J.range(0.24, 0.36)
        J.chance(0.45), J.chance(0.45)
        life = J.range(2.1, 2.8)
        J.range(0, TAU)
        tw, tw0 = J.range(0.5, 0.85), J.range(0.15, 0.6)
        flakes.append((r, np.cos(a) * sp, np.sin(a) * sp * 0.85 - 20, life, tw, tw0))
    start = gather(POP, 0.16, s, 5, 0, 900, 2400, ticks=8, rng=rng, spread=0.5)
    hit = st([icecrack(0.5, s + 1, 0.04), ice_weight(0.15, s * 7 + 547, 0.3),
              burst(0.35, 1, 0.2, 9, s + 2, short=True)], 0)
    body = st(glitter(0.8, decay(T(0.8), 4), 0, s + 3, 0.7) * 0.32, 0)
    put(body, st(air(0.4, 1, 5, 1.0, s + 4, "fall") * 0.12, (-0.1, -0.5)) + st(air(0.4, 1, 5, 1.0, s + 5, "fall") * 0.12, (0.1, 0.5)), 0)
    tail = blank(2.8)
    dt = 1 / 60
    for r, vx, vy, life, tw, tw0 in flakes:
        x, y, age, k = 0.0, CY, 0.0, 0
        while age < life - 0.35:
            age += dt
            vx -= vx * 2.8 * dt
            vy -= vy * 2.8 * dt - 26 * dt
            x += vx * dt
            y += vy * dt
            if y > -r * 0.3:
                break
            if age >= tw0 + tw * (0.25 + k):
                k += 1
                g = 0.11 * (1 - age / 2.8) * (0.6 + 0.4 * r / 11)
                c = S(noise(len(T(0.015)), 0, True, int(rng.integers(1, 99))) * q(decay(T(0.015), 160)),
                      pulse(np.full(len(T(0.03)), rng.uniform(3000, 4400)), 0.125) * q(decay(T(0.03), 90)) * 0.4)
                place(tail, c * g, age, pan_x(m, x))
    full = shot(m, [(start, 0), (hit, POP), (body, POP + 0.01), (tail, POP)])
    return leveled(m, full, {"start": start, "hit": hit, "body": body, "tail": tail},
                   "short icy gather (0-0.16), cold pop at 0.16 (crisp crack, tinks, sparkling fizz, frost ring "
                   "rushing out), faint glints on the flakes' own twinkles, silence as they settle and melt", -26)


SOUNDS = {
    "blizzard-vortex": blizzard_vortex,
    "freeze": freeze,
    "frost-breath": frost_breath,
    "frost-nova": frost_nova,
    "ice-crystal": ice_crystal,
    "ice-lance": ice_lance,
    "ice-shatter": ice_shatter,
    "ice-spikes": ice_spikes,
    "icicle-fall": icicle_fall,
    "snowflake-burst": snowflake_burst,
}
