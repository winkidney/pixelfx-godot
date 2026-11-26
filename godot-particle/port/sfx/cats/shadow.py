# shadow: dark magic is not a minor chord (references/sound.md, rule 1). Darkness gathering is noise climbing out of
# the rumble with a low glide under it, a hit's weight is what is struck (synth.material_hit, sound.md rule 2): shadow
# ink splashes and gulps like a heavy liquid (water's whomp, no tone), bone stamps, cracks and clacks like dry wood,
# spells and souls land as energy, a body struck is flesh, void shards knock like dark glass. Only the dark explosion's
# blast takes the pitch-dropping thump.
# Orbs, eclipses, flames and skulls that just hang there turning are silent (rule 2). Every event sits on the
# original's beats (src/fx/shadow/<name>.js), replaying its own draws (JsRng) where the times come from them.
import numpy as np
from synth import *  # noqa: F401,F403
from cats.explosions import pan_x, burst, fizz
from cats.impacts import crack, thump, rumble, knock, air, fly, st, put, S, hits_of, seed_of
from cats.water import wet_hit
from cats.fire import moving, loop_curve
from cats.arcane import JsRng, glitter, gather, pop, twinkles, struck, TAU
from cats.ice import q, iceknock, tinkle, crackles, landed, leveled
from cats.projectiles import shot, lput

G = 950.0


def js_rand(*ns):
    """The original's rand(...ns) (src/core/math.js hash / 2^32): a fixed random number per (seed, index, ...)."""
    h = 0x9E3779B9
    for n in ns:
        h = ((h ^ (int(n) & 0xFFFFFFFF)) * 0x85EBCA6B) & 0xFFFFFFFF
        h ^= h >> 13
        h = (h * 0xC2B2AE35) & 0xFFFFFFFF
        h ^= h >> 16
    return h / 4294967296


# ------------------------------------------------------------------ voices
def splash(power, seed):
    """Shadow ink breaking the surface: a wet burst going from bright to dull and the ink's own weight, a heavy liquid
    (water's noise whomp and spray, no falling tone) (mono)."""
    t = T(0.25)
    r = np.round(np.interp(t, [0, 0.25], [3, 10])).astype(int)
    s = noise(len(t), r, seed=seed) * q(np.minimum(1, t / 0.004) * decay(t, 16))
    return S(s, wet_hit(0.2 + 0.25 * min(1.0, power), seed + 1, 0.55)) * power


def gulp(vol, seed, secs=0.2, f0=70, f1=190):
    """Ink closing over something: a dull wet noise and a bubble gliding up (a liquid gulp, not a note) (mono)."""
    t = T(secs)
    s = noise(len(t), np.round(np.interp(t, [0, secs], [8, 12])).astype(int), seed=seed) * q(decay(t, 14)) * 0.55
    s += tri(f0 * (f1 / f0) ** (t / secs)) * q(np.sin(np.pi * t / secs)) * 0.6
    return s * vol


def slurp(secs, vol, seed):
    """Something dragged down under: a sucking rush falling in pitch, growing, cut as it goes under (mono)."""
    t = T(secs)
    u = t / secs
    return noise(len(t), np.round(5 + 7 * u).astype(int), seed=seed) * q(0.2 + 0.8 * u ** 1.5) * vol


def pats(buf, m, rng, x0, n, power, vol, y0=-1.0, at=0.0):
    """Drops of ink thrown up (shadow/_lib.js Drops: gravity 0.8, x drag 0.4) landing as soft wet pats where they land."""
    g = G * 0.8
    for _ in range(n):
        vx, vy = rng.uniform(-70, 70) * power, -rng.uniform(90, 220) * power
        tl = (-vy + np.sqrt(vy * vy - 2 * g * y0)) / g
        x = x0 + vx * (1 - np.exp(-0.4 * tl)) / 0.4
        t = T(0.03)
        c = noise(len(t), 5, seed=int(rng.integers(1, 999))) * q(decay(t, 120)) * vol * rng.uniform(0.5, 1)
        place(buf, c, at + tl, pan_x(m, x))


def clack(vol, seed, rng):
    """Bone on stone: a dry knock, a hollow wood-like 'tok' (bone, its own pitch) and a little click on top (mono)."""
    t = T(0.06)
    s = noise(len(t), 3, seed=seed) * q(decay(t, 85))
    s += pulse(np.full(len(t), rng.uniform(700, 1100)), 0.25) * q(decay(t, 110)) * 0.3
    return S(s, material_hit("wood", 0.15 * rng.random(), seed + 1, 0.35)) * vol


def snap(vol, seed):
    """A knuckle or a bone snapping: a very short dry crack and a small hollow bone 'tok' (wood-like) (mono)."""
    return S(crack(0.02, 2, 1.0, 160, seed), material_hit("wood", 0.05, seed + 1, 0.3)) * vol


# ------------------------------------------------------------------ silent: steady things with no noise of their own
def black_hole(m):
    return Silent("a disk turning round a black hole, debris spiralling in: a steady thing with no noise of its own "
                  "stays silent (rule 2); its two gulps a loop would be a steady rhythm (rule 1)")


def eclipse(m):
    return Silent("a black moon over a breathing corona: a steady glow in the sky, silent (rule 2)")


def necro_skulls(m):
    return Silent("skulls circling a cold flame on their orbit: an idle steady thing, silent (rule 2)")


def shadow_flames(m):
    return Silent("inside-out flames burning steadily on the floor: a steady fire is silent like a torch (rule 2)")


def void_orb(m):
    return Silent("a black orb hanging in the air, a vortex winding into it: an idle orb, silent (rule 2); its two "
                  "gulps a loop would be a steady rhythm (rule 1)")


# ------------------------------------------------------------------ soul drain (loop)
def soul_drain(m):
    """Loop (3.2 s): a drain being channelled, so it has events: each of the 4 souls (the original's own birth times
    (j + 0.15 + rand(j, 7) 0.5) D/4 and streamlines) is torn loose out on the right with an airy rip, dragged down its
    funnel line for 1.45 s as a whistling rush that speeds up (u = (age/1.45)^1.8: brighter and louder as it goes),
    panned along its path, and lands in the black crystal vessel (x 0) as a soft energy landing (a small zap and
    whoomp) and a glassy knock (the crystal), the vessel's flare a short sparkle. Under them a faint low draw of air down the funnel, swelling a
    little with no beat. The souls' times are irregular, so nothing repeats like a rhythm."""
    s = seed_of(m)
    rng = np.random.default_rng(s)
    D, SOULS, TRAVEL = m["duration"], 4, 1.45
    t = T(D + X)
    draw = noise(len(t), np.round(10 + loop_curve(t, D, 2, rng)).astype(int), seed=s) * q(0.8 + 0.2 * loop_curve(t, D, 1.5, rng)) * 0.05
    buf = blank(D + X)
    place(buf, draw, 0, pan_x(m, 50))
    for j in range(SOULS):
        born = (j + 0.15 + js_rand(j, 7) * 0.5) * (D / SOULS)
        i = int(js_rand(j, 8) * 11)
        sx, sy = 96 + js_rand(i, 1) * 64, -88 + js_rand(i, 2) * 72
        c1x, c2x = sx * 0.55, 22 + js_rand(i, 4) * 14
        tt = T(TRAVEL)
        u = (tt / TRAVEL) ** 1.8
        v = 1 - u
        x = v ** 3 * sx + 3 * v * v * u * c1x + 3 * v * u * u * c2x
        sp = np.gradient(u) * SR * TRAVEL / 1.8                 # 0 .. 1: how fast it's dragged
        rush = noise(len(tt), np.round(8 - 6 * sp).astype(int), seed=s + 10 + j) * q(0.15 + 0.85 * sp ** 1.4) * 0.16
        part = blank(TRAVEL + 0.5)
        moving(part, rush, 0, np.array([pan_x(m, xx) for xx in x]))
        put(part, st(air(0.2, 2, 7, 1.0, s + 20 + j, "fall") * 0.12, pan_x(m, sx)), 0)
        hit = S(material_hit("energy", 0.15 * rng.uniform(0.7, 1.3), s + 430 + j, 0.45), iceknock(0.3, s + 30 + j, rng.uniform(900, 1300), 0),
                glitter(0.25, decay(T(0.25), 12), 0, s + 40 + j, 0.7) * 0.12)
        put(part, st(hit, pan_x(m, 0)), TRAVEL)
        lput(buf, part, born, D)
    loop = wrap(buf, D)
    return leveled(m, loop, {"loop": loop},
                   "faint draw of air down the funnel; 4 souls at their own times: airy rip on the right, a whistling rush "
                   "speeding down the funnel (panned right->left), a soft energy landing + crystal knock as each lands", -30)


# ------------------------------------------------------------------ curse
def curse(m):
    """Wisps gather over the head (0 .. STAMP 0.55, motes at 40 -> 100 per s spiralling in): darkness gathering, noise
    climbing out of the rumble with a low glide under it, wisps ticking in. Hit at 0.55 (hit-stop 0.09): the skull
    stamps down: a bone stamp (crack, a dry knock, bone's hollow wood-like 'tok', no dropping thump). After the freeze
    the curse floods down the body (0.59 .. 0.97): a dark rush sinking in pitch. Its eyes burn: a lingering status,
    silent (rule 2). CRACK 1.72 .. BREAK 1.98: the bone cracks, dry crackles quickening while it shakes; BREAK: it snaps
    apart (crack, knock, a smaller bone tok, a puff as the eye fire goes out); 24 bone chunks clack down on their own
    flights (gravity 0.85, bounce 0.35) and the grit ticks after them."""
    s = seed_of(m)
    rng = np.random.default_rng(s)
    STAMP, CRACK, BREAK, SY = 0.55, 1.72, 1.98, -60
    (th, fz), = hits_of(m)
    start = gather(th, 0.24, s, 13, 4, 80, 300, 2.0, 12, rng, 0.4)
    hit = st([crack(0.045, 3, 0.8, 50, s + 1), knock(0.45, s + 2, 4, 0.07, 45),
              struck("wood", 0.75 * rng.uniform(0.9, 1.1), s + 441, 0.75, 0.025)], 0)
    t = T(0.6)
    flood = noise(len(t), np.round(3 + 9 * t / 0.6).astype(int), seed=s + 3) * q(np.minimum(1, t / 0.04) * (1 - t / 0.6) ** 1.5) * 0.3
    body = st(flood, 0)
    brk = blank(BREAK - CRACK)
    crackles(brk, rng, 0.0, BREAK - CRACK - 0.005, 12, 70, 0.1, 0.3, (-0.12, 0.12), short=False)
    t = T(BREAK - CRACK)
    u = t / (BREAK - CRACK)
    place(brk, noise(len(t), 10, True, s + 5) * q((0.2 + 0.8 * u) ** 2 * (0.6 + 0.4 * np.abs(np.sin(61 * t)))) * 0.08, 0)
    snp = st([crack(0.04, 2, 0.75, 60, s + 6), knock(0.4, s + 7, 3, 0.06, 55), struck("wood", 0.4, s + 442, 0.45, 0.006),
              air(0.35, 2, 7, 1.0, s + 8, "fall") * 0.14], 0)
    tail = blank(1.5)
    for _ in range(24):
        x, y = rng.uniform(-8.5, 8.5), rng.uniform(-9, 9) * 0.85
        lands = fly(x * rng.uniform(2.5, 6) + rng.uniform(-12, 12), rng.uniform(-70, 10), x, SY + y, 0.85, 0.4, 0.35,
                    rng.uniform(0.8, 1.2))
        for at, v, xx in lands:
            a = min(1.0, v / 330)
            if a > 0.2:
                place(tail, clack(0.18 * a, int(rng.integers(1, 999)), rng), at, pan_x(m, xx))
    for _ in range(10):
        lands = fly(rng.uniform(-32, 32), rng.uniform(-60, 20), rng.uniform(-7, 7), SY + rng.uniform(-8, 8), 1, 0, 0, 1.3)
        for at, v, xx in lands:
            place(tail, tick(1.0, int(rng.integers(1, 99)), False) * 0.06, at, pan_x(m, xx))
    full = shot(m, [(start, 0), (hit, th), (body, th + fz), (brk, CRACK + fz), (snp, BREAK + fz), (tail, BREAK + fz)])
    return leveled(m, full, {"start": start, "hit": hit, "body": body, "crack": brk, "break": snp, "tail": tail},
                   "dark gather over the head (0-0.55); bone stamp (crack, knock, bone tok) at 0.55; the curse flooding down "
                   "after the 0.09 hit-stop; silent burn; bone crackling faster (1.72-1.98), snapping apart, chunks "
                   "clacking down and grit", -23)


# ------------------------------------------------------------------ dark explosion
def dark_explosion(m):
    """The charge (0 .. REL 0.52): motes swirl in (90 -> 240 per s) and streaks shoot at the core: darkness gathering,
    noise climbing from rumble to hiss with a low glide rising, streak ticks denser; the core beats twice (0.26, 0.416):
    two dull low noise throbs (no falling tone: the thump is saved for the blast); it collapses to a white point at
    0.45: the rush cut dead. REL 0.52, the blast (an explosion, so material "blast"): a bright crack, a deep dropping
    thump with a sub under it, the shock rings rushing out both ways. The black sphere burns (.. BURN 1.62): a fire roar
    with the flicker of its flame tongues (0.88 + 0.12 sin 37t sin 23t) over the blast's rumble. BURN .. POP 1.84: it
    draws its flame back in (an inward rush climbing, cut); POP: the sphere collapses, a second, smaller crack with void
    energy's weight (a zap gliding down, a noise whoomp), not a second blast. The 34 void shards rain down on their own
    flights (gravity 0.75, drag 1.3/1.7, bounce 0.35) as dark glass knocks (big) and tinkles (fine); embers tick; the
    smoke rises silently."""
    s = seed_of(m)
    rng = np.random.default_rng(s)
    REL, BURN, POP, Y, RS = 0.52, 1.62, 1.84, -54, 16
    start = blank(REL)
    put(start, gather(REL - 0.07, 0.34, s, 13, 2, 70, 420, 2.2, 18, rng, 0.7), 0)
    for at, v in ((REL * 0.5, 0.4), (REL * 0.8, 0.55)):
        t = T(0.14)
        place(start, noise(len(t), np.where(t < 0.02, 11, 13), seed=s + 12 + int(at * 100)) * q(np.minimum(1, t / 0.008) * decay(t, 20)) * v, at - 0.01)
    t = T(0.07)
    place(start, noise(len(t), 12, seed=s + 14) * q(decay(t, 35)) * 0.35, REL - 0.075)
    hit = st([crack(0.06, 0, 0.95, 45, s + 1), thump(270 * rng.uniform(0.92, 1.08), 38, 0.8, 0.85, 5, 8),
              thump(120, 28, 1.0, 0.3, 3, 5), burst(0.4, 12, 0.35, 6, s + 2)], 0)
    put(hit, st(air(0.5, 1, 8, 1.0, s + 3, "fall") * 0.26, (-0.15, -0.8)) + st(air(0.5, 1, 8, 1.0, s + 4, "fall") * 0.26, (0.15, 0.8)), 0.02)
    L = BURN - REL
    t = T(L)
    flick = 0.88 + 0.12 * np.sin(t * 37) * np.sin(t * 23)
    rise = np.minimum(1, t / 0.15) * (1 - 0.25 * t / L)
    roar = noise(len(t), np.where(loop_curve(t, L, 3, rng) > 0.3, 11, 10), seed=s + 5) * q(flick * rise) * 0.24
    roar += noise(len(t), 4, seed=s + 6) * q(flick * rise) * 0.07
    body = st([rumble(1.6, 0.4, 14, 1.6, 60, 0.35, s + 7)], 0)
    put(body, st(roar, 0), 0)
    d = POP - BURN
    t = T(d)
    u = t / d
    coll = noise(len(t), np.round(12 - 10 * u ** 1.3).astype(int), seed=s + 8) * q(0.1 + 0.9 * u ** 2.5) * 0.3
    coll += pulse(120 * 5 ** u, 0.125) * q(u ** 2) * 0.06
    pop_ = st([crack(0.04, 0, 0.8, 60, s + 9), struck("energy", 0.5 * rng.uniform(0.9, 1.1), s + 451, 0.65),
               burst(0.3, 1, 0.12, 10, s + 11, short=True)], 0)
    tail = blank(3.4)
    for i in range(34):
        big = i < 20
        a = rng.uniform(0, TAU)
        sp = rng.uniform(80, 170) if big else rng.uniform(130, 220)
        x, y = np.cos(a) * RS * 0.7, Y + np.sin(a) * RS * 0.7
        lands = fly(np.cos(a) * sp, np.sin(a) * sp - rng.uniform(40, 110), x, min(y, -2), 0.75, 1.3 if big else 1.7, 0.35,
                    rng.uniform(1.6, 2.6))
        for at, v, xx in lands:
            k = min(1.0, v / 260)
            if k < 0.25:
                continue
            c = iceknock(0.2 * k, int(rng.integers(1, 999)), rng.uniform(700, 1100), 0.4) if big else \
                tinkle(0.12 * k, int(rng.integers(1, 999)), rng.uniform(1500, 2600))
            place(tail, c, at, pan_x(m, xx))
    for _ in range(14):
        place(tail, tick(1.0, int(rng.integers(1, 99))) * rng.uniform(0.03, 0.07), rng.uniform(0.6, 2.6), rng.uniform(-0.6, 0.6))
    full_coll = st(coll, 0)
    full = shot(m, [(start, 0), (hit, REL), (body, REL + 0.04), (full_coll, BURN), (pop_, POP), (tail, REL)])
    return leveled(m, full, {"start": start, "hit": hit, "body": body, "collapse": full_coll, "pop": pop_, "tail": tail},
                   "dark gather with two dull core beats, cut at 0.45; blast at 0.52 (crack, deep drop + sub, rings rushing "
                   "out L/R); the sphere's flame roar over the rumble to 1.62; flame drawn back in, void energy pop at 1.84; "
                   "void shards knocking/tinkling down, embers", -20)


# ------------------------------------------------------------------ the pool effects: grasping hands, shadow tendrils
def pool(secs_open, shut, seed):
    """A dark pool spreading open (a low wet swell) and later closing (a gulp, its bubble gliding up as a liquid's
    does, never a falling low tone): (open part, close part), stereo."""
    t = T(secs_open)
    u = t / secs_open
    o = noise(len(t), np.round(13 - 3 * u).astype(int), seed=seed) * q(np.sin(np.pi * np.clip(u * 0.8, 0, 1)) ** 1.2) * 0.14
    o += tri(45 + 30 * u) * q(np.sin(np.pi * u) ** 2) * 0.2
    c = S(gulp(0.4, seed + 1, 0.35, 60, 150), noise(len(T(0.45)), 12, seed=seed + 2) * q(np.sin(np.pi * T(0.45) / 0.45)) * 0.08)
    return st(o * 0.45, 0), st(c * 0.45, 0)


def grasping_hands(m):
    """The pool opens (0 .. OPEN 0.32): a low wet swell. Four shadow arms (the original's draws: x, rise t0 = 0.3 +
    [1,3,0,2] 0.06 + jitter) burst up out of it, each with a splash and an upward rush, the front two louder, 12 drops
    patting down round each; at t0 + 0.36 each hand clenches into a claw: a dry knuckle snap and a puff of dark
    breath. They strain silently. Each is dragged back under (td = 1.45 + [2,0,3,1] 0.09 + jitter, over 0.34 s): a
    sucking rush, then the ink closes over it (td + 0.28) with a gulp and a smaller splash. The pool shuts (2.35 ..
    2.8) with a last low gulp."""
    s = seed_of(m)
    rng = np.random.default_rng(s)
    J = JsRng(s)
    OPEN, SHUT = 0.32, 2.35
    LAY = [(-20, -2.5, 1), (17, -2.5, -1), (-30, 2.5, 1), (28, 2.5, -1)]
    arms = []
    for i, (x, y, toward) in enumerate(LAY):
        ax = x + J.range(-3, 3)
        J.range(44, 52) if y < 0 else J.range(36, 44)
        J.range(3.2, 3.8) if y < 0 else J.range(3.6, 4.2)
        lean = -toward * J.range(0.16, 0.3)
        J.range(0.35, 0.6), J.range(0.05, 0.15)
        t0 = 0.3 + [1, 3, 0, 2][i] * 0.06 + J.range(0, 0.03)
        td = 1.45 + [2, 0, 3, 1][i] * 0.09 + J.range(0, 0.05)
        J.range(0, TAU)
        arms.append((ax, y < 0, lean, t0, td))
    op, cl = pool(OPEN + 0.1, SHUT, s)
    rise = blank(1.0)
    for k, (ax, back, lean, t0, _) in enumerate(arms):
        g = 0.65 if back else 1.0
        p = pan_x(m, ax)
        place(rise, splash(0.55 * g, s + 10 + k), t0, p)
        place(rise, air(0.22, 7, 2, 1.0, s + 20 + k, "bell") * 0.22 * g, t0, p)
        pats(rise, m, rng, ax, 12, 1.0, 0.1 * g, -1.0, t0)
        hx = ax + np.sin(lean) * 40
        place(rise, snap(0.5 * g, s + 30 + k), t0 + 0.36, pan_x(m, hx))
        place(rise, air(0.3, 3, 8, 1.0, s + 40 + k, "fall") * 0.08 * g, t0 + 0.37, pan_x(m, hx))
    down = blank(1.2)
    T0 = min(a[4] for a in arms)
    for k, (ax, back, _, _, td) in enumerate(arms):
        g = 0.65 if back else 1.0
        p = pan_x(m, ax)
        place(down, slurp(0.28, 0.16 * g, s + 50 + k), td - T0, p)
        place(down, gulp(0.32 * g, s + 60 + k), td + 0.28 - T0, p)
        place(down, splash(0.3 * g, s + 70 + k), td + 0.28 - T0, p)
        pats(down, m, rng, ax, 8, 0.7, 0.07 * g, -1.0, td + 0.28 - T0)
    full = shot(m, [(op, 0), (rise, 0), (down, T0), (cl, SHUT)])
    return leveled(m, full, {"start": op, "rise": rise, "down": down, "close": cl},
                   "pool opening (0-0.32); four arms splashing up (0.3-0.5) on their own times with drops patting, each hand "
                   "snapping shut 0.36 s later; silent strain; each dragged under (1.45-1.8) with a sucking rush, a gulp "
                   "and a small splash; the pool shuts with a low gulp (2.35)", -23)


def shadow_tendrils(m):
    """The pool opens (0 .. OPEN 0.34): a low wet swell. Seven tentacles (the original's draws) lash up out of it at
    t0 = 0.3 + order 0.045 + jitter: each a splash and a quick lash of air, the back row dimmer, 12 drops patting down
    round each. They writhe silently; the ones that whip (45 %, at their own time) give a swish panned where they stand.
    Each sinks (t1 = 1.5 + last 0.1 + jitter, over 0.5 s): a sucking rush, and the ink closes over it at t1 + 0.4
    with a gulp and a smaller splash. The pool shuts (2.5 .. 2.95) with a last low gulp."""
    s = seed_of(m)
    rng = np.random.default_rng(s)
    J = JsRng(s)
    OPEN, SHUT, SINK = 0.34, 2.5, 0.5
    rows = [(-22, -2.5), (-8, -3), (7, -3), (21, -2.5), (-28, 2.5), (-1, 3), (27, 2.5)]
    order, last = [3, 0, 5, 2, 4, 1, 6], [1, 5, 0, 6, 3, 2, 4]
    tents = []
    for i, (x, y) in enumerate(rows):
        back = y < 0
        tx = x + J.range(-3, 3)
        J.range(46, 62) if back else J.range(32, 46)
        J.range(3.2, 4) if back else J.range(3.8, 4.6)
        J.range(-0.06, 0.06)
        J.chance(0.75)
        J.range(36, 50), J.range(4.5, 7), J.next(), J.range(0, TAU), J.range(0.06, 0.085), J.range(0.15, 0.32)
        t0 = 0.3 + order[i] * 0.045 + J.range(0, 0.03)
        t1 = 1.5 + last[i] * 0.1 + J.range(0, 0.05)
        whip = None
        if J.chance(0.45):
            wt = J.range(0.9, 1.5)
            wa = J.range(0.28, 0.45) * (-1 if J.next() < 0.5 else 1)
            whip = (wt, wa)
        tents.append((tx, back, t0, t1, whip))
    op, cl = pool(OPEN + 0.1, SHUT, s)
    rise = blank(1.0)
    for k, (tx, back, t0, _, _) in enumerate(tents):
        g = 0.6 if back else 1.0
        p = pan_x(m, tx)
        place(rise, splash(0.5 * g, s + 10 + k), t0, p)
        place(rise, air(0.16, 5, 0, 1.0, s + 20 + k, "bell") * 0.2 * g, t0 + 0.01, p)
        pats(rise, m, rng, tx, 12, 1.0, 0.08 * g, -1.0, t0)
    whips = blank(1.7)
    for k, (tx, back, _, _, whip) in enumerate(tents):
        if whip:
            wt, wa = whip
            p = pan_x(m, tx)
            place(whips, air(0.2, 4, 1, 1.0, s + 30 + k, "bell") * 0.17 * (0.6 if back else 1.0), wt - 0.1, p)
    T0 = min(t[3] for t in tents)
    down = blank(1.4)
    for k, (tx, back, _, t1, _) in enumerate(tents):
        g = 0.6 if back else 1.0
        p = pan_x(m, tx)
        place(down, slurp(0.38, 0.13 * g, s + 40 + k), t1 + 0.06 - T0, p)
        place(down, gulp(0.26 * g, s + 50 + k), t1 + SINK * 0.8 - T0, p)
        place(down, splash(0.22 * g, s + 60 + k), t1 + SINK * 0.8 - T0, p)
        pats(down, m, rng, tx, 6, 0.6, 0.06 * g, -1.0, t1 + SINK * 0.8 - T0)
    full = shot(m, [(op, 0), (rise, 0), (whips, 0), (down, T0), (cl, SHUT)])
    return leveled(m, full, {"start": op, "rise": rise, "whips": whips, "down": down, "close": cl},
                   "pool opening (0-0.34); 7 tentacles lashing up with splashes on their own times (0.3-0.6), drops patting; "
                   "swishes where they whip; each sinking with a sucking rush, gulp and small splash (1.5-2.2); pool "
                   "shuts with a low gulp (2.5)", -23)


# ------------------------------------------------------------------ hex sigil
def hex_sigil(m):
    """A burning pen traces the sigil (0.12 .. its end, on the original's stroke timing: the outer circle at 420 px/s,
    the star 700, the inner circle 550, the core 380, the diamond 300, a 0.04 s lift between strokes): a scratch of
    bright noise as loud as the pen is quick, panned with the pen, spitting sparks (70 a second). Power is drawn in
    while it is written and held (0.2 .. FLARE 2.6, streaks at 8 -> 22 a second): a dark charge, noise climbing and a low
    glide rising, swelling toward the flare. The 7 glyphs pop in (1.62 + 0.07 i, round the ring): small crackling
    pops where they sit, jittered (a ripple, not a beat). FLARE 2.6 (a spell flaring in the air, energy): crack, a zap
    gliding down and a noise whoomp, a ring rushing out, a sparkle;
    BREAK 2.74: it crumbles: a dry crunch of crackles, a soft puff of soot, and the burning fragments (gravity 0.22 ..
    0.45, bounce 0.25) patter down as cinders."""
    s = seed_of(m)
    rng = np.random.default_rng(s)
    CY, RO, RI, RC, GLYPH, FLARE, BREAK = -50, 28, 22, 6, 1.62, 2.6, 2.74

    def circle(r, a0):
        n = int(np.ceil(r * TAU))
        return [(np.cos(a0 + i / n * TAU) * r, CY + np.sin(a0 + i / n * TAU) * r) for i in range(n + 1)]

    star = [(np.cos(-np.pi / 2 + ((i * 3) % 7) * TAU / 7) * RI, CY + np.sin(-np.pi / 2 + ((i * 3) % 7) * TAU / 7) * RI) for i in range(8)]
    paths = [circle(RO, -np.pi / 2), star, circle(RI, -np.pi / 2), circle(RC, np.pi / 2),
             [(0, CY - 3.5), (2, CY), (0, CY + 3.5), (-2, CY), (0, CY - 3.5)]]
    speeds = [420, 700, 550, 380, 300]
    pts, lifts, t = [], [], 0.12
    for k, path in enumerate(paths):
        for (x0, y0), (x1, y1) in zip(path[:-1], path[1:]):
            L = np.hypot(x1 - x0, y1 - y0)
            pts.append((t, x0, y0, speeds[k]))
            t += L / speeds[k]
        lifts.append((t, t + 0.04))
        t += 0.04
    END = t
    pts.append((END, 0, CY, 0))
    a = np.array(pts)
    tt = T(END)
    on = np.interp(tt, a[:, 0], a[:, 3], left=0)
    gap = np.zeros(len(tt), bool)
    for l0, l1 in lifts:                                   # the pen lifted between strokes
        gap |= (tt >= l0) & (tt < l1)
    lvl = np.where((tt > 0.12) & ~gap, np.clip(on / 700, 0, 1), 0)
    pan = np.array([pan_x(m, xx) for xx in np.interp(tt, a[:, 0], a[:, 1])])
    scratch = noise(len(tt), 1, seed=s) * q(0.3 + 0.7 * lvl) * (lvl > 0) * 0.08
    scratch += fizz(END, 70, 0.11, s + 1, None, 0, 0.0) * (lvl > 0)
    pen = blank(END + 0.1)
    moving(pen, scratch, 0, pan)
    d = FLARE - 0.2
    t = T(d)
    u = np.clip((t - 0.0) / d, 0, 1)
    sm = u * u * (3 - 2 * u)
    chg = noise(len(t), np.round(13 - 9 * sm).astype(int), seed=s + 2) * q(0.05 + 0.95 * sm ** 2) * 0.17
    chg += pulse(70 * (5 ** sm), 0.125) * q(sm ** 2) * 0.05
    charge_ = stereo(chg)
    at = 0.0
    while True:
        at += rng.exponential(1 / (8 + 14 * np.interp(at, [0, d], [0, 1]) ** 2))
        if at >= d - 0.05:
            break
        ang = rng.uniform(0, TAU)
        place(charge_, tick(1.0, int(rng.integers(1, 99))) * (0.04 + 0.1 * at / d), at + 0.27, pan_x(m, 0.6 * np.cos(ang) * 30))
    glyphs = blank(0.7)
    for i in range(7):
        ang = -np.pi / 2 + i * TAU / 7 + np.pi / 7
        x = np.cos(ang) * (RO + RI) / 2
        place(glyphs, pop(0.32 * rng.uniform(0.7, 1), s + 10 + i, 700 * rng.uniform(0.85, 1.15), 160, 1, bool(i % 2)),
              i * 0.07 + rng.uniform(-0.015, 0.015) + 0.015, pan_x(m, x))
    flare = st([crack(0.05, 0, 0.85, 50, s + 3), struck("energy", 0.6 * rng.uniform(0.92, 1.05), s + 461, 0.65),
                glitter(0.4, decay(T(0.4), 8), 0, s + 4, 0.6) * 0.22], 0)
    put(flare, st(air(0.35, 1, 6, 1.0, s + 5, "fall") * 0.2, (-0.1, -0.6)) + st(air(0.35, 1, 6, 1.0, s + 6, "fall") * 0.2, (0.1, 0.6)), 0.01)
    brk = blank(1.6)
    crackles(brk, rng, 0.0, 0.3, 160, 25, 0.3, 0.08, (-0.35, 0.35), short=False)
    put(brk, st(air(0.6, 9, 12, 1.0, s + 7, "fall") * 0.12, 0), 0)
    for (pt, x, y, _) in pts[::8]:                            # every few pixels of the strokes drop a fragment
        lands = fly(rng.uniform(-8, 8), rng.uniform(-12, 6), x, y, rng.uniform(0.22, 0.45), 0.6, 0.25, rng.uniform(0.8, 1.2))
        for at, v, xx in lands:
            k = min(1.0, v / 160)
            if k > 0.2:
                place(brk, tick(1.0, int(rng.integers(1, 99)), False) * 0.1 * k, at, pan_x(m, xx))
    full = shot(m, [(pen, 0), (charge_, 0.2), (glyphs, GLYPH), (flare, FLARE), (brk, BREAK)])
    return leveled(m, full, {"pen": pen, "charge": charge_, "glyphs": glyphs, "hit": flare, "break": brk},
                   "burning pen scratching and spitting along its 5 strokes (0.12-%.2f), panned with it; a dark charge "
                   "swelling to the flare; 7 glyph pops (1.62-2.04); flare at 2.6 (crack, energy, ring out); crumble at 2.74, "
                   "cinders pattering" % END, -25)


# ------------------------------------------------------------------ life steal
def life_steal(m):
    """The act's hit at 0.01 (hit-stop 0.07): the target on the right (x 104) is struck: a crack and flesh's weight (a
    mid noise smack, a very short low push), 14 drops of blood spraying and patting down. After the freeze the 7 orbs (the original's draws) burst out and
    hover; each turns for home at its own time (0.36 + 0.05 i + jitter) and whips back to the caster (x 1) along its
    simulated flight: a rushing whoosh climbing as it speeds up, panned from the target to the caster, landing as a
    soft energy landing (a small zap and whoomp) with a small sparkle; the caster flushing as they land is a warm low swell. Hit 2 at 1.6 (the flush
    ends) is silent."""
    s = seed_of(m)
    rng = np.random.default_rng(s)
    J = JsRng(s)
    TX, TY, HX, HY, N = 104, -24, 1, -20, 7
    (h1, f1), _ = hits_of(m)
    orbs = []
    for i in range(N):
        a = -np.pi / 2 + (i - (N - 1) / 2) * 0.4 + J.range(-0.12, 0.12)
        sp = J.range(100, 170)
        home = 0.36 + i * 0.05 + J.range(0, 0.04)
        J.range(1.6, 2.4)
        orbs.append([TX, TY, np.cos(a) * sp + 10, np.sin(a) * sp, home])
    dt = 1 / 240
    paths = []
    for x, y, vx, vy, home in orbs:
        t, xs = 0.0, []
        while t < 2.2:
            t += dt
            if t < home:
                vx -= vx * 5 * dt
                vy -= vy * 5 * dt
            else:
                dx, dy = HX - x, HY - y
                d = np.hypot(dx, dy) or 1
                pull = 2600 * min(1, (t - home) * 3)
                vx += dx / d * pull * dt
                vy += dy / d * pull * dt
                vx -= vx * 2.2 * dt
                vy -= vy * 2.2 * dt
                if d < 6:
                    break
            x += vx * dt
            y += vy * dt
            xs.append((t, x, np.hypot(vx, vy)))
        paths.append((home, xs))
    pt, pc = pan_x(m, TX), pan_x(m, HX)
    hit = st([crack(0.03, 4, 0.75, 70, s), crack(0.015, 1, 0.3, 120, s + 1), struck("flesh", 0.55 * rng.uniform(0.9, 1.1), s + 471, 0.8, 0.02),
              burst(0.12, 6, 0.3, 30, s + 2)], pt)
    drops = blank(1.0)
    pats(drops, m, rng, TX, 14, 0.9, 0.08, TY)
    body = st(noise(len(T(0.3)), 7, seed=s + 3) * q(decay(T(0.3), 9)) * 0.12, pt)
    fly_ = blank(2.2)
    lands = []
    for k, (home, xs) in enumerate(paths):
        a = np.array([(t, x, v) for t, x, v in xs if t >= home])
        if not len(a):
            continue
        t0, t1 = a[0, 0], a[-1, 0]
        tt = T(t1 - t0)
        v = np.interp(tt + t0, a[:, 0], a[:, 2])
        k_ = np.clip(v / max(1, a[:, 2].max()), 0, 1)
        sig = noise(len(tt), np.round(9 - 8 * k_).astype(int), seed=s + 10 + k) * q(0.1 + 0.9 * k_ ** 1.5) * 0.16
        moving(fly_, sig, t0, np.array([pan_x(m, xx) for xx in np.interp(tt + t0, a[:, 0], a[:, 1])]))
        lands.append(t1)
        thud = S(material_hit("energy", 0.1 * rng.uniform(0.6, 1.4), s + 480 + k, 0.4), burst(0.08, 3, 0.25, 40, s + 20 + k))
        place(fly_, thud * rng.uniform(0.75, 1), t1, pc)
        tw = blank(0.5)
        twinkles(tw, rng, 2, (0.02, 0.25), 0.1, (pc - 0.1, pc + 0.15))
        put(fly_, tw, t1)
    if lands:
        t = T(0.9)
        put(fly_, st(noise(len(t), 11, seed=s + 30) * q(np.sin(np.pi * t / 0.9) ** 2) * 0.1, pc), min(lands) - 0.05)
    full = shot(m, [(hit, h1), (drops, h1 + f1), (body, h1 + f1), (fly_, f1)])
    return leveled(m, full, {"hit": hit, "body": body, "drops": drops, "drain": fly_},
                   "crack + flesh smack on the target at 0.01, blood drops patting; after the 0.07 hit-stop 7 orbs whip home "
                   "on their own times (~0.4-0.9) as whooshes panning target->caster, each a soft energy landing, a "
                   "warm swell as the caster flushes", -24)


SOUNDS = {
    "black-hole": black_hole,
    "curse": curse,
    "dark-explosion": dark_explosion,
    "eclipse": eclipse,
    "grasping-hands": grasping_hands,
    "hex-sigil": hex_sigil,
    "life-steal": life_steal,
    "necro-skulls": necro_skulls,
    "shadow-flames": shadow_flames,
    "shadow-tendrils": shadow_tendrils,
    "soul-drain": soul_drain,
    "void-orb": void_orb,
}
