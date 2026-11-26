# spawn: things appearing and dying (references/sound.md). Each is a strong dynamic moment, so each gets clear phases
# on the effect's own beats: an anticipation (quiet, rising, no notes), the hit where it happens (the hit recipe for
# anything that bursts or lands), the body after any hit-stop, and a sparse physical tail. A hit's weight is what is
# struck (synth.material_hit, sound.md rule 2), never the blast's pitch-dropping thump (nothing here explodes): gold
# clinks, eggshell cracks thin and toks hollow, the floor knocks and crunches, ice cracks and tinkles, a body slumps as
# flesh, a cartoon poof pops; fire roars and crackles, smoke puffs are air; energy (beams, light, souls) lands as a zap
# and a noise whoomp, and otherwise is a jittering buzz, a glide or glittering noise, never a tune (rule 1). A
# soul simply drifting up is kept faint. Beats from src/fx/spawn/<name>.js and act.timing in port/meta.json.
import numpy as np
from synth import *  # noqa: F401,F403
from cats.impacts import seed_of, hits_of, windup_of, pan_of, S, st, put, crack, knock, earth, air, breath, \
    fly, grit_lands, debris
from cats.projectiles import shot, st_path
from cats.ice import leveled, q, icecrack, iceknock, shatter, crackles, landed, ice_weight
from cats.lightning import zap, crackle as arcs
from cats.arcane import glitter, sweep, gather, pop, twinkles, struck
from cats.explosions import burst, wash, spit, clink
from cats.fire import loop_curve
from cats.scifi import Rng, lay, drone, spark_rain, in_out_sine

FPS = 30
TAU = 2 * np.pi
G = 950.0


def start_with_windup(m, part, pan, seed, default=0.2):
    """The act's windup (the pose before t 0) as a quiet low breath, then the effect's own anticipation."""
    w = windup_of(m, default)
    return np.concatenate([st(breath(w, 12, 9, 0.07, seed), pan), part]) if w > 0 else part


# ------------------------------------------------------------------ deaths
def coin_drop(m):
    """hit (t 0): the enemy goes up in a soft poof: a cartoon pop (crack, synth pop_hit's quick upward blip) and a puff
    of air. The coins (7) fly out
    and fall on the original's own draws and physics (its Rng replayed, gravity 820, bounce x0.45 while faster than
    110 px/s, 120 Hz steps): each landing a gold clink as loud as it hits, panned where it lands, every coin its own
    pitch (no scale), the last settling bounces soft. Lying there twinkling: silent. tail: they wink out one by one
    (2.15 + 0.07 i + rand): each a tiny sparkle of noise, no tone."""
    sd = seed_of(m)
    rng = np.random.default_rng(sd)
    o = m["options"]
    R = Rng(int(o.get("seed", 23)))
    CY = -16
    for _ in range(10):
        R.range(0, 1), R.range(0, 1), R.range(0, 1), R.range(0, 1)
    n = int(o.get("coins", 7))
    coins = []
    for i in range(n):
        u = i / (n - 1) - 0.5 if n > 1 else 0
        a = -np.pi / 2 + u * 1.6 + R.range(-0.1, 0.1)
        sp = R.range(230, 300)
        x = R.range(-3, 3)
        R.range(0, TAU)
        R.range(9, 15)
        R.sign()
        out = 2.15 + i * 0.07 + R.range(0, 0.1)
        R.range(1.2, 1.9)
        born = R.range(0.04, 0.12)
        coins.append(dict(x=x, y=CY, vx=np.cos(a) * sp * 0.4, vy=np.sin(a) * sp, out=out, born=born, rest=False, hits=[]))
    dt, t = 1 / 120, 0.0
    while t < m["duration"]:
        t += dt
        for c in coins:
            if t < c["born"] or t > c["out"] or c["rest"]:
                continue
            c["vy"] += 820 * dt
            c["vx"] -= c["vx"] * 0.4 * dt
            c["x"] += c["vx"] * dt
            c["y"] += c["vy"] * dt
            if c["y"] >= -1.5 and c["vy"] > 0:
                c["y"] = -1.5
                c["hits"].append((t, c["vy"], c["x"]))
                if c["vy"] > 110:
                    c["vy"] *= -0.45
                    c["vx"] *= 0.7
                else:
                    c["rest"] = True
    p0 = pan_of(m, 0)
    hit = lay((st([crack(0.03, 0, 0.7, 80, sd), struck("pop", 0.45, sd + 601, 0.6, 0.005), crack(0.03, 1, 0.4, 90, sd + 1)], p0), 0),
              (st(wash(0.5, 4, 9, 1.0, 0.02, 5, sd + 2) * 0.35, p0), 0))
    twinkles(hit, rng, 8, (0.25, 0.6), 0.05, (p0 - 0.3, p0 + 0.3))
    lands = blank(2.2)
    for c in coins:
        f = rng.uniform(2500, 3900)
        for at, v, x in c["hits"]:
            a = min(1.0, v / 420)
            place(lands, clink(f * rng.uniform(0.97, 1.03), 0.35 * a + 0.03, int(rng.integers(1, 999))), at, pan_of(m, x))
    tail = blank(1.0)
    first = min(c["out"] for c in coins)
    for c in coins:
        s = glitter(0.12, decay(T(0.12), 25), 0, int(rng.integers(1, 999)), 0.7, True) * 0.12
        s[:int(0.02 * SR)] += burst(0.02, 0, 0.12, 150, int(rng.integers(1, 99)), short=True)
        place(tail, s, c["out"] - first, pan_of(m, c["x"]))
    full = shot(m, [(hit, 0), (lands, 0), (tail, first)])
    return leveled(m, full, {"hit": hit, "body": lands, "tail": tail},
                   "poof pop + puff at 0; 7 coins clinking on their own bounces (JS Rng + physics, 0.4-1.6 s), each its own "
                   "pitch; silent while they lie; tiny sparkles as they wink out 2.15-2.7", -24)


def disintegrate(m):
    """start: the act's windup (0.2 s), then the charge (0 .. FLASH 0.42): light gathering into the body: noise and a
    thin glide climbing, crackle getting denser. hit (FLASH): the white flash: a zap and energy's light weight (a zap
    gliding down, a noise whoomp), the floor ring as a breath of air. body (P0 0.49 .. 1.69, the peel front easing in and out): each pixel flaring and streaming off: a
    bright glittering fizz whose density is the front's speed (sin of the ease), crackling with flares, over a wind
    gusting (the JS's gust 0.7 .. 1.2) that carries it to the right. tail (to ~2.9): the wind drops, the last motes hang
    as a fading glitter, a few ash flakes settle with faint ticks."""
    sd = seed_of(m)
    rng = np.random.default_rng(sd)
    FLASH, P0, PEEL = 0.42, 0.49, 1.2
    p0 = pan_of(m, 0)
    ch = lay((st(charge(FLASH, 12, 2, 240, 950, 0.18, sd), p0), 0),
             (st(arcs(FLASH, lambda a: 8 + 60 * (a / FLASH) ** 1.5, lambda a: 0.04 + 0.11 * a / FLASH, sd + 1), p0), 0))
    start = start_with_windup(m, ch, p0, sd + 2)
    hit = lay((st([zap(0.85, sd + 3, 0.12, 50), struck("energy", 0.25, sd + 611, 0.55)], p0), 0),
              (st(air(0.5, 1, 7, 1.0, sd + 4, "fall") * 0.18, p0), 0.01))
    L = PEEL + 1.2
    t = T(L)
    u = np.clip(t / PEEL, 0, 1)
    rate = np.where(t < PEEL, np.sin(np.pi * u), 0)
    gust = 0.7 + 0.5 * (0.5 + 0.5 * loop_curve(t, L, 1.6, rng))
    drop = 1 - 0.55 * np.clip((t - PEEL) / 1.2, 0, 1)
    fizz = glitter(L, 0.15 + 0.85 * rate, 0, sd + 5, 0.75) * 0.2 * np.minimum(1, t / 0.05)
    fizz *= np.where(t < PEEL + 0.1, 1, np.exp(-(t - PEEL - 0.1) * 2.5))
    wind = noise(len(t), np.where(gust > 1.0, 5, 6), seed=sd + 6) * q(gust * drop * np.minimum(1, t / 0.3) *
                                                                    np.minimum(1, (L - t) / 0.5)) * 0.1
    pans = p0 + 0.55 * np.clip(t / (PEEL + 0.6), 0, 1)
    body = lay((st_path(fizz, pans), 0), (st_path(wind, pans + 0.1), 0),
               (st(arcs(PEEL, lambda a: 5 + 45 * np.sin(np.pi * a / PEEL), lambda a: 0.1, sd + 7), (p0, p0 + 0.4)), 0))
    tail = blank(1.6)
    for _ in range(8):
        lands = fly(rng.uniform(10, 40), rng.uniform(-30, 0), rng.uniform(-6, 6), rng.uniform(-9, -1), 260 / G, 1.2, 0.35, 2.0, 50)
        for at, v, x in lands:
            place(tail, tick(1.0, int(rng.integers(1, 99)), False) * 0.06 * min(1, v / 120), at + rng.uniform(0, 1.0), pan_of(m, x + 15))
    full = shot(m, [(ch, 0), (hit, FLASH), (body, P0), (tail, P0 + PEEL - 0.4)])
    return leveled(m, full, {"start": start, "hit": hit, "body": body, "tail": tail},
                   "windup breath, charge climbing + crackle denser (0-0.42); white flash zap at 0.42; pixels peeling "
                   "0.49-1.69 as a fizz on the front's speed over a gusting wind drifting right; wind drops, motes "
                   "fade, ash ticks", -23)


def dissolve_burn(m):
    """start: the act's windup (0.16 s) and the moment before the feet catch (.. IGNITE 0.15): a quiet breath. hit
    (IGNITE): the feet catch: a soft whoomp of flame (a rush and a low noise puff, no falling tone: fire strikes
    nothing) and the spit of 10 sparks ticking down.
    body (0.15 .. 2.05, the seam climbing on an ease in-out): fire: a roar with a hiss over it swelling with how fast the
    seam eats the body (the ease's speed) and fluttering with the flames, pops crackling as often (the burnt pixels
    turning to flame, embers and ash). tail: the last flames die (a roar falling away over 0.7 s), embers spit now and
    then, low ash grit ticking on the floor."""
    sd = seed_of(m)
    rng = np.random.default_rng(sd)
    IGNITE, BURN = 0.15, 1.9
    p0 = pan_of(m, 0)
    pre = st(breath(IGNITE, 11, 8, 0.08, sd), p0)
    start = start_with_windup(m, pre, p0, sd + 1, 0.16)
    hit = lay((st([wash(0.45, 9, 6, 1.0, 0.03, 6, sd + 2) * 0.7, wash(0.25, 13, 11, 1.0, 0.01, 14, sd + 9) * 0.5,
                   crack(0.03, 3, 0.5, 70, sd + 3)], p0), 0),
              (spark_rain(m, 0, -1, 10, rng, (50, 150), 0.8, 0.07), 0))
    L = BURN + 0.8
    t = T(L)
    u = np.clip(t / BURN, 0, 1)
    speed = np.sin(np.pi * u)
    flick = 0.85 + 0.15 * loop_curve(t, L, 6, rng)
    env = np.where(t < BURN, 0.2 + 0.8 * speed, 0.2 * np.exp(-(t - BURN) * 4)) * np.minimum(1, t / 0.08) * flick
    roar = noise(len(t), np.where(loop_curve(t, L, 2, rng) > 0.3, 10, 9), seed=sd + 4) * q(env) * 0.3
    roar += noise(len(t), 3, seed=sd + 5) * q(env) * 0.12
    body = st(roar, p0)
    at = 0.0
    while True:
        at += rng.exponential(1 / (4 + 34 * np.sin(np.pi * min(1, at / BURN)) if at < BURN else 3))
        if at >= L - 0.1:
            break
        place(body, burst(rng.uniform(0.015, 0.035), int(rng.integers(0, 4)), rng.uniform(0.06, 0.16) * (1 if at < BURN else 0.5),
                          90, int(rng.integers(1, 99)), short=rng.random() < 0.2), at, p0 + rng.uniform(-0.15, 0.15))
    tail = blank(1.4)
    for _ in range(6):
        place(tail, spit(rng.uniform(0.04, 0.08), int(rng.integers(1, 99)), 0.03), rng.uniform(0, 1.2), p0 + rng.uniform(-0.2, 0.2))
    lands = []
    for _ in range(10):
        lands += grit_lands(rng.uniform(-12, 12), rng.uniform(-20, 0), rng.uniform(-8, 8), -rng.uniform(1, 7), rng)
    put(tail, debris(m, [(a + rng.uniform(0, 1.0), v, x) for a, v, x in lands], 0.05, 6, seed=sd + 6), 0)
    full = shot(m, [(hit, IGNITE), (body, IGNITE), (tail, IGNITE + BURN)])
    return leveled(m, full, {"start": start, "hit": hit, "body": body, "tail": tail},
                   "windup breath; feet catch at 0.15 (whoomp, low puff, sparks); fire roar + crackle swelling with the "
                   "seam's climb 0.15-2.05; flames dying, ember spits, ash grit ticks", -24)


def poof(m):
    """hit (t 0): the white pop: a bright crack and a cartoon pop (synth pop_hit: a quick upward blip and a puff), a puff
    of air bursting out with the speed lines
    (a quick hiss falling away), the feet's dust skidding out both ways. body: the stars spun off winking out; each big
    smoke ball goes with a pip of light as it shrinks away (14 of them, at the times the original's Rng gives:
    delay + life, 0.7 .. 1.3 s) as faint high clicks; the cloud lifting is silent."""
    sd = seed_of(m)
    rng = np.random.default_rng(sd)
    R = Rng(int(m["options"].get("seed", 21)))
    pips = []
    for i in range(9):
        a = (i / 9) * TAU + R.range(-0.2, 0.2)
        R.range(95, 140)
        R.range(5, 7)
        life = R.range(0.7, 1.05)
        delay = R.range(0, 0.03)
        pips.append((delay + life, np.cos(a) * 20))
    for _ in range(5):
        a = R.range(0, TAU)
        R.range(20, 60)
        R.range(6.5, 8.5)
        life = R.range(0.85, 1.2)
        delay = R.range(0.02, 0.06)
        pips.append((delay + life, np.cos(a) * 8))
    p0 = pan_of(m, 0)
    hit = lay((st([crack(0.04, 1, 0.75, 60, sd), struck("pop", 0.6, sd + 621, 0.75, 0.005)], p0), 0),
              (st(wash(0.55, 3, 9, 1.0, 0.015, 5.5, sd + 1) * 0.5, p0), 0),
              (st(burst(0.12, 0, 0.3, 30, sd + 2), p0), 0),
              (st(air(0.45, 8, 11, 1.0, sd + 3, "fall") * 0.12, (p0, p0 - 0.5)), 0.01),
              (st(air(0.45, 8, 11, 1.0, sd + 4, "fall") * 0.12, (p0, p0 + 0.5)), 0.01))
    body = blank(1.4)
    twinkles(body, rng, 12, (0.3, 0.95), 0.05, (p0 - 0.4, p0 + 0.4))
    for at, x in pips:
        place(body, burst(0.015, 0, 0.07, 180, int(rng.integers(1, 99)), short=rng.random() < 0.5), at, pan_of(m, x))
    full = shot(m, [(hit, 0), (body, 0)])
    return leveled(m, full, {"hit": hit, "body": body},
                   "pop (crack + cartoon blip) and puff of air at 0, dust skids both ways; stars winking, 14 pips as the "
                   "balls go (0.7-1.3 s, the JS's draws)", -24)


def respawn_beam(m):
    """start (0 .. SLAM 0.32): streaks run in along the floor and the guide line drops: a quiet gather from both sides,
    the pillar falling in its last 0.07 s as a fast falling glide. hit (SLAM): the pillar of light slams onto the spot:
    a crack, a zap, energy's weight and the floor's dry knock (stone: a knock and a gritty crunch), dust skidding out
    both ways, sparks ticking down; the second floor ring (0.4) a
    breath of air. body (WRITE0 0.4 .. DONE 1.35): the beam's hum (a jittering low buzz on its width: overshoot at the
    slam, its own flutter 0.92 + 0.08 sin 40t) with the scan bar climbing feet to crown (ease in-out) as a thin glide
    rising under a fizz of the sparks it throws off; DONE: written, a soft glint of light. release (LIFT 1.47): the beam
    lifts away bottom first and narrows: its buzz gliding up and fading, a rush rising. tail: sparks landing."""
    sd = seed_of(m)
    rng = np.random.default_rng(sd)
    SLAM, WRITE0, WRITE = 0.32, 0.4, 0.95
    DONE, DROP = WRITE0 + WRITE, 0.07
    LIFT = DONE + 0.12
    p0 = pan_of(m, 0)
    start = lay((gather(SLAM - DROP, 0.22, sd, 11, 3, 260, 800, 2.0, 8, rng, 0.8), 0),
                (st(sweep(2000, 450, DROP, np.linspace(0.6, 1, len(T(DROP)))) * 0.22, p0), SLAM - DROP))
    hit = lay((st([crack(0.05, 0, 0.8, 50, sd + 1), zap(0.6, sd + 2, 0.1, 60),
                   struck("energy", 0.7 * rng.uniform(0.93, 1.05), sd + 631, 0.7),
                   struck("stone", 0.45 * rng.uniform(0.9, 1.1), sd + 632, 0.55, 0.018)], p0), 0),
              (st(wash(0.6, 8, 11, 1.0, 0.02, 4, sd + 3) * 0.2, (p0, p0 - 0.6)), 0),
              (st(wash(0.6, 8, 11, 1.0, 0.02, 4, sd + 4) * 0.2, (p0, p0 + 0.6)), 0),
              (st(air(0.4, 2, 7, 1.0, sd + 5, "fall") * 0.1, p0), WRITE0 - SLAM),
              (spark_rain(m, 0, -1, 24, rng, (60, 200), 1.3, 0.07), 0))
    L = LIFT - SLAM
    t = T(L)
    tt = t + SLAM
    width = (1 + 0.4 * np.exp(-(tt - SLAM) * 10)) * (0.92 + 0.08 * np.sin(tt * 40)) / 1.4
    hum = drone(L, width * np.minimum(1, t / 0.03), 105, sd + 6, 3, 0.05, 0.5) * 0.18
    body = lay((st(hum, p0), 0), (blank(L + 0.4), 0))
    t = T(WRITE)
    u = t / WRITE
    env = np.sin(np.pi * u) ** 0.5
    write = sweep(500, 1600, WRITE, env, 0.125, in_out_sine) * 0.07 + glitter(WRITE, env, 0, sd + 7, 0.6) * 0.05
    put(body, st(write, p0), WRITE0 - SLAM)
    put(body, st(arcs(WRITE, lambda a: 25, lambda a: 0.07, sd + 8), p0), WRITE0 - SLAM)
    put(body, st(glitter(0.4, decay(T(0.4), 8), 0, sd + 9, 0.7) * 0.09, p0), DONE - SLAM)
    t = T(0.45)
    u = np.clip(t / 0.3, 0, 1)
    rel = st([drone(0.45, (1 - u) ** 1.5, 105 * (500 / 105) ** u, sd + 10, 1, 0.05, 0.4) * 0.18,
              air(0.45, 6, 1, 1.0, sd + 11, "fall") * 0.14], p0)
    tail = lay((blank(0.8), 0), (spark_rain(m, 0, -40, 12, rng, (20, 80), 1.2, 0.05), 0))
    full = shot(m, [(start, 0), (hit, SLAM), (body, SLAM), (rel, LIFT), (tail, LIFT)])
    return leveled(m, full, {"start": start, "hit": hit, "body": body, "release": rel, "tail": tail},
                   "floor gather + pillar dropping (0-0.32); slam crack + zap + energy + floor knock + dust at 0.32; beam hum, scan glide "
                   "rising feet to crown 0.4-1.35 with spark fizz, glint at 1.35; beam lifting away with a rising glide "
                   "1.47; sparks", -23)


def shatter_death(m):
    """start: the act's windup (0.2 s), then frost racing up the body (0 .. LOCK 0.5, outCubic): crisp ice crackle
    getting denser over a thin hiss brightening, vapour rolling off the feet. hit 1 (LOCK 0.5, hit-stop 0.02): sealed in
    ice: a crisp crack and ice's own light weight (a short-mode crack and high tinks, no low weight); after the freeze a glint sweeps it (a faint glitter crossing left to right).
    CRACK 1.05: cracks spread from the chest: a crack and 5 chips tinkling down, the block creaking (crackle denser, a
    short-mode shiver swelling) to the burst. hit 2 (BURST 1.4, hit-stop 0.09): it bursts: the ice shatter (crack,
    ice's weight, metallic burst, glassy ring, splinters); after the freeze the body rings out and the facets tumble,
    bounce (x0.32 over 90 px/s) and skid as ice knocks, 64 shards tinkling where they land; melting is silent."""
    sd = seed_of(m)
    rng = np.random.default_rng(sd)
    CRACK = 1.05                                          # LOCK 0.5 and BURST 1.4 are the act's two hits
    (h1, f1), (h2, f2) = hits_of(m)
    IY = -20
    p0 = pan_of(m, 0)
    pre = blank(h1)
    t = T(h1)
    u = t / h1
    hiss = noise(len(t), np.round(5 - 5 * u).astype(int), seed=sd) * q(0.25 + 0.75 * u ** 1.5) * 0.08
    put(pre, st(hiss, p0), 0)
    put(pre, st(air(h1, 10, 12, 1.0, sd + 1, "bell") * 0.06, p0), 0)
    crackles(pre, rng, 0.0, h1 - 0.01, 20, 80, 0.08, 0.2, (p0 - 0.15, p0 + 0.15))
    start = start_with_windup(m, pre, p0, sd + 2)
    hit = st([icecrack(0.6, sd + 3), ice_weight(0.25, sd + 641, 0.4), burst(0.1, 0, 0.25, 35, sd + 4, short=True)], p0)
    seal = blank(CRACK - h1 - f1)
    t = T(0.5)
    put(seal, st_path(glitter(0.5, np.sin(np.pi * t / 0.5), 0, sd + 5, 0.7) * 0.07, np.linspace(p0 - 0.3, p0 + 0.3, len(t))), 0.03)
    crk = blank(h2 - CRACK)
    place(crk, icecrack(0.6, sd + 6), 0, p0)
    for _ in range(5):
        a = rng.uniform(0, TAU)
        sp = rng.uniform(60, 150)
        landed(crk, m, rng, fly(np.cos(a) * sp, np.sin(a) * sp - 60, 0, IY, 0.8, 0.6, 0.3, rng.uniform(0.5, 0.9)), 0.12)
    crackles(crk, rng, 0.02, h2 - CRACK - 0.005, 20, 100, 0.1, 0.25, (p0 - 0.2, p0 + 0.2))
    t = T(h2 - CRACK)
    uu = t / (h2 - CRACK)
    place(crk, noise(len(t), 7, True, sd + 7) * q((0.2 + 0.8 * uu) ** 2) * 0.12, 0, p0)
    shat = st(shatter(1.0, sd + 8, rng, 360, 0.6), p0)
    t = T(0.9)
    body = st([burst(0.7, 1, 0.22, 5, sd + 9, short=True),
               noise(len(t), np.round(3 + 6 * t / 0.9).astype(int), seed=sd + 11) * q(decay(t, 4)) * 0.1], p0)
    tail = blank(1.6)
    for _ in range(16):                                   # the facets, flung out from the chest
        x, y = rng.uniform(-12, 12), rng.uniform(-38, -2)
        dx, dy = x, y - IY
        l = np.hypot(dx, dy) or 1
        sp = rng.uniform(55, 115)
        for at, v, xx in fly(dx / l * sp + rng.uniform(-18, 18), dy / l * sp * 0.6 - rng.uniform(110, 220), x, y, 900 / G,
                             0.5, 0.32, rng.uniform(1.3, 1.85), 90):
            place(tail, iceknock(0.13 * min(1, v / 320), int(rng.integers(1, 999)), rng.uniform(1300, 1900), 0.35), at, pan_of(m, xx))
    for _ in range(64):
        a = -np.pi / 2 + rng.uniform(-1.45, 1.45)
        sp = rng.uniform(60, 180)
        landed(tail, m, rng, fly(np.cos(a) * sp, np.sin(a) * sp, rng.uniform(-6, 6), IY + rng.uniform(-8, 8), 0.85, 0.6, 0.3,
                                 rng.uniform(0.9, 1.6)), 0.12)
    b2 = h2 + f2
    full = shot(m, [(pre, 0), (hit, h1), (seal, h1 + f1), (crk, CRACK), (shat, h2), (body, b2), (tail, b2)])
    return leveled(m, full, {"start": start, "hit": hit, "seal": seal, "crack": crk, "shatter": shat, "body": body,
                             "tail": tail},
                   "windup breath, frost crackling up the body (0-0.5); sealed: crisp crack at 0.5, glint glitter; crack + "
                   "chips at 1.05, creaking denser; shatter at 1.4, body after the 0.09 hit-stop, facets knocking and "
                   "shards tinkling down", -22)


def soul_rise(m):
    """start: the act's windup (0.2 s), then the outline flaring (0 .. LEAVE 0.35): a faint shimmer swelling. hit
    (LEAVE): the soul tears loose: a soft airy whoomp with energy's faint weight (a small zap, a noise whoomp), the
    floor ring a breath of air, stars off the rim glittering. The body slumps to the floor (its pose lands at 1.1, the
    act's dust): a soft flesh thud (a noise smack, a very short low push), a knock and a puff. body:
    the soul drifting up (.. TOP 2.05): kept faint, a thin airy rush rising toward hiss; it thins into light (TOP - 0.25
    .. GONE 2.55): motes pouring off as a glitter swelling and dispersing."""
    sd = seed_of(m)
    LEAVE, TOP, GONE, SLUMP = 0.35, 2.05, 2.55, 1.1
    p0 = pan_of(m, 0)
    t = T(LEAVE)
    pre = st(glitter(LEAVE, (t / LEAVE) ** 1.5, 0, sd, 0.7) * 0.06 + noise(len(t), 6, seed=sd + 1) * q((t / LEAVE) ** 2) * 0.04, p0)
    start = start_with_windup(m, pre, p0, sd + 2)
    hit = lay((st([air(0.5, 2, 8, 1.0, sd + 3, "fall") * 0.3, material_hit("energy", 0.1, sd + 651, 0.3)], p0), 0),
              (st(glitter(0.5, decay(T(0.5), 7), 0, sd + 4, 0.7) * 0.1, p0), 0))
    L = GONE - LEAVE + 0.3
    t = T(L)
    tt = t + LEAVE
    u = np.clip((tt - LEAVE) / (TOP - LEAVE), 0, 1)
    thin = np.clip((tt - (TOP - 0.25)) / (GONE - TOP + 0.25), 0, 1)
    gone = np.clip(1 - (tt - GONE) / 0.3, 0, 1)
    whisper = noise(len(t), np.round(7 - 6 * u).astype(int), seed=sd + 5) * q((0.2 + 0.5 * np.sin(np.pi * u)) * gone * np.minimum(1, t / 0.3)) * 0.04
    motes = glitter(L, (0.15 + 0.85 * np.sin(np.pi * thin)) * gone, 0, sd + 6, 0.8) * 0.07
    body = lay((st(whisper + motes, p0), 0), (st([knock(0.2, sd + 7, 11, 0.08, 35), material_hit("flesh", 0.45, sd + 652, 0.4),
                                                  air(0.4, 9, 12, 1.0, sd + 8, "fall") * 0.1],
                                                 p0), SLUMP - 0.05 - LEAVE))
    full = shot(m, [(pre, 0), (hit, LEAVE), (body, LEAVE)])
    return leveled(m, full, {"start": start, "hit": hit, "body": body},
                   "windup, outline shimmer rising (0-0.35); soft whoomp as the soul tears loose 0.35; body slumps with a "
                   "soft thud at 1.05; faint rising whisper, motes glittering as it thins 1.8-2.55", -28)


def egg_hatch(m):
    """Three rocks (0.3, 0.85, 1.4, each harder): the egg lurching on its base as a soft knock, and at t0 + 0.05 the
    shell cracking further: a dry crack (eggshell, not glass), louder each time, its chips (1, 2, 3) ticking down. The
    shiver (1.84 .. POP 1.98): a short rattle swelling. hit (POP): it bursts: a crack, the shell's own weight (thin
    and brittle: glass's crisp crack and tinks, small, and a cartoon pop's upward blip; no low weight), a brittle burst,
    light pouring up out of it as a rising glitter; body: the 6 lit shell pieces thrown up and landing as shell knocks on
    their own flights (g 900, bounce x0.35 over 80 px/s), 14 shards ticking. tail: CRUMBLE (D - 0.55): the empty cup
    crumbles with a soft crunch, its 4 pieces dropping."""
    sd = seed_of(m)
    rng = np.random.default_rng(sd)
    WOB = [(0.3, 0.11), (0.85, 0.19), (1.4, 0.28)]
    POP, ZY, EH, EW = 1.98, 11, 20, 16
    CRUMBLE = m["duration"] - 0.55
    p0 = pan_of(m, 0)

    def shell(vol, seed):
        """Eggshell giving: a dry crack (long noise, mid rate) with a metallic tick on top and a small hollow shell
        'tok' under it (synth wood_hit, light, its own pitch; no pitch drop)."""
        return S(burst(0.03, 3, vol, 90, seed), burst(0.015, 0, vol * 0.5, 200, seed + 1, short=True),
                 knock(vol * 0.3, seed + 2, 9, 0.05, 60), material_hit("wood", 0.05, seed + 3, vol * 0.35))

    start = blank(POP)
    for i, (t0, amp) in enumerate(WOB):
        k = amp / 0.28
        place(start, S(knock(0.1 + 0.12 * k, sd + 10 * i, 10, 0.06, 50), material_hit("wood", 0.2, sd + 10 * i + 4, 0.08 + 0.12 * k)),
              t0, p0)
        place(start, shell(0.25 + 0.45 * k, sd + 10 * i + 1), t0 + 0.05, p0 + rng.uniform(-0.1, 0.1))
        for _ in range(i + 1):
            for at, v, x in fly(rng.uniform(-50, 50), -rng.uniform(40, 90), rng.uniform(-4, 4), -rng.uniform(10, 16), 0.9, 0.5, 0.3, 0.8):
                place(start, tick(1.0, int(rng.integers(1, 99)), True) * 0.08 * min(1, v / 150), t0 + 0.05 + at, pan_of(m, x))
        place(start, glitter(0.18, decay(T(0.18), 15), 0, sd + 10 * i + 3, 0.7) * 0.04 * (1 + i), t0 + 0.05, p0)
    t = T(0.14)
    u = t / 0.14
    place(start, noise(len(t), 8, True, sd + 4) * q((0.3 + 0.7 * u) ** 2 * (0.6 + 0.4 * np.abs(np.sin(t * 120)))) * 0.14, POP - 0.14, p0)
    t = T(0.7)
    hit = st([crack(0.04, 1, 0.8, 60, sd + 5), struck("glass", 0.3, sd + 661, 0.45, 0.02), struck("pop", 0.3, sd + 662, 0.45, 0.03),
              burst(0.2, 2, 0.3, 18, sd + 6, short=True),
              sweep(500, 1300, 0.7, decay(t, 2.6)) * 0.035, glitter(0.7, decay(t, 2.6), 0, sd + 7, 0.75) * 0.1], p0)
    body = blank(1.2)
    for _ in range(6):
        cx = rng.uniform(-EW / 2 + 1, EW / 2 - 1)
        cy = rng.uniform(ZY, EH)
        for at, v, x in fly(cx * rng.uniform(8, 13) + rng.uniform(-14, 14), -rng.uniform(140, 210), cx, -cy, 900 / G, 0.6, 0.35, 1.1, 80):
            place(body, shell(0.3 * min(1, v / 300), int(rng.integers(1, 999))), at, pan_of(m, x))
    for _ in range(14):
        a = -np.pi / 2 + rng.uniform(-1.2, 1.2)
        sp = rng.uniform(70, 170)
        for at, v, x in fly(np.cos(a) * sp, np.sin(a) * sp, rng.uniform(-5, 5), -ZY - rng.uniform(0, 4), 0.9, 0.6, 0.3, 0.85):
            if v > 60:
                place(body, tick(1.0, int(rng.integers(1, 99)), True) * 0.07 * min(1, v / 200), at, pan_of(m, x))
    tail = blank(0.8)
    place(tail, S(burst(0.08, 4, 0.25, 30, sd + 8), shell(0.15, sd + 9)), 0, p0)
    for _ in range(4):
        cx = rng.uniform(-6, 6)
        for at, v, x in fly(cx * rng.uniform(4, 8), -rng.uniform(40, 80), cx, -rng.uniform(2, 8), 900 / G, 0.6, 0.35, 0.45, 80):
            place(tail, shell(0.12 * min(1, v / 150) + 0.03, int(rng.integers(1, 999))), at, pan_of(m, x))
    full = shot(m, [(start, 0), (hit, POP), (body, POP), (tail, CRUMBLE)])
    return leveled(m, full, {"start": start, "hit": hit, "body": body, "tail": tail},
                   "three rocks (knock + shell crack, louder each: 0.35/0.9/1.45) with chips ticking; shiver rattle to "
                   "1.98; burst crack + shell crack/pop + light pouring at 1.98; shell pieces knocking down; cup crumbling at 2.55",
                   -24)


def spawn_portal(m):
    """start (0 .. 0.21): the rift tears open: a ripping noise climbing, light pulled in. The tear snaps open at 0.21
    (the ring): a low whoomp with the rift's energy weight (a zap gliding down, a noise whoomp) and dust skidding.
    While it's open (.. SHUT 1.9) it swirls: a low whirl of air, quiet, breathing. Two belches (0.52, 0.76): burps of
    smoke (a low rush, a dull noise puff; smoke is air, no tone) spitting sparks. hit (BURST 1.0): something comes up
    through it: a crack, the floor breaking (stone and earth: a dry heavy knock, a gritty crunch, a short noise thud)
    with the rift's energy, a gush of smoke, 34 sparks ticking down, 12 chunks of floor knocking down as stone on their
    own flights (g 1, drag 0.4, bounce 0.3), the 5 wisps bursting in small pops as they run out (0.75 .. 1.0 s later).
    release (SHUT 1.9 .. POP 2.22): the swirl whips round faster: a rush climbing and a glide rising, getting denser,
    cut by the pop: a crack and a small energy zap, sparks, specks twinkling out."""
    sd = seed_of(m)
    rng = np.random.default_rng(sd)
    OPEN, B0, B1, BURST, SHUT, POP = 0.3, 0.52, 0.76, 1.0, 1.9, 2.22
    RX = m["options"].get("width", 28)
    p0 = pan_of(m, 0)
    t = T(OPEN * 0.7)
    u = t / (OPEN * 0.7)
    rip = noise(len(t), np.round(8 - 7 * u).astype(int), seed=sd) * q(0.2 + 0.8 * u ** 1.5) * 0.22
    start = lay((st(rip, p0), 0), (st(arcs(OPEN * 0.7, lambda a: 20 + 80 * a / 0.21, lambda a: 0.1, sd + 1, short=False), p0), 0))
    opn = lay((st([wash(0.45, 11, 13, 1.0, 0.02, 5, sd + 2) * 0.4, material_hit("energy", 0.3, sd + 671, 0.5)], p0), 0),
              (st(air(0.5, 9, 12, 1.0, sd + 3, "fall") * 0.12, (p0, p0 - 0.6)), 0),
              (st(air(0.5, 9, 12, 1.0, sd + 4, "fall") * 0.12, (p0, p0 + 0.6)), 0))
    L = SHUT - OPEN
    t = T(L)
    whirl = noise(len(t), np.where(loop_curve(t, L, 2, rng) > 0, 11, 12), seed=sd + 5) * \
        q((0.75 + 0.25 * loop_curve(t, L, 1.5, rng)) * np.minimum(1, t / 0.2)) * 0.07
    swirl = st(whirl, p0)
    for i, (bt, n, up) in enumerate(((B0, 8, 210), (B1, 12, 240))):
        b = lay((st([wash(0.4, 11, 13, 1.0, 0.03, 6, sd + 10 + i) * 0.35,
                     wash(0.2, 13, 11, 1.0, 0.01, 16, sd + 14 + i) * 0.35], p0), 0),
                (spark_rain(m, 0, -1, n, rng, (up * 0.5, up), 0.6, 0.06), 0))
        put(swirl, b, bt - OPEN)
    hit = lay((st([crack(0.05, 1, 0.9, 50, sd + 20),
                   np.concatenate([np.zeros(int(0.03 * SR)), earth(0.75 * rng.uniform(0.93, 1.05), sd + 681, 0.85)]),
                   struck("energy", 0.45, sd + 682, 0.45, 0.015)], p0), 0),
              (st(wash(0.8, 10, 13, 1.0, 0.03, 3, sd + 21) * 0.3, p0), 0))
    body = lay((blank(0.1), 0), (spark_rain(m, 0, -1, 34, rng, (200, 400), 0.8, 0.07), 0))
    lands = []
    for _ in range(12):
        x = rng.choice((-1, 1)) * rng.uniform(0.75, 1.05) * RX
        lands += [l for l in fly(rng.uniform(-100, 100), -rng.uniform(150, 280), x, -1, 1.0, 0.4, 0.3, rng.uniform(1.3, 1.9))]
    put(body, debris(m, lands, 0.3, 8, weight=0.2, seed=sd + 23, mat="stone"), 0)
    for i in range(5):
        a = -np.pi / 2 + (i - 2) * 0.27
        at = rng.uniform(0.75, 1.0)
        put(body, st(pop(0.3, sd + 30 + i, 700, 200, 1, True, 0.15), pan_of(m, np.cos(a) * 200 * at * 0.5)), at)
    L2 = POP - SHUT
    t = T(L2)
    u = t / L2
    rel = st(noise(len(t), np.round(12 - 10 * u).astype(int), seed=sd + 40) * q((0.15 + 0.85 * u ** 2)) * 0.32 +
             sweep(160, 900, L2, 0.15 + 0.85 * u ** 2) * 0.08, p0)
    put(rel, st(arcs(L2, lambda a: 10 + 80 * a / L2, lambda a: 0.12, sd + 41, short=False), p0), 0)
    pp = lay((st([crack(0.04, 0, 0.7, 70, sd + 42), struck("energy", 0.25, sd + 691, 0.55)], p0), 0),
             (spark_rain(m, 0, -1, 18, rng, (90, 270), 1.4, 0.06), 0))
    twinkles(pp, rng, 14, (0.5, 1.4), 0.04, (p0 - 0.3, p0 + 0.3))
    full = shot(m, [(start, 0), (opn, OPEN * 0.7), (swirl, OPEN), (hit, BURST), (body, BURST), (rel, SHUT), (pp, POP)])
    return leveled(m, full, {"start": start, "open": opn, "swirl": swirl, "hit": hit, "body": body, "release": rel,
                             "tail": pp},
                   "rip tearing (0-0.21), open whoomp 0.21; quiet whirl with belches at 0.52/0.76; burst at 1.0 (crack, "
                   "floor knock + energy, smoke, sparks, chunks knocking, wisp pops ~1.8-2.0); swirl whipping up 1.9-2.22, pop "
                   "at 2.22, specks twinkling", -22)


def summon_rise(m):
    """start (0 .. IGN 0.5): the rune circle burns into the floor, two fronts running round it from the back to the front
    (x = -+ sin(ph) 36): a fire sizzle and crackle each, panned along its front. IGN: the circle catches (a soft
    whoomp); its fire then roars low under everything, on the JS's heat (flaring at the break and the eyes, dying in the
    fade). RUNES 0.78: the runes flare (a soft whoomp) and the ground starts to rumble, grit jumping (.. BREAK).
    hit (BREAK 1.05): the floor bursts: a crack, the ground's own weight (stone and earth: a dry heavy knock, a gritty
    crunch, a short low noise thud; no pitch drop), a gush of dust; 18 chunks knock down as stone and 60 grit tick on
    their own flights. body: the brute heaves up in two heaves (the JS's rise(): 1.05 .. 1.45,
    1.67 .. 2.12): earth sliding off it, a gravelly rush on the rise's speed; the second heave (1.69) heaves the
    earth again (a smaller earth knock) and throws 8 more chunks. EYES 2.3: the eyes flare: a short hot sizzle, sparks, a puff of dust. tail: the circle dies (FADE 3.4 ..
    4.2), the roar falling away, embers spitting."""
    sd = seed_of(m)
    rng = np.random.default_rng(sd)
    IGN, RUNES, BREAK, EYES, FADE = 0.5, 0.78, 1.05, 2.3, 3.4
    R0 = 36
    D = m["duration"]
    p0 = pan_of(m, 0)
    start = blank(IGN + 0.05)
    t = T(IGN)
    ph = t / IGN * np.pi
    for s in (-1, 1):
        x = -s * np.sin(ph) * R0
        sz = glitter(IGN, 0.4 + 0.6 * np.sin(ph / 2), 1, sd + s, 0.6) * 0.08
        cr = arcs(IGN, lambda a: 30, lambda a: 0.1, sd + 3 + s, short=False)
        put(start, st_path(sz + cr, np.array([pan_of(m, v) for v in x])), 0)
    D2 = D + 0.6
    t = T(D2)

    def smooth(a, b, x):
        v = np.clip((x - a) / (b - a), 0, 1)
        return v * v * (3 - 2 * v)
    heat = smooth(0, IGN, t) * (1 - smooth(FADE, FADE + 0.8, t)) * (1 - 0.25 * smooth(EYES + 0.2, EYES + 0.9, t)) * \
        (0.85 + 0.15 * loop_curve(t, D2, 9 / TAU, rng) + 0.5 * np.exp(-((t - BREAK) ** 2) / 0.02) + 0.3 * np.exp(-((t - EYES) ** 2) / 0.02))
    roar = noise(len(t), 10, seed=sd + 5) * q(heat / 1.5) * 0.12 + noise(len(t), 4, seed=sd + 6) * q(heat / 1.5) * 0.04
    bed = st(roar, p0)
    put(bed, st(wash(0.5, 10, 8, 1.0, 0.05, 5, sd + 7) * 0.25, p0), IGN)
    put(bed, st(wash(0.4, 9, 7, 1.0, 0.04, 6, sd + 8) * 0.2, p0), RUNES)
    t = T(BREAK - RUNES)
    u = t / (BREAK - RUNES)
    put(bed, st(noise(len(t), 15, seed=sd + 9) * q(0.2 + 0.8 * u ** 1.5) * 0.25 +
                arcs(BREAK - RUNES, lambda a: 40, lambda a: 0.06 + 0.1 * a / 0.27, sd + 10, short=False), p0), RUNES)
    hit = lay((st([crack(0.06, 2, 0.6, 45, sd + 11),
                   np.concatenate([np.zeros(int(0.03 * SR)), earth(0.9 * rng.uniform(0.93, 1.05), sd + 701, 0.95)]),
                   burst(0.35, 12, 0.4, 7, sd + 12)], p0), 0),
              (st(wash(0.9, 11, 13, 1.0, 0.03, 3, sd + 13) * 0.3, (p0, p0 - 0.5)), 0),
              (st(wash(0.9, 11, 13, 1.0, 0.03, 3, sd + 14) * 0.3, (p0, p0 + 0.5)), 0))
    body = blank(2.2)
    lands = []
    for _ in range(18):
        lands += fly(rng.uniform(-75, 75), -rng.uniform(170, 320), rng.uniform(-14, 14), -2, 1.0, 0.7, 0.32, rng.uniform(1.6, 2.4))
    put(body, debris(m, lands, 0.32, 8, weight=0.25, seed=sd + 16, mat="stone"), 0)
    grit = []
    for _ in range(60):
        uu = rng.uniform(-1, 1)
        a = -np.pi / 2 + uu * 0.7
        sp = rng.uniform(80, 230) * (1 - 0.4 * abs(uu))
        grit += grit_lands(np.cos(a) * sp, np.sin(a) * sp, uu * 10, -1, rng)
    put(body, debris(m, grit, 0.07, 5, seed=sd + 17), 0)

    def rise(x):
        a = (1 - (1 - np.clip((x - BREAK) / 0.4, 0, 1)) ** 3) * 0.56
        sag = 0.04 * np.sin(np.pi * np.clip((x - BREAK - 0.42) / 0.3, 0, 1))
        c1, c3 = 1.4, 2.4                                 # ease.outBack(x, 1.4)
        k = np.clip((x - BREAK - 0.62) / 0.45, 0, 1) - 1
        b = np.where(k <= -1, 0, 1 + c3 * k ** 3 + c1 * k ** 2) * 0.44
        return np.where(x < BREAK, 0, a - sag + b)
    t = T(1.2)
    rv = np.clip(np.gradient(rise(t + BREAK)) * SR, 0, None)
    slide = noise(len(t), np.where(rv > 1.0, 12, 13), seed=sd + 18) * q(np.clip(rv / 2.0, 0, 1)) * 0.25
    put(body, st(slide, p0), 0)
    l2 = []
    for _ in range(8):
        l2 += fly(rng.choice((-1, 1)) * rng.uniform(25, 70), -rng.uniform(90, 180), rng.choice((-1, 1)) * rng.uniform(10, 22), -2,
                  1.0, 0.7, 0.3, rng.uniform(1.2, 1.8))
    put(body, debris(m, l2, 0.22, 9, weight=0.15, seed=sd + 19, mat="stone"), 0.64)
    put(body, st(earth(0.4, sd + 702, 0.35), p0), 0.64)
    eyes = lay((st([burst(0.18, 1, 0.3, 16, sd + 20), wash(0.35, 6, 3, 1.0, 0.02, 8, sd + 21) * 0.18], p0), 0),
               (spark_rain(m, 0, -46, 10, rng, (40, 110), 1.2, 0.05), 0),
               (st(air(0.5, 9, 12, 1.0, sd + 22, "fall") * 0.08, p0), 0.02))
    tail = blank(1.4)
    for _ in range(8):
        place(tail, spit(rng.uniform(0.04, 0.08), int(rng.integers(1, 99)), 0.03), rng.uniform(0, 1.0), p0 + rng.uniform(-0.25, 0.25))
    full = shot(m, [(start, 0), (bed, 0), (hit, BREAK), (body, BREAK), (eyes, EYES), (tail, FADE)])
    return leveled(m, full, {"start": start, "fire": bed, "hit": hit, "body": body, "eyes": eyes, "tail": tail},
                   "circle burning in from both fronts (0-0.5), catches 0.5, runes flare 0.78, ground rumbling; floor "
                   "bursts at 1.05 (crack, earth knock + crunch, chunks + grit knocking); two heaves of sliding earth, second "
                   "throws chunks 1.69; eyes flare sizzle 2.3; circle dying 3.4-4.2", -21)


SOUNDS = {
    "coin-drop": coin_drop,
    "disintegrate": disintegrate,
    "dissolve-burn": dissolve_burn,
    "egg-hatch": egg_hatch,
    "poof": poof,
    "respawn-beam": respawn_beam,
    "shatter-death": shatter_death,
    "soul-rise": soul_rise,
    "spawn-portal": spawn_portal,
    "summon-rise": summon_rise,
}
