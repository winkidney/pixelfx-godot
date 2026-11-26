# pickups: an idle pickup (a coin spinning, a gem turning, a heart bobbing, a potion bubbling, a loot beam standing) is a
# steady thing with no noise of its own and stays silent (references/sound.md, rule 2): its sound is the moment it is
# collected, which is collect-burst (or the game's own one-shot). That moment may carry the genre's one exception to
# rule 1: two short notes, the coin "ding" (B5 -> E6), once, on the collect; never in a loop, never a longer tune.
# Everything else is material (rule 5): a chest is wood that knocks and creaks with an iron lock that clunks, coins clink
# on the floor, gems tink like glass; light is bright noise, never notes. Beats from src/fx/pickups/<name>.js, the loot's
# own physics and the original's own draws (JsRng) replayed so every landing sits on the frame it shows.
import numpy as np
from synth import *  # noqa: F401,F403
from cats.explosions import pan_x, burst, clink, wash
from cats.impacts import crack, clank, air, st, put, S, seed_of
from cats.arcane import JsRng, glitter, twinkles, TAU
from cats.ice import q, tinkle, leveled
from cats.projectiles import shot

FPS = 30


# ------------------------------------------------------------------ voices shared with cats/ui.py
def ding(vol=0.35, lo=NOTE(83), hi=NOTE(88), gap=0.07, secs=0.42, duty=0.25):
    """The genre's collect/confirm: two short notes (B5 cut short by E6, which rings and dies). Rule 1's only
    exception: use it once, on the moment something is collected or confirmed, never in a loop."""
    a = pulse(np.full(len(T(gap)), lo), duty) * steps(np.full(len(T(gap)), vol * 0.8))
    t = T(secs)
    return np.concatenate([a, pulse(np.full(len(t), hi), duty) * steps(decay(t, 7.5) * vol)])


def chirp(vol, seed, f0=2600.0):
    """One bit of loot snatched up: a short-mode tick with a 25 ms thin sweep up off it (a glide, its own random
    pitch each time, so a run of them is a shower and not a scale)."""
    t = T(0.03)
    s = pulse(f0 * (1 + 0.6 * t / 0.03), 0.125) * q(decay(t, 80)) * 0.5
    s[: int(0.02 * SR)] += noise(int(0.02 * SR), 0, True, seed) * q(decay(T(0.02), 140))
    return s * vol


def creak(secs, f0, f1, vol, seed):
    """Wood straining: a thin buzzing pulse sliding f0 -> f1 with stick-slip grain (its pitch and level jump every
    60 Hz frame), so it reads as a creak and not a tone."""
    rng = np.random.default_rng(seed)
    t = T(secs)
    u = np.clip(t / secs, 0, 1)
    nf = len(t) // (SR // 60) + 1
    jit = (1 + 0.09 * rng.standard_normal(nf)).repeat(SR // 60)[: len(t)]
    grain = rng.uniform(0.25, 1, nf).repeat(SR // 60)[: len(t)]
    f = f0 * (f1 / f0) ** u * jit
    return pulse(f, 0.125) * q(np.sin(np.pi * u) ** 0.5 * grain) * vol


def tickle(n, secs, vol, rng, short=True):
    """n tiny ticks at random over `secs` (mono): grit, sparks, a shower of glints."""
    out = np.zeros(int((secs + 0.05) * SR))
    for at in rng.uniform(0, secs, n):
        c = tick(vol * rng.uniform(0.4, 1), int(rng.integers(1, 99)), short)
        j = int(at * SR)
        out[j:j + len(c)] += c[: len(out) - j]
    return out


# ------------------------------------------------------------------ silent: idle pickups
IDLE = ("{}: an idle pickup, a steady thing with no noise of its own, stays silent (rule 2); its sound is the moment "
        "it is collected (collect-burst, or the game's own one-shot)")


def silent(what):
    return lambda m: Silent(IDLE.format(what))


# ------------------------------------------------------------------ chest open
def chest_open(m):
    """A banded chest rattles at RATTLES (0.1, 0.32, 0.5, 0.64, each harder: a wood knock, the iron straps rattling on
    the shake's swings, a creak; the two hard ones hop and land), strains (lid creeping, 0.66), and at T_OPEN 0.8 the
    iron lock clunks and the lid kicks open (a heavy wooden tok, no pitch-dropping thump: wood and iron carry the
    weight; the hinge creaking as it swings, a lighter tok at its overshoot), gold light bursting out; the 16 coins and gems (the original's own launch draws, its 30 fps physics:
    gravity 950, bounce 0.42 while over 110 px/s) clink and tink where they land; from T_COLLECT 2.55 they are snapped up
    outside in (one ding on the first, a chirp each); T_POOF 3.3 the chest dissolves into rising gold dust."""
    s = seed_of(m)
    o = m.get("options", {})
    rng = np.random.default_rng(s)
    T_OPEN, T_COLLECT, T_POOF = 0.8, 2.55, 3.3
    RATTLES = [(0.1, 0.4), (0.32, 0.62), (0.5, 0.8), (0.64, 1.0)]

    # anticipation: rattles that get harder, then the strain
    start = blank(T_OPEN + 0.1)
    for t0, sc in RATTLES:
        sd = int(rng.integers(1, 999))
        place(start, wood_hit(0.3 + 0.4 * sc, sd, 0.5 * sc), t0, rng.uniform(-0.1, 0.1))
        for j in range(1, 6):                       # the shake swings at sin(u * 90): the straps rattle on each swing
            u = j * np.pi / 90
            place(start, tick(0.3 * sc * (1 - u / 0.18), int(rng.integers(1, 999))), t0 + u, (-0.15, 0.15)[j % 2])
        place(start, creak(0.13, 150 * rng.uniform(0.9, 1.1), 115, 0.16 * sc, int(rng.integers(1, 999))), t0 + 0.01)
        if sc > 0.5:                                # it hops (u < 0.06) and lands
            place(start, wood_hit(0.5 + 0.3 * sc, int(rng.integers(1, 999)), 0.4 * sc), t0 + 0.06)
    place(start, creak(0.15, 150, 270, 0.26, s + 7), T_OPEN - 0.15)
    t = T(0.12)
    place(start, noise(len(t), 4, True, s + 8) * q(np.minimum(1, t / 0.1)) * 0.06, T_OPEN - 0.12)
    # the light leaking from the seam builds through the rattles (inner()): a faint shimmer swelling
    t = T(T_OPEN)
    inner = 0.1 + 0.45 * t / T_OPEN + 0.5 * np.clip((t - T_OPEN + 0.14) / 0.14, 0, 1)
    for t0, sc in RATTLES:
        inner += np.where(t > t0, 0.45 * sc * np.exp(-(t - t0) * 9), 0)
    place(start, glitter(T_OPEN, inner / inner.max(), 0, s + 9, 0.7) * 0.05, 0)

    # the lid kicks open: the iron lock clunks, the lid's heavy wood toks; the hinge creaks as it swings, the lid toks
    # again lighter at its overshoot (0.125 s)
    hit = blank(0.5)
    place(hit, S(clank(620, 0.45, 0.25, 16, s + 10), wood_hit(1.0, s + 11, 0.9), crack(0.03, 3, 0.5, 60, s + 12)), 0)
    place(hit, creak(0.12, 320, 170, 0.22, s + 13), 0.02)
    place(hit, wood_hit(0.6, s + 14, 0.35), 0.125)
    # gold light bursts out, rays fanning up
    body = blank(1.3)
    t = T(1.2)
    place(body, glitter(1.2, np.minimum(1, t / 0.04) * decay(t, 2.8), 0, s + 15, 0.6) * 0.16, 0)
    place(body, air(0.4, 6, 1, 0.2, s + 16), 0)
    for _ in range(7):                              # the 7 sparks of the burst winking out
        place(body, tick(0.12 * rng.uniform(0.5, 1), int(rng.integers(1, 999))), rng.uniform(0.12, 0.26), rng.uniform(-0.4, 0.4))

    # the loot: the original's own draws, in its order
    R = JsRng(s)
    for _ in range(9 * 6):                          # the 9 rays
        R.next()
    loot = []
    n = int(o.get("coins", 12))
    for i in range(n + 4):
        sg = 1 if i % 2 else -1
        a = sg * R.range(0.1, 0.5)
        sp = R.range(190, 270)
        x = R.range(-7, 7)
        t0 = T_OPEN + 0.03 + R.range(0, 0.2)
        for _ in range(5):                          # ax, spin, sign, vs, ph
            R.next()
        loot.append(dict(gem=i >= n, x=x, y=-12.0, vx=np.sin(a) * sp, vy=-np.cos(a) * sp, t0=t0, r=2.6 if i >= n else 3.0,
                         rest=False, gone=False))
    for k, it in enumerate(sorted(loot, key=lambda it: -abs(it["vx"]))):
        it["pop"] = T_COLLECT + k * 0.04 + R.range(0, 0.02)
    tail = blank(T_COLLECT - T_OPEN + 0.3)
    coll = blank(1.3)
    dt, tt, first = 1 / FPS, 0.0, None
    while tt < m["duration"]:
        tt += dt
        for it in loot:
            if it["gone"] or tt < it["t0"]:
                continue
            if tt >= it["pop"] + 0.13:                # snapped up: a chirp each, the ding on the first
                it["gone"] = True
                first = first if first is not None else tt
                place(coll, chirp(0.3, int(rng.integers(1, 999)), rng.uniform(2300, 3600)), tt - T_COLLECT, pan_x(m, it["x"]))
                continue
            if it["rest"]:
                it["vx"] -= it["vx"] * 9 * dt
                it["x"] = float(np.clip(it["x"] + it["vx"] * dt, -74, 74))
                continue
            it["vy"] += 950 * dt
            it["x"] += it["vx"] * dt
            if abs(it["x"]) > 74:
                it["x"], it["vx"] = np.sign(it["x"]) * 74, it["vx"] * -0.3
            it["y"] += it["vy"] * dt
            if it["y"] + it["r"] >= -0.5 and it["vy"] > 0:
                v = it["vy"]
                it["y"] = -0.5 - it["r"]
                a = min(1.0, v / 380)
                if v > 50:
                    sd = int(rng.integers(1, 999))
                    c = tinkle(0.55 * a, sd, rng.uniform(3300, 4500)) if it["gem"] else clink(rng.uniform(2300, 3400), 0.3 * a, sd)
                    place(tail, c, tt - T_OPEN, pan_x(m, it["x"]))
                if v > 110:
                    it["vy"], it["vx"] = -v * 0.42, it["vx"] * 0.5
                else:
                    it["rest"], it["vy"] = True, 0.0
    place(coll, ding(0.3), first - T_COLLECT, 0.0)

    # the empty chest dissolves into rising gold dust
    poof = blank(1.0)
    t = T(0.9)
    place(poof, air(0.9, 9, 2, 0.16, s + 17), 0)
    place(poof, glitter(0.9, np.minimum(1, t / 0.05) * decay(t, 3.5), 1, s + 18, 0.6) * 0.07, 0)

    full = shot(m, [(start, 0), (hit, T_OPEN), (body, T_OPEN), (tail, T_OPEN), (coll, T_COLLECT), (poof, T_POOF)])
    return leveled(m, full, {"start": start, "hit": hit, "body": body, "tail": tail, "collect": coll, "poof": poof},
                   "wood toks + strap rattles + creaks at the 4 rattles (0.1-0.64), strain creak, iron lock clunk and "
                   "lid kicked open at 0.8 (heavy wood tok, hinge creak, lighter tok), gold light burst; coins clink / gems tink where they land "
                   "(own physics); collect from 2.55: one B5-E6 ding + a chirp per item; dust poof at 3.3", -24)


# ------------------------------------------------------------------ collect burst
def collect_burst(m):
    """The moment of pickup (t 0): the two-note ding with a bright crack under the white flash, the thin ring snapping
    out (a quick bright wash, 0.32 s); the 14 twinkles (the original's own draws and 30 fps paths) wink out over the
    last 30 % of their lives as tiny glints, panned where each is."""
    s = seed_of(m)
    rng = np.random.default_rng(s)
    hit = blank(0.6)
    place(hit, ding(0.42), 0)
    place(hit, S(crack(0.03, 0, 0.45, 90, s, True), burst(0.16, 1, 0.22, 18, s + 1, True)), 0)
    place(hit, wash(0.32, 1, 4, 0.22, 0.01, 9, s + 2), 0.01)
    R = JsRng(s)
    stars = []
    for i in range(14):
        a = i / 14 * TAU + R.range(-0.2, 0.2)
        sp = R.range(145, 225) * (1.12 if i % 3 == 0 else 0.85)
        turn = (1 if i % 2 else -1) * R.range(2.5, 5)
        life = R.range(0.75, 1.15)
        if i % 3:
            R.next()
        stars.append(dict(x=0.0, y=-30.0, a=a, sp=sp, turn=turn, life=life, age=0.0, ph=R.range(0, TAU), on=True))
    tail = blank(1.4)
    dt, tt = 1 / FPS, 0.0
    while tt < 1.3:
        tt += dt
        for st_ in stars:
            if st_["age"] > st_["life"]:
                continue
            st_["age"] += dt
            st_["a"] += st_["turn"] * dt * max(0.0, 1 - st_["age"] * 1.5)
            st_["sp"] -= st_["sp"] * 4.3 * dt
            st_["x"] += np.cos(st_["a"]) * st_["sp"] * dt
            st_["y"] += np.sin(st_["a"]) * st_["sp"] * dt + 6 * st_["age"] * dt
            if st_["y"] > -2:
                st_["y"], st_["a"], st_["sp"] = -2, -abs(st_["a"]), st_["sp"] * 0.5
            k = 1 - st_["age"] / st_["life"]
            on = not (k < 0.3 and np.sin(st_["age"] * 40 + st_["ph"]) < 0)
            if k < 0.3 and on and not st_["on"]:     # a wink back on: a tiny glint
                place(tail, burst(0.012, 0, 0.16 * (0.4 + k), 170, int(rng.integers(1, 999)), True), tt, pan_x(m, st_["x"]))
            st_["on"] = on
    full = shot(m, [(hit, 0), (tail, 0)])
    return leveled(m, full, {"hit": hit, "tail": tail},
                   "collect (t 0): B5-E6 ding over a bright crack and the ring's quick wash; the twinkles' own "
                   "wink-outs as tiny panned glints (0.5-1.15)", -24)


SOUNDS = {
    "chest-open": chest_open,
    "coin-spin": silent("a coin turning and bobbing over its shadow"),
    "collect-burst": collect_burst,
    "crystal-shard": silent("a shard hovering and swaying, light pulsing through it, splinters orbiting"),
    "gem-spin": silent("a gem turning on its axis, facets flashing"),
    "heart-pickup": silent("a heart bobbing and beating its glow (a light pulse, not a heartbeat sound)"),
    "key-glint": silent("a key hovering, a glint running down it"),
    "loot-beam": silent("a dropped sword standing in its pillar of rarity light"),
    "potion": silent("a flask rocking, its brew bubbling idly"),
    "power-star": silent("a star rocking and swelling on its beat (a steady rhythm would be music, rule 1)"),
    "xp-orb": silent("an orb racing its figure-eight with a comet tail"),
}
