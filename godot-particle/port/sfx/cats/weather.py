# weather: most of the sky makes no noise (references/sound.md, rule 2): fog, clouds, aurora, god-rays, fireflies,
# drifting leaves and petals, falling snow and far meteors are silent. Global environment that does make noise (rain,
# a gale, a storm) gets a quiet loop of its material only: hiss and patter, moving air; no accents, about 15-20 dB
# under a hit. A storm's strike is its strong moment and stays a one-shot phase of its own (cats/lightning.py
# storm-cloud), the in-cloud flashes soft far grumbles. Beats from src/fx/weather/<name>.js.
import numpy as np
from synth import *  # noqa: F401,F403
from cats.impacts import seed_of, pan_of, st, put
from cats.projectiles import lput, db, top, ticks
from cats.lightning import zap, buzz, thunder, crackle, spark_lands
from cats.fire import loop_curve, moving
from cats.ice import q

FPS = 30
MASTER = 0.5        # make.py's master gain
TAU = 2 * np.pi


def at_db(buf, target):
    """buf scaled so it measures `target` dB RMS after make.py's master gain."""
    return buf * 10 ** ((target - db(buf * MASTER)) / 20)


def at_top(buf, target):
    """buf scaled so its loudest 100 ms measures `target` dB after the master gain (how hard a one-shot hits)."""
    return buf * 10 ** ((target - top(buf * MASTER)) / 20)


# ------------------------------------------------------------------ voices of weather
def hiss(secs, P, rng, seed, rates=(1, 3), mix=(0.7, 0.3), depth=0.12, flick=1.5):
    """Rain as a bed: bright noise, a decorrelated take in each ear (wide, not a point), its level drifting with the
    gusts on a smooth curve that repeats every P (no accents). Stereo, at full scale."""
    t = T(secs)
    w = q(1 - depth + depth * loop_curve(t, P, flick, rng))
    ch = []
    for side in (0, 1):
        s = sum(noise(len(t), r, seed=seed + 10 * side + i) * k for i, (r, k) in enumerate(zip(rates, mix)))
        ch.append(s * w)
    return np.stack(ch, 1)


def patter(secs, P, rng, per_s, vol, pans=(-0.8, 0.8), rate=(2, 5)):
    """Drops landing everywhere at once: so many tiny wet ticks (random times, places, strengths) that they make a
    texture, never a beat. Built at full scale, then mixed down (steps() would round faint ones to nothing)."""
    kinds = []
    for i in range(10):
        t = T(0.018)
        kinds.append(noise(len(t), int(rng.integers(rate[0], rate[1] + 1)), seed=100 + i) * q(decay(t, 200)))
    buf = blank(secs)
    for at in rng.uniform(0, P, int(per_s * P)):
        lput(buf, st(kinds[int(rng.integers(0, 10))] * rng.uniform(0.3, 1), rng.uniform(*pans)), at, P)
    return buf * vol


def grumble(secs, vol, seed, attack=0.18, k=2.2):
    """Thunder far off inside the clouds: a slow swell of the lowest noise, no crack."""
    t = T(secs)
    env = np.minimum(1, t / attack) * decay(np.maximum(0, t - attack), k)
    return noise(len(t), np.where(t < attack, 14, 15), seed=seed) * q(env) * vol


# ------------------------------------------------------------------ environment loops
def rain(m):
    """Global environment, so a quiet loop of its material and nothing else: the hiss of rain everywhere (a take in
    each ear), its level drifting a little as the JS's gust sheets sweep across (a smooth curve, a whole number of
    swells a loop), the near drops' splashes (about 140 a second on screen: 42 near drops x 25-29 falls a loop) as a
    dense patter of tiny wet ticks spread across the floor, a soft low wash of water under it. No accents."""
    sd = seed_of(m)
    rng = np.random.default_rng(sd)
    P = m["duration"]
    S = P + X
    bed = hiss(S, P, rng, sd, (1, 3), (0.65, 0.35), 0.12, 1.2) * 0.32
    t = T(S)
    wash = noise(len(t), 9, seed=sd + 5) * q(0.9 + 0.1 * loop_curve(t, P, 1, rng)) * 0.12
    bed += stereo(wash)
    bed += patter(S, P, rng, 140, 0.11)
    loop = at_db(wrap(bed, P), -33)
    return Sound(loop, {"loop": loop},
                 "loop: rain hiss (a take per ear) drifting with the gust sheets, dense splash patter, low wash; no accents")


def blizzard(m):
    """A gale, so global environment: a quiet loop of moving air and snow and nothing else. The JS's gusts are waves
    rolling left to right, two a loop (gustAt: sin(TAU((x + 160)/400 - 2t/D) + 0.8)): the wind swells with how much
    of the sky the gust covers and its pan follows the gust's crest across, a smooth curve, no beat. Under it a low
    steady roar; over it the snow's hiss brightening in the gust (spindrift streaming off the drift)."""
    sd = seed_of(m)
    rng = np.random.default_rng(sd)
    P = m["duration"]
    S = P + X
    t = T(S)
    xs = np.linspace(-160, 160, 81)
    tf = np.arange(int(np.ceil(S * FPS)) + 1) / FPS
    g = 0.5 + 0.5 * np.sin(TAU * ((xs[None, :] + 160) / 400 - 2 * tf[:, None] / P) + 0.8)
    level = g.mean(1)                                                     # how much of the sky the gust covers
    w = g ** 3
    cx = (w * xs).sum(1) / w.sum(1)                                       # where its crest is
    lv = np.interp(t, tf, (level - level.min()) / (level.max() - level.min()))
    pan = np.interp(t, tf, np.array([pan_of(m, x) for x in cx]))
    roar = noise(len(t), 13, seed=sd) * q(0.75 + 0.25 * lv) * 0.32
    body = noise(len(t), 7, seed=sd + 1) * q(0.25 + 0.75 * lv ** 1.3) * 0.36
    snow = noise(len(t), 1, seed=sd + 2) * q(0.2 + 0.8 * lv ** 2) * 0.12
    buf = stereo(roar)
    moving(buf, body, 0, pan)
    moving(buf, snow, 0, pan * 0.8)
    loop = at_db(wrap(buf, P), -32)
    return Sound(loop, {"loop": loop},
                 "loop: low wind roar, a gust body swelling twice a loop and panning left to right with the JS's gust "
                 "crest, snow hiss brightening in the gust; no accents")


def storm(m):
    """Global environment with a strike in it (cats/lightning.py storm-cloud). loop: the driving rain's hiss and patter
    and a low wind, steady, no accents. strike (one-shot, from the stepped leader 2.62): the leader feeling down in 9
    steps (crackles getting louder as it nears), the stroke at T1 3.0 (a white crack and the bolt's own weight where it
    lands at x 52: energy, a zap gliding down and a noise whoomp, never a falling pulse thump; the channel buzzing on
    its flicker table F1), arcs skittering out along the wet floor, sparks skipping, the wet floor steaming; the
    restrike at T2 3.3 (a crack, buzz on F2); thunder rolling on from each. sheet: the sheet lightning at 6.4 (pulses
    6.48, 6.7) as a far grumble swelling in from the left; the far flickers (8.6 right, 0.9 left) as fainter
    grumbles."""
    sd = seed_of(m)
    rng = np.random.default_rng(sd)
    P = m["duration"]
    S = P + X
    T_LEAD, T1, T2, T_SHEET, T_FAR, T_FAR2 = 2.62, 3.0, 3.3, 6.4, 8.6, 0.9
    F1, F2 = [1, 0.62, 0.95, 0.4, 0.7, 0.22], [0.92, 0.5, 0.8, 0.3, 0.12]
    BX = 52
    pb = pan_of(m, BX)
    t = T(S)
    bed = hiss(S, P, rng, sd, (1, 2), (0.6, 0.4), 0.1, 1.0) * 0.32
    bed += patter(S, P, rng, 110, 0.1)
    wind = noise(len(t), 14, seed=sd + 7) * q(0.8 + 0.2 * loop_curve(t, P, 0.8, rng)) * 0.3
    bed += stereo(wind)
    bed = at_db(wrap(bed, P), -32)

    # the strike, on the effect clock from T_LEAD
    k0 = T1 - T_LEAD
    strike = blank(3.2)
    for i in range(9):                                     # the leader's steps (the JS's floor(.. * 9) / 9 reach)
        at = k0 * i / 9 + rng.uniform(0.005, 0.02)
        put(strike, st(zap(0.06 + 0.22 * (i / 8) ** 1.5, sd + 10 + i, 0.05, 90), pb), at)
    put(strike, st(crackle(k0, lambda a: 25 + 60 * a / k0, lambda a: 0.04 + 0.1 * a / k0, sd + 20), pb), 0)
    for ts, fl, k, j in ((T1, F1, 1.0, 0), (T2, F2, 0.8, 1)):
        a = ts - T_LEAD
        put(strike, st([zap(0.95 * k, sd + 30 + j, 0.2, 45), material_hit("energy", 0.6 * k, sd * 7 + 601 + j, 0.55 * k)], pb), a)
        put(strike, st(buzz(fl, 0.28 * k, sd + 32 + j), pb), a + 0.01)
        for s in (-1, 1):                                  # arcs skittering out along the wet floor while it flashes
            c = crackle(len(fl) / FPS, lambda u: 60, lambda u: 0.12 * k, sd + 34 + 2 * j + s)
            put(strike, st(c, (pb, float(np.clip(pb + s * 0.25, -1, 1)))), a + 0.02)
        put(strike, st(thunder(2.4 if j == 0 else 1.4, 0.36 * k, sd + 40 + j, 1.1 if j == 0 else 1.7, 4), pb * 0.6), a + 0.05)
    tl = T(1.2)
    steam = noise(len(tl), 0, seed=sd + 45) * q(np.minimum(1, tl / 0.05) * decay(tl, 3.2)) * 0.12
    put(strike, st(steam, pb), k0 + 0.06)
    put(strike, spark_lands(m, BX, -1, 16, rng, (110, 420), 1.35, 0.06), k0)
    strike = at_top(strike, -15)

    sheet = st(grumble(1.6, 0.4, sd + 50, 0.12, 2.0), pan_of(m, -96) * 0.6)
    put(sheet, st(grumble(1.3, 0.55, sd + 51, 0.15, 2.4), pan_of(m, -60) * 0.6), 0.25)
    sheet = at_top(sheet, -25)
    far = at_top(st(grumble(1.0, 0.4, sd + 52, 0.1, 3.0), pan_of(m, 128) * 0.6), -28)
    far2 = at_top(st(grumble(0.9, 0.4, sd + 53, 0.1, 3.2), pan_of(m, -40) * 0.6), -30)

    ev = blank(S)
    lput(ev, strike, T_LEAD, P)
    lput(ev, sheet, T_SHEET + 0.06, P)
    lput(ev, far, T_FAR + 0.04, P)
    lput(ev, far2, T_FAR2 + 0.04, P)
    full = wrap(ev, P) + bed
    return Sound(full, {"loop": bed, "strike": strike, "sheet": sheet, "far": far},
                 "loop: driving rain hiss + patter + low wind (no accents); strike one-shot from 2.62: leader stepping "
                 "down, crack + energy whoomp at 3.0, restrike 3.3, buzz on the flicker, floor arcs, sparks, steam, thunder; "
                 "sheet lightning 6.4 as a far grumble; fainter grumbles under the far flickers (8.6, 0.9)")


# ------------------------------------------------------------------ silent
def aurora(m):
    return Silent("curtains of light rippling over the stars: light makes no noise, a steady thing stays silent (rule 2)")


def cherry_blossoms(m):
    return Silent("petals drifting down on a light breeze: a steady thing with no noise of its own (rule 2); the breeze "
                  "is no gale, so it is not a global wind loop")


def clouds(m):
    return Silent("clouds drifting past the moon: a steady thing with no noise of its own (rule 2)")


def falling_leaves(m):
    return Silent("leaves swinging down and settling in the litter: a steady thing with no noise of its own (rule 2); "
                  "its gusts are a breeze, not a gale")


def fireflies(m):
    return Silent("fireflies glowing up and fading over the grass: light, a steady thing with no noise (rule 2)")


def fog(m):
    return Silent("banks of fog drifting: a steady thing with no noise of its own (rule 2)")


def god_rays(m):
    return Silent("shafts of light swaying, dust motes drifting through them: light, a steady thing with no noise (rule 2)")


def shooting_stars(m):
    return Silent("meteors burning across a far night sky: too far to be heard, light only, a steady sky (rule 2); a whoosh "
                  "would be magic, not material (rule 5)")


def snow(m):
    return Silent("snow drifting down in a gentle breeze and settling: falling snow makes no noise (rule 2); a gale is the "
                  "blizzard's loop")


SOUNDS = {
    "aurora": aurora,
    "blizzard": blizzard,
    "cherry-blossoms": cherry_blossoms,
    "clouds": clouds,
    "falling-leaves": falling_leaves,
    "fireflies": fireflies,
    "fog": fog,
    "god-rays": god_rays,
    "rain": rain,
    "shooting-stars": shooting_stars,
    "snow": snow,
    "storm": storm,
}
