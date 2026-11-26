# melee: swish over the sweep, then the hit sounds like what is struck (references/sound.md rule 2, synth.material_hit).
# Every weapon follows the same shape on its act's own hits (port/meta.json act.timing): start = the windup (a quiet
# breath, no notes), the swing's air on the JS sweep window, the crack on each hit, the body only after the hit-stop,
# debris from the effect's own physics. Material picks the weight: a blade's edge rings steel and cuts into flesh, fists
# and claws smack flesh, a spear shaft toks wood, hammers and greatswords knock and crunch stone. No pitch-dropping
# thump: nothing here is a blast. Shared blocks live in cats/impacts.py.
import numpy as np
from synth import *  # noqa: F401,F403
from cats.impacts import (S, st, put, mix, out, crack, rumble, knock, ring, clank, glide, air, breath, fly,
                          grit_lands, debris, earth, pan_of, hits_of, windup_of, seed_of)


def sword_slash(m):
    """The effect starts with the sweep (t 0) and hits at 0.06 (act timing): the steel edge cuts into the target: the
    edge's scrape and short inharmonic ring, and a flesh smack under it. start: the act's windup, a low breath
    that rises; during the hit-stop the edge rings on unchanged."""
    sd = seed_of(m)
    full = blank(m["duration"])
    place(full, whoosh(0.16, 1, 7, 0.55, 4), 0.0)
    clank = S(metal_hit(0.5, sd + 2, 0.6), flesh_hit(0.45, sd + 3, 0.45))
    place(full, clank, 0.06, 0.3)
    w = m.get("act", {}).get("timing", {}).get("windup", 0.55)
    t = T(w)
    start = stereo(tri(NOTE(45) + 30 * t / w) * steps(np.clip(t / w, 0, 1) * 0.12))
    return Sound(full, {"start": start, "hit": stereo(clank), "swish": stereo(whoosh(0.16, 1, 7, 0.55, 4))},
                 "swish over the sweep (0-0.16), steel edge ring + flesh smack on the hit (0.06); start = the act's "
                 "windup")


def claw_swipe(m):
    """Three claw marks rake down one after another (t0 = 0, 0.04, 0.08, each tearing open over RAKE 0.05), each a rough
    tearing scrape with a small flesh smack on its hit (0.04, 0.08); the third is the act's real hit (0.12): a fuller
    flesh smack, its body after the 0.08 hit-stop. A couple of hot drips land softly. start: the windup's breath."""
    sd = seed_of(m)
    rng = np.random.default_rng(sd)
    hits = hits_of(m)
    p = pan_of(m, 40)
    start = st(breath(windup_of(m), 12, 8, 0.1, sd), p)
    rake = blank(0.2)
    for i, (th, fz) in enumerate(hits):
        q = p + (i - 1) * 0.12
        tear = air(0.07, 2 + i, 6, 0.28, sd + i, "fall") + noise(len(T(0.07)), 3, short=True, seed=sd + 9 + i) \
            * steps(decay(T(0.07), 30) * 0.1)
        put(rake, st(tear, q), i * 0.04)
        if i < len(hits) - 1:
            put(rake, st([crack(0.02, 4, 0.25, 90, sd + 20 + i), flesh_hit(0.15 + 0.1 * i, sd + 24 + i, 0.3)], q), th)
    th, fz = hits[-1]
    hit = st([crack(0.035, 3, 0.6, 60, sd + 30), flesh_hit(0.75, sd + 32, 0.8)], p + 0.12)
    body = st(rumble(0.2, 0.2, 12, 14, 0, 0, sd + 31), p + 0.12)
    tail = blank(0.5)
    for _ in range(2):
        put(tail, st(knock(0.08, int(rng.integers(1, 99)), 10, 0.04, 70), p + rng.uniform(-0.2, 0.3)), rng.uniform(0.2, 0.45))
    full = mix([(rake, 0), (hit, th), (body, th + fz), (tail, th + fz)], m["duration"])
    return out(full, {"start": start, "rake": rake, "hit": hit, "body": body, "tail": tail},
               "3 tearing rakes (0, 0.04, 0.08) with small flesh smacks on hits 0.04/0.08, full flesh smack at 0.12, "
               "body after the 0.08 hit-stop", 0.7)


DAGGER_CUTS = [(21, 1), (33, -1), (26, 1), (37, -1), (19, 1), (30, -1)]   # src/fx/melee/dagger-flurry.js CUTS (x, dir)


def dagger_flurry(m):
    """Six small cuts every EVERY 0.055 s (sweep 0.035) on the act's six small hits, each a short swish and a tiny steel
    tick, every one drawn differently (rate, glint pitch, level, pan) so the run is a flurry and not a beat; then the
    big cut (t0 0.37, sweep 0.055) clanks on its hit (0.42), the edge biting flesh under it, and glints and bursts after
    its 0.12 hit-stop."""
    sd = seed_of(m)
    rng = np.random.default_rng(sd)
    hits = hits_of(m)
    start = st(breath(windup_of(m), 11, 7, 0.09, sd), pan_of(m, 25))
    flurry = blank(0.45)
    for k, ((x, d), (th, fz)) in enumerate(zip(DAGGER_CUTS, hits)):
        q = pan_of(m, x) + 0.15 * d
        g = rng.uniform(0.75, 1.1)
        put(flurry, st(whoosh(0.05, int(rng.integers(0, 3)), int(rng.integers(5, 9)), 0.32 * g, sd + k), (q - 0.1 * d, q + 0.1 * d)), k * 0.055)
        put(flurry, st([crack(0.02, 1, 0.3 * g, 120, sd + 10 + k, short=True),
                        blip(rng.uniform(1900, 3100), 0.06, 0.125, 0.1 * g, 40)], q), th)
    th, fz = hits[-1]
    p = pan_of(m, 24)
    swish = st(air(0.07, 0, 7, 0.5, sd + 20), (p + 0.25, p - 0.15))
    hit = st([clank(1500 * rng.uniform(0.94, 1.06), 0.3, 0.35, 9, sd + 21), crack(0.03, 1, 0.5, 70, sd + 22),
              flesh_hit(0.35, sd + 24, 0.45)], p)
    body = st([crack(0.22, 2, 0.22, 12, sd + 23), ring(1900, 0.4, 0.08, 9)], p)
    full = mix([(flurry, 0), (swish, 0.37), (hit, th), (body, th + fz)], m["duration"])
    return out(full, {"start": start, "flurry": flurry, "swish": swish, "hit": hit, "body": body},
               "6 varied swish+ticks on the small hits (0.05-0.325), big swish 0.37, clank + flesh smack 0.42, glint burst after "
               "the 0.12 hit-stop", 0.63)


def double_slash(m):
    """A down cut (t0 0, sweep 0.06) clanks lightly on hit 1 (0.06); the up cut (UP 0.14) crosses it and the X closes
    on hit 2 (0.16): a full clank and crack, then after its 0.14 hit-stop the crossing bursts (bright fizz)."""
    sd = seed_of(m)
    rng = np.random.default_rng(sd)
    (t1, f1), (t2, f2) = hits_of(m)
    p = pan_of(m, 34)
    start = st(breath(windup_of(m), 11, 7, 0.1, sd), p)
    sw1 = st(whoosh(0.08, 1, 7, 0.5, sd + 1), (p - 0.2, p + 0.15))
    sw2 = st(whoosh(0.08, 0, 6, 0.55, sd + 2), (p + 0.2, p - 0.15))
    f = 1300 * rng.uniform(0.94, 1.06)
    hit1 = st(clank(f, 0.2, 0.3, 11, sd + 3), p)
    hit = st([clank(f * 1.17, 0.33, 0.4, 8, sd + 4), crack(0.03, 1, 0.5, 70, sd + 5)], p)
    body = st([crack(0.3, 2, 0.24, 10, sd + 6), ring(f * 1.6, 0.35, 0.06, 10)], p)
    full = mix([(sw1, 0), (hit1, t1), (sw2, 0.14), (hit, t2), (body, t2 + f2)], m["duration"])
    return out(full, {"start": start, "swish": sw1, "hit1": hit1, "swish2": sw2, "hit": hit, "body": body},
               "down swish 0, light clank 0.06, up swish 0.14, full clank at the X 0.16, burst after the 0.14 hit-stop",
               0.65)


def hammer_smash(m):
    """The hammer comes over and down (DROP 0.15), its air growing to the slam; at the hit (0.15, hit-stop 0.2) steel on
    stone: a crack, the heaviest stone knock and crunch, and a dull low clank of the head. After the freeze a short low
    ground body and the dust rolling both ways; the 15 rocks thrown from the dent (bounce 0.38) and 11 chips land on
    their own flights, as stone knocks sized by the rock."""
    sd = seed_of(m)
    rng = np.random.default_rng(sd)
    (th, fz), = hits_of(m)
    X = 30
    p = pan_of(m, X)
    start = st(breath(windup_of(m), 13, 10, 0.12, sd), p - 0.1)
    swing = st(air(th, 10, 5, 0.55, sd + 1, "rise"), (p - 0.3, p))
    hit = st([crack(0.06, 1, 0.6, 40, sd + 8), earth(1.0, sd + 2, 0.95),
              ring(330, 0.25, 0.14, 14, 5, 1.43)], p)
    body = st(rumble(0.6, 0.55, 14, 5, 0, 0, sd + 4), p)
    put(body, st(air(1.0, 9, 12, 0.1, sd + 5), (p - 0.1, p - 0.8)) + st(air(1.0, 9, 12, 0.1, sd + 6), (p + 0.1, p + 0.8)), 0)
    lands = []
    for i in range(15):
        s = rng.choice([-1, 1])
        sz = rng.choice([1, 1, 2, 2, 3])
        L = fly(s * rng.uniform(20, 105), -rng.uniform(110, 300), X + s * rng.uniform(0, 5), -2, 1, 0.35, 0.38,
                rng.uniform(1.25, 1.65))
        lands.append(([(t, v * (0.7 + 0.15 * sz), x) for t, v, x in L], sz))
    tail = blank(1.8)
    for L, sz in lands:
        put(tail, debris(m, L, 0.22, 11 - sz, weight=0.15 * sz, vref=320, seed=int(rng.integers(1, 999)), mat="stone"), 0)
    chips = []
    for i in range(11):
        a = -np.pi / 2 + rng.uniform(-1.2, 1.2)
        sp = rng.uniform(90, 230)
        chips += fly(np.cos(a) * sp, np.sin(a) * sp, X + rng.uniform(-4, 4), -2, 0.9, 0.5, 0.35, rng.uniform(0.9, 1.5))
    put(tail, debris(m, chips, 0.12, 6, vref=230, seed=sd + 7), 0)
    full = mix([(swing, 0), (hit, th), (body, th + fz), (tail, th + fz)], m["duration"])
    return out(full, {"start": start, "swish": swing, "hit": hit, "body": body, "tail": tail},
               "heavy air growing over the drop (0-0.15), crack + stone knock/crunch + dull clank at the slam (0.15), "
               "short ground body and dust after the 0.2 hit-stop, 15 rocks + 11 chips land and bounce", 0.615)


def heavy_cleave(m):
    """The blade is raised (0-RAISE 0.2: the glint is light, silent), then the arc accelerates over the top (SWING
    0.2-0.335) as rising air; at the hit (0.335, hit-stop 0.2) the greatsword bites stone: a crack, a heavy stone knock
    and crunch, and a steel clank. After the freeze: a short low ground body, dust rolling both ways, grit and stones
    thrown forward. The embers lifting off are silent (rule 4: no ember crackle)."""
    sd = seed_of(m)
    rng = np.random.default_rng(sd)
    (th, fz), = hits_of(m)
    X = 35
    p = pan_of(m, X)
    start = st(breath(windup_of(m), 12, 9, 0.1, sd), p - 0.2)
    swing = st(air(th - 0.2, 9, 2, 0.6, sd + 1, "rise"), (p - 0.4, p))
    hit = st([crack(0.06, 1, 0.6, 40, sd + 8), earth(0.9, sd + 2, 0.9), clank(560, 0.22, 0.4, 10, sd + 3)], p)
    body = st(rumble(0.6, 0.55, 14, 5, 0, 0, sd + 4), p)
    put(body, st(air(0.9, 9, 12, 0.1, sd + 5), (p - 0.1, p - 0.8)) + st(air(0.9, 9, 12, 0.1, sd + 6), (p + 0.1, p + 0.8)), 0)
    lands = []
    for i in range(9):
        a = -np.pi / 2 + rng.uniform(0.1, 1.0)
        v = rng.uniform(80, 220)
        lands += grit_lands(np.cos(a) * v, np.sin(a) * v, X + rng.uniform(-3, 3), -1, rng)
    tail = debris(m, lands, 0.2, 8, vref=220, seed=sd + 7)
    full = mix([(swing, 0.2), (hit, th), (body, th + fz), (tail, th + fz)], m["duration"])
    return out(full, {"start": start, "swish": swing, "hit": hit, "body": body, "tail": tail},
               "air accelerating over the arc (0.2-0.335), crack + stone knock/crunch + steel clank at the floor "
               "(0.335), short ground body, dust both ways and grit after the 0.2 hit-stop", 0.65)


def scythe_reap(m):
    """A slow huge reap: the sweep (WIND 0.08 to 0.42) is a long low rush moving right to left round the front; the
    act's hit (0.14, hit-stop 0.12) is a dull cut into a body (a flesh smack) with a cold hiss (shadow skin); the rest
    of the sweep resumes after the freeze, and the crescent tearing into cold vapour (TEAR 0.56-1.11) is a ragged fading
    hiss."""
    sd = seed_of(m)
    rng = np.random.default_rng(sd)
    (th, fz), = hits_of(m)
    p0, p1 = 0.5, -0.5
    start = st(breath(windup_of(m), 13, 10, 0.1, sd), p0)
    a, b = 0.08, 0.42
    k = (th - a) / (b - a)
    pre = st(air(th - a, 10, 7, 0.4, sd + 1, "rise"), (p0, p0 + (p1 - p0) * k))
    post = st(air(b - th, 7, 11, 0.4, sd + 2, "fall"), (p0 + (p1 - p0) * k, p1))
    hit = st([crack(0.03, 4, 0.55, 60, sd + 3), flesh_hit(0.5, sd + 6, 0.6),
              crack(0.1, 1, 0.15, 25, sd + 4)], p0 + (p1 - p0) * k)
    t = T(0.6)
    flutter = rng.uniform(0.4, 1.0, len(t) // (SR // 60) + 1).repeat(SR // 60)[: len(t)]
    tear = noise(len(t), np.round(np.interp(t, [0, 0.6], [1, 3])).astype(int), seed=sd + 5) \
        * steps(np.sin(np.pi * np.clip(t / 0.6, 0, 1)) ** 0.7 * flutter * 0.12)
    tail = st(tear, (p1 + 0.2, p1 - 0.2))
    full = mix([(pre, a), (hit, th), (post, th + fz), (tail, 0.56 + fz)], m["duration"])
    return out(full, {"start": start, "swish": pre, "hit": hit, "body": post, "tail": tail},
               "long low rush over the sweep (0.08-0.42, R to L) split by the dull cut at 0.14 and its 0.12 "
               "hit-stop, ragged cold hiss as it tears away (0.56)", 1.12)


def spear_sweep(m):
    """A wide low sweep (sweep 0.13, ease outExpo: fastest at the start) from behind the left leg round to the right;
    the shaft cracks into the shins at the hit (0.1, hit-stop 0.12): wood and flesh, a hollow 'tok' and a smack. After
    the freeze the wake of dust rolls on to the right, and grit ticks down."""
    sd = seed_of(m)
    rng = np.random.default_rng(sd)
    (th, fz), = hits_of(m)
    start = st(breath(windup_of(m), 12, 9, 0.1, sd), -0.3)
    t = T(0.16)
    sw = noise(len(t), np.round(np.interp(t, [0, 0.16], [2, 8])).astype(int), seed=sd + 1) \
        * steps(np.clip(t / 0.02, 0, 1) * np.exp(-t / 0.06) * 0.6)
    swish = st(sw, (-0.6, 0.6))
    hit = st([crack(0.025, 3, 0.45, 80, sd + 2), wood_hit(0.5, sd + 6, 0.4), flesh_hit(0.4, sd + 7, 0.5)], pan_of(m, 30))
    body = st(air(0.7, 8, 12, 0.18, sd + 4, "fall"), (0.3, 0.8))
    lands = []
    for i in range(6):
        a = -np.pi / 2 + rng.uniform(0.2, 1.0)
        v = rng.uniform(60, 150)
        lands += grit_lands(np.cos(a) * v, np.sin(a) * v, rng.uniform(10, 50), -1, rng)
    tail = debris(m, lands, 0.16, 8, vref=180, seed=sd + 5)
    full = mix([(swish, 0), (hit, th), (body, th + fz), (tail, th + fz)], m["duration"])
    return out(full, {"start": start, "swish": swish, "hit": hit, "body": body, "tail": tail},
               "wide swish L->R front-loaded (0-0.16), wood tok + flesh smack at the shins (0.1), dust wake rolling "
               "right and grit after the 0.12 hit-stop", 0.99)


def spin_slash(m):
    """The edge goes once round the waist (SW 0.17, a0 0.5, dir -1): its air pans with the edge's x and dips while
    it is behind the body; the ring closes on the hit (0.17, hit-stop 0.12) with a steel clank; after the freeze the
    ring flares and dissolves into a soft fading rush."""
    sd = seed_of(m)
    rng = np.random.default_rng(sd)
    (th, fz), = hits_of(m)
    start = st(breath(windup_of(m), 11, 7, 0.1, sd), 0)
    t = T(th)
    U = 2 * np.pi * (1 - (1 - np.clip(t / th, 0, 1)) ** 1.6)      # turn(t): fraction of the turn, as the JS
    ang = 0.5 - U
    behind = np.sin(ang) < 0
    sw = noise(len(t), np.round(np.interp(t, [0, th], [1, 6])).astype(int), seed=sd + 1) \
        * steps(np.sin(np.pi * np.clip(t / th, 0, 1)) ** 0.5 * np.where(behind, 0.55, 1.0) * 0.5)
    pan = 0.65 * np.cos(ang)
    swish = np.stack([sw * np.sqrt((1 - pan) / 2), sw * np.sqrt((1 + pan) / 2)], 1) * np.sqrt(2)
    p = 0.65 * np.cos(0.5)
    hit = st([clank(1250 * rng.uniform(0.94, 1.06), 0.32, 0.4, 8, sd + 2), crack(0.03, 1, 0.45, 70, sd + 3)], p)
    body = st(air(0.3, 2, 6, 0.14, sd + 4, "fall"), (p, -p))
    full = mix([(swish, 0), (hit, th), (body, th + fz)], m["duration"])
    return out(full, {"start": start, "swish": swish, "hit": hit, "body": body},
               "a full-turn swish panned with the edge, dipping behind the body (0-0.17), clank as the ring closes "
               "(0.17), fading rush after the 0.12 hit-stop", 0.715)


def thrust(m):
    """A stab: a short sharp rush of air as the point shoots out (OUT 0.07), from the hand to the tip; the pierce at the
    hit (0.07, hit-stop 0.12) is a thin metallic crack, a small flesh smack and a bright tink; after the freeze and the
    HOLD 0.06 the blade pulls back (PULL 0.2) with a soft reverse rush."""
    sd = seed_of(m)
    rng = np.random.default_rng(sd)
    (th, fz), = hits_of(m)
    ph, pt = pan_of(m, 9), pan_of(m, 9 + m["options"].get("reach", 66))
    start = st(breath(windup_of(m), 12, 8, 0.1, sd), ph)
    swish = st(air(th + 0.02, 3, 0, 0.45, sd + 1, "rise"), (ph, pt))
    hit = st([crack(0.02, 1, 0.6, 110, sd + 2, short=True), flesh_hit(0.3, sd + 4, 0.45),
              blip(rng.uniform(2600, 3200), 0.12, 0.125, 0.12, 30)], pt)
    body = st(air(0.2, 6, 3, 0.18, sd + 3), (pt, ph))
    full = mix([(swish, 0), (hit, th), (body, th + fz + 0.06)], m["duration"])
    return out(full, {"start": start, "swish": swish, "hit": hit, "body": body},
               "short sharp rush hand->tip (0-0.07), pierce crack + flesh smack + tink (0.07), pull-back rush after the "
               "0.12 hit-stop and the 0.06 hold", 0.9)


def uppercut(m):
    """A fist rising (crescent t0 0.02, sweep 0.07): a quick rising rush; at the top the punch lands (hit 0.076,
    hit-stop 0.13) on flesh: a crack and a heavy flesh smack with its short low push, no metal, no pitched drop; a short
    body after the freeze."""
    sd = seed_of(m)
    (th, fz), = hits_of(m)
    p = pan_of(m, 20)
    start = st(breath(windup_of(m), 12, 8, 0.1, sd), p)
    swish = st(air(th - 0.02 + 0.01, 8, 2, 0.45, sd + 1, "rise"), p)
    hit = st([crack(0.03, 3, 0.8, 60, sd + 2), flesh_hit(0.9, sd + 4, 0.9)], p)
    body = st(rumble(0.25, 0.28, 12, 12, 0, 0, sd + 3), p)
    full = mix([(swish, 0.02), (hit, th), (body, th + fz)], m["duration"])
    return out(full, {"start": start, "swish": swish, "hit": hit, "body": body},
               "quick rising rush (0.02-0.076), punch crack + heavy flesh smack at the top (0.076), short body after the "
               "0.13 hit-stop", 0.765)


def whip_crack(m):
    """The whip's loop runs out (ROLL0 0.02 .. CRACK 0.21) faster and faster: air whose rate climbs and swells, panned
    from the hand to the tip; the tip breaks the air at the hit (0.21, hit-stop 0.1): a very sharp short crack, a
    tiny snap, almost no weight. After the freeze the ring of air and puff of smoke hiss, and the whip recoils
    (RECOIL 0.16) with a soft rush back."""
    sd = seed_of(m)
    rng = np.random.default_rng(sd)
    (th, fz), = hits_of(m)
    ph, pt = pan_of(m, 11), pan_of(m, 11 + m["options"].get("length", 76))
    start = st(breath(windup_of(m), 12, 8, 0.1, sd), ph)
    t = T(th - 0.02)
    u = t / (th - 0.02)
    roll = noise(len(t), np.round(10 - 9 * u ** 1.5).astype(int), seed=sd + 1) * steps(u ** 2 * 0.45)
    swish = st(roll, (ph, pt))
    hit = st([crack(0.018, 0, 1.0, 140, sd + 2), crack(0.012, 1, 0.5, 160, sd + 3, short=True),
              glide(1900 * rng.uniform(0.92, 1.08), 600, 0.035, 0.3, 0.25, 50)], pt)
    body = st(crack(0.25, 2, 0.16, 10, sd + 4), pt)
    recoil = st(air(0.16, 5, 9, 0.15, sd + 5), (pt, ph))
    full = mix([(swish, 0.02), (hit, th), (body, th + fz), (recoil, th + fz)], m["duration"])
    return out(full, {"start": start, "swish": swish, "hit": hit, "body": body, "recoil": recoil},
               "air rolling out faster and rising (0.02-0.21) hand->tip, a very sharp crack at the tip (0.21), hiss "
               "and recoil rush after the 0.1 hit-stop", 0.8)


SOUNDS = {
    "sword-slash": sword_slash,
    "claw-swipe": claw_swipe,
    "dagger-flurry": dagger_flurry,
    "double-slash": double_slash,
    "hammer-smash": hammer_smash,
    "heavy-cleave": heavy_cleave,
    "scythe-reap": scythe_reap,
    "spear-sweep": spear_sweep,
    "spin-slash": spin_slash,
    "thrust": thrust,
    "uppercut": uppercut,
    "whip-crack": whip_crack,
}
