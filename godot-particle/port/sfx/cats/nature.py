# nature: material over magic (rule 5). Stone and earth that land: a crack, the weight of stone (synth material_hit:
# a dry knock and a gritty crunch, a big one a low noise thud; never the explosions' falling pulse thump, sound.md
# rule 2), a short body, debris knocking down where the effect's own physics lands it. Wood
# and roots creak (a low pulse whose period jitters every frame, a short-mode rasp) and splinter (a cluster of cracks);
# leaves rustle (noise whose level jumps at random each frame); acid splats and sizzles; wind is moving noise. Things
# that only grow, glow or hang in the air (a gas cloud, a tar puddle, petals and spores drifting) make no noise of their
# own (rule 2): only their strong moments sound. A run of thorns or roots on near-even beats gets a different size,
# pitch and pan for each, so it reads as one tearing motion, not a rhythm (rule 1). Beats from src/fx/nature/<name>.js
# and act.timing in port/meta.json.
import numpy as np
from synth import *  # noqa: F401,F403
from cats.impacts import (seed_of, hits_of, windup_of, pan_of, st, put, crack, rumble, air, breath, fly, grit_lands,
                          debris, glide, S)
from cats.explosions import wash
from cats.projectiles import leveled, shot, lput, st_path
from cats.arcane import glitter, sweep, gather, twinkles, env_at
from cats.fire import loop_curve, moving
from cats.lightning import zap, thunder
from cats.water import lvl, splat, plink, glitter_env, rush, wet_hit

G = 950.0


# ------------------------------------------------------------------ voices of wood, leaves, earth, acid
def creak(secs, env, f0=70.0, seed=1, jitter=0.22, grit=0.5):
    """Wood under strain: a thin low pulse whose period jumps every 60 Hz frame (a ratchety creak, never a note) and
    a short-mode rasp under it. env: a number or an array as long as T(secs)."""
    rng = np.random.default_rng(seed)
    t = T(secs)
    fr = SR // 60
    jit = (1 + jitter * rng.uniform(-1, 1, len(t) // fr + 1)).repeat(fr)[: len(t)]
    f = np.broadcast_to(np.asarray(f0, float), t.shape) * jit
    sig = pulse(f, 0.125) * 0.65 + noise(len(t), 9, short=True, seed=seed) * grit * 0.5
    return sig * lvl(np.broadcast_to(env, t.shape))


def rustle(secs, env, seed=1, rate=3, depth=0.85):
    """Leaves and litter: bright noise whose level jumps at random each frame."""
    return glitter(secs, env, rate, seed, depth)


def snaps(secs, rate, vol, seed, pans=(-0.3, 0.3), stone=True):
    """Stone snapping as it cracks (or wood fibres giving): small knocks at rate(t) per second, each as loud as vol(t),
    at random times (never a rhythm). Returns stereo."""
    rng = np.random.default_rng(seed)
    buf = blank(secs + 0.1)
    at = 0.0
    while True:
        at += rng.exponential(1 / max(1e-3, rate(at)))
        if at >= secs:
            break
        s = knock(vol(at) * rng.uniform(0.5, 1), int(rng.integers(1, 999)), int(rng.integers(2, 6)) if stone else 7,
                  0.04, rng.uniform(60, 110))
        put(buf, st(s, rng.uniform(*pans)), at)
    return buf


def knock(vol=0.25, seed=1, rate=9, secs=0.06, k=55, weight=0.0):
    """A stone or clod landing: a short burst of long-mode noise (lower rate = heavier); weight adds a dry triangle
    knock at its own fixed pitch under it (stone: no glide, unlike cats/impacts.knock's little pitch drop)."""
    t = T(secs)
    s = noise(len(t), rate, seed=seed) * steps(decay(t, k) * vol)
    if weight:
        f = 95 + 70 * np.random.default_rng(seed).random()
        s += tri(np.full(len(t), f)) * steps(decay(t, k * 0.8) * vol * weight)
    return s


def tock(vol=0.25, seed=1, rng=None):
    """A piece of bark or wood landing: a light knock and a small hollow wood 'tok' (its own pitch every time)."""
    rng = rng or np.random.default_rng(seed)
    k = knock(vol, seed, int(rng.integers(5, 9)), 0.05, 70)
    d = wood_hit(0.1 * rng.random(), seed + 1, vol * 0.5 * rng.uniform(0.8, 1.0))
    out = np.zeros(max(len(k), len(d)))
    out[: len(k)] += k
    out[: len(d)] += d
    return out


def after(sig, secs=0.012):
    """A hit's weight comes just after its crack (sound.md rule 2: a bright crack, then the weight)."""
    return np.concatenate([np.zeros(int(secs * SR)), sig])


def ground(weight, seed, vol):
    """The low weight of a lot of earth moving: a short burst of the lowest noise, longer for a bigger one. Noise,
    never a falling tone."""
    t = T(0.12 + 0.25 * weight)
    return noise(len(t), 15, seed=seed) * steps(np.minimum(1, t / 0.015) * decay(t, 24 - 12 * weight) * vol)


def thud(vol=0.3, seed=1, low=110):
    """A chunk of stone or a slab landing: stone's dry knock and crunch at its own pitch (a lower `low` is a bigger
    chunk), a low noise burst under it."""
    w = float(np.clip(1.3 - low / 100, 0.1, 0.6))
    return S(material_hit("stone", w, seed, vol * 1.6), ground(0.2, seed + 1, vol * 0.8))



def ndrop(x, y, vx, vy, s=1):
    """When a drop of nature/_lib.js Drops (drag 0.6/s sideways, 0.3/s down, g 950) hits the floor: (t, x, speed)."""
    dt, t, drag = 1 / 120, 0.0, 0.6 / s
    while t < 3:
        py = y
        vy += G * dt
        vx -= vx * drag * dt
        vy -= vy * drag * 0.5 * dt
        x += vx * dt
        y += vy * dt
        t += dt
        if vy > 0 and py <= 0 <= y:
            return t, x, vy
    return None


def fall_time(y0, vy):
    """Time for a bit thrown from height y0 (negative = up) at vy (negative = up) to reach the floor, no drag."""
    return (-vy + np.sqrt(vy * vy - 2 * G * y0)) / G


def rock_hit(m, x, k=1.0, sd=1, rng=None, dull=0):
    """Stone landing or erupting (k 0..1 sets its size): a crack, stone's weight (a dry knock and a gritty crunch, no
    glide), a heavy noise knock and, the bigger it is, a low noise thud: a pebble ticks, a boulder thuds."""
    rng = rng or np.random.default_rng(sd)
    k = k * rng.uniform(0.92, 1.0)                    # each its own size (and the effect's draws stay in step)
    return st([crack(0.05, 1 + dull, 0.55 + 0.4 * k, 50, sd), after(material_hit("stone", 0.35 + 0.65 * k, sd + 2, 0.5 + 0.4 * k)),
               knock(0.25 + 0.25 * k, sd + 1, 10, 0.08, 40, 0.6), after(ground(k, sd + 3, 0.2 + 0.4 * k))], pan_of(m, x))


# ------------------------------------------------------------------ silent
def poison_cloud(m):
    return Silent("a miasma creeping along the floor and curling up: gas makes no noise of its own, a steady thing "
                  "(rule 2); a one-shot only if the game releases or ignites it")


def toxic_puddle(m):
    return Silent("a tar puddle at rest, bubbles slowly doming and popping, vapour curling: a still puddle, a steady "
                  "thing with no noise of its own (rule 2, like the campfire's sparks); its 8 pops a loop would recur "
                  "every 4 s as a pattern (rule 1)")


# ------------------------------------------------------------------ loops
def leaf_storm(m):
    """Loop (2.4 s): wind spiralling round the character with leaves riding it. The wind bands go round 2-3 times a
    loop at their own speeds, so the wind is three voices each circling at its own rate (the pans never line up into
    a beat), its level wobbling smoothly; the 28 leaves rustle (level jumping each frame), the litter at the feet a
    lower scuff. No accents. start: the wind gathering; stop: dying away."""
    sd = seed_of(m)
    rng = np.random.default_rng(sd)
    P = m["duration"]
    t = T(P + X)
    buf = blank(P + X)
    for j, (K, rate) in enumerate(((2, 5), (3, 3), (2, 7))):
        w = rush(P + X, rate, 0.4, rng, sd + j, 1.5, 0.35, P)
        moving(buf, w, 0, 0.6 * np.cos(rng.uniform(0, 2 * np.pi) + 2 * np.pi * K * t / P))
    leaves = noise(len(t), 2, seed=sd + 5) * glitter_env(t, P, rng, 0.16, 0.85)
    litter = noise(len(t), 9, seed=sd + 6) * glitter_env(t, P, rng, 0.12, 0.7)
    moving(buf, leaves, 0, 0.5 * np.sin(2 * np.pi * 3 * t / P + 1))
    buf += stereo(litter)
    loop = wrap(buf, P)
    start = st(air(0.6, 10, 4, 0.5, sd + 7, "rise"))
    put(start, st(rustle(0.6, np.linspace(0, 0.2, int(round(0.6 * SR))), sd + 8), 0.3), 0)
    stop = st(air(0.6, 5, 10, 0.45, sd + 9, "fall"))
    start, stop = start * 0.9, stop * 0.9
    return leveled(m, loop, {"loop": loop, "start": start, "stop": stop},
                   "loop: wind whirling round (3 voices circling at their own rates) + leaf rustle + litter scuff, no "
                   "accents; start: wind gathering; stop: dying away", -30)


def tornado(m):
    """Loop (2 s): a funnel of wind: a deep roar and a howling mid wind swelling with the funnel's snaking (smooth, no
    beat), the wind's pan swaying with the spine (ax(1): one sway a loop); leaves and debris whirling past as faint
    ticks. Its crown flickers with lightning at q 0.62 and 0.69 (1.24, 1.38): a distant crackle and a grumble, kept in
    their own phase (flash); the loop phase is the wind alone. start: the whirl spinning up; stop: dying down."""
    sd = seed_of(m)
    rng = np.random.default_rng(sd)
    P = m["duration"]
    t = T(P + X)
    ph = 2 * np.pi * t / P
    roar = rush(P + X, 13, 0.55, rng, sd, 1.5, 0.25, P)
    howl = noise(len(t), np.round(5 + 1.5 * loop_curve(t, P, 1.5, rng)).astype(int), seed=sd + 1) * lvl(
        (0.7 + 0.3 * loop_curve(t, P, 1, rng)) * 0.3)
    bed = stereo(roar)
    moving(bed, howl, 0, pan_of(m, 0) + 0.35 * np.sin(ph - 2.6))
    for _ in range(18):
        a = rng.uniform(0, 2 * np.pi)
        lput(bed, st(tick(rng.uniform(0.05, 0.12), int(rng.integers(1, 999)), short=bool(rng.random() < 0.4)),
                     0.5 * np.cos(a)), rng.uniform(0, P), P)
    bed = wrap(bed, P)
    cx = pan_of(m, 8.5 * np.sin(2 * np.pi * 0.62 - 2.6) + 3 * np.sin(4 * np.pi * 0.62 + 1.3 - 4.5))
    flash = imix_([(st([zap(0.6, sd + 2, 0.12, 60)], cx), 0), (st(zap(0.35, sd + 3, 0.08, 70), cx), 0.14),
                   (st(thunder(1.2, 0.3, sd + 4, 2.2, 2), cx * 0.5), 0.03)])
    full = blank(P + X)
    lput(full, flash, 0.62 * P, P)
    full = wrap(full, P) + bed
    start = st(air(0.7, 13, 6, 0.5, sd + 5, "rise"))
    stop = st(air(0.6, 6, 13, 0.4, sd + 6, "fall"))
    return leveled(m, full, {"loop": bed, "flash": flash, "start": start, "stop": stop},
                   "loop: deep roar + howling wind swaying with the spine + debris ticks (no accents); flash: distant "
                   "crackle + grumble on the crown's lightning (1.24, 1.38); start/stop", -29)


def imix_(parts):
    n = max(int(round(a * SR)) + len(s) for s, a in parts)
    buf = np.zeros((n, 2))
    for s, a in parts:
        put(buf, s, a)
    return buf


# ------------------------------------------------------------------ one-shots: stone and earth
def boulder(m):
    """The boulder is hurled at t 0 (a dust puff: a short heave of air) and arcs right (VX 220, VY -170, g 860)
    tumbling: a rough rumble whose level jumps as it turns, an air rush growing with its speed, panned along its path;
    hit at tHit 0.479 (x 111): a boulder of stone landing: a crack, stone's dry knock and crunch, a heavy knock and a
    low noise thud (no falling tone); body: a noise rumble (no tone under it) and the dust rolling
    out both ways; tail: its 9 big chunks (drag 0.7, bounce 0.35) thudding, 14 small ones knocking, 60 grit ticking,
    each where and when its flight lands it."""
    sd = seed_of(m)
    rng = np.random.default_rng(sd)
    X0, Y0, VX, VY, Gb, RAD = 6, -26, 220, -170, 860, m["options"].get("size", 11)
    tH = (-VY + np.sqrt(VY * VY - 2 * Gb * (Y0 + RAD * 0.8))) / Gb
    xH = X0 + VX * tH
    t = T(tH)
    sp = np.hypot(VX, VY + Gb * t)
    sp = sp / sp.max()
    fr = SR // 60
    turn = (1 - 0.7 * rng.random(len(t) // fr + 1)).repeat(fr)[: len(t)]
    tumble = noise(len(t), 12, seed=sd) * lvl(turn * (0.4 + 0.6 * sp) * 0.3)
    rushs = noise(len(t), np.round(9 - 3 * sp).astype(int), seed=sd + 1) * lvl(sp ** 2 * 0.18)
    start = st_path(tumble + rushs, [pan_of(m, X0 + VX * tt) for tt in t[::441]])
    put(start, st(air(0.2, 9, 12, 0.3, sd + 2), pan_of(m, X0)), 0)
    hit = rock_hit(m, xH, 1.0, sd * 7 + 401, rng)
    pH = pan_of(m, xH)
    body = st(rumble(1.6, 0.42, 14, 1.6, 70, 0, sd + 4), pH)
    for side in (-1, 1):
        put(body, st(wash(1.2, 6, 10, 0.12, 0.08, 2.2, sd + 5 + side), (pH, pH + side * 0.5)), 0.02)
    lands = []
    for _ in range(9):
        a, v = -np.pi / 2 + rng.uniform(-1.2, 1.1), rng.uniform(100, 240)
        lands += [(tt, s, xx, 1) for tt, s, xx in fly(np.cos(a) * v + 30, np.sin(a) * v, xH + rng.uniform(-5, 5),
                                                      -6.6 + rng.uniform(-5, 5), 1, 0.7, 0.35, rng.uniform(1.3, 1.7))]
    for _ in range(14):
        a, v = -np.pi / 2 + rng.uniform(-1.4, 1.4), rng.uniform(120, 280)
        lands += [(tt, s, xx, 0) for tt, s, xx in fly(np.cos(a) * v + 25, np.sin(a) * v, xH + rng.uniform(-4, 4), -6.6,
                                                      1, 0.8, 0.3, rng.uniform(1.1, 1.5))]
    tail = blank(2.6)
    for tt, s, xx, big in lands:
        a = min(1.0, s / 320)
        if a < 0.12:
            continue
        snd = thud(0.3 * a, int(rng.integers(1, 999)), rng.uniform(85, 120)) if big else \
            knock(0.22 * a, int(rng.integers(1, 999)), int(rng.integers(6, 10)), weight=0.3)
        put(tail, st(snd, pan_of(m, xx)), tt)
    grit = []
    for _ in range(60):
        u = rng.uniform(-1, 1)
        a, v = -np.pi / 2 + u * 1.1, rng.uniform(80, 300) * (1 - 0.3 * abs(u))
        grit += grit_lands(np.cos(a) * v + 30, np.sin(a) * v, xH + u * 6, -1, rng)
    tail += debris(m, grit, 0.1, 0, short=True, vref=260, seed=sd + 6, secs=len(tail) / SR)
    full = shot(m, [(start, 0), (hit, tH), (body, tH + 0.03), (tail, tH)])
    return leveled(m, full, {"start": start, "hit": hit, "body": body, "tail": tail},
                   "heave + tumbling rumble and rush panned along the arc (0-0.48), stone crack + knock + thud at 0.479, "
                   "rumble + dust rolling out, chunks thudding and grit ticking where they land", -21)


def earth_spike(m):
    """start (0 .. UP 0.34): the floor cracks with light: stone snapping faster and faster along the cracks, grit
    hopping, a low groan rising; hit at UP: the main spike rams up (stone: crack, dry knock and crunch, a low noise thud), the back shard at 0.385 and the
    front one at 0.425 smaller and lower, each at its own x; body: the rumble; tail: each spike's chunks (drag 0.35,
    bounce 0.32) knocking down where they land, the rubble thrown high raining back (from ~1.0 s) as grit; split: the
    spikes strain from CRACK 1.18 (snaps getting denser, a stone grind), crack apart at 1.40, 1.50 and 1.58, crumble
    from the top as rubble knocks (FALL 0.42), the stumps grinding down into the floor (1.92 .. 2.5)."""
    sd = seed_of(m)
    rng = np.random.default_rng(sd)
    UP, CRACK, SPLIT, FALL, SINK = 0.34, 1.18, 1.5, 0.42, 0.55
    H = m["options"].get("height", 62)
    spikes = [(-H * 0.17, 0.52, H * 0.22, UP + 0.045, SPLIT - 0.1), (H * 0.18, 0.40, H * 0.2, UP + 0.085, SPLIT + 0.08),
              (0.0, 1.0, H * 0.36, UP, SPLIT)]
    t = T(UP)
    u = t / UP
    groan = noise(len(t), 14, seed=sd) * lvl((0.1 + 0.9 * u ** 2) * 0.3) + tri(42 + 25 * u) * lvl(u ** 2 * 0.2)
    start = st(groan)
    start += snaps(UP, lambda a: 6 + 60 * (a / UP) ** 2, lambda a: 0.08 + 0.2 * a / UP, sd + 1, (-0.4, 0.4))[: len(start)]
    hit = blank(0.8)
    tail = blank(3.2)
    lands = []
    for x, k, w, at, _ in spikes:
        put(hit, rock_hit(m, x, k, sd * 7 + 409 + int(at * 1000), rng), at - UP)
        for _ in range(round(16 * k) + 3):
            a, v = -np.pi / 2 + rng.uniform(-1.1, 1.1), rng.uniform(140, 360) * (0.6 + 0.4 * k)
            lands += [(at + tt, s, xx) for tt, s, xx in fly(np.cos(a) * v, np.sin(a) * v, x + rng.uniform(-w / 3, w / 3),
                                                            -rng.uniform(1, 6), 1, 0.35, 0.32, rng.uniform(1.4, 2.4))]
    for tt, s, xx in lands:
        a = min(1.0, s / 330)
        if a > 0.12:
            put(tail, st(knock(0.26 * a, int(rng.integers(1, 999)), int(rng.integers(6, 10)), weight=0.4), pan_of(m, xx)), tt)
    for _ in range(14):
        x, y0, vy, delay = rng.uniform(-60, 60), -rng.uniform(110, 125), rng.uniform(10, 60), rng.uniform(0.25, 0.9)
        put(tail, st(tick(rng.uniform(0.06, 0.12), int(rng.integers(1, 999)), short=False), pan_of(m, x)),
            UP + delay + fall_time(y0, vy))
    body = st(rumble(1.6, 0.42, 14, 1.6, 65, 0, sd + 2))
    # the split: strain, three cracks, rubble crumbling off the tops, the stumps grinding down
    D = SPLIT + 0.08 + FALL + SINK + 0.3 - CRACK
    split = blank(D + 1.0)
    tt = T(SPLIT + 0.08 - CRACK)
    uu = tt / tt[-1]
    put(split, st(noise(len(tt), 9, seed=sd + 3) * lvl(uu ** 1.5 * 0.14)), 0)
    put(split, snaps(len(tt) / SR, lambda a: 5 + 40 * (a / (SPLIT - CRACK)) ** 2, lambda a: 0.06 + 0.12 * a / 0.32,
                     sd + 4, (-0.25, 0.25)), 0)
    for x, k, w, at, sp in spikes:
        p = pan_of(m, x)
        put(split, st([crack(0.035, 2, 0.45 + 0.3 * k, 70, sd + int(sp * 100)), knock(0.3 + 0.2 * k, sd + 7, 5, 0.06, 45, 0.4),
                       material_hit("stone", 0.25 + 0.35 * k, sd * 7 + 419 + int(sp * 100), 0.35 + 0.2 * k)], p), sp - CRACK)
        n = round(4 + 6 * k)
        for j in range(1, n + 1):
            ut = 1 - 0.75 * j / n
            tb = sp + 0.04 + FALL * np.sqrt(j / n)
            for half in (-1, 1):
                vx, vy = half * rng.uniform(8, 40), -rng.uniform(0, 50)
                for tl, s, xx in fly(vx, vy, x + half * 2, -ut * H * k, 1, 0.3, 0.3, rng.uniform(1.1, 1.6)):
                    a = min(1.0, s / 300)
                    if a > 0.12:
                        put(split, st(knock(0.22 * a * (0.6 + 0.4 * k), int(rng.integers(1, 999)), int(rng.integers(6, 10)),
                                            weight=0.3), pan_of(m, xx)), tb + tl - CRACK)
    tg = T(SINK + 0.1)
    put(split, st(noise(len(tg), 13, seed=sd + 8) * lvl(np.sin(np.pi * tg / tg[-1]) * 0.2)), SPLIT + FALL - CRACK)
    full = shot(m, [(start, 0), (hit, UP), (body, UP + 0.03), (tail, 0), (split, CRACK)])
    return leveled(m, full, {"start": start, "hit": hit, "body": body, "tail": tail, "split": split},
                   "stone snaps quickening + groan (0-0.34), stone hit at 0.34 with smaller shards at 0.385/0.425, "
                   "rumble, chunks knocking, rubble rain; strain from 1.18, cracks 1.40/1.50/1.58, crumble, stump grind",
                   -21)


def quake(m):
    """Three jolts on the effect's beats (JOLTS 0.06, 0.5, 0.92), each smaller (k 1, 0.8, 0.6) and pitched apart, each
    earth struck: a dull underground crack, stone's knock and crunch, a burst of the lowest noise (no falling
    tone) and the floor's shudder (the original's sin 80t, dying e^-9t); the
    first tears the rift open both ways (a rip running out L and R over 0.45 s). Body: the ground rumbling under it all,
    swelling with each jolt, the rift grinding shut at CLOSE 2.2. Tail: the slabs it heaves (vy 70..170 k) drop back as
    heavy thuds, a few bounce once; the chunks it throws knock down; grit ticks. Slabs landing at their own times keep
    three near-even jolts from reading as a beat."""
    sd = seed_of(m)
    rng = np.random.default_rng(sd)
    JOLTS, CLOSE, REACH = (0.06, 0.5, 0.92), 2.2, m["options"].get("reach", 118)
    hit = blank(1.6)
    slabs = []
    x = -REACH + 8
    while x < REACH - 6:
        slabs.append(x + rng.uniform(-2, 2))
        x += rng.uniform(12, 17)
    busy = {}
    tail = blank(3.6)
    for j, tj in enumerate(JOLTS):
        k = 1 - 0.2 * j
        o = (1 - (1 - np.clip((tj - 0.06) / 0.45, 0, 1)) ** 3) * REACH * (0.55 + 0.45 * np.clip((tj - 0.5) / 0.3, 0, 1))
        L = o + 10
        t = T(0.6)
        shud = noise(len(t), 12, seed=sd + j) * lvl(decay(t, 9) * np.abs(np.sin(80 * t)) * 0.4 * k)
        put(hit, st([crack(0.06, 4, 0.55 + 0.35 * k, 40, sd + 10 + j), after(material_hit("stone", k * rng.uniform(0.95, 1.0), sd * 7 + 431 + j, 0.5 + 0.3 * k)),
                     ground(k, sd * 7 + 437 + j, 0.4 + 0.3 * k), shud]), tj - JOLTS[0])
        if j == 0:
            for side in (-1, 1):
                tr = T(0.5)
                rip = noise(len(tr), np.round(np.interp(tr, [0, 0.5], [5, 12])).astype(int), seed=sd + 20 + side) * lvl(
                    decay(tr, 4) * 0.35)
                put(hit, st(rip, (0.0, side * 0.75)), 0.01)
        for sx in slabs:
            d = abs(sx) / REACH
            if abs(sx) > L or rng.random() < 0.25 + d * 0.3 or busy.get(sx, 0) > tj:
                continue
            v = rng.uniform(70, 170) * k * (1 - d * 0.5)
            t1 = tj + 2 * v / G
            put(tail, st(thud(min(0.34, v / 420), int(rng.integers(1, 999)), rng.uniform(80, 115)), pan_of(m, sx)), t1)
            busy[sx] = t1
            if v > 160:
                v2 = v * 0.25
                put(tail, st(thud(v2 / 420, int(rng.integers(1, 999)), 120), pan_of(m, sx)), t1 + 2 * v2 / G)
        for _ in range(round(8 * k)):
            a, v = -np.pi / 2 + rng.uniform(-0.9, 0.9), rng.uniform(100, 230) * k
            for tt, s, xx in fly(np.cos(a) * v, np.sin(a) * v, rng.uniform(-L, L) * 0.8, -2, 1, 0.5, 0.3, 1.5):
                if s > 40:
                    put(tail, st(knock(0.24 * min(1, s / 250), int(rng.integers(1, 999)), int(rng.integers(6, 10)), weight=0.3),
                                 pan_of(m, xx)), tj + tt)
        for _ in range(round(14 * k)):
            a, v = -np.pi / 2 + rng.uniform(-0.6, 0.6), rng.uniform(40, 200) * k
            put(tail, st(tick(0.08 * v / 200, int(rng.integers(1, 999)), short=False), pan_of(m, rng.uniform(-L, L))),
                tj + 2 * abs(np.sin(a) * v) / G)
    t = T(3.1)
    env = sum((1 - 0.2 * j) * np.where(t >= tj, decay(np.maximum(t - tj, 0), 1.1), 0) * np.minimum(1, np.maximum(t - tj, 0) / 0.05)
              for j, tj in enumerate(JOLTS))
    env = np.minimum(env, 1.2) * (0.35 + 0.65 * (t < CLOSE)) + 0.25 * np.exp(-((t - CLOSE - 0.25) / 0.2) ** 2)
    env *= 1 - np.clip((t - CLOSE - 0.5) / 0.4, 0, 1)
    body = st(noise(len(t), 15, seed=sd + 30) * lvl(env * 0.36) + noise(len(t), 13, seed=sd + 32) * lvl(env * 0.14))
    tc = T(0.6)
    close = st(noise(len(tc), 12, seed=sd + 31) * lvl(np.sin(np.pi * tc / 0.6) * 0.16) +
               noise(len(tc), 15, seed=sd + 33) * lvl(np.sin(np.pi * tc / 0.6) * 0.1))
    full = shot(m, [(hit, JOLTS[0]), (body, 0), (tail, 0), (close, CLOSE)])
    return leveled(m, full, {"hit": hit, "body": body, "tail": tail, "close": close},
                   "3 jolts (0.06/0.5/0.92: dull crack + stone knock + low noise + shudder, each smaller, own pitch; rift rip "
                   "L/R on the first), ground rumble swelling, slabs thudding back, chunks and grit, rift grinding shut "
                   "at 2.2", -20)


def thorns(m):
    """A seam races along the floor (0.04 .. 0.54, outCubic) left to right: earth tearing, a rush panned with its head.
    The 6 thorns punch up at their own beats (0.12 + i 0.075) each bigger than the last (h 12 .. 48): each a dirt burst
    (crack, knock) with a hollow wood 'tok' (synth wood_hit), louder and lower for a bigger thorn and panned at its x, so the run reads as one
    tearing motion growing, not a beat; chips and grit knock down where they land; after the biggest, a short rumble.
    They hold (silent), then sink one after another from 1.45: a soft earth grind sliding left to right, a few chips."""
    sd = seed_of(m)
    rng = np.random.default_rng(sd)
    n = max(2, m["options"].get("count", 6))
    th = []
    for i in range(n):
        k = i / (n - 1)
        th.append((10 + i * 104 / (n - 1) + rng.uniform(-3, 3), 12 + 36 * k, k, 0.12 + i * 0.075, 1.45 + i * 0.06))
    reach = th[-1][0] + 8
    t = T(0.5)
    run = 1 - (1 - np.clip(t / 0.5, 0, 1)) ** 3
    tear = noise(len(t), np.round(10 - 3 * (1 - run)).astype(int), seed=sd) * lvl((1 - run) ** 0.7 * 0.25 + 0.02)
    start = st_path(tear, [pan_of(m, r * reach) for r in run[::441]])
    hit = blank(0.9)
    tail = blank(2.6)
    lands = []
    for i, (x, h, k, at, _) in enumerate(th):
        p = pan_of(m, x)
        put(hit, st([crack(0.035, 3, 0.35 + 0.5 * k, 60, sd + i), knock(0.2 + 0.25 * k, sd + 10 + i, 9, 0.07, 45, 0.5),
                     after(material_hit("wood", (0.2 + 0.8 * k) * rng.uniform(0.93, 1.0), sd * 7 + 443 + i, 0.3 + 0.35 * k))], p), at - th[0][3])
        sp = 0.6 + 0.6 * k
        for _ in range(3 + round(5 * k)):
            a, v = -np.pi / 2 + rng.uniform(-1.1, 1.1), rng.uniform(60, 210) * sp
            lands += [(at + tt, s, xx) for tt, s, xx in fly(np.cos(a) * v, np.sin(a) * v, x, -1, 1, 0, 0, 1.0)]
        for _ in range(round((10 + 18 * k) / 3)):
            a, v = -np.pi / 2 + rng.uniform(-1, 1), rng.uniform(60, 230) * (0.6 + 0.6 * k)
            put(tail, st(tick(0.05 + 0.04 * k, int(rng.integers(1, 999)), short=False), pan_of(m, x + np.cos(a) * v * 0.3)),
                at + fall_time(-1, np.sin(a) * v))
    for tt, s, xx in lands:
        if s > 60:
            put(tail, st(knock(0.18 * min(1, s / 250), int(rng.integers(1, 999)), int(rng.integers(6, 10))), pan_of(m, xx)), tt)
    body = st(rumble(1.0, 0.3, 14, 2.6, 65, 0, sd + 20), pan_of(m, th[-1][0]))
    s0, s1 = th[0][4], th[-1][4] + 0.36
    tg = T(s1 - s0)
    grind = noise(len(tg), 11, seed=sd + 21) * lvl(np.sin(np.pi * tg / tg[-1]) ** 0.7 * 0.14)
    sink = st_path(grind, [pan_of(m, th[0][0] + (th[-1][0] - th[0][0]) * u) for u in np.clip(tg[::441] / (s1 - s0 - 0.36), 0, 1)])
    for x, h, k, at, sk in th:
        for _ in range(2 + round(2 * k)):
            a, v = -np.pi / 2 + rng.uniform(-1.1, 1.1), rng.uniform(60, 210) * 0.35
            put(sink, st(knock(0.08, int(rng.integers(1, 999)), 9), pan_of(m, x)), sk - s0 + fall_time(-1, np.sin(a) * v))
    full = shot(m, [(start, 0.04), (hit, th[0][3]), (body, th[-1][3] + 0.03), (tail, 0), (sink, s0)])
    return leveled(m, full, {"start": start, "hit": hit, "body": body, "tail": tail, "sink": sink},
                   "earth tearing L->R (0.04-0.54), 6 thorn punches 0.12-0.495 growing louder/lower and panned "
                   "out, short rumble, chips/grit; silent hold; earth grind sliding L->R as they sink (1.45-2.1)", -23)


# ------------------------------------------------------------------ one-shots: plants
def root_snare(m):
    """start: the act's windup (0.24 s): a low breath of earth. The floor cracks (0 .. 0.4: grit ticking) and the 5
    roots burst up at their own times (0.16 + i 0.07 + up to 0.04), each a dirt burst of its own size and pan with chips
    knocking down; they spiral up the legs creaking, tighter toward the cinch. hit 1 at CINCH 0.62: the snap as they
    cinch (a sharp crack and a woody 'tok'); after the 0.05 freeze, the squeeze: a creak dying away, a dust puff. The
    hold is silent. hit 2 at BREAK 1.75: they splinter (a cluster of cracks); after the 0.04 freeze, they crumble (a
    rustle) and the bark chips tock down where they land."""
    sd = seed_of(m)
    rng = np.random.default_rng(sd)
    (CINCH, fz1), (BREAK, fz2) = hits_of(m)
    start = st(breath(windup_of(m), 14, 11, 0.12, sd))
    grow = blank(CINCH)
    for _ in range(9):
        put(grow, st(tick(rng.uniform(0.04, 0.09), int(rng.integers(1, 999)), short=False), rng.uniform(-0.35, 0.35)),
            rng.uniform(0, 0.4) + rng.uniform(0.05, 0.15))
    roots = []
    for i in range(5):
        at, x = 0.16 + i * 0.07 + rng.uniform(0, 0.04), rng.uniform(-20, 20)
        roots.append(at)
        v = rng.uniform(0.6, 1.0)
        put(grow, st([crack(0.03, 4, 0.3 * v, 70, sd + i), knock(0.32 * v, sd + 10 + i, int(rng.integers(8, 11)), 0.08, 40, 0.4)],
                     pan_of(m, x)), at)
        for _ in range(4):
            vy = rng.uniform(60, 160)
            put(grow, st(knock(0.06 * vy / 160, int(rng.integers(1, 999)), 8), pan_of(m, x + rng.uniform(-15, 15))),
                at + fall_time(-1, -vy))
    tc = T(CINCH - roots[0])
    put(grow, st(creak(len(tc) / SR, (tc / tc[-1]) ** 1.5 * 0.2, 62, sd + 20)), roots[0])
    hit = st([crack(0.03, 1, 0.85, 90, sd + 21, True), crack(0.04, 3, 0.5, 60, sd + 22),
              after(material_hit("wood", 0.35 * rng.uniform(0.93, 1.07), sd * 7 + 457, 0.55), 0.01), knock(0.4, sd + 23, 7, 0.07, 45, 0.5)])
    tb = T(0.6)
    body = st(creak(0.6, decay(tb, 5) * 0.3, 55 - 10 * tb, sd + 24))
    put(body, st(air(0.45, 8, 11, 0.12, sd + 25)), 0)
    brk = blank(0.3)
    for j, (at, v, sh) in enumerate(((0, 0.9, True), (0.012, 0.6, False), (0.031, 0.55, True), (0.052, 0.35, False))):
        put(brk, st(crack(0.03, int(rng.integers(0, 3)), v, 80, sd + 30 + j, sh), rng.uniform(-0.2, 0.2)), at + rng.uniform(0, 0.006))
    put(brk, st(after(material_hit("wood", 0.7, sd * 7 + 461, 0.45))), 0)
    tr = T(0.6)
    crumble = st(noise(len(tr), 7, seed=sd + 40) * lvl(decay(tr, 6) * 0.3))
    for _ in range(26):
        y0, vy = -rng.uniform(1, 21), -rng.uniform(50, 150)
        x = rng.uniform(-18, 18) + np.sign(rng.uniform(-1, 1)) * rng.uniform(25, 85) * 0.2
        put(crumble, st(tock(rng.uniform(0.05, 0.16), int(rng.integers(1, 999)), rng), pan_of(m, x)), fall_time(y0, vy))
    full = shot(m, [(grow, 0), (hit, CINCH), (body, CINCH + fz1), (brk, BREAK), (crumble, BREAK + fz2)])
    return leveled(m, full, {"start": start, "grow": grow, "hit": hit, "body": body, "break": brk, "tail": crumble},
                   "5 dirt bursts at the roots' own times (0.16-0.52) + creak tightening, snap at 0.62, squeeze creak "
                   "after the 0.05 freeze, silent hold, splinter at 1.75, crumble + bark tocks after the 0.04 freeze",
                   -23)


def vine_whip(m):
    """The vine bursts from the floor at t 0 (dirt burst, grit) and shoots up rustling (0 .. 0.14); it rears back
    coiled (0.1 .. LASH 0.36), creaking tighter; the lash runs up it (LASH .. CRACK 0.555) as air rising and swelling
    from the root to the tip on the right; hit at CRACK: a whip crack at the tip with a wet sap splat; the sap spray
    spatters down (18 drops) and the torn leaves flutter off silently; it relaxes (0.82 .. 1.0, a soft rustle back) and
    slides into the floor (1.0 .. 1.3, an earth grind, a little dirt at 1.08)."""
    sd = seed_of(m)
    rng = np.random.default_rng(sd)
    N, LS, LASH, LAG, TAU_S = 24, 3.3, 0.36, 0.0052, 0.055
    OM = 2 * np.pi / 0.21
    CRACK = LASH + LAG * N + (np.pi - np.arctan(OM * TAU_S)) / OM
    tip = N * LS * 0.9
    p0, pt = pan_of(m, 0), pan_of(m, tip)
    start = blank(CRACK)
    put(start, st([crack(0.03, 4, 0.35, 60, sd), knock(0.35, sd + 1, 9, 0.08, 40, 0.5)], p0), 0)
    put(start, st(rustle(0.16, np.sin(np.pi * np.clip(T(0.16) / 0.16, 0, 1)) * 0.25, sd + 2), p0), 0.01)
    for _ in range(6):
        put(start, st(tick(rng.uniform(0.05, 0.1), int(rng.integers(1, 999)), short=False), p0 + rng.uniform(-0.2, 0.2)),
            fall_time(-1, -rng.uniform(40, 120)))
    tr = T(LASH - 0.1)
    put(start, st(creak(len(tr) / SR, (tr / tr[-1]) ** 1.3 * 0.18, 80, sd + 3), p0), 0.1)
    tl = T(CRACK - LASH)
    u = tl / tl[-1]
    lash = noise(len(tl), np.round(10 - 9 * u ** 1.5).astype(int), seed=sd + 4) * lvl(u ** 2 * 0.45)
    put(start, st(lash, (p0, pt)), LASH)
    hit = st([crack(0.018, 0, 0.75, 140, sd + 5), crack(0.012, 1, 0.45, 160, sd + 6, short=True),
              glide(1700 * rng.uniform(0.92, 1.08), 600, 0.035, 0.28, 0.25, 50), splat(0.3, sd + 7, 0.08, 3, 40)], pt)
    body = blank(0.6)
    put(body, st(crack(0.2, 2, 0.12, 12, sd + 8), pt), 0)
    for _ in range(18):
        a, v = rng.uniform(-1.2, 0.4), rng.uniform(60, 200)
        r = ndrop(tip, -30 + rng.uniform(-6, 6), np.cos(a) * v, np.sin(a) * v)
        if r:
            put(body, st(splat(rng.uniform(0.04, 0.1), int(rng.integers(1, 999)), 0.03, 2, 90), pan_of(m, r[1])), r[0])
    tail = blank(0.6)
    put(tail, st(rustle(0.25, np.sin(np.pi * T(0.25) / 0.25) * 0.15, sd + 9), (pt, p0)), 0)
    tg = T(0.35)
    put(tail, st(noise(len(tg), 11, seed=sd + 10) * lvl(np.sin(np.pi * tg / 0.35) * 0.16), p0), 1.0 - 0.82)
    for _ in range(3):
        put(tail, st(tick(0.06, int(rng.integers(1, 999)), short=False), p0), 1.08 - 0.82 + rng.uniform(0.1, 0.3))
    full = shot(m, [(start, 0), (hit, CRACK), (body, CRACK + 0.02), (tail, 0.82)])
    return leveled(m, full, {"start": start, "hit": hit, "body": body, "tail": tail},
                   "dirt burst + rustle up (0-0.14), creak coiling (0.1-0.36), lash air rising root->tip, whip crack + "
                   "sap splat at 0.555, sap spatter, rustle back, earth grind sliding in (1.0-1.3)", -24)


def healing_bloom(m):
    """A sprout breaks the soil at t 0 (a soft knock, grit hopping) and pushes up rustling (0 .. STEM 0.42); the bud
    draws light in (STEM .. 0.93): a quiet gather, glitter swelling and a thin glide rising, the bud's petals unfolding
    (BUD 0.75 .. OPEN 1.05) as a leafy rustle; at OPEN - 0.12 (0.93) it flares open round its heart: a bright 'pssh'
    and sparkle, no drop (nothing lands). The motes and the petals lifting away float silently (rule 2) and each petal
    winks as it twinkles out at the end of its flight. The wilt is silent."""
    sd = seed_of(m)
    rng = np.random.default_rng(sd)
    STEM, BUD, OPEN, LIFT = 0.42, 0.75, 1.05, 1.7
    POP = OPEN - 0.12
    start = blank(POP)
    put(start, st(knock(0.22, sd, 11, 0.07, 45, 0.3)), 0)
    for _ in range(8):
        put(start, st(tick(rng.uniform(0.04, 0.08), int(rng.integers(1, 999)), short=False), rng.uniform(-0.15, 0.15)),
            fall_time(-1, -rng.uniform(40, 100)))
    ts = T(STEM)
    put(start, st(rustle(STEM, np.sin(np.pi * ts / STEM) * 0.16, sd + 1, 5)), 0.02)
    g = gather(POP - STEM, 0.13, sd + 2, 6, 0, 420, 1100, 2.0, 6, rng, 0.3)
    put(start, g, STEM)
    tb = T(OPEN - BUD)
    put(start, st(rustle(OPEN - BUD, np.sin(np.pi * tb / tb[-1]) * 0.12, sd + 3, 3)), BUD)
    hit = st([crack(0.3, 0, 0.32, 11, sd + 4), glitter(0.35, decay(T(0.35), 8) * 0.22, 1, sd + 5, 0.7, True),
              sweep(1500, 2600, 0.12, decay(T(0.12), 20) * 0.08)])
    tail = blank(2.5)
    for i in range(6):
        at = LIFT + ((i * 0.37) % 1) * 0.55
        life = min(rng.uniform(0.75, 1.0), 3.3 - 0.45 - at)
        x = 10 * np.cos(i / 6 * 2 * np.pi + 0.3) + rng.uniform(-10, 10)
        put(tail, st(crack(0.014, 0, rng.uniform(0.08, 0.13), 170, sd + 10 + i, True), pan_of(m, x)), at + life - POP)
    full = shot(m, [(start, 0), (hit, POP), (tail, POP)])
    return leveled(m, full, {"start": start, "hit": hit, "tail": tail},
                   "soil knock + grit, rustle up (0-0.42), quiet gather of light (0.42-0.93) + petal rustle, bright "
                   "pssh + sparkle at 0.93, silent motes/petals, 6 tiny winks as the petals twinkle out", -27)


def spore_burst(m):
    """A toadstool pushes up at t 0 (soil cracking, grit) with a rubbery swell (0 .. GROW 0.32); it swells and trembles
    as its gills glow (GROW .. PUFF 0.8): a quiver getting faster (the original's sin 70t jitter, here a level jumping
    each frame) over a low tone gliding up, spores drawn in as a rising hiss; at PUFF it squashes and puffs: a soft
    'poof' (no bright crack: it's soft) over a soft flesh-like smack and push (synth flesh_hit, no falling tone), the
    poof wobbling as the cap springs back (e^-7t cos 26t), a sparkle of
    spores; the cloud billows out as a soft breath dying away; the spores drift silently (rule 2); it sinks back at
    SINK 2.15 with a soft soil slide."""
    sd = seed_of(m)
    rng = np.random.default_rng(sd)
    GROW, PUFF, SINK = 0.32, 0.8, 2.15
    start = blank(PUFF)
    put(start, st(knock(0.2, sd, 11, 0.07, 45, 0.4)), 0)
    for _ in range(10):
        put(start, st(tick(rng.uniform(0.03, 0.07), int(rng.integers(1, 999)), short=False), rng.uniform(-0.2, 0.2)),
            fall_time(-1, -rng.uniform(40, 120)))
    tg = T(GROW)
    put(start, st(tri(85 * 1.6 ** (tg / GROW)) * lvl(np.sin(np.pi * tg / GROW) * 0.22)), 0)
    tq = T(PUFF - GROW)
    k = tq / tq[-1]
    fr = SR // 60
    quiv = (1 - 0.7 * rng.random(len(tq) // fr + 1)).repeat(fr)[: len(tq)]
    tone = pulse(95 * 1.8 ** k, 0.125) * lvl((0.2 + 0.8 * k) * quiv * 0.12)
    hiss = noise(len(tq), np.round(6 - 4 * k).astype(int), seed=sd + 1) * lvl((0.1 + 0.9 * k ** 2) * 0.14)
    put(start, st(tone + hiss), GROW)
    t = T(0.5)
    squash = material_hit("flesh", 0.45, sd * 7 + 467, 0.45)
    poof = noise(len(t), np.round(np.interp(t, [0, 0.5], [3, 7])).astype(int), seed=sd + 2) * lvl(
        np.minimum(1, t / 0.02) * decay(t, 7) * (1 + 0.3 * np.cos(26 * t)) * 0.4)
    hit = st([squash, poof, glitter(0.3, decay(T(0.3), 10) * 0.12, 1, sd + 3, 0.7, True)])
    tb = T(1.4)
    body = st(noise(len(tb), np.round(np.interp(tb, [0, 1.4], [6, 9])).astype(int), seed=sd + 4) * lvl(
        np.minimum(1, tb / 0.15) * decay(tb, 2.2) * 0.2))
    tl = T(0.45)
    sink = st(noise(len(tl), 11, seed=sd + 5) * lvl(np.sin(np.pi * tl / 0.45) * 0.12))
    full = shot(m, [(start, 0), (hit, PUFF), (body, PUFF + 0.03), (sink, SINK)])
    return leveled(m, full, {"start": start, "hit": hit, "body": body, "sink": sink},
                   "soil crack + rubbery swell (0-0.32), quivering rising tone + spore hiss (0.32-0.8), soft poof + "
                   "soft smack + wobbling poof + sparkle at 0.8, cloud breath, silent drift, soil slide at 2.15", -26)


def acid_splash(m):
    """The gob falls silently and bursts at HIT 0.3: a wet splat (a darker crack, liquid's weight: a small low noise whomp, no falling tone; spatter); body: it
    eats into the floor, sizzling: a hiss crackling hotter as the pit spreads (heat: up over 0.3 s, out by GONE 2.2),
    with the original's pops spitting beads at random (about 9 a second, from HIT + 0.15); tail: the 26 drops and the 13
    beads off the crown's spikes (shed at HIT + 0.09) each hiss where they land (the Drops lib's flight); the pit's
    last smoke is silent."""
    sd = seed_of(m)
    rng = np.random.default_rng(sd)
    HIT, GONE = 0.3, 2.2
    hit = st([crack(0.05, 2, 0.7, 50, sd), wet_hit(0.25 * rng.uniform(0.92, 1.08), sd * 7 + 479, 0.55),
              splat(0.45, sd + 1, 0.18, 3, 20)])
    D = GONE + 0.3 - HIT
    t = T(D)
    tt = t + HIT
    heat = np.clip((tt - HIT) / 0.3, 0, 1) * (1 - np.clip((tt - GONE + 0.3) / 0.55, 0, 1))
    sizzle = glitter(D, heat * 0.2, 0, sd + 2, 0.75) + noise(len(t), 2, seed=sd + 3) * lvl(heat * 0.06)
    body = st(sizzle)
    at = HIT + 0.15
    while True:
        at += rng.exponential(1 / 9)
        if at >= GONE:
            break
        h = np.clip((at - HIT) / 0.3, 0, 1) * (1 - np.clip((at - GONE + 0.3) / 0.55, 0, 1))
        put(body, st(crack(0.025, int(rng.integers(0, 2)), 0.2 * h * rng.uniform(0.5, 1), 110, int(rng.integers(1, 999)),
                           bool(rng.random() < 0.3)), pan_of(m, rng.uniform(-25, 25))), at - HIT)
    tail = blank(2.0)
    lands = []
    for _ in range(26):
        a, v = -np.pi / 2 + rng.uniform(-1.35, 1.35), rng.uniform(60, 250)
        r = ndrop(rng.uniform(-3, 3), -2, np.cos(a) * v, np.sin(a) * v, 2 if rng.random() < 0.3 else 1)
        if r:
            lands.append(r)
    for i in range(13):
        a = i / 13 * 2 * np.pi
        r = ndrop(np.cos(a) * 14, -12, np.cos(a) * rng.uniform(30, 80), -rng.uniform(50, 130))
        if r:
            lands.append((0.09 + r[0], r[1], r[2]))
    for tl, x, v in lands:
        tl_ = T(0.12)
        s = noise(len(tl_), 0, seed=int(rng.integers(1, 999))) * lvl(decay(tl_, 30) * 0.12 * min(1, v / 250 + 0.3))
        put(tail, st(s, pan_of(m, x)), tl)
    full = shot(m, [(hit, HIT), (body, HIT), (tail, HIT)])
    return leveled(m, full, {"hit": hit, "body": body, "tail": tail},
                   "wet splat + small wet whomp at 0.3, sizzle crackling hotter then out by 2.2 with bead pops at random, "
                   "each landing drop hissing where it falls", -24)


SOUNDS = {
    "acid-splash": acid_splash,
    "boulder": boulder,
    "earth-spike": earth_spike,
    "healing-bloom": healing_bloom,
    "leaf-storm": leaf_storm,
    "poison-cloud": poison_cloud,
    "quake": quake,
    "root-snare": root_snare,
    "spore-burst": spore_burst,
    "thorns": thorns,
    "tornado": tornado,
    "toxic-puddle": toxic_puddle,
    "vine-whip": vine_whip,
}
