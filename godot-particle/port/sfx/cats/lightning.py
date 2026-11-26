# lightning: electricity is energy, so its voices are synthetic, but only as cracks, buzzes and rising noise, never
# notes (references/sound.md, rules 1 and 5). A strike is a crack (bright noise, a metallic sizzle) and, where it lands,
# the hit recipe; thunder is the body after it (a ripping start rolling down into rumble); an arc held on screen is a
# buzz whose loudness follows the effect's own flicker table frame by frame; a charge is crackle getting denser over
# noise and a glide that climb. Where a bolt lands, the weight is what it strikes (synth.material_hit, sound.md rule 2):
# energy (a zap gliding down, a noise whoomp), and the floor's dry knock and crunch where it splits stone; only the
# thunderclap's shock ring is a blast. Thunder keeps its slow falling roll as the shockwave after a strike, never a
# short thump under it. Steady things that make no noise of their own (a plasma lamp, an idling orb) are silent
# except their strong moments. Beats from src/fx/lightning/<name>.js and act.timing in port/meta.json.
import numpy as np
from synth import *  # noqa: F401,F403
from cats.impacts import seed_of, hits_of, windup_of, pan_of, st, put, crack, air, breath, fly, grit_lands, debris, \
    earth, mix as imix
from cats.projectiles import leveled, shot, lput, per_frame, ticks
from cats.ice import leveled as safe_leveled                     # the same, but never peaking over 0.95

FPS = 30


# ------------------------------------------------------------------ voices of electricity
def zap(vol=0.8, seed=1, secs=0.14, k=55):
    """The strike's crack: a white burst of noise (rate 0), about 40 ms, with a metallic short-mode sizzle under it."""
    t = T(secs)
    return noise(len(t), 0, seed=seed) * steps(decay(t, k) * vol) + \
        noise(len(t), 1, short=True, seed=seed + 1) * steps(decay(t, k * 0.4) * vol * 0.3)


def struck(material, weight, seed, vol, delay=0.01):
    """The weight of what a bolt strikes (synth.material_hit), just after its crack (mono)."""
    return np.concatenate([np.zeros(int(delay * SR)), material_hit(material, weight, seed, vol)])


def buzz(levels, vol=0.3, seed=1, f=118.0, rate=3, jitter=0.05):
    """An arc held on screen: a raspy buzz (noise over a thin low pulse) whose loudness is the arc's brightness, frame
    by frame (levels at 30 fps, the effect's own flicker table). The pulse's pitch jitters each frame, so it stays a
    buzz and never settles into a note."""
    rng = np.random.default_rng(seed)
    secs = len(levels) / FPS
    t = T(secs)
    env = per_frame(np.clip(levels, 0, 1.5), secs)
    jit = per_frame(1 + rng.uniform(-jitter, jitter, len(levels)), secs)
    s = pulse(f * jit, 0.125) * 0.4 + noise(len(t), rate, seed=seed) * 0.6
    return s * steps(env * vol)


def thunder(secs=2.0, vol=0.5, seed=1, k=1.3, rolls=4, rip=0.25):
    """Thunder as the body after a strike: a ripping start (noise sliding from mid rates down to the lowest), rolling
    on in a few irregular swells, a falling triangle under it."""
    rng = np.random.default_rng(seed)
    t = T(secs)
    roll = np.ones(len(t))
    for _ in range(rolls):
        c, w, h = rng.uniform(0.15, secs * 0.55), rng.uniform(0.08, 0.25), rng.uniform(0.3, 0.8)
        roll += h * np.exp(-((t - c) / w) ** 2)
    env = np.minimum(1, t / 0.02) * decay(t, k) * roll / roll.max() * vol
    rate = np.round(np.interp(t, [0, rip, rip * 3, secs], [6, 13, 15, 15])).astype(int)
    b = noise(len(t), rate, seed=seed) * steps(env)
    return b + tri(70 * decay(t, 0.7) + 38) * steps(decay(t, k * 0.8) * vol * 0.55)


def zip_in(secs, vol=0.3, seed=1, f0=500, f1=1800):
    """A bolt racing out (a leader, a leap): noise rising to a hiss and a thin glide up, cut at the landing."""
    t = T(secs)
    u = t / secs
    return noise(len(t), np.round(4 - 4 * u).astype(int), seed=seed) * steps((0.3 + 0.7 * u) * vol) + \
        pulse(f0 * (f1 / f0) ** u, 0.125) * steps((0.3 + 0.7 * u) * vol * 0.3)


def crackle(secs, rate, vol, seed, short=True):
    """Crackles at rate(t) per second (random, so never a rhythm), each as loud as vol(t): static, sparks, arcs."""
    rng = np.random.default_rng(seed)
    out = np.zeros(int(round(secs * SR)) + int(0.05 * SR))
    at = 0.0
    while True:
        at += rng.exponential(1 / max(1e-3, rate(at)))
        if at >= secs:
            break
        c = tick(vol(at) * rng.uniform(0.5, 1.0), int(rng.integers(1, 99)), short=short)
        j = int(at * SR)
        out[j:j + len(c)] += c[: len(out) - j]
    return out[: int(round(secs * SR))]


def spark_lands(m, x0, y0, n, rng, sp=(50, 190), spread=1.3, vol=0.08, t_max=None):
    """Sparks thrown up from (x0, y0) as the lightning lib's flight() moves them (g 0.45, drag 2.2, bounce 0.45):
    a faint glassy tick on each landing, panned with its x. Starts at t 0."""
    lands = []
    for _ in range(n):
        a = -np.pi / 2 + rng.uniform(-spread, spread)
        v = rng.uniform(*sp)
        life = rng.uniform(0.25, 0.6)
        lands += [l for l in fly(np.cos(a) * v, np.sin(a) * v, x0, y0, 0.45, 2.2, 0.45, life) if l[0] < life]
    if not lands:
        return blank(0.1)
    return debris(m, lands, vol, 0, short=True, vref=120, seed=int(rng.integers(1, 999)))


# ------------------------------------------------------------------ one-shots
def zap_hit(m):
    """The arc snaps in from the left in two frames (0-SNAP 0.05): a zip rising, panned in from x -66. At SNAP the
    hit: a white crack and energy's small weight (a zap gliding down, a noise whoomp). Body: the arc's buzz on its own flicker (strobing 1/0.7 frame by frame to
    0.2, then letting go by 0.32) and the overloaded knot crackling, thinning to 0.45. Tail: the jinking sparks as
    faint ticks scattered both ways."""
    sd = seed_of(m)
    rng = np.random.default_rng(sd)
    SNAP = 0.05
    p0, pl = pan_of(m, 0), pan_of(m, -66)
    start = st(zip_in(SNAP, 0.28, sd), (pl, p0))
    hit = st([zap(0.85, sd + 1), struck("energy", 0.3, sd + 501, 0.6)], p0)
    lv = []
    for f in range(2, 11):
        t = f / FPS
        lv.append((0.7 if f % 2 else 1) if t < 0.2 else max(0, 0.55 * (1 - (t - 0.2) / 0.12)))
    knot = crackle(0.4, lambda a: 80 - 100 * a, lambda a: 0.16 * (0.75 * (1 - a / 0.4) + 0.25), sd + 2)
    body = imix([(st(buzz(lv, 0.3, sd + 3), p0), 0), (st(knot, p0), 0)], 0)
    tail = blank(0.45)
    for i in range(12):
        put(tail, st(tick(rng.uniform(0.04, 0.09), int(rng.integers(1, 99))), float(np.clip(p0 + rng.uniform(-0.6, 0.6), -1, 1))),
            rng.uniform(0.02, 0.36))
    full = shot(m, [(start, 0), (hit, SNAP), (body, SNAP + 1 / FPS), (tail, SNAP)])
    return leveled(m, full, {"start": start, "hit": hit, "body": body, "tail": tail},
                   "zip in from the left (0-0.05), crack + energy at the snap (0.05), arc buzz strobing on its flicker "
                   "+ knot crackle to 0.45, jinking sparks tick", -23)


def chain_lightning(m):
    """start: the windup (0.46 s before t 0, quiet static gathering) running into the charge at the hand (0-0.12,
    crackle getting denser). Three leaps (0.12 + 0.075 i, 0.05 s each): a zip panned node to node; each landing
    (on(i) 0.17 / 0.245 / 0.32, the frames where the link reaches its target) a crack and energy's weight, each its own
    take, the third the hardest. Each
    link then hums: a buzz on the JS's level(i, t) (hard flash, restless hum, stuttering out from 0.78 + 0.05 i),
    panned on its target, starting after that hit's freeze. Each target pops when its link gives out (0.94 / 0.99 /
    1.04); the floor spits faint crackles under each target while it holds."""
    sd = seed_of(m)
    rng = np.random.default_rng(sd)
    WIND, LEAP, GAP, HOLD, BREAK = 0.12, 0.05, 0.075, 0.78, 0.16
    HAND, HOPS = 10, [58, 104, 150]
    fz = [f for _, f in hits_of(m)][:3] or [0.03, 0.03, 0.07]
    w = windup_of(m, 0.46)
    on = lambda i: WIND + i * GAP + LEAP
    off = lambda i: HOLD + i * 0.05

    def level(i, t):
        a = t - on(i)
        if a < 0:
            return 0.0
        hum = ([1, 0.55, 1][int(a * 30)] if a < 0.1 else 0.78 + 0.22 * np.sin(t * 61 + i) * np.sin(t * 23 + i * 2))
        b = t - off(i)
        return hum if b < 0 else hum * (1 - b / BREAK) * (0.5 if int(b * 60) % 3 == 1 else 1) if b < BREAK else 0.0

    gather = charge(WIND, 9, 2, 500, 1200, 0.3, sd)
    start = st(np.concatenate([charge(w, 13, 6, 140, 420, 0.12, sd + 1, crackle=False), gather]), pan_of(m, HAND))
    pts = [HAND] + HOPS
    parts, tagged = [(st(gather, pan_of(m, HAND)), 0)], []
    for i, x in enumerate(HOPS):
        lp = st(zip_in(LEAP, 0.22, sd + 10 + i), (pan_of(m, pts[i]), pan_of(m, x)))
        h = st([zap((0.7, 0.72, 0.9)[i], sd + 20 + i), struck("energy", (0.15, 0.2, 0.3)[i] * rng.uniform(0.85, 1.15),
                                                             sd + 510 + i, (0.5, 0.5, 0.65)[i])], pan_of(m, x))
        parts += [(lp, WIND + i * GAP), (h, on(i))]
        tagged += [(lp, WIND + i * GAP, "hit"), (h, on(i), "hit")]
        t0 = on(i) + fz[i]
        frames = np.arange(t0, off(i) + BREAK, 1 / FPS)
        hum = st(buzz([level(i, t) for t in frames], 0.16, sd + 30 + i), pan_of(m, x))
        spit = crackle(off(i) - t0, lambda a: 7, lambda a: 0.07, sd + 40 + i)
        put(hum, st(spit, pan_of(m, x + rng.uniform(-5, 5))), 0)
        pop = st([zap(0.32, sd + 50 + i, 0.08, 70), ticks(5, 0.3, 0.05, sd + 60 + i)], pan_of(m, x))
        parts += [(hum, t0), (pop, off(i) + BREAK)]
        tagged += [(hum, t0, "body"), (pop, off(i) + BREAK, "body")]
    full = shot(m, parts)
    hits, body = blank(0.35), blank(1.0)
    for s, a, kind in tagged:
        put(hits if kind == "hit" else body, s, a - (WIND if kind == "hit" else on(0)))
    return leveled(m, full, {"start": start, "hit": hits, "body": body},
                   "windup static -> charge at the hand (0-0.12), 3 leaps landing as cracks (0.17/0.245/0.32), each "
                   "link's hum on its flicker after the freeze, pops as they give out (0.94-1.04)", -23)


def charge_up(m):
    """start: the windup (0.36 s), a quiet breath. charge 0-1.6 (REL): energy rushing in with no notes: noise climbing
    from rumble to hiss, a thin glide rising, the throb under it quickening as the JS's pulse does (1.5 -> 12.5 a
    second, a continuous change, not a beat), arcs whipping in as crackles more and more often (from k 0.2), a rasp
    as the core shakes (k > 0.85). The release at 1.6 (hit, freeze 0.14): the crack and energy's heavy weight (a zap
    gliding down, a noise whoomp; energy bursting from the hand, not an explosion);
    after the freeze, the 8 bolts buzz on their flicker (the floor ones zap the floor), the ring bursts out as a
    whoosh, thunder rolls, the charge bleeds off in crackles; sparks fall."""
    sd = seed_of(m)
    rng = np.random.default_rng(sd)
    REL = m["options"].get("charge", 1.6)
    (th, fz), = hits_of(m)[:1] or [(REL, 0.14)]
    CX, CY = 15, -21
    p = pan_of(m, CX)
    start = st(breath(windup_of(m, 0.36), 12, 8, 0.08, sd), p)
    t = T(REL)
    k = t / REL
    e = k * k
    swell = 0.12 + 0.88 * e
    ph = np.cumsum((1.5 + 11 * e) / SR)
    throb = 0.75 + 0.25 * np.sin(2 * np.pi * ph)
    sig = noise(len(t), np.round(13 - 11 * k).astype(int), seed=sd + 1) * steps(swell * throb) * 0.45          # full-scale steps, mixed down: the swell keeps its 16 levels
    sig += pulse(130 * (900 / 130) ** k, 0.125) * steps(swell) * 0.14
    sig += noise(len(t), 3, short=True, seed=sd + 2) * steps(np.clip((k - 0.85) / 0.15, 0, 1) * 0.12)
    sig += crackle(REL, lambda a: 0 if a < 0.2 * REL else 2 + 16 * (a / REL) ** 2,
                   lambda a: 0.1 + 0.2 * (a / REL) ** 2, sd + 3)
    chg = st(sig, p)
    hit = st([zap(1.0, sd + 4), struck("energy", 0.9 * rng.uniform(0.94, 1.04), sd + 521, 0.85)], p)
    BK = [1, 0.7, 0.95, 0.5, 0.8, 0.35]
    body = blank(1.6)
    for i in range(8):
        a = (i / 8) * 2 * np.pi + rng.uniform(-0.25, 0.25)
        L = rng.uniform(44, 72)
        x1, y1 = CX + np.cos(a) * L, min(0, CY + np.sin(a) * L)
        t0 = rng.uniform(0, 0.05)
        put(body, st(buzz(BK, 0.1, sd + 10 + i), pan_of(m, x1)), t0)
        if y1 > -1:
            put(body, st(zap(0.28, sd + 20 + i, 0.08, 70), pan_of(m, x1)), t0)
    put(body, st(air(0.45, 2, 9, 0.22, sd + 6), (p, p - 0.6)) + st(air(0.45, 2, 9, 0.22, sd + 7), (p, p + 0.6)), 0)
    put(body, st(thunder(1.4, 0.32, sd + 8, 1.8, 3), p), 0.03)
    put(body, st(crackle(0.35, lambda a: 25, lambda a: 0.14 * (1 - a / 0.35) + 0.03, sd + 9), p), 0.15)
    tail = spark_lands(m, CX, CY, 14, rng, (140, 330), np.pi, 0.07)
    full = shot(m, [(chg, 0), (hit, th), (body, th + fz), (tail, th + fz)])
    return leveled(m, full, {"start": start, "charge": chg, "hit": hit, "body": body, "tail": tail},
                   "charge 0-1.6 (noise + glide climbing, throb quickening, crackles denser), release crack + heavy energy "
                   "(1.6), bolts buzz + ring whoosh + thunder after the 0.14 freeze, sparks", -21)


def lightning_strike(m):
    """start 0-0.76: the sigil charges: static crackling off it from 0.15, denser as k = (t/0.76)^1.5 climbs, over a
    thin glide and noise rising; the stepped leader feels down from 0.48 in 9 steps (crackles getting louder and
    lower as it nears); the streamer climbs to meet it from 0.62. The strike at 0.76: the biggest crack, energy's
    weight and the floor splitting (stone and earth: a dry heavy knock, a gritty crunch, a short noise thud; no pitch
    drop), the channel buzzing on its flicker table. Two return strokes (1.04, 1.26; strength 0.8, 0.55), each after a
    dart zipping down 0.06 s before: a crack, a smaller energy weight and a stone knock. Arcs race out along the cracks
    left and right. Thunder rolls on as the body; grit from each stroke knocks down where it lands."""
    sd = seed_of(m)
    rng = np.random.default_rng(sd)
    S1, LEAD0, STEPS = 0.76, 0.48, 9
    STROKES = [(0.76, 1.0), (1.04, 0.8), (1.26, 0.55)]
    FLICK = [1, 0.72, 0.3, 0.95, 0.5, 0.8, 0.22]
    X0 = rng.uniform(8, 18) * rng.choice([-1, 1])
    p = pan_of(m, 0)
    t = T(S1)
    kk = np.clip(t / S1, 0, 1) ** 1.5
    sig = noise(len(t), np.round(13 - 9 * kk).astype(int), seed=sd) * steps(kk) * 0.16
    sig += pulse(150 * (700 / 150) ** kk, 0.125) * steps(kk) * 0.06
    stat = crackle(S1 - 0.15, lambda a: 30 * (1 + 4 * ((a + 0.15) / S1) ** 1.5),
                   lambda a: 0.05 + 0.12 * ((a + 0.15) / S1) ** 1.5, sd + 1)
    sig[int(0.15 * SR):int(0.15 * SR) + len(stat)] += stat
    start = st(np.concatenate([sig, np.zeros(int(0.1 * SR))]), p)
    for i in range(STEPS):                         # the leader's steps, closer and louder
        at = LEAD0 + (S1 - LEAD0) * (i + rng.uniform(0.1, 0.6)) / STEPS
        put(start, st(zap(0.08 + 0.2 * (i / STEPS) ** 1.5, sd + 10 + i, 0.06, 80), pan_of(m, X0 * (1 - i / STEPS))), at)
    put(start, st(crackle(S1 - 0.62, lambda a: 40, lambda a: 0.06 + 0.3 * a, sd + 20), p), 0.62)
    parts = [(start, 0)]
    floor = np.concatenate([np.zeros(int(0.03 * SR)), earth(0.8 * rng.uniform(0.92, 1.05), sd + 533, 0.75)])
    hit = st([zap(1.0, sd + 30, 0.2, 45), struck("energy", 0.85 * rng.uniform(0.94, 1.04), sd + 531, 0.55, 0.015), floor], p)
    parts.append((hit, S1))
    parts.append((st(buzz(FLICK, 0.3, sd + 32), p), S1 + 0.01))
    for j, (ts, k) in enumerate(STROKES[1:]):
        parts.append((st(zip_in(0.06, 0.12 * k, sd + 40 + j, 900, 300), (pan_of(m, X0), p)), ts - 0.06))
        parts.append((st([zap(0.85 * k, sd + 42 + j, 0.12, 50), struck("energy", 0.4 * k, sd + 540 + j, 0.6 * k),
                          struck("stone", 0.35 * k, sd + 545 + j, 0.4 * k, 0.015)], p), ts))
        parts.append((st(buzz([f * k for f in FLICK], 0.3, sd + 44 + j), p), ts + 0.01))
    for j, (ts, k) in enumerate(STROKES):          # arcs racing out along the cracks, both ways
        run = 0.35 if j == 0 else 0.22
        for s in (-1, 1):
            c = crackle(run + 0.05, lambda a: 70, lambda a: 0.14 * k * (1 - a / (run + 0.05)) + 0.02, sd + 50 + 2 * j + s)
            parts.append((st(c, (p, float(np.clip(p + s * 0.45, -1, 1)))), ts + 0.02))
    body = st(thunder(2.3, 0.55, sd + 60, 1.1, 5), p)
    put(body, st(thunder(1.4, 0.25, sd + 61, 1.8, 2), p), 1.04 - S1)
    parts.append((body, S1 + 0.03))
    tail = blank(2.0)
    for j, (ts, k) in enumerate(STROKES):
        lands = []
        for _ in range(int(round(18 * k * 0.5))):
            a = -np.pi / 2 + rng.uniform(-1.1, 1.1)
            v = rng.uniform(50, 190)
            lands += grit_lands(np.cos(a) * v, np.sin(a) * v, rng.uniform(-3, 3), -1, rng)
        put(tail, debris(m, lands, 0.16, 7, vref=200, seed=sd + 70 + j), ts - S1)
    put(tail, st(ticks(sorted(rng.uniform(0.75, 1.5, 5)), 1.6, 0.04, sd + 80), p), 0)
    parts.append((tail, S1))
    full = shot(m, parts)
    return safe_leveled(m, full, {"start": start, "hit": hit, "body": body, "tail": tail},
                        "sigil static + rising glide, leader stepping down (0.48-0.76), strike crack + energy + stone "
                        "floor split (0.76), return strokes (1.04, 1.26) each after a dart, arcs racing out, thunder, "
                        "grit", -20)


def thunderclap(m):
    """start: the windup (0.46 s), a quiet rising breath, then the sparks rushing in to the chest (0-0.12) as crackle
    getting denser. The clap at 0.12 (hit, freeze 0.13): hands clapping (a dull crack) and the strike's crack; its
    weight is the shock ring tearing out (the effect is a shockwave nova, so material "blast": the pitch-dropping
    thump, its own take). After the freeze: thunder (the body), the 8 bolts buzzing on their flicker (the 4 down ones
    zap the floor at their x), the shock ring running out left and right along the floor (0.12-0.62) as two rushes,
    hitting the target at 0.42 (a small zap and energy's small weight, panned right); small arcs crackle round the
    caster as the charge bleeds away (0.32-1.02); grit tossed by the ring knocks down."""
    sd = seed_of(m)
    rng = np.random.default_rng(sd)
    hs = hits_of(m)
    (th, fz) = hs[0] if hs else (0.12, 0.13)
    t2 = hs[1][0] if len(hs) > 1 else 0.42
    CY, REACH = -22, m["options"].get("reach", 104)
    p = pan_of(m, 0)
    gather = charge(th, 9, 2, 400, 1100, 0.3, sd)
    start = st(np.concatenate([breath(windup_of(m, 0.46), 12, 7, 0.1, sd + 1), gather]), p)
    hit = st([crack(0.035, 3, 0.8, 70, sd + 2), zap(0.9, sd + 3), material_hit("blast", 0.65, sd + 551, 0.9)], p)
    BK = [1, 0.7, 0.95, 0.5, 0.8, 0.3]
    body = blank(1.8)
    for i in range(8):
        down, side = i % 2 == 0, (-1 if i % 4 < 2 else 1)
        if down:
            a = rng.uniform(0.35, 0.75) if side > 0 else np.pi - rng.uniform(0.35, 0.75)
            x1 = np.cos(a) * (-CY / np.sin(a))
        else:
            a = -rng.uniform(0.15, 1.2) if side > 0 else np.pi + rng.uniform(0.15, 1.2)
            x1 = np.cos(a) * rng.uniform(40, 62)
        t0 = rng.uniform(0, 0.06)
        put(body, st(buzz(BK, 0.09, sd + 10 + i), pan_of(m, x1)), t0)
        if down:
            put(body, st(zap(0.3, sd + 20 + i, 0.08, 70), pan_of(m, x1)), t0)
    put(body, st(thunder(1.7, 0.5, sd + 30, 1.4, 4), p), 0.02)
    put(body, st(air(0.5, 5, 11, 0.22, sd + 31, "fall"), (p, -0.6)) + st(air(0.5, 5, 11, 0.22, sd + 32, "fall"), (p, 0.6)), 0)
    put(body, st(crackle(0.7, lambda a: 24, lambda a: 0.1 * (1 - a / 0.7) + 0.02, sd + 33), p), 0.2)
    shock = st([zap(0.42, sd + 40, 0.1, 60), struck("energy", 0.2, sd + 552, 0.45)], pan_of(m, REACH))
    lands = []
    for s in (-1, 1):
        for _ in range(10):
            a = rng.uniform(0, 0.5)
            x0 = s * (8 + (REACH - 8) * (1 - (1 - a / 0.5) ** 3))
            lands += [(a + tt, v, x) for tt, v, x in grit_lands(s * rng.uniform(10, 60), -rng.uniform(60, 180), x0, -1, rng)]
    tail = debris(m, sorted(lands), 0.14, 7, vref=200, seed=sd + 50)
    full = shot(m, [(st(gather, p), 0), (hit, th), (body, th + fz), (shock, t2 + fz), (tail, th + fz)])
    return leveled(m, full, {"start": start, "hit": hit, "body": body, "shock": shock, "tail": tail},
                   "breath + sparks rushing in, the clap's crack + shock-ring blast (0.12), thunder + bolt buzzes + floor ring "
                   "rushing out after the 0.13 freeze, the target zapped (0.42), crackles bleed off, grit", -20)


# ------------------------------------------------------------------ loops
def electrified(m):
    """A character with current running through him: the arcs crawling over him make noise of their own, so the loop
    is their crackling buzz, re-struck every other frame at a random strength (as the JS draws them), with the feet
    grounding out as crackles. The three jolts (frames 3, 22, 41; strength 1, 0.7, 0.9) are the loop's events: a
    crack, a buzz flaring and fading over its 3 frames, a spray of sparks; each its own take so they don't tick like
    a clock."""
    sd = seed_of(m)
    rng = np.random.default_rng(sd)
    P = m["duration"]
    JOLTS = [(3, 1.0), (22, 0.7), (41, 0.9)]
    nf = int(round(P * FPS))
    lv = []
    for f in range(nf + 2):
        j = next((k for f0, k in JOLTS if f0 <= f % nf < f0 + 3), 0)
        r = np.random.default_rng((sd, f >> 1)).uniform(0.6, 1)
        n = 2 + (2 if j else int(rng.integers(0, 2)))
        lv.append((0.75 if f & 1 else 0.95) * r * n / 3)
    env = per_frame(lv, P + X)
    t = T(P + X)
    sig = noise(len(t), 1, seed=sd) * steps(env * 0.2) + noise(len(t), 2, short=True, seed=sd + 1) * steps(env * 0.1)
    sig += pulse(118 * per_frame(1 + rng.uniform(-0.05, 0.05, nf + 2), P + X), 0.125) * steps(env * 0.1)
    loop = stereo(sig)
    lput(loop, st(crackle(P, lambda a: 30 * 0.4, lambda a: 0.25, sd + 2), 0), 0, P)
    jolts = []
    for i, (f0, k) in enumerate(JOLTS):
        jt = st([zap(1.0 * k, sd + 10 + i, 0.1, 60), buzz([k, 0.6 * k, 0.25 * k], 0.7, sd + 20 + i),
                 ticks(int(9 * k), 0.35, 0.22 * k, sd + 30 + i)], rng.uniform(-0.15, 0.15))
        lput(loop, jt, f0 / FPS, P)
        jolts.append(jt)
    loop = wrap(loop, P)
    return leveled(m, loop, {"loop": loop, "jolt": jolts[0]},
                   "crackling arc buzz re-struck every other frame + feet grounding out; jolts at 0.1/0.733/1.367 "
                   "(crack, buzz flare, sparks)", -28)


def spark_arc(m):
    """A Jacob's ladder. Struck at t 0: a crack at the foot, sparks off the roots. Climbing 0-1.42 (SNAP): the arc's
    buzz on its brightness frame by frame (1 - 0.22 u, sputtering past u 0.88), the buzz gliding up a little and its
    rasp thinning to hiss as the arc stretches. The snap at 1.42: a pop, sparks sprayed up. Quiet while the gap
    waits; from 1.84 little sparks jump the gap (70 % of frames) as tiny ticks: the anticipation before the loop
    strikes again. Molten drips (0.45, 0.8, 1.15) sizzle where they land."""
    sd = seed_of(m)
    rng = np.random.default_rng(sd)
    P, SNAP, H = m["duration"], 1.42, 58
    p = pan_of(m, 0)
    loop = blank(P + X)
    put(loop, st([zap(1.0, sd, 0.12, 50), ticks(6, 0.5, 0.15, sd + 1)], p), 0)
    nf = int(SNAP * FPS)
    lv = []
    for f in range(nf):
        u = f / nf
        k0 = 1 if f == 0 else 1 - 0.22 * u
        sput = 0.4 if u > 0.88 and rng.random() < 0.25 else 1
        lv.append(k0 * sput * (0.82 + 0.18 * rng.random()) * (0.8 + 0.2 * u))
    t = T(nf / FPS)
    u = t / (nf / FPS)
    env = per_frame(lv, nf / FPS)
    arc = pulse(112 * (1 + 0.3 * u) * per_frame(1 + rng.uniform(-0.04, 0.04, nf), nf / FPS), 0.125) * steps(env * 0.24)
    arc += noise(len(t), np.round(5 - 3 * u).astype(int), seed=sd + 2) * steps(env * 0.32)
    put(loop, st(arc, p), 0)
    put(loop, st([zap(0.85, sd + 3, 0.1, 60), struck("energy", 0.05, sd + 561, 0.45)], p), SNAP)
    put(loop, st(ticks(5, 0.45, 0.13, sd + 4), p), SNAP + 0.1)
    for i, tt in enumerate((0.45, 0.8, 1.15)):
        h = 1.5 + H * (tt / SNAP) ** 1.35
        for s in (-1, 1):
            for tl, v, x in fly(rng.uniform(-3, 3), rng.uniform(5, 30), s * (4.5 + h / 60 * 19.5), -9 - h, 0.45, 2.2, 0.0, 2.0):
                put(loop, st(tick(0.13, int(rng.integers(1, 99))), pan_of(m, x)), tt + tl)
    for f in range(int(round((P - 0.16) * FPS)), int(round(P * FPS))):
        if rng.random() < 0.7:
            put(loop, st(tick(rng.uniform(0.1, 0.2), int(rng.integers(1, 99))), p), f / FPS)
    full = np.zeros((int(round((P + X) * SR)), 2))
    lput(full, loop, 0, P)
    full = wrap(full, P)
    return leveled(m, full, {"loop": full}, "strike crack (t 0), climbing arc buzz rising + thinning to 1.42, snap pop, "
                   "quiet gap, tiny gap sparks from 1.84 lead into the next strike", -27)


def tesla_coil(m):
    """The coil hisses all the time (brush discharge off the rim, new streamers every frame): a faint hiss whose
    level shifts frame by frame. Volleys of arcs off the torus (frames 2, 20, 30, 38, 56, 66; a few each, staggered,
    3-7 frames long) buzz on the JS's flicker table FL, panned to their side; the two zaps to the floor (frames 14 and
    47, right then left) are cracks with energy's small weight and a longer buzz, their sparks ticking where they
    bounce."""
    sd = seed_of(m)
    rng = np.random.default_rng(sd)
    N = 72
    P = m["duration"]
    FL = [1, 0.7, 0.95, 0.55, 0.85, 0.45, 0.7, 0.35]
    t = T(P + X)
    hiss = noise(len(t), 1, seed=sd) * steps(per_frame(rng.uniform(0.35, 0.65, N + 2), P + X) * 0.2)
    loop = stereo(hiss)
    for v, n in ((2, 3), (20, 3), (30, 1), (38, 3), (56, 3), (66, 1)):
        for j in range(n + int(rng.integers(0, 2))):
            side = rng.choice([-1, 1])
            f0 = (v + j * int(rng.integers(2, 5))) % N
            ln = int(rng.integers(3, 8))
            lput(loop, st([zap(0.45, int(rng.integers(1, 999)), 0.06, 80), buzz(FL[:ln], 0.36, int(rng.integers(1, 999)))],
                          pan_of(m, side * rng.uniform(15, 35))), f0 / FPS, P)
    for f0, side in ((14, 1), (47, -1)):
        x = side * rng.uniform(38, 56)
        z = st([zap(1.0, sd + f0, 0.14, 50), struck("energy", 0.3 * rng.uniform(0.85, 1.15), sd + 570 + f0, 0.7),
                buzz([1, 0.75, 1, 0.6, 0.85, 0.4], 0.5, sd + f0 + 1)],
               pan_of(m, x))
        z = imix([(z, 0), (spark_lands(m, x, -1, 18, rng, vol=0.14), 0)], 0)
        lput(loop, z, f0 / FPS, P)
    loop = wrap(loop, P)
    return leveled(m, loop, {"loop": loop}, "steady discharge hiss; arc volleys buzz on their flicker (frames 2-66); "
                   "floor zaps at frames 14 (right) and 47 (left) with sparks", -26)


def ball_lightning(m):
    """The orb wandering round its path is an idle steady thing: silent (rule 2). Its strong moment is the zap: once
    a loop (frame 62), low over the floor, it strikes down: a crack, energy's small weight where it lands, a buzz on its
    4-frame
    flicker, sparks kicked up ticking where they bounce. The loop is that zap on its frame, silence around it."""
    sd = seed_of(m)
    rng = np.random.default_rng(sd)
    P, ZAP = m["duration"], 62
    a = ZAP / FPS / P * 2 * np.pi
    gx = 38 * np.sin(a) + 9 * np.sin(2 * a + 1) + rng.uniform(-10, 10)
    pz = pan_of(m, gx)
    z = st([zap(0.8, sd, 0.14, 50), struck("energy", 0.25, sd + 581, 0.45), buzz([1, 0.6, 0.9, 0.4], 0.28, sd + 1)], pz)
    z = imix([(z, 0), (spark_lands(m, gx, -1, 14, rng, vol=0.07), 0)], 0)
    loop = blank(P + X)
    lput(loop, z, ZAP / FPS, P)
    loop = wrap(loop, P)
    return leveled(m, loop, {"zap": z}, "silent orb; once a loop (2.067) the zap to the floor: crack, energy, buzz, sparks", -33)


def plasma_ball(m):
    return Silent("a plasma lamp glowing on its stand, tendrils wandering: a steady prop with no strong moment; "
                  "silent thing stays silent")


def storm_cloud(m):
    """Weather, heard everywhere: the loop is the rain's hiss and a low wind under it, steady, no accents. The strike
    (frame 52, 1.73) is the cloud's strong moment, a one-shot: the crack and energy's weight where it hits the floor,
    re-struck on its flicker (frames 3 and 5), a buzz, the thunder rolling on (wrapping into the loop's start). The flashes inside the billows (frames 7, 29-33,
    70-72) are soft distant grumbles, slow in, no crack."""
    sd = seed_of(m)
    rng = np.random.default_rng(sd)
    P = m["duration"]
    t = T(P + X)
    rain = noise(len(t), 1, seed=sd) * 0.085 + noise(len(t), 4, seed=sd + 1) * 0.045         # steady: set by mixer gain
    wind = noise(len(t), 15, seed=sd + 2) * steps(0.4 + 0.08 * np.sin(2 * np.pi * t / P)) * 0.19
    bed = wrap(stereo(rain + wind), P)
    full = np.zeros((int(round((P + X) * SR)), 2))
    BK = [1, 0.7, 0.3, 0.95, 0.5, 0.75, 0.2]
    bx1 = rng.uniform(-24, 24)
    pb = pan_of(m, bx1)
    strike = st([zap(0.9, sd + 3, 0.2, 45), struck("energy", 0.4, sd + 591, 0.55), buzz(BK, 0.25, sd + 4)], pb)
    strike = imix([(strike, 0), (st(zap(0.5, sd + 5, 0.1, 60), pb), 3 / FPS), (st(zap(0.35, sd + 6, 0.1, 60), pb), 5 / FPS),
                   (st(thunder(2.0, 0.5, sd + 7, 1.3, 4), pb * 0.5), 0.04), (spark_lands(m, bx1, -1, 16, rng, vol=0.06), 0)], 0)
    strike = strike * 1.33
    lput(full, strike, 52 / FPS, P)

    def grumble(k, seed):
        tg = T(1.2)
        env = np.minimum(1, tg / 0.15) * decay(tg, 2.5) * k * 0.3
        return noise(len(tg), np.where(tg < 0.3, 14, 15), seed=seed) * steps(env)
    flick = None
    for f0, k, x in ((7, 0.8, -40), (29, 1.0, 5), (70, 0.8, 0)):
        g = st(grumble(k, sd + f0), pan_of(m, x) * 0.6)
        lput(full, g, f0 / FPS + 0.05, P)
        flick = g if flick is None else flick
    full = wrap(full, P) + bed
    return leveled(m, full, {"loop": bed, "strike": strike, "flicker": flick},
                   "loop: rain hiss + low wind (no accents); strike one-shot at 1.73 (crack, re-strikes, thunder "
                   "wrapping round); soft grumbles under the in-cloud flashes", -29)


SOUNDS = {
    "ball-lightning": ball_lightning,
    "chain-lightning": chain_lightning,
    "charge-up": charge_up,
    "electrified": electrified,
    "lightning-strike": lightning_strike,
    "plasma-ball": plasma_ball,
    "spark-arc": spark_arc,
    "storm-cloud": storm_cloud,
    "tesla-coil": tesla_coil,
    "thunderclap": thunderclap,
    "zap-hit": zap_hit,
}
