# holy: light shimmers, it does not play a chord (rule 1). Light is bright noise glittering frame by frame, rising is a
# thin glide or a noise climbing to hiss, a landing follows the hit recipe: a crack, then the weight of what is struck
# (synth.material_hit, sound.md rule 2): light landing is energy, a hammer of light on the floor is energy and stone.
# None of these is an explosion, so none uses the blast's pitch-dropping thump. Auras, halos and glows that just hang
# there are silent.
import numpy as np
from synth import *  # noqa: F401,F403
from cats.explosions import pan_x, burst, panned
from cats.impacts import crack, earth, air, fly, st, put, mix, out, debris, seed_of
from cats.fire import moving
from cats.arcane import JsRng, glitter, sweep, gather, pop, twinkles, env_at, struck, TAU


def spread_out(secs, r0, r1, vol, seed, p0=0.15, p1=0.85, shape="fall", centre=0.0):
    """Something rushing out to both sides along the floor (a ring of light, a gust): one voice per side, panned
    outward as it goes."""
    return st(air(secs, r0, r1, vol, seed, shape), (centre - p0, centre - p1)) + \
        st(air(secs, r0, r1, vol, seed + 1, shape), (centre + p0, centre + p1))


# ------------------------------------------------------------------ silent: glows that just hang there
def blessing(m):
    return Silent("a cone of light resting on the character, sparkles drifting through it: a status glow, silent "
                  "(rule 2)")


def divine_shield(m):
    return Silent("a bubble of light held round the character, turning: a status glow with no noise of its own, "
                  "silent (rule 2); a block on it is shield-block's hit")


def halo(m):
    return Silent("a halo hovering over the head: an idle glow, silent (rule 2)")


def sunburst(m):
    return Silent("a sun turning slowly, rays breathing: a steady glow, silent (rule 2)")


# ------------------------------------------------------------------ feather burst
def feather_burst(m):
    """The pop at t 0 (white flash, a ring of air): a soft 'poof', a puff of air with a light cartoon pop in it (synth
    pop_hit: a quick upward blip; feathers have no weight to thud), the ring of air rushing out both ways; the 20 feathers thrown out and braking hard (drag 3.4): a quick flurry of
    swishes over the first ~0.3 s. Then they rock and sink, which makes no sound (material: feathers): silence."""
    s = seed_of(m)
    rng = np.random.default_rng(s)
    p = pan_x(m, 0)
    t = T(0.45)
    puff = noise(len(t), np.round(np.interp(t, [0, 0.45], [3, 7])).astype(int), seed=s) * steps(
        np.minimum(1, t / 0.008) * decay(t, 9) * 0.6)
    hit = st([puff, struck("pop", 0.3, s + 301, 0.45, 0.005), crack(0.02, 2, 0.3, 90, s + 1)], p)
    put(hit, spread_out(0.25, 2, 6, 0.2, s + 2), 0.01)
    body = blank(0.6)
    for i in range(9):
        at = 0.02 + 0.3 * rng.random() ** 1.5
        sw = air(rng.uniform(0.06, 0.1), int(rng.integers(3, 6)), int(rng.integers(6, 9)), rng.uniform(0.08, 0.14) * (1 - at),
                 int(rng.integers(1, 99)))
        place(body, sw, at, p + rng.uniform(-0.7, 0.7))
    full = mix([(hit, 0), (body, 0)], m["duration"])
    return out(full, {"hit": hit, "body": body},
               "soft poof + light pop + ring of air out both ways at the pop (t 0), a flurry of feather swishes "
               "braking (0-0.3), then silence while they sink", 1.05)


# ------------------------------------------------------------------ heal
def heal(m):
    """Petals bloom round the feet (0.02 .. ~0.57, each on its own beat): bright noise fading in, a tiny sparkle as
    each opens; the hoop of light rises up the body (LIFT 0.16 .. 0.74, inOutSine): a thin glide climbing with a hiss
    swelling under it, sparkles left as it passes; at LIFT 0.74 it bursts over the head: a bright 'pssh' (no drop,
    nothing lands); the 16 motes riding the spiral pop into hearts and sparkles at their own ends (0.95 .. 1.5): tiny
    winks. The act's windup (0.3 s) is the character hurt and still: no sound."""
    s = seed_of(m)
    rng = np.random.default_rng(s)
    LIFT0, LIFT1, PR = 0.16, 0.74, 16
    p = pan_x(m, 0)
    rise = blank(LIFT1)
    t = T(LIFT1)
    put(rise, st(glitter(LIFT1, env_at(t, [(0, 0), (0.15, 0.1), (LIFT1, 0.1)]), 1, s, 0.7), p), 0)
    for k in range(8):
        at = 0.02 + ((k * 3) % 8) * 0.035 + rng.uniform(0, 0.01)
        place(rise, burst(0.015, 0, rng.uniform(0.1, 0.16), 150, s + 10 + k, short=True), at, p + 0.25 * np.cos(k / 8 * TAU + 0.2))
    d = LIFT1 - LIFT0
    t = T(d)
    u = t / d
    e = 0.5 - 0.5 * np.cos(np.pi * u)
    lift = sweep(330, 1250, d, (0.3 + 0.7 * u) * 0.07, shape=lambda v: 0.5 - 0.5 * np.cos(np.pi * v))
    lift += noise(len(t), np.round(3 - 3 * e).astype(int), seed=s + 1) * steps((0.2 + 0.8 * u ** 1.5) * 0.14)
    put(rise, st(lift, p), LIFT0)
    twinkles(rise, rng, 9, (LIFT0 + 0.03, LIFT1 - 0.02), 0.1, (p - 0.2, p + 0.2))
    hit = st([burst(0.3, 0, 0.32, 11, s + 2), glitter(0.3, decay(T(0.3), 9) * 0.22, 1, s + 3, 0.7, True)], p)
    tail = blank(1.0)
    ends = [0.2 + k * 0.05 + rng.uniform(0.75, 0.95) for k in range(8)] + \
        [LIFT1 + rng.uniform(0, 0.06) + rng.uniform(0.35, 0.6) for _ in range(8)]
    for i, at in enumerate(ends):
        place(tail, burst(0.014, 0, rng.uniform(0.08, 0.13), 170, s + 20 + i, short=True), at - LIFT1,
              p + rng.uniform(-0.3, 0.3))
    full = mix([(rise, 0), (hit, LIFT1), (tail, LIFT1)], m["duration"])
    return out(full, {"rise": rise, "hit": hit, "tail": tail},
               "petal sparkles + bright noise fading in (0-0.57), a glide + hiss climbing with the hoop (0.16-0.74), a "
               "bright pssh as it bursts over the head (0.74), motes winking out 0.95-1.5", 1.1)


# ------------------------------------------------------------------ heal aoe
def heal_aoe(m):
    """Streaks rush into a seed of light (0 .. SEED 0.3): a quiet gather; at SEED it sinks into the floor: energy's
    soft weight (a small zap, a noise whoomp) and a glitter of light; the ring rolls out over ROLL 1.0 s (outCubic to the reach): a soft rush spreading to
    both sides and dying as it slows; 26 plus signs sprout where and when the ring passes them (the original's own
    draws: t = passed(d)): each a tiny pop, panned where it grows, thinning out as the ring slows."""
    s = seed_of(m)
    rng = np.random.default_rng(s)
    SEED, ROLL, REACH = 0.3, 1.0, m["options"].get("reach", 104)
    J = JsRng(s)
    sites = []
    for i in range(26):
        a = J.range(0, TAU)
        d = REACH * np.sqrt(J.range(0.04, 0.92))
        t0 = SEED + ROLL * (1 - np.cbrt(1 - min(0.999, d / REACH))) + J.range(0, 0.06)
        J.range(18, 34), J.range(0.9, 1.3), J.range(0, TAU)
        sites.append((t0, np.cos(a) * d, i % 5 < 2))
    start = gather(SEED, 0.2, s, 9, 2, 250, 800, ticks=10, rng=rng, spread=0.4)
    hit = st([crack(0.04, 5, 0.4, 50, s + 1), struck("energy", 0.3, s + 311, 0.55),
              glitter(0.35, decay(T(0.35), 7) * 0.24, 0, s + 2, 0.6)], 0)
    t = T(1.1)
    fr = 1 - (1 - np.clip(t / ROLL, 0, 1)) ** 3
    roll = blank(1.1)
    for side in (-1, 1):
        w = noise(len(t), np.round(3 + 5 * fr).astype(int), seed=s + 3 + side) * steps(
            np.minimum(1, t / 0.04) * (1 - fr) ** 0.7 * 0.18)
        moving(roll, w, 0, np.array([pan_x(m, side * REACH * v) for v in fr[::64]]).repeat(64))
    sprouts = blank(1.3)
    for i, (t0, x, big) in enumerate(sorted(sites)):
        place(sprouts, pop(0.17 if big else 0.1, s + 10 + i, 900, 300, 1), t0 - SEED, pan_x(m, x))
    full = mix([(start, 0), (hit, SEED), (roll, SEED + 0.01), (sprouts, SEED)], m["duration"])
    return out(full, {"start": start, "hit": hit, "roll": roll, "tail": sprouts},
               "quiet gather (0-0.3), soft energy + glitter as the seed sinks (0.3), a rush rolling out both ways and "
               "slowing, 26 tiny pops where the plus signs sprout as the ring passes", 0.94)


# ------------------------------------------------------------------ holy pillar
def holy_pillar(m):
    """A sun opens at the top (0.02 .. 0.45): bright noise swelling and a thin glide up; the fan of shafts opens
    (OPEN 0.3) and their fronts pour down onto the mark (inQuad, faster and faster, to HIT 0.66): noise swelling and
    sinking from hiss toward the floor. HIT 0.66, they converge: a crack and light's weight on the mark (energy: a zap
    gliding down, a noise whoomp), the sigil burning in round the ring (0.2 s: a sizzle). The shafts hold, pulsing (.. FOLD 2.05): a bright shimmer with the sigil's embers
    crackling; the fan folds shut (2.05 .. SHUT 2.45): the shimmer narrowing and dying, a soft puff and stars at SHUT;
    the shafts lift and the sun closes with one glint (LIFT 2.75)."""
    s = seed_of(m)
    rng = np.random.default_rng(s)
    OPEN, HIT, FOLD, SHUT, LIFT = 0.3, 0.66, 2.05, 2.45, 2.75
    start = blank(HIT)
    t = T(0.45)
    put(start, st([glitter(0.45, (t / 0.45) * 0.12, 0, s, 0.6), sweep(500, 1500, 0.45, (t / 0.45) * 0.05)], 0), 0.02)
    d = HIT - OPEN
    t = T(d)
    u = t / d
    q = u ** 2
    pour = noise(len(t), np.round(1 + 4 * q).astype(int), seed=s + 1) * steps((0.15 + 0.85 * q) * 0.26)
    pour += sweep(1900, 700, d, (0.2 + 0.8 * q) * 0.05, shape=lambda v: v ** 2)
    put(start, st(pour, 0), OPEN)
    hit = st([crack(0.05, 0, 0.85, 50, s + 2), struck("energy", 0.65 * rng.uniform(0.92, 1.05), s + 321, 0.7)], 0)
    t = T(0.25)
    sig = noise(len(t), 1, True, s + 3) * steps(np.minimum(1, t / 0.02) * decay(t, 6) * 0.22)
    put(hit, st(sig, (0, 0)), 0.02)
    L = SHUT + 0.15 - HIT
    t = T(L)
    lvl = env_at(t, [(0, 1), (0.25, 0.65), (FOLD - HIT, 0.55), (SHUT - HIT, 0.12), (L, 0)])
    body = st(glitter(L, lvl * 0.24, 0, s + 4, 0.45), 0)
    put(body, st(noise(len(t), 3, seed=s + 5) * steps(lvl * 0.5) * 0.12, 0), 0)
    at = 0.05
    while at < SHUT - HIT:                          # the sigil's embers: about 10 a second while it burns
        place(body, burst(0.02, int(rng.integers(0, 3)), rng.uniform(0.06, 0.12) * (1.2 - at / L), 110,
                          int(rng.integers(1, 99))), at, rng.uniform(-0.35, 0.35))
        at += rng.exponential(0.1)
    rel = blank(0.75)
    put(rel, st(air(0.4, 0, 4, 0.12, s + 6, "fall"), (0.0, 0.0)), 0)
    put(rel, st([burst(0.18, 2, 0.2, 18, s + 7), glitter(0.25, decay(T(0.25), 10) * 0.14, 0, s + 8, 0.7)], 0), SHUT - FOLD)
    twinkles(rel, rng, 6, (SHUT - FOLD + 0.03, SHUT - FOLD + 0.3), 0.09, (-0.2, 0.2))
    put(rel, st(burst(0.02, 0, 0.18, 120, s + 9, short=True), 0), LIFT - FOLD)
    full = mix([(start, 0), (hit, HIT), (body, HIT), (rel, FOLD)], m["duration"])
    return out(full, {"start": start, "hit": hit, "body": body, "release": rel},
               "sun opening (glitter + glide up), shafts pouring down faster (0.3-0.66), crack + energy + sigil sizzle at "
               "0.66, held shimmer with ember crackles, folding shut (2.05-2.45) with a puff, one glint at 2.75", 0.72)


# ------------------------------------------------------------------ resurrection
def resurrection(m):
    """The light pours down on the fallen (0 .. POUR 0.34, the front speeding up): bright noise swelling as it falls,
    then reaches the floor (light's soft weight: a small energy zap and whoomp, the lit ring spreading); life climbs the body (CL0 0.5 .. CL1 1.15): a glide
    and a hiss climbing together, bits of light ticking off; the hero frame at CL1: a bright burst. The wings burst
    open (W0 1.1 .. 1.5): a rush out to both sides; the halo forms with a glint (H1 1.5). The beat: a slow raise (B0
    1.95 .. B1 2.25, air drawn in) and the hard downstroke into the gust along the floor (B2 2.34): a soft heavy whump
    of air (low noise, no tone: wings beat air, they strike nothing) and air rushing out both ways, light flung off the tips. The wings come apart, tips first (SC 2.95 .. ~3.2):
    sparkles crackling out across both wings; the halo melts and the light fades in silence."""
    s = seed_of(m)
    rng = np.random.default_rng(s)
    POUR, CL0, CL1, W0, H1, B0, B1, B2, SC = 0.34, 0.5, 1.15, 1.1, 1.5, 1.95, 2.25, 2.37, 2.95
    t = T(POUR)
    q = (t / POUR) ** 2
    pour = st(noise(len(t), np.round(1 + 3 * q).astype(int), seed=s) * steps((0.15 + 0.85 * q) * 0.24), 0)
    land = st([material_hit("energy", 0.2, s + 331, 0.35), glitter(0.3, decay(T(0.3), 8) * 0.18, 0, s + 1, 0.6)], 0)
    put(land, spread_out(0.4, 3, 7, 0.1, s + 2), 0)
    d = CL1 - CL0
    t = T(d)
    u = t / d
    e = 0.5 - 0.5 * np.cos(np.pi * u)
    climb = st(sweep(260, 1150, d, (0.3 + 0.7 * u) * 0.07, shape=lambda v: 0.5 - 0.5 * np.cos(np.pi * v))
               + noise(len(t), np.round(4 - 4 * e).astype(int), seed=s + 3) * steps((0.15 + 0.85 * u ** 1.5) * 0.15), 0)
    twinkles(climb, rng, 10, (0.05, d - 0.02), 0.1, (-0.25, 0.25))
    rise = blank(0.9)
    put(rise, st([burst(0.25, 0, 0.32, 12, s + 4), glitter(0.35, decay(T(0.35), 7) * 0.2, 1, s + 5, 0.6, True)], 0), CL1 - W0)
    put(rise, spread_out(0.45, 7, 3, 0.18, s + 6, 0.15, 0.6, "bell"), 0)
    twinkles(rise, rng, 8, (0.0, 0.35), 0.1, (-0.6, 0.6))
    put(rise, st(burst(0.02, 0, 0.16, 120, s + 7, short=True), 0), H1 - W0)
    beat = blank(1.2)
    put(beat, st(air(B1 - B0, 11, 8, 0.1, s + 8, "rise"), 0), 0)
    put(beat, st(air(B2 - B1, 9, 5, 0.22, s + 9, "rise"), 0), B1 - B0)
    g = B2 - 0.03 - B0
    t = T(0.4)
    whump = noise(len(t), np.round(np.interp(t, [0, 0.05, 0.4], [14, 11, 9])).astype(int), seed=s + 10) * \
        steps(np.minimum(1, t / 0.01) * decay(t, 9)) * 0.42
    put(beat, st(whump, 0), g)
    put(beat, spread_out(0.6, 5, 10, 0.24, s + 11, 0.2, 0.9), g)
    twinkles(beat, rng, 8, (g + 0.02, g + 0.4), 0.1, (-0.7, 0.7))
    scatter = blank(1.0)
    for side in (-1, 1):
        for i in range(18):
            at = rng.uniform(0, 0.2) ** 1.0 + rng.uniform(0, 0.04)
            place(scatter, burst(0.015, int(rng.integers(0, 2)), rng.uniform(0.07, 0.13), 150, int(rng.integers(1, 99)),
                                 short=bool(rng.random() < 0.5)), at, side * rng.uniform(0.15, 0.6))
    put(scatter, st(glitter(0.5, decay(T(0.5), 5) * 0.1, 1, s + 12, 0.8), 0), 0)
    full = mix([(pour, 0), (land, POUR), (climb, CL0), (rise, W0), (beat, B0), (scatter, SC)], m["duration"])
    return out(full, {"start": pour, "land": land, "climb": climb, "rise": rise, "beat": beat, "tail": scatter},
               "light pouring down (0-0.34) + soft landing, glide + hiss climbing the body (0.5-1.15), bright burst at "
               "1.15, wings opening out L/R (1.1), halo glint 1.5, wingbeat whump + gust out both ways (2.34), "
               "sparkles as the wings come apart (2.95-3.2)", 0.78)


# ------------------------------------------------------------------ smite
def smite(m):
    """A glint marks the spot (0 .. MARK 0.42, the ring closing on it): a quiet thin shimmer; the hammer of light drops
    (MARK .. HIT 0.54, inCubic: faster and faster): a rush and a zap gliding down; HIT 0.54, a hammer of light on stone
    (not an explosion): a bright crack, light's weight (energy: a zap gliding down, a noise whoomp) and the floor's
    (stone and earth: a dry heavy knock, a gritty crunch, a short low noise thud), the air shock and the dust rolling
    out both ways; 14 stone chips (gravity 1, drag 0.4, bounce 0.35) knock down as stone and grit ticks on their own
    flights. The glowing cracks cool in silence (rule 4: no ember bed)."""
    s = seed_of(m)
    rng = np.random.default_rng(s)
    MARK, HIT = 0.42, 0.54
    t = T(MARK)
    start = st([glitter(MARK, np.minimum(1, t / 0.08) * (0.5 + 0.5 * t / MARK) * 0.1, 0, s, 0.7),
                sweep(1100, 1600, MARK, np.minimum(1, t / 0.08) * 0.04)], 0)
    d = HIT - MARK
    t = T(d)
    u = (t / d) ** 3
    drop = st([noise(len(t), np.round(np.interp(u, [0, 1], [1, 6])).astype(int), seed=s + 1) * steps((0.2 + 0.8 * u) * 0.4),
               sweep(2400, 300, d, (0.3 + 0.7 * u) * 0.12, 0.25, lambda v: v ** 3)], 0)
    hit = st([crack(0.05, 0, 0.7, 45, s + 2), crack(0.03, 0, 0.35, 80, s + 3, True),
              struck("energy", 0.85 * rng.uniform(0.92, 1.05), s + 341, 0.55),
              np.concatenate([np.zeros(int(0.03 * SR)), earth(0.85 * rng.uniform(0.92, 1.05), s + 342, 0.8)])], 0)
    body = spread_out(0.9, 8, 12, 0.3, s + 5, 0.15, 0.85)
    put(body, st(air(0.5, 9, 5, 0.35, s + 4, "bell"), 0), 0)        # the air shock: a dome of light thrown up over it
    tail = blank(2.2)
    lands = []
    for i in range(14):
        a = -np.pi / 2 + rng.uniform(-1.2, 1.2)
        sp = rng.uniform(90, 230)
        lands += fly(np.cos(a) * sp, np.sin(a) * sp, rng.uniform(-5, 5), -2, 1, 0.4, 0.35, rng.uniform(1.2, 1.8))
    put(tail, debris(m, lands, 0.26, 9, weight=0.15, vref=260, seed=s + 6, mat="stone"), 0)
    grit = []
    for i in range(34):
        a = -np.pi / 2 + rng.uniform(-1, 1)
        sp = rng.uniform(60, 220)
        grit += fly(np.cos(a) * sp, np.sin(a) * sp, rng.uniform(-4, 4), -1, 1, 0.0, 0.0, rng.uniform(0.9, 1.5))
    put(tail, debris(m, grit, 0.1, 5, short=True, vref=240, seed=s + 7), 0)
    full = mix([(start, 0), (drop, MARK), (hit, HIT), (body, HIT + 0.04), (tail, HIT)], m["duration"])
    return out(full, {"start": start, "drop": drop, "hit": hit, "body": body, "tail": tail},
               "quiet shimmer on the mark (0-0.42), rush + zap gliding down as the hammer drops (0.42-0.54), "
               "hammer of light at 0.54: crack + energy + stone/earth knock and crunch, dust out L/R, stone chips "
               "and grit knocking down", 0.62)


SOUNDS = {
    "blessing": blessing,
    "divine-shield": divine_shield,
    "feather-burst": feather_burst,
    "halo": halo,
    "heal": heal,
    "heal-aoe": heal_aoe,
    "holy-pillar": holy_pillar,
    "resurrection": resurrection,
    "smite": smite,
    "sunburst": sunburst,
}
