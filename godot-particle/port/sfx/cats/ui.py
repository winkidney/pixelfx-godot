# ui: HUD pops, numbers and toasts. Never music (references/sound.md, rule 1): no jingles, no fanfares, no beeping
# countdown tune. A confirmation (a coin into the counter, an achievement medal, a quest sealed, a level reached) may
# carry the genre's one exception, two short notes (the B5 -> E6 ding), once, on that moment; a level-up or a quest
# complete is otherwise a bright burst, a rising glide and sparkle. Things that land or slam carry the hit recipe in
# small, with a UI pop for their weight (a crack, synth pop_hit's upward blip and puff; never the pitch-dropping
# thump, which is a blast's: sound.md rule 2); things that move are air (whooshes); material where there is one
# (rule 3): coins clink (metal), paper confetti rustles, a wax seal toks on the desk (wood), a cardboard popper pops,
# a heart breaks like glass. Steady glows,
# shines and draining timers are silent or a breath of glitter at most. Beats from src/fx/ui/<name>.js.
import numpy as np
from synth import *  # noqa: F401,F403
from cats.explosions import pan_x, burst, clink, wash
from cats.impacts import crack, rumble, knock, air, glide, st, put, S, seed_of
from cats.arcane import JsRng, glitter, sweep, gather, twinkles, TAU
from cats.ice import q, icecrack, crackles, leveled
from cats.fire import crackle
from cats.projectiles import shot, st_path
from cats.explosions import fizz
from cats.pickups import ding, tickle

FPS = 30


def frame_at(t):
    """The first rendered frame at or after t (the original's update runs once per 30 fps frame)."""
    return np.ceil(t * FPS - 1e-9) / FPS


def slam(vol, seed, weight=0.6, rate=1):
    """A UI slam (the hit recipe in small): a bright crack, the pop (an upward blip and a puff) and a short low noise
    knock for its push, with no pitch under it. weight 0..1 sets its size; the seed varies every one."""
    return S(crack(0.04, rate, vol, 60, seed), material_hit("pop", weight, seed + 1, vol),
             knock(vol * 0.5, seed + 2, 11, 0.06 + 0.08 * weight, 40))


def upop(vol, seed, weight=0.3, fizz=0.0):
    """A small UI pop (a word or a seal popping away): a crack and the pop's upward blip, an optional sparkle fizz."""
    parts = [crack(0.03, 0, vol, 80, seed), material_hit("pop", weight, seed + 1, vol)]
    return S(*parts, *([burst(0.3, 1, vol * fizz, 12, seed + 2, short=True)] if fizz else []))


def sparks(n, t_rng, vol, rng, pans, secs=None):
    """A spray of sparks winking out: n short-mode ticks at random in t_rng, panned in pans (stereo)."""
    buf = blank(secs or t_rng[1] + 0.1)
    for _ in range(n):
        place(buf, tick(vol * rng.uniform(0.4, 1), int(rng.integers(1, 999))), rng.uniform(*t_rng), rng.uniform(*pans))
    return buf


# ------------------------------------------------------------------ achievement
def achievement(m):
    """The toast slides in from the right on speed lines (0 .. IN 0.2, air, fast first) and settles (a soft knock);
    MEDAL 0.26 the gold medal pops on: the two-note confirm with a metal clink, its 12 stars bursting at 0.32;
    SHINE 0.95 a shine sweeps the toast left to right (a breath of glitter); OUT 1.98 it slides off right."""
    s = seed_of(m)
    rng = np.random.default_rng(s)
    IN, MEDAL, SHINE, OUT = 0.2, 0.26, 0.95, 1.92
    pm = pan_x(m, -48)
    start = st(air(IN, 3, 7, 0.45, s, "fall"), (0.35, 0.0))
    put(start, st(knock(0.18, s + 1, 7, 0.05, 60), 0.0), IN - 0.005)
    hit = blank(0.9)
    place(hit, ding(0.36), 0, pm)
    place(hit, clink(1750, 0.3, s + 2), 0, pm)
    t = T(0.45)
    place(hit, glitter(0.45, np.minimum(1, t / 0.02) * decay(t, 7), 0, s + 3, 0.6) * 0.12, 0.06, pm)
    twinkles(hit, rng, 12, (0.25, 0.5), 0.1, (pm - 0.3, pm + 0.3))
    t = T(0.36)
    body = st(glitter(0.36, np.sin(np.pi * t / 0.36), 0, s + 4, 0.5) * 0.05, (pan_x(m, -77), pan_x(m, 83)))
    rel = st(air(0.2, 7, 3, 0.4, s + 5, "rise"), (0.0, 0.5))
    full = shot(m, [(start, 0), (hit, MEDAL), (body, SHINE), (rel, OUT + 0.06)])
    return leveled(m, full, {"start": start, "hit": hit, "body": body, "release": rel},
                   "slide-in whoosh from the right (0-0.2) + settle knock; medal pops at 0.26: two-note confirm + "
                   "metal clink + star sparkle; faint shine sweep L->R at 0.95; slide-off whoosh at 1.98", -25)


# ------------------------------------------------------------------ coin collect
def coin_collect(m):
    """POP 0.3 the coin bursts: the collect ding over a spray of clinks (the coins thrown up) and the burst's sparks;
    the coins hang silent, then zip one by one into the HUD (FLY0 0.58 + i GAP 0.075, FLY 0.28), each landing on its
    own frame with a clink into the counter and the counter's tick (pitch and level its own, so the run is a
    clatter, not a beat); FOLD 2.0 the counter folds away."""
    s = seed_of(m)
    o = m.get("options", {})
    rng = np.random.default_rng(s)
    POP, FLY0, GAP, FLY, FOLD = 0.3, 0.58, 0.075, 0.28, 2.0
    p0, ph = pan_x(m, 0), pan_x(m, 62)
    hit = blank(0.8)
    place(hit, ding(0.34), 0, p0)
    place(hit, crack(0.03, 0, 0.35, 90, s, True), 0, p0)
    for _ in range(6):
        place(hit, clink(rng.uniform(2300, 3400), 0.22 * rng.uniform(0.5, 1), int(rng.integers(1, 999))),
              rng.uniform(0, 0.07), p0 + rng.uniform(-0.25, 0.25))
    put(hit, sparks(10, (0.12, 0.4), 0.1, rng, (p0 - 0.4, p0 + 0.4)), 0)
    n = int(np.clip(round(o.get("count", 10)), 1, 12))
    tail = blank(FOLD - FLY0)
    for i in range(n):
        at = frame_at(FLY0 + i * GAP + FLY) - FLY0
        a = rng.uniform(0.6, 1)
        place(tail, clink(rng.uniform(2500, 3700), 0.2 * a, int(rng.integers(1, 999))), at, ph)
        place(tail, tick(0.12 * a, int(rng.integers(1, 999))), at + 0.004, ph)
    rel = blank(0.3)
    place(rel, air(0.18, 3, 6, 0.12, s + 3, "fall"), 0, ph)
    place(rel, tick(0.1, s + 4, short=False), 0.17, ph)
    full = shot(m, [(hit, POP), (tail, FLY0), (rel, FOLD)])
    return leveled(m, full, {"hit": hit, "tail": tail, "release": rel},
                   "coin bursts at 0.3: collect ding + clink spray + sparks; each coin into the HUD on its own frame "
                   "(0.87-1.57): a clink + counter tick, panned right; fold-away puff at 2.0", -24)


# ------------------------------------------------------------------ combo counter
def combo_counter(m):
    """x5 COMBO rockets in from the left (0 .. HIT 0.1, a rising whoosh) and slams to a stop at HIT: crack, a big UI
    pop, the ring's wash, sparks; BEAT 0.5 it pulses once (a soft little pop); the timer bar drains silent; OUT 1.1 it
    whooshes out to the right with its motes."""
    s = seed_of(m)
    rng = np.random.default_rng(s)
    HIT, BEAT, OUT = 0.1, 0.5, 1.1
    start = st(air(HIT, 6, 1, 0.5, s, "rise"), (-0.45, -0.1))
    hit = blank(0.7)
    place(hit, slam(0.9, s + 1, 0.85), 0, -0.1)
    place(hit, wash(0.32, 2, 6, 0.22, 0.008, 7, s + 2), 0.01)
    put(hit, sparks(10, (0.06, 0.3), 0.1, rng, (-0.5, 0.4)), 0)
    beat = blank(0.2)
    place(beat, material_hit("pop", 0.2, s + 7, 0.4), 0)
    place(beat, glitter(0.08, decay(T(0.08), 30), 0, s + 3) * 0.05, 0)
    rel = st(air(0.22, 2, 6, 0.4, s + 4, "bell"), (0.0, 0.6))
    put(rel, sparks(6, (0.05, 0.16), 0.06, rng, (0.3, 0.7)), 0)
    full = shot(m, [(start, 0), (hit, HIT), (beat, BEAT), (rel, OUT)])
    return leveled(m, full, {"start": start, "hit": hit, "beat": beat, "release": rel},
                   "rising whoosh in from the left (0-0.1), slam at 0.1 (crack, UI pop, ring wash, sparks), "
                   "one soft pulse pop at 0.5, whoosh out right at 1.1", -23)


# ------------------------------------------------------------------ confetti
def _paper(rng, pp, n, ribbon):
    """The original's paper bits (or streamers) from popper pp, moved at 30 fps as confetti.js does: [(t, x)] while
    they flutter (once slower than 40 px/s) and when each lands."""
    a0, px, py, t0 = pp
    mx, my = px + np.cos(a0) * 11, py + np.sin(a0) * 11
    flut, lands = [], []
    for _ in range(n):
        an = a0 + rng.uniform(-0.25, 0.25) if ribbon else a0 + rng.uniform(-0.38, 0.38)
        sp = rng.uniform(220, 330) if ribbon else rng.uniform(200, 380)
        vx, vy, x, y = np.cos(an) * sp, np.sin(an) * sp, mx, my
        ph, amp, fw = rng.uniform(0, TAU), rng.uniform(6, 12) if ribbon else rng.uniform(5, 12), rng.uniform(1.5, 2.4) if ribbon else rng.uniform(2, 3.4)
        fall = rng.uniform(22, 32) if ribbon else rng.uniform(26, 40)
        drag, g, slow = (3.0, 120, 35) if ribbon else (3.4, 140, 40)
        mode, x0, t = 0, 0.0, t0
        while t < 3.4 and mode < 2:
            t += 1 / FPS
            if mode == 0:
                vx -= vx * drag / FPS
                vy -= vy * drag / FPS - g / FPS
                x += vx / FPS
                y += vy / FPS
                if np.hypot(vx, vy) < slow:
                    mode, x0 = 1, x - np.sin(ph) * amp
            else:
                ph += fw / FPS
                x0 += vx / FPS
                vx -= vx * 2 / FPS
                x = x0 + np.sin(ph) * amp
                y += fall * ((0.5 + 0.7 * abs(np.cos(ph))) if ribbon else (0.4 + 0.9 * abs(np.cos(ph)))) / FPS
                flut.append((t, x, abs(np.sin(ph))))
                if y >= -1:
                    mode = 2
                    lands.append((t, x))
    return flut, lands


def confetti(m):
    """Two party poppers bang, left at 0.1 and right at 0.26 (a cardboard pop: crack, the pop's blip, the paper's burst
    of rustle, a puff of smoke); the 92 bits and 8 streamers (confetti.js's own motion at 30 fps) stall and flutter down,
    a paper rustle as loud as how many are fluttering and panned where they are, fading as they settle; a few land
    with the faintest paper tick."""
    s = seed_of(m)
    rng = np.random.default_rng(s)
    D = m["duration"]
    POPPERS = [(-np.pi / 2 + 0.62, -74, -1, 0.1), (-np.pi / 2 - 0.62, 74, -1, 0.26)]
    hit = blank(0.8)
    flut, lands = [], []
    for k, pp in enumerate(POPPERS):
        p = pan_x(m, pp[1] * 0.9)
        b = S(crack(0.035, 1, 0.9, 60, s + k), material_hit("pop", 0.5, s + 12 + k, 0.7),
              wash(0.3, 2, 5, 0.32, 0.005, 9, s + 10 + k),
              wash(0.5, 10, 12, 0.1, 0.02, 4, s + 20 + k))
        place(hit, b, pp[3] - 0.1, p)
        f, l = _paper(rng, pp, 46, False)
        f2, l2 = _paper(rng, pp, 4, True)
        flut += f + f2
        lands += l + l2
    # the rustle: per 30 fps frame, how many bits flutter (and how hard: |sin ph| is the flip) and where on average
    nfr = int(D * FPS) + 1
    amt, xs = np.zeros(nfr), np.zeros(nfr)
    for t, x, w in flut:
        i = int(round(t * FPS))
        if i < nfr:
            amt[i] += 0.4 + 0.6 * w
            xs[i] += x * (0.4 + 0.6 * w)
    pan = np.array([pan_x(m, xs[i] / amt[i]) if amt[i] else 0.0 for i in range(nfr)])
    env = np.convolve((amt / max(amt.max(), 1)) ** 0.7, np.ones(3) / 3, "same")
    body_secs = D - 0.3
    t = T(body_secs)
    e = np.interp(t + 0.3, np.arange(nfr) / FPS, env)
    sig = glitter(body_secs, e, 3, s + 30, 0.85) * 0.11 + glitter(body_secs, e, 1, s + 31, 0.9, True) * 0.03
    body = st_path(sig, np.interp(np.linspace(0.3, D, 200), np.arange(nfr) / FPS, pan))
    tail = blank(D)
    for t_, x in lands:
        if rng.random() < 0.35:
            place(tail, tick(0.05 * rng.uniform(0.5, 1), int(rng.integers(1, 999)), short=False), t_, pan_x(m, x))
    full = shot(m, [(hit, 0.1), (body, 0.3), (tail, 0)])
    return leveled(m, full, {"hit": hit, "body": body, "tail": tail},
                   "cardboard popper bangs at 0.1 (left) and 0.26 (right) with a paper burst + smoke puff; paper "
                   "rustle following how many bits flutter and where (own motion), fading as they settle; faint "
                   "landing ticks", -24)


# ------------------------------------------------------------------ countdown
def countdown(m):
    """3, 2, 1 slam in every STEP 0.62 (0, 0.62, 1.24): each a slam (crack + UI pop, its own size and seed), the shock
    ring's wash and its ring of 14 sparks; the timer ring burns down like a fuse between slams (k 0.06 .. 0.97 of the
    step: a hiss with sparks at the original's 21 per second, panned with the burning head); GO 1.86: the ring blows
    into a shockwave (a bigger UI pop with a low noise push and the ring's rush of air, no pitch drop: it is a word on
    the HUD, not a blast; a rising glide, 36 sparks, stars twinkling); OUT 2.64 the word pops away. No beeps:
    the beat is the slams, the numbers are not notes."""
    s = seed_of(m)
    o = m.get("options", {})
    rng = np.random.default_rng(s)
    STEP, R_ = 0.62, 30
    n = int(np.clip(round(o.get("from", 3)), 1, 3))
    GO, OUT = n * STEP, n * STEP + 0.78
    parts, slams = [], []
    for i in range(n):
        b = blank(STEP + 0.4)
        place(b, slam(0.8, s + i, rng.uniform(0.55, 0.8)), 0)
        place(b, wash(0.3, 3, 7, 0.16, 0.005, 8, s + 10 + i), 0.005)
        put(b, sparks(14, (0.08, 0.3), 0.09, rng, (-0.45, 0.45)), 0)
        secs = (0.97 - 0.06) * STEP
        u = np.linspace(0, 1, 100)
        head = -np.pi / 2 + TAU * u
        put(b, st_path(fizz(secs, 21, 0.11, s + 20 + i, hiss=0.035), np.cos(head) * R_ / 76 * 0.8), 0.06 * STEP)
        parts.append((b, i * STEP))
        slams.append(b)
    go = blank(1.3)
    place(go, S(crack(0.05, 0, 1.0, 50, s + 30), material_hit("pop", 1.0, s + 32, 0.9),
                knock(0.5, s + 33, 12, 0.2, 18)), 0)
    place(go, wash(0.6, 1, 8, 0.4, 0.01, 4.5, s + 31), 0.01)
    t = T(0.25)
    place(go, sweep(500, 2400, 0.25, decay(t, 6)) * 0.09, 0.02)
    put(go, sparks(36, (0.1, 0.36), 0.1, rng, (-0.7, 0.7)), 0)
    twinkles(go, rng, 14, (0.4, 1.0), 0.07, (-0.5, 0.5))
    rel = blank(0.5)
    place(rel, upop(0.35, s + 40, 0.4, fizz=0.2), 0.05)
    twinkles(rel, rng, 10, (0.2, 0.4), 0.06, (-0.5, 0.5))
    full = shot(m, parts + [(go, GO), (rel, OUT)])
    return leveled(m, full, {"slam": slams[0], "go": go, "release": rel},
                   "slams at 0, 0.62, 1.24 (crack + UI pop + spark ring) with a fuse hiss burning round between "
                   "them (panned with the head); GO at 1.86: big pop + air rush + rising glide + sparks; pop away "
                   "at 2.69", -22)


# ------------------------------------------------------------------ crit number
def crit_number(m):
    """CRIT 128! slams in at t 0 over a starburst with a hard shake (0.32 s): a full small hit (crack, the biggest UI
    pop, a short noise rumble) and shards flung out; the CRIT tag stamps at 0.09 (a knock); embers crackle faintly
    while it holds; FOLD 0.92 the starburst snaps in (a short suck), TAGOUT 0.98 the tag pops off, POP 1.06 the number squashes
    and bursts into sparks at 1.11."""
    s = seed_of(m)
    rng = np.random.default_rng(s)
    FOLD, TAGOUT, POP = 0.92, 0.98, 1.06
    hit = blank(0.8)
    place(hit, S(crack(0.05, 0, 1.0, 45, s), material_hit("pop", 1.0, s + 9, 0.9),
                 rumble(0.6, 0.35, 13, 4.0, 60, 0, s + 1)), 0)
    place(hit, glitter(0.12, decay(T(0.12), 18), 0, s + 2) * 0.1, 0)
    put(hit, sparks(14, (0.03, 0.32), 0.12, rng, (-0.6, 0.6)), 0)
    place(hit, S(knock(0.5, s + 3, 7, 0.07, 50), crack(0.02, 2, 0.3, 90, s + 4)), 0.09, -0.1)
    body = blank(0.9)
    crackle(body, rng, 4, (0.03, 0.75), 0.07, (-0.4, 0.4))
    place(body, glitter(0.24, np.sin(np.pi * T(0.24) / 0.24), 0, s + 5, 0.5) * 0.035, 0.24)
    rel = blank(0.8)
    place(rel, air(0.12, 3, 0, 0.18, s + 6, "rise"), 0.0)
    place(rel, upop(0.25, s + 7, 0.2), TAGOUT - (FOLD - 0.12), -0.1)
    place(rel, upop(0.5, s + 8, 0.6, fizz=0.3), POP + 0.05 - (FOLD - 0.12))
    put(rel, sparks(10, (0.04, 0.3), 0.09, rng, (-0.6, 0.6)), POP + 0.05 - (FOLD - 0.12))
    full = shot(m, [(hit, 0), (body, 0.12), (rel, FOLD - 0.12)])
    return leveled(m, full, {"hit": hit, "body": body, "release": rel},
                   "slam at 0 (crack, big pop, short noise rumble, shard ticks) + tag stamp knock at 0.09; faint ember crackles "
                   "and shine; fold suck at 0.8-0.92, tag pop at 0.98, number bursts at 1.11", -21)


# ------------------------------------------------------------------ damage number
def damage_number(m):
    """A red -27 punches out of a hit spark at t 0 (a small punch: crack, a little pop, sparks); it arcs up and lands
    with a squash and a hop (its own 30 fps motion: vy -175, gravity 900, a 0.36 rebound): a soft knock and a tiny
    pop each, the hop quieter; it fades as it lifts away, silent."""
    s = seed_of(m)
    rng = np.random.default_rng(s)
    hit = blank(0.4)
    place(hit, S(crack(0.03, 0, 0.6, 80, s, True), material_hit("pop", 0.3, s + 5, 0.5)), 0, pan_x(m, 0))
    place(hit, wash(0.2, 1, 4, 0.12, 0.005, 14, s + 1), 0.005, pan_x(m, 0))
    put(hit, sparks(9, (0.05, 0.22), 0.08, rng, (-0.5, 0.3)), 0)
    tail = blank(m["duration"])
    x, y, vx, vy, hops, t = 0.0, -8.0, 34.0, -175.0, 0, 0.0
    while hops < 2 and t < 1.0:
        t += 1 / FPS
        vy += 900 / FPS
        vx -= vx * 2 / FPS
        x += vx / FPS
        y += vy / FPS
        if y >= -8 and vy > 0:
            a = 0.4 + 0.6 * min(1.0, vy / 300)
            land = S(knock(0.4 * a, s + 2 + hops, 8, 0.06, 50), material_hit("pop", 0.1, s + 6 + hops, 0.25 * a))
            place(tail, land, t, pan_x(m, x))
            hops += 1
            y, vy = -8.0, (-vy * 0.36 if hops < 2 else 0.0)
    full = shot(m, [(hit, 0), (tail, 0)])
    return leveled(m, full, {"hit": hit, "tail": tail},
                   "punch at 0 (crack + little pop + sparks); soft landing knock + tiny pop with a squash (~0.4) and a "
                   "quieter hop landing (~0.53); silent fade", -25)


# ------------------------------------------------------------------ exclamation
def exclamation(m):
    """The hero startles (pose snap at 0); at 0.04 a bold ! springs up off the head (a quick thin glide up, the burst of
    surprise ticks), squashes as the spring turns it round (a soft tick); the second flick of ticks at 0.48; POP 1.1 it
    squashes and pops away at 1.15. A glide, not a note: surprise, not a tune."""
    s = seed_of(m)
    rng = np.random.default_rng(s)
    POP = 1.1
    hit = blank(0.5)
    place(hit, glide(380, 1900, 0.08, 0.3, 0.125, 25, 3.0), 0)
    place(hit, crack(0.02, 0, 0.25, 100, s, True), 0)
    put(hit, sparks(4, (0.0, 0.08), 0.12, rng, (-0.4, 0.4)), 0)
    y, vy, t = -40.0, -420.0, 0.0
    while t < POP:
        t += 1 / FPS
        vy += (-(y + 45) * 900 - vy * 14) / FPS
        y += vy / FPS
        if vy > 0:
            break
    place(hit, knock(0.18, s + 1, 6, 0.04, 70), t - 0.04)
    body = blank(0.3)
    put(body, sparks(3, (0.0, 0.08), 0.07, rng, (-0.4, 0.4)), 0)
    rel = blank(0.4)
    place(rel, upop(0.3, s + 2, 0.2), 0.05)
    twinkles(rel, rng, 6, (0.15, 0.35), 0.05, (-0.4, 0.4))
    full = shot(m, [(hit, 0.04), (body, 0.48), (rel, POP)])
    return leveled(m, full, {"hit": hit, "body": body, "release": rel},
                   "spring-up at 0.04: quick thin glide up + surprise ticks, squash tick at the spring's turn; second "
                   "tick flick at 0.48; small pop away at 1.15", -26)


# ------------------------------------------------------------------ health bar hit
def health_bar_hit(m):
    """The bar opens (0 .. 0.14, a small click); HIT 0.2 it takes the blow: crack + UI pop, the lost chunk's
    chips spraying off where it sits (x from 45 % to 80 % of the bar); DRAIN 0.62 .. DRAINED 1.05 the ghost drains left
    behind a sparking edge (a fizz at the original's 15 sparks a second, panned with the edge, and a thin glide down
    following its inOutQuad); FOLD 1.62 it folds away."""
    s = seed_of(m)
    o = m.get("options", {})
    rng = np.random.default_rng(s)
    HIT, DRAIN, DRAINED, FOLD = 0.2, 0.62, 1.05, 1.62
    BX, BW = -48, 104
    fr, to = o.get("from", 0.8), o.get("to", 0.45)
    xa, xb = BX + BW * to, BX + BW * fr
    start = blank(0.2)
    place(start, tick(0.12, s, short=False), 0.06)
    hit = blank(0.5)
    place(hit, slam(0.8, s + 1, 0.6), 0, pan_x(m, (xa + xb) / 2))
    put(hit, sparks(10, (0.0, 0.25), 0.11, rng, (pan_x(m, xa), pan_x(m, xb))), 0)
    secs = DRAINED - DRAIN
    u = np.linspace(0, 1, 100)
    e = np.where(u < 0.5, 2 * u * u, 1 - (-2 * u + 2) ** 2 / 2)
    xs = xb - (xb - xa) * e
    body = st_path(fizz(secs, 15, 0.12, s + 2, hiss=0.04), [pan_x(m, v) for v in xs])
    t = T(secs)
    ut = t / secs
    sh = lambda k: np.where(k < 0.5, 2 * k * k, 1 - (-2 * k + 2) ** 2 / 2)
    put(body, st_path(sweep(950, 280, secs, np.sin(np.pi * ut), 0.125, sh) * 0.07, [pan_x(m, v) for v in xs]), 0)
    rel = blank(0.3)
    place(rel, air(0.18, 3, 6, 0.12, s + 3, "fall"), 0)
    place(rel, tick(0.08, s + 4, short=False), 0.16)
    full = shot(m, [(start, 0), (hit, HIT), (body, DRAIN), (rel, FOLD)])
    return leveled(m, full, {"start": start, "hit": hit, "body": body, "release": rel},
                   "open click; hit at 0.2 (crack + pop + chips); drain 0.62-1.05: sparking fizz + thin falling glide "
                   "panned with the edge; fold puff at 1.62", -24)


# ------------------------------------------------------------------ heart lost
def heart_lost(m):
    """HIT 0.14 the heart flashes and jolts (a small hit, a UI pop); CRACK 0.24 a crack runs down it (crackles racing,
    the heart trembling at sin(t * 90) as a faint rattle); SPLIT 0.5 it breaks in two like glass (a crisp crack and
    high tinks, no low weight; chips and dust), the halves tumble apart and puff out at 0.95, one each side."""
    s = seed_of(m)
    rng = np.random.default_rng(s)
    HIT, CRACK, SPLIT = 0.14, 0.24, 0.5
    hit = blank(0.5)
    place(hit, slam(0.75, s + 20, 0.5), 0)
    put(hit, sparks(8, (0.02, 0.2), 0.08, rng, (-0.5, 0.5)), 0)
    body = blank(SPLIT - CRACK + 0.05)
    crackles(body, rng, 0.0, 0.2, 70, 30, 0.13, 0.08, lambda u: 0.05 * np.sin(u * 9))
    t = T(SPLIT - CRACK)
    place(body, noise(len(t), 6, True, s + 1) * q(np.abs(np.sin((t + CRACK) * 90)) * (0.5 + t / (SPLIT - CRACK))) * 0.04, 0)
    rel = blank(0.9)
    place(rel, S(icecrack(0.7, s + 2), material_hit("glass", 0.4, s + 9, 0.5)), 0)
    place(rel, wash(0.4, 9, 11, 0.12, 0.01, 6, s + 3), 0.01)
    put(rel, sparks(12, (0.02, 0.4), 0.1, rng, (-0.6, 0.6)), 0)
    for k, sd in enumerate((-1, 1)):
        place(rel, upop(0.18, s + 4 + k, rng.uniform(0.1, 0.3)), 0.95 - SPLIT, sd * 0.6)
    twinkles(rel, rng, 6, (0.47, 0.75), 0.05, (-0.7, 0.7))
    full = shot(m, [(hit, HIT), (body, CRACK), (rel, SPLIT)])
    return leveled(m, full, {"hit": hit, "crack": body, "release": rel},
                   "hit at 0.14 (crack + pop + sparks); crack racing down with a trembling rattle 0.24-0.5; split at "
                   "0.5 like glass (crisp crack, tinks, chips, dust); the halves puff out L and R at 0.95", -24)


# ------------------------------------------------------------------ level up
def level_up(m):
    """Gold gathers at the feet (0 .. REL 0.28: noise climbing, a thin glide rising, streak ticks); REL 0.28 the act's
    hit (freeze 0.05): a bright crack on the frame, then after the freeze the pillar bursts up (a rising glide and a
    whoosh) and stands as light (a glitter dying away); RET 1.02 .. GONE 1.34 it lifts off and shoots away; the 8
    letters of LEVEL UP! drop and land one by one (their own 30 fps fall: a small knock each, panned along the word);
    LANDED 1.06 the two-note confirm; SHINE 1.24 a breath of glitter; EXIT 2.3 the letters pop away one by one."""
    s = seed_of(m)
    rng = np.random.default_rng(s)
    hits = m.get("act", {}).get("timing", {}).get("hits", [])
    REL = hits[0]["t"] if hits else 0.28
    FZ = hits[0]["freeze"] if hits else 0.05
    RET, GONE, DROP, STAG, LANDED, SHINE, EXIT = 1.02, 1.34, 0.5, 0.05, 1.06, 1.24, 2.3
    start = gather(REL, 0.2, s, 11, 2, 200, 800, 2.0, 10, rng, 0.4)
    hit = blank(0.3)
    place(hit, S(crack(0.04, 0, 0.9, 60, s + 1, True), burst(0.25, 1, 0.35, 12, s + 2, True)), 0)    # light, no weight
    body = blank(GONE - REL)
    t = T(0.5)
    place(body, sweep(350, 2200, 0.5, (1 - t / 0.5) ** 0.7, 0.125, lambda u: 1 - (1 - u) ** 3) * 0.16, 0)
    place(body, air(0.3, 6, 0, 0.35, s + 3, "fall"), 0)
    t = T(RET - REL - FZ)
    place(body, glitter(RET - REL - FZ, np.minimum(1, t / 0.05) * decay(t, 2.2), 1, s + 4, 0.6) * 0.1, 0)
    t = T(GONE - RET)
    place(body, air(GONE - RET, 5, 0, 0.25, s + 5, "rise"), RET - REL - FZ)
    place(body, sweep(900, 3000, GONE - RET, (t / (GONE - RET)) ** 1.5) * 0.05, RET - REL - FZ)
    tail = blank(m["duration"] - DROP + 0.5)
    for i in range(8):
        cx = -50 + i * 100 / 7
        off, v, t = -18.0, 60.0, DROP + i * STAG
        t = frame_at(t)
        while t < 2.0:
            t += 1 / FPS
            v += 1700 / FPS
            off += v / FPS
            if off >= 0 and v > 0:
                break
        place(tail, S(knock(0.3 * rng.uniform(0.7, 1), int(rng.integers(1, 999)), 6, 0.05, 60),
                      tick(0.1, int(rng.integers(1, 999)))), t - DROP, pan_x(m, cx))
    t = T(0.34)
    place(tail, glitter(0.34, np.sin(np.pi * t / 0.34), 0, s + 6, 0.5) * 0.05, SHINE - DROP)
    for i in range(8):
        cx = -50 + i * 100 / 7
        place(tail, S(burst(0.02, 0, 0.18, 120, int(rng.integers(1, 999)), True), tick(0.08, int(rng.integers(1, 999)))),
              frame_at(EXIT + i * 0.04 + 0.06) - DROP, pan_x(m, cx))
    conf = ding(0.3)
    full = shot(m, [(start, 0), (hit, REL), (body, REL + FZ), (tail, DROP), (stereo(conf), LANDED)])
    return leveled(m, full, {"start": start, "hit": hit, "body": body, "confirm": stereo(conf), "tail": tail},
                   "gold gather 0-0.28; bright crack at the hit (0.28), after the freeze the pillar bursts up: rising "
                   "glide + whoosh + dying glitter; lift-off whoosh 1.02-1.34; letters land (0.61-0.97) as small "
                   "knocks; two-note confirm at 1.06; letters pop away from 2.36", -23)


# ------------------------------------------------------------------ quest complete
def quest_complete(m):
    """The ribbon unrolls from the middle (0 .. OPEN 0.32, a rustle out to both sides, fast first); QUEST COMPLETE types
    on letter by letter (TYPE 0.2 + i STEP 0.036: faint ticks along the line); the gold seal drops (0.83) and stamps at
    STAMP 0.95 (a wooden tok on the desk, on the right) and its check ticks (a scratch with the two-note confirm, 1.03); POPSEAL 2.0
    the seal pops; ROLL 2.08 the ribbon rolls away into the middle."""
    s = seed_of(m)
    rng = np.random.default_rng(s)
    OPEN, TYPE, STEP, STAMP, POPSEAL, ROLL = 0.32, 0.2, 0.036, 0.95, 2.0, 2.08
    ps = pan_x(m, 64)
    start = blank(0.8)
    for sd in (-1, 1):
        put(start, st(air(OPEN, 3, 5, 0.18, s + (sd > 0), "fall"), (sd * 0.15, sd * 0.65)), 0)
    for i in range(13):
        place(start, tick(0.1 * rng.uniform(0.5, 1), int(rng.integers(1, 999)), rng.random() < 0.6),
              TYPE + i * STEP, -0.45 + 0.9 * i / 12)
    hit = blank(1.0)
    place(hit, air(0.12, 6, 3, 0.1, s + 2, "rise"), 0, ps)
    place(hit, S(wood_hit(0.8, s + 3, 0.7), knock(0.45, s + 4, 9, 0.08, 40), crack(0.025, 3, 0.35, 80, s + 5)), 0.12, ps)
    t = T(0.16)
    place(hit, noise(len(t), 1, True, s + 6) * q(np.sin(np.pi * t / 0.16)) * 0.05, 0.2, ps)
    place(hit, ding(0.3), 0.2, ps)
    rel = blank(0.6)
    place(rel, upop(0.3, s + 7, 0.3, fizz=0.2), 0.05, ps)
    twinkles(rel, rng, 8, (0.15, 0.35), 0.05, (ps - 0.3, ps + 0.2))
    for sd in (-1, 1):
        put(rel, st(air(0.26, 6, 3, 0.28, s + 8 + (sd > 0), "rise"), (sd * 0.65, sd * 0.1)), ROLL - POPSEAL)
    full = shot(m, [(start, 0), (hit, STAMP - 0.12), (rel, POPSEAL)])
    return leveled(m, full, {"start": start, "hit": hit, "release": rel},
                   "ribbon unroll rustle out to both sides (0-0.32) + faint typing ticks; seal drops and toks (wood) at 0.95 "
                   "(right), check scratch + two-note confirm at 1.03 (inside the at-most-two-notes rule); seal pop at "
                   "2.05, ribbon rolls away at 2.08", -24)


SOUNDS = {
    "achievement": achievement,
    "coin-collect": coin_collect,
    "combo-counter": combo_counter,
    "confetti": confetti,
    "countdown": countdown,
    "crit-number": crit_number,
    "damage-number": damage_number,
    "exclamation": exclamation,
    "health-bar-hit": health_bar_hit,
    "heart-lost": heart_lost,
    "level-up": level_up,
    "quest-complete": quest_complete,
}
