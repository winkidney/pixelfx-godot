# water: material first (rule 5): water splashes, plinks and bubbles, and roars when a lot of it moves. A drop into
# water is a tiny wet tick and a short tone sweeping up (the bubble it traps); a bubble is the same, lower for a bigger
# one; a splash is a wet noise burst over water's own weight (a low noise whomp opening into a wash, never a falling
# tone: sound.md rule 2). Drips and bubbles never form a tune or a beat: every
# one gets its own pitch, length and level, and they fall where the effect's own drops and bubbles land, so their
# times are irregular. Flowing water heard all round (a waterfall, a fountain, rain, a whirlpool) is a quiet loop of
# its material only, no accents (rule 2, exception 2). Still water and an idle orb are silent (rule 2). Beats from
# src/fx/water/<name>.js; times of the original's own particles replayed with its hash (src/core/math.js).
import numpy as np
from synth import *  # noqa: F401,F403
from cats.impacts import seed_of, pan_of, st, put, crack, air
from cats.projectiles import leveled, shot, lput, st_path
from cats.arcane import JsRng, glitter
from cats.fire import loop_curve, moving

M32 = 0xFFFFFFFF


# ------------------------------------------------------------------ the original's randomness (src/core/math.js)
def jhash(*ns):
    """hash(...ns): the original's integer hash, so cycle() births and rand() values come out as on screen."""
    h = 0x9E3779B9
    for n in ns:
        h = ((h ^ (int(n) & M32)) * 0x85EBCA6B) & M32
        h ^= h >> 13
        h = (h * 0xC2B2AE35) & M32
        h ^= h >> 16
    return h & M32


def jrand(*ns):
    return jhash(*ns) / 4294967296


def jrng(*ns):
    return JsRng(jhash(*ns))


def births(period, count, seed, life):
    """core/particles.js cycle(): each particle's birth time in the loop, its life, its own Rng, its index."""
    out = []
    for i in range(count):
        g = jrng(seed, i, 911)
        born = g.next() * period
        L = life(g) if callable(life) else life
        out.append((born, L, jrng(seed, i), i))
    return out


# ------------------------------------------------------------------ voices of water
def lvl(env):
    """Volume stepped in 16 levels at the layer's own scale (a quiet layer keeps its shape; README pitfall)."""
    e = np.asarray(env, float)
    top = float(e.max()) if e.size else 0.0
    return steps(e / top) * top if top > 0 else e


def plink(f, vol=0.3, seed=1, secs=0.08, up=1.8, k=40, wet=0.5):
    """A drop into water: a tiny wet tick and a short triangle sweeping up fast (the bubble a drop traps rings up).
    Every caller draws its own f, so a run of them never settles on notes."""
    t = T(secs)
    tone = tri(f * up ** np.minimum(1, t / (secs * 0.45))) * lvl(decay(t, k) * vol)
    return tone + noise(len(t), 1, seed=seed) * lvl(decay(t, 160) * vol * wet)


def blub(r, vol=0.25, seed=1, rng=None):
    """A bubble breaking the surface: a plink, lower and rounder the bigger it is (r in px, 0.5 .. 3)."""
    rng = rng or np.random.default_rng(seed)
    f = 560 / max(0.4, r) * rng.uniform(0.85, 1.18)
    return plink(f, vol, seed, 0.045 + 0.025 * r, rng.uniform(1.4, 1.9), 34 - 4 * min(r, 3), 0.25)


def splat(vol=0.3, seed=1, secs=0.12, rate=3, k=35):
    """A splash: a wet noise burst (mid-rate noise, darker than a crack) with a bright fleck on its front."""
    t = T(secs)
    return noise(len(t), rate, seed=seed) * lvl(decay(t, k) * vol) + \
        noise(len(t), 0, seed=seed + 1) * lvl(decay(t, 110) * vol * 0.5)


def wet_hit(weight=0.5, seed=1, vol=0.6):
    """Water's weight when nothing plunges in (a gob bursting on the floor, a column bursting up, goo landing): the
    whomp and spray of synth's water_hit without its bubble bloop. No tone (sound.md rule 2)."""
    secs = 0.35 + 0.6 * weight
    t = T(secs)
    rate = np.round(np.interp(t, [0, 0.04, secs], [14, 9 + 2 * weight, 6])).astype(int)
    whomp = noise(len(t), rate, seed=seed) * lvl(np.exp(-t / (0.08 + 0.25 * weight)) * vol * (0.6 + 0.4 * weight))
    spray = noise(len(t), np.round(np.interp(t, [0, secs], [3, 1])).astype(int), seed=seed + 1) * \
        lvl(np.interp(t, [0, 0.03, secs], [0, 1, 0]) ** 1.5 * vol * 0.35)
    return whomp + spray


def wdrop(h, vh, vx=0.0, x=0.0, g=820.0, drag=0.35, life=4.0):
    """When a drop of water/_lib.js Drops (height h, up-speed vh, drag on all axes) comes down: (t, x, speed)."""
    dt, t = 1 / 120, 0.0
    while t < life:
        vh -= g * dt
        vx -= vx * drag * dt
        vh -= vh * drag * dt * 0.5
        x += vx * dt
        h += vh * dt
        t += dt
        if h <= 0 and vh < 0:
            return t, x, -vh
    return None


def drops_land(buf, m, lands, vol, rng, f_rng=(900, 2000), ref=300.0, wet=0.5, at0=0.0):
    """Each landing [(t, x, speed)] plinks where it falls, as loud as it hits, at its own pitch."""
    for t, x, v in lands:
        a = min(1.0, v / ref)
        if a < 0.1:
            continue
        s = plink(rng.uniform(*f_rng), vol * a * rng.uniform(0.6, 1.0), int(rng.integers(1, 999)),
                  rng.uniform(0.05, 0.09), rng.uniform(1.4, 2.2), rng.uniform(32, 55), wet)
        put(buf, st(s, pan_of(m, x)), at0 + t)


def babble(P, per_s, vol, seed, pans=(-0.4, 0.4), f_rng=(700, 2400)):
    """Many small drops into water at random (never on a grid): a loop of P (+X) seconds that wraps."""
    rng = np.random.default_rng(seed)
    buf = blank(P + X)
    for at in rng.uniform(0, P, int(per_s * P)):
        s = plink(rng.uniform(*f_rng), vol * rng.uniform(0.25, 1.0), int(rng.integers(1, 999)), rng.uniform(0.035, 0.07),
                  rng.uniform(1.3, 2.2), rng.uniform(40, 70), rng.uniform(0.3, 0.9))
        lput(buf, st(s, rng.uniform(*pans)), at, P)
    return buf


def rush(secs, rate, level, rng, seed, flick=1.5, depth=0.2, period=None):
    """Moving water: noise at a rate, its level wobbling smoothly (repeating every period, so a loop wraps)."""
    t = T(secs)
    w = 1 - depth + depth * loop_curve(t, period or secs, flick, rng)
    return noise(len(t), rate, seed=seed) * lvl(w * level)


# ------------------------------------------------------------------ silent
def ripples(m):
    return Silent("still dark water with rings spreading: a steady thing with no noise of its own (rule 2); its drop "
                  "falls on a strict 0.5 s clock, so a plink on each would be a metronome (rule 1)")


def water_orb(m):
    return Silent("an idle orb of water floating and wobbling, its drips small: a steady thing with no noise of its own "
                  "(rule 2); a one-shot only if the game bursts or summons it")


# ------------------------------------------------------------------ loops
def bubbles(m):
    """Loop (4 s): a stream of bubbles from a vent. Its own 46 bubbles (cycle() replayed: birth, size, speed) break the
    surface ~90 px up, the big ones after doming 0.12 s: each a blub at its own pitch (lower for a bigger one), small
    ones a faint tick; under them a soft low burble at the vent. A bubbling stream is a texture: no accents."""
    sd = seed_of(m)
    S, P = m["options"]["seed"], m["duration"]
    rng = np.random.default_rng(sd)
    buf = blank(P + X)
    mouths = [-5, 1, 6]
    for born, L, r, i in births(P, 46, S, lambda g: g.range(2.2, 3.4)):
        r0 = r.range(0.5, 1.4) if r.next() < 0.7 else r.range(1.6, 2.6)
        vy = 30 + 9 * r0 + r.range(-4, 4)
        rr = r0 * 1.45
        age = (90 - rr) / vy + (0.12 if rr >= 1.4 else 0)
        if age >= L:
            continue
        x = mouths[i % 3] + rng.uniform(-4, 4)
        v = 0.5 if rr >= 1.4 else 0.18
        lput(buf, st(blub(rr, v * rng.uniform(0.7, 1), sd + i, rng), pan_of(m, x)), born + age, P)
    t = T(P + X)
    burble = noise(len(t), 9, seed=sd + 1) * glitter_env(t, P, rng, 0.14, 0.75)
    buf += stereo(burble, pan_of(m, 0))
    loop = wrap(buf, P)
    return leveled(m, loop, {"loop": loop}, "loop: the vent's 46 bubbles blub as they break the surface (each its own "
                   "pitch and time, from the original's cycle), soft burble at the vent; no accents", -34)


def glitter_env(t, P, rng, vol, depth):
    """A level that jumps at random each 60 Hz frame (bubbling, rustling), repeating every loop P."""
    fr = SR // 60
    n = int(round(P * 60))
    pat = 1 - depth * rng.random(n)
    idx = (np.arange(len(t)) // fr) % n
    return lvl(pat[idx] * vol)


def drip(m, take=0):
    """Loop (1.6 s): a bead swells and lets go at LET 0.78 (silent), falls 62 px (g 760) and plinks into the puddle at
    1.184; its rebound bead drops back 0.26 s later, a smaller plink at another pitch. The game should draw a new take
    for every drop (hit phase), so a dripping cave never repeats a pitch or forms a beat."""
    sd = seed_of(m) + take
    rng = np.random.default_rng(sd)
    P = m["duration"]
    land = 0.78 + np.sqrt(2 * m["options"].get("height", 62) / 760)
    f = rng.uniform(900, 1350)
    hit = blank(0.5)
    put(hit, st(plink(f, 0.6, sd, 0.11, rng.uniform(1.7, 2.1), 28, 0.6)), 0)
    put(hit, st(splat(0.1, sd + 1, 0.05, 2, 70)), 0)
    put(hit, st(plink(f * rng.uniform(1.27, 1.42), 0.22, sd + 2, 0.06, rng.uniform(1.4, 1.8), 45, 0.4)), 0.26)
    loop = blank(P + X)
    lput(loop, hit, land, P)
    loop = wrap(loop, P)
    return leveled(m, loop, {"hit": hit}, "silent swell; plink into the puddle at 1.184 and a smaller one from the "
                   "rebound at 1.444 (new pitch each take)", -33)


def fountain(m):
    """Loop (2 s): flowing water heard round a fountain: the basin's patter (its arcs' beads coming down all round,
    many small plinks at random pitches and times) over a soft splashing wash and the jet's hiss. No accents."""
    sd = seed_of(m)
    rng = np.random.default_rng(sd)
    P = m["duration"]
    wash = rush(P + X, 8, 0.5, rng, sd, 1.5, 0.25, P) + rush(P + X, 2, 0.22, rng, sd + 1, 2, 0.2, P)
    jet = rush(P + X, 1, 0.12, rng, sd + 2, 3, 0.15, P)
    buf = stereo(wash) + stereo(jet, pan_of(m, 0))
    buf += babble(P, 40, 0.35, sd + 3, (pan_of(m, -36), pan_of(m, 36)), (800, 2600))
    loop = wrap(buf, P)
    return leveled(m, loop, {"loop": loop}, "loop: soft splashing wash + jet hiss + the basin's patter of small "
                   "plinks at random; no accents", -33)


def rain_splash(m):
    """Loop (2.4 s): rain on a puddle, heard everywhere: a steady hiss, fine rain dimpling the water as dense random
    ticks, and the 8 big drops (at the original's own times, rand()-jittered) as soft splats no louder than the
    patter round them, each its own pitch: a bed, no accents (rule 2, exception 2)."""
    sd = seed_of(m)
    S, P = m["options"]["seed"], m["duration"]
    rng = np.random.default_rng(sd)
    t = T(P + X)
    bed = noise(len(t), 1, seed=sd) * 0.3 + noise(len(t), 4, seed=sd + 1) * 0.12
    buf = stereo(bed)
    buf += babble(P, 30, 0.3, sd + 2, (-0.6, 0.6), (1400, 3200))
    for i in range(8):
        x, t0 = (jrand(i, S) - 0.5) * 120, (i + 0.25 * jrand(i, S + 2)) / 8 * P
        s = splat(0.2 * rng.uniform(0.7, 1), sd + 10 + i, 0.07, 2, 50) + \
            plink(rng.uniform(700, 1300), 0.2, sd + 20 + i, 0.07, rng.uniform(1.5, 2.0), 40, 0.2)
        lput(buf, st(s, pan_of(m, x)), t0, P)
    loop = wrap(buf, P)
    return leveled(m, loop, {"loop": loop}, "loop: rain hiss + dense random fine-drop ticks + the 8 big drops as soft "
                   "splats inside the patter; no accents", -32)


def water_jet(m):
    """Loop (1 s): a pressurised stream blasting right: the nozzle's hiss on the left, the stream's rush across, its
    end tearing into chunks and spray on the right (the original's 70 spray drops a loop, at random, as wet ticks and
    spits). The surges running down it are seen, not heard: a 4 Hz pump would be a beat. start: the valve opening (a
    fast 'pshh' and the gush); stop: the pressure dropping off, a last sputter."""
    sd = seed_of(m)
    rng = np.random.default_rng(sd)
    P, L = m["duration"], m["options"].get("length", 118)
    pn, pm, pe = pan_of(m, 0), pan_of(m, L * 0.5), pan_of(m, L)
    t = T(P + X)
    buf = stereo(rush(P + X, 1, 0.5, rng, sd, 4, 0.15, P), pn)
    buf += stereo(rush(P + X, 6, 0.55, rng, sd + 1, 3, 0.25, P), pm)
    buf += stereo(rush(P + X, 3, 0.3, rng, sd + 2, 5, 0.35, P), pe)
    for _ in range(70):
        x = L * (0.3 + 0.7 * np.sqrt(rng.random())) + rng.uniform(0, 40)
        s = splat(rng.uniform(0.08, 0.2), int(rng.integers(1, 999)), 0.04, int(rng.integers(0, 3)), 80)
        lput(buf, st(s, pan_of(m, x)), rng.uniform(0, P), P)
    loop = wrap(buf, P)
    start = blank(0.5)
    put(start, st(air(0.25, 4, 0, 0.6, sd + 3, "rise"), (pn, pm)), 0)
    put(start, st(air(0.35, 2, 6, 0.4, sd + 4, "fall"), (pm, pe)), 0.2)
    stop = blank(0.6)
    tt = T(0.45)
    put(stop, st(noise(len(tt), np.round(1 + 6 * tt / 0.45).astype(int), seed=sd + 5) * lvl((1 - tt / 0.45) ** 1.5 * 0.5),
                 (pn, pm)), 0)
    for k, at in enumerate(sorted(rng.uniform(0.2, 0.5, 3))):
        put(stop, st(splat(rng.uniform(0.15, 0.3), sd + 6 + k, 0.06, 2, 45), pn), at)
    start, stop = start * 2.0, stop * 1.8                 # a touch over the held loop (start, stop > loop)
    return leveled(m, loop, {"loop": loop, "start": start, "stop": stop},
                   "loop: nozzle hiss (left) + stream rush + spray spitting off its end (right), steady, no pump; "
                   "start: valve 'pshh' + gush; stop: pressure falling, a sputter", -29)


def waterfall(m):
    """Loop (2 s): a river falling into a pool, heard all round: the deep roar of the falling sheet, the churn of foam
    at its foot (a level that jumps at random each frame), the hiss of spray and mist. A bed, no accents."""
    sd = seed_of(m)
    rng = np.random.default_rng(sd)
    P = m["duration"]
    t = T(P + X)
    roar = rush(P + X, 13, 0.7, rng, sd, 1, 0.15, P)
    churn = noise(len(t), 7, seed=sd + 1) * glitter_env(t, P, rng, 0.35, 0.45)
    spray = rush(P + X, 2, 0.22, rng, sd + 2, 2, 0.25, P)
    buf = stereo(roar, pan_of(m, 0) * 0.5)
    moving(buf, churn, 0, 0.25 * loop_curve(t, P, 1, rng))
    buf += stereo(spray, pan_of(m, 8))
    loop = wrap(buf, P)
    return leveled(m, loop, {"loop": loop}, "loop: deep roar of the falling sheet + foam churn + spray hiss; no "
                   "accents", -33)


def whirlpool(m):
    """Loop (3 s): water winding into a vortex, its spiral turning once a loop: a swirling wash whose pan circles once a
    loop, a low gurgle drawn down at the eye. Quiet, steady, no accents."""
    sd = seed_of(m)
    rng = np.random.default_rng(sd)
    P = m["duration"]
    t = T(P + X)
    swirl = rush(P + X, 7, 0.5, rng, sd, 1.5, 0.3, P) + rush(P + X, 3, 0.18, rng, sd + 1, 2, 0.3, P)
    gurgle = noise(len(t), 12, seed=sd + 2) * glitter_env(t, P, rng, 0.35, 0.6)
    buf = blank(P + X)
    moving(buf, swirl, 0, 0.45 * np.cos(2 * np.pi * t / P))
    buf += stereo(gurgle, pan_of(m, 0))
    loop = wrap(buf, P)
    return leveled(m, loop, {"loop": loop}, "loop: swirling wash circling once a loop + low gurgle at the eye; no "
                   "accents", -34)


# ------------------------------------------------------------------ one-shots
def splash(m):
    """A stone drops into still water at HIT 0.16: a wet crack, water's 'plunk' (a mid-sized water hit: low noise
    whomp, spray and the bubble bloop of a plunge, no falling tone) and the first sheet of spray
    whooshing up; body: the crown falling back, foam churning; the jet bouncing back up the middle (HIT + JET 0.46) is
    a rising 'bloop', its bead dropping back to plink; the crown's 20 spray drops, 12 finger beads (torn off at HIT +
    0.11) and 8 heavy drops (HIT + 0.3) plink where their flight (g 820, drag 0.35) lands them; the stone's air glugs up
    in 3 bubbles (1.31, 1.56, 1.86), each its own blub; foam fizzing out."""
    sd = seed_of(m)
    rng = np.random.default_rng(sd)
    HIT, JET, TEAR = 0.16, 0.3, 0.11
    hit = st([crack(0.06, 1, 0.75, 45, sd), material_hit("water", 0.35 * rng.uniform(0.9, 1.1), sd * 7 + 311, 0.75),
              air(0.3, 3, 0, 0.35, sd + 1, "bell")], 0)
    t = T(0.9)
    churn = noise(len(t), np.round(np.interp(t, [0, 0.9], [4, 8])).astype(int), seed=sd + 2) * lvl(
        np.minimum(1, t / 0.04) * decay(t, 4) * 0.4)
    body = st(churn, 0)
    tt = T(0.14)
    bloop = tri(190 * 3.4 ** (tt / 0.14)) * lvl(np.sin(np.pi * np.minimum(1, tt / 0.14)) * 0.4)
    put(body, st(bloop), JET)
    tail = blank(2.4)
    lands = []
    for _ in range(20):
        a, v = rng.uniform(0, 2 * np.pi), rng.uniform(50, 125)
        r = wdrop(rng.uniform(1, 6), rng.uniform(160, 270), np.cos(a) * v, 3 * np.cos(a))
        if r:
            lands.append((r[0] + rng.uniform(0, 0.04), r[1], r[2]))
    for _ in range(12):
        a, v = rng.uniform(0, 2 * np.pi), rng.uniform(32, 88)
        r = wdrop(19 * 1.25, rng.uniform(90, 190), np.cos(a) * v, 14 * np.cos(a))
        if r:
            lands.append((TEAR + r[0], r[1], r[2]))
    for _ in range(8):
        a, v = rng.uniform(0, 2 * np.pi), rng.uniform(15, 40)
        r = wdrop(rng.uniform(3, 7), rng.uniform(30, 80), np.cos(a) * v, 11 * np.cos(a))
        if r:
            lands.append((0.3 + r[0], r[1], r[2]))
    drops_land(tail, m, lands, 0.3, rng, (900, 2100), 280)
    bead = wdrop(27, 55, rng.uniform(-6, 6))
    put(tail, st(plink(rng.uniform(650, 900), 0.4, sd + 3, 0.09, 1.9, 30, 0.6), pan_of(m, bead[1])), JET + 0.12 + bead[0])
    put(tail, st(air(0.5, 6, 9, 0.12, sd + 4, "fall")), JET + 0.38)
    for k, at in enumerate((0.95 + 0.2, 1.2 + 0.2, 1.5 + 0.2)):
        put(tail, st(blub(rng.uniform(1.3, 2.3), rng.uniform(0.25, 0.4), sd + 5 + k, rng), pan_of(m, rng.uniform(-5, 5))), at)
    tf = T(2.0)
    put(tail, st(noise(len(tf), 0, seed=sd + 9) * lvl(np.minimum(1, tf / 0.2) * decay(tf, 1.6) * 0.05)), 0.1)
    full = shot(m, [(hit, HIT), (body, HIT + 0.02), (tail, HIT)])
    return leveled(m, full, {"hit": hit, "body": body, "tail": tail},
                   "wet crack + water plunk (whomp, bloop) + spray whoosh at 0.16, crown churn, rising bloop of the jet (0.46), drops "
                   "plinking where they land, bead plink, 3 glugs (1.31/1.56/1.86), foam fizz", -23)


def geyser(m):
    """start (0 .. ERUPT 1.15): the pool heaves: a low rumble swelling, bubbles bursting on the mound faster and faster
    (the original's rate 1.5 + 9 k^2 per s, at random), each a low blub, and the 4 spurts (0.46, 0.72, 0.92, 1.04) as
    small sploshes whose drops plink back; hit at ERUPT: the burst (a crack, water's weight: a big low noise whomp
    opening into spray, no falling tone; a rush of water up); body: the column roaring while it holds, surging on the original's noise(t * 2.2), slumping from FALL 2.6 to GONE 3.3; tail:
    the head's drops raining back as patter, the collapse (2.72) as a heavy splatter, two sputters (3.45, 3.85), steam
    hissing out."""
    sd = seed_of(m)
    rng = np.random.default_rng(sd)
    ERUPT, FALL, GONE, H = 1.15, 2.6, 3.3, m["options"].get("height", 100)
    t = T(ERUPT)
    k = t / ERUPT
    heave = noise(len(t), 14, seed=sd) * lvl((0.15 + 0.85 * k ** 2) * 0.35) + tri(45 + 30 * k) * lvl(k ** 2 * 0.25)
    start = stereo(heave)
    at = 0.0
    while True:
        kk = at / ERUPT
        at += rng.exponential(1 / (1.5 + 9 * kk * kk))
        if at >= ERUPT - 0.02:
            break
        put(start, st(blub(rng.uniform(1.6, 3.2), 0.2 + 0.25 * at / ERUPT, int(rng.integers(1, 999)), rng),
                      pan_of(m, rng.uniform(-7, 7))), at)
        for _ in range(rng.integers(1, 4)):
            r = wdrop(2, rng.uniform(50, 120), rng.uniform(-25, 25))
            put(start, st(plink(rng.uniform(1200, 2400), 0.08, int(rng.integers(1, 999)), 0.04, 1.6, 60), pan_of(m, r[1])), at + r[0])
    for s0, hs in ((0.46, 7), (0.72, 12), (0.92, 9), (1.04, 15)):
        put(start, st(splat(0.12 + 0.02 * hs, int(rng.integers(1, 999)), 0.14, 3, 22)), s0)
        lands = []
        for _ in range(3 + round(hs / 4)):
            a, v = rng.uniform(0, 2 * np.pi), rng.uniform(10, 40)
            r = wdrop(hs * 0.8, rng.uniform(20, 90), np.cos(a) * v)
            if r:
                lands.append((s0 + 0.08 + r[0], r[1], r[2]))
        drops_land(start, m, lands, 0.14, rng, (1000, 2200), 200)
    hit = st([crack(0.07, 1, 0.85, 40, sd + 1), wet_hit(0.85 * rng.uniform(0.92, 1.08), sd * 7 + 353, 0.8),
              air(0.4, 6, 1, 0.5, sd + 2, "fall")], 0)
    D = GONE + 0.3 - ERUPT
    t = T(D)
    tt = t + ERUPT
    surge = 0.93 + 0.07 * np.interp(tt * 2.2, np.arange(0, 12), rng.uniform(-1, 1, 12))
    hold = np.minimum(1, t / 0.06) * surge * (1 - np.clip((tt - FALL) / (GONE - FALL), 0, 1) ** 2)
    col = noise(len(t), 4, seed=sd + 3) * lvl(hold * 0.4) + noise(len(t), 11, seed=sd + 4) * lvl(hold * 0.42)
    col += noise(len(t), 15, seed=sd + 7) * lvl(hold * decay(t, 0.8) * 0.22)       # its low weight: noise, no tone
    body = stereo(col)
    tail = blank(4.0)
    at = ERUPT + 0.1
    while at < FALL + 0.4:
        hk = np.clip((at - ERUPT - 0.08) / 0.22, 0, 1) * (1 - np.clip((at - FALL - 0.1) / 0.35, 0, 1))
        at += rng.exponential(1 / (30 * max(hk, 0.05)))
        r = wdrop(H * rng.uniform(0.85, 1.0), rng.uniform(-40, 60), rng.uniform(-60, 60))
        put(tail, st(plink(rng.uniform(900, 2400), 0.16 * rng.uniform(0.4, 1), int(rng.integers(1, 999)),
                           0.05, rng.uniform(1.4, 2.0), 50, 0.6), pan_of(m, r[1])), at + r[0] - ERUPT)
    land = wdrop(H * 0.95, 10)[0]
    put(tail, st(splat(0.4, sd + 5, 0.5, 3, 7)), FALL + 0.12 + land - ERUPT)
    lands = []
    for _ in range(40):
        a, v = rng.uniform(0, 2 * np.pi), rng.uniform(15, 80)
        r = wdrop(H * 0.95 + rng.uniform(-8, 4), rng.uniform(-40, 60), np.cos(a) * v)
        lands.append((FALL + 0.12 + rng.uniform(0, 0.25) + r[0] - ERUPT, r[1], r[2]))
    drops_land(tail, m, lands, 0.22, rng, (700, 1900), 400)
    for s0, hs in ((GONE + 0.15, 15), (GONE + 0.55, 8)):
        put(tail, st([splat(0.1 + 0.015 * hs, int(rng.integers(1, 999)), 0.16, 4, 20),
                      blub(rng.uniform(2.2, 3.0), 0.25, int(rng.integers(1, 999)), rng)]), s0 - ERUPT)
    ts = T(2.6)
    put(tail, st(noise(len(ts), 0, seed=sd + 6) * lvl(np.minimum(1, ts / 0.3) * decay(ts, 1.1) * 0.06)), GONE - ERUPT)
    full = shot(m, [(start, 0), (hit, ERUPT), (body, ERUPT), (tail, ERUPT)])
    return leveled(m, full, {"start": start, "hit": hit, "body": body, "tail": tail},
                   "heave rumble + blubs quickening + 4 spurt sploshes (0-1.15), water burst (whomp + spray) at 1.15, column roar surging, "
                   "slumping 2.6-3.3, drops pattering back, collapse splatter ~3.2, sputters 3.45/3.85, steam", -22)


def wave_crash(m):
    """start (0 .. CRASH 1.2): the swell rolls in from x -80 (a low rush swelling with its height, inOutSine), wind
    tearing spray off its crest once it stands over 14 px (a hiss), the lip thrown forward from LIP0 0.62 (a curling
    rush brightening toward the crash), all panned with the crest; hit at CRASH: the lip slams down: a slap, the
    weight of a lot of water (a big low noise whomp opening into a wash, no falling tone), a burst of white water;
    body: the long foam wash surging on to the right and calming (1.1 s of foam boiling, noise only); tail:
    its burst drops and the spit plume (vh 220-300) splattering down where they land, lace fizzing out."""
    sd = seed_of(m)
    rng = np.random.default_rng(sd)
    CRASH, LIP0 = 1.2, 0.62

    def ease_ios(u):
        return 0.5 - 0.5 * np.cos(np.pi * np.clip(u, 0, 1))

    def crest_x(tt):
        return np.where(tt < CRASH, -80 + 72 * ease_ios(tt / CRASH),
                        -8 + 30 * (1 - (1 - np.clip((tt - CRASH) / 1.4, 0, 1)) ** 3))
    t = T(CRASH)
    hgt = 5 + 33 * ease_ios(t / (CRASH * 0.92))
    pans = np.array([pan_of(m, x) for x in crest_x(t[::441])])
    swell = noise(len(t), np.round(13 - 4 * t / CRASH).astype(int), seed=sd) * lvl(hgt / 38 * 0.22)
    spray = noise(len(t), 1, seed=sd + 1) * lvl(np.clip((hgt - 14) / 24, 0, 1) * 0.07)
    u = np.clip((t - LIP0) / (CRASH - LIP0), 0, 1)
    curl = noise(len(t), np.round(9 - 6 * u).astype(int), seed=sd + 2) * lvl(u ** 1.6 * 0.2)
    start = st_path(swell + spray + curl, pans)
    x0 = 8.0
    p0 = pan_of(m, x0)
    hit = st([crack(0.08, 2, 0.7, 35, sd + 3), wet_hit(1.0, sd * 7 + 389, 0.95 * rng.uniform(0.92, 1.08)), splat(0.5, sd + 4, 0.4, 3, 9)], p0)
    t = T(1.8)
    foam = noise(len(t), np.round(np.interp(t, [0, 1.8], [3, 7])).astype(int), seed=sd + 5) * lvl(
        np.minimum(1, t / 0.05) * decay(t, 1.8) * 0.5)
    foam += noise(len(t), 13, seed=sd + 7) * lvl(np.minimum(1, t / 0.05) * decay(t, 2.6) * 0.3)    # the surge's weight
    body = st_path(foam, [pan_of(m, x) for x in crest_x(CRASH + t[::441])])
    tail = blank(2.6)
    lands = []
    for _ in range(46):
        a, v = rng.uniform(-0.9, 0.6) * np.pi, rng.uniform(30, 120)
        r = wdrop(rng.uniform(2, 8), rng.uniform(120, 320), np.cos(a) * v * 0.85 + 18, x0)
        if r:
            lands.append((r[0] + rng.uniform(0, 0.1), r[1], r[2]))
    for _ in range(14):
        r = wdrop(rng.uniform(2, 6), rng.uniform(220, 300), rng.uniform(-15, 25), x0)
        if r:
            lands.append((r[0] + rng.uniform(0.04, 0.16), r[1], r[2] * 1.3))
    for at, x, v in lands:
        s = splat(0.16 * min(1, v / 300) * rng.uniform(0.6, 1), int(rng.integers(1, 999)), 0.05, int(rng.integers(1, 4)), 60)
        put(tail, st(s, pan_of(m, x)), at)
    tl = T(2.0)
    put(tail, st(noise(len(tl), 0, seed=sd + 6) * lvl(np.minimum(1, tl / 0.3) * decay(tl, 1.3) * 0.07), pan_of(m, 15)), 0.3)
    full = shot(m, [(start, 0), (hit, CRASH), (body, CRASH + 0.02), (tail, CRASH)])
    return leveled(m, full, {"start": start, "hit": hit, "body": body, "tail": tail},
                   "swell rushing in L->centre + crest spray hiss + lip curl rising (0-1.2), crash at 1.2 (slap, big "
                   "water whomp into a wash, white-water burst), foam surging right and calming, drops splattering, lace fizz", -21)


SOUNDS = {
    "bubbles": bubbles,
    "drip": drip,
    "fountain": fountain,
    "geyser": geyser,
    "rain-splash": rain_splash,
    "ripples": ripples,
    "splash": splash,
    "water-jet": water_jet,
    "water-orb": water_orb,
    "waterfall": waterfall,
    "wave-crash": wave_crash,
    "whirlpool": whirlpool,
}
