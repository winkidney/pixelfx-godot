# impacts: everything here lands, so every one follows the hit recipe (references/sound.md, rule 2): a bright crack,
# then the weight of what is struck (synth.material_hit: flesh smacks, stone knocks and crunches, steel rings, energy
# zaps), a short body after any hit-stop, then debris landing on the times the effect's own physics gives (GRAVITY
# 950 px/s², the bits' drag and bounce), panned with each piece's x. Size sets the weight, the effect's seed varies it.
# The pitch-dropping `thump` stays here for the categories that import it, but it is a blast's weight only: none of
# these hits is an explosion, so none of them uses it.
import numpy as np
from synth import *  # noqa: F401,F403

G = 950.0     # src/core/sim.js GRAVITY


# ------------------------------------------------------------------ helpers shared with cats/melee.py
def seed_of(m):
    return int(m.get("options", {}).get("seed", 1))


def hits_of(m):
    """[(t, freeze)] of the act's hits; [] for a plain sim effect."""
    return [(h["t"], h["freeze"]) for h in m.get("act", {}).get("timing", {}).get("hits", [])]


def windup_of(m, default=0.4):
    return m.get("act", {}).get("timing", {}).get("windup", default)


def pan_of(m, x):
    """Pan of a point x px right of the effect's origin, from where it sits in the effect's frame."""
    w, ox = m["size"][0], m["origin"][0]
    return float(np.clip((ox + x - w / 2) / (w / 2), -1, 1) * 0.7)


def S(*sigs):
    """Mono signals of different lengths summed, all from t 0."""
    out = np.zeros(max(len(x) for x in sigs))
    for x in sigs:
        out[:len(x)] += x
    return out


def st(sig, pan=0.0):
    """Mono (or a list of monos, summed) -> stereo with a fixed pan, or a moving one when pan is (p0, p1)."""
    if isinstance(sig, (list, tuple)):
        sig = S(*sig)
    if isinstance(pan, tuple):
        p = np.linspace(pan[0], pan[1], len(sig))
        return np.stack([sig * np.sqrt((1 - p) / 2), sig * np.sqrt((1 + p) / 2)], 1) * np.sqrt(2)
    return stereo(sig, pan)


def put(buf, s, at, gain=1.0):
    """Mix a stereo part into a stereo buffer at `at` seconds."""
    i = int(round(at * SR))
    if i >= len(buf) or i < 0:
        return
    n = min(len(s), len(buf) - i)
    buf[i:i + n] += s[:n] * gain


def mix(parts, secs):
    """[(stereo part, at)] -> one stereo buffer long enough for all of them (at least secs)."""
    n = max([int(round(secs * SR))] + [int(round(a * SR)) + len(s) for s, a in parts])
    buf = np.zeros((n, 2))
    for s, a in parts:
        put(buf, s, a)
    return buf


def out(full, phases, notes, gain=1.0):
    """The Sound, every part scaled by one gain (sets the effect's level, keeps its balance)."""
    return Sound(full * gain, {k: v * gain for k, v in phases.items()}, notes)


def crack(secs=0.045, rate=2, vol=0.8, k=55, seed=1, short=False):
    """The bright noise crack that opens a hit."""
    t = T(secs)
    return noise(len(t), rate, short, seed) * steps(decay(t, k) * vol)


def thump(f0=300, f1=46, secs=0.35, vol=0.6, k=7, kf=10, duty=0.5):
    """A pulse whose pitch drops fast (300 -> 46 Hz): the weight of a blast (explosions, shockwaves) only; any other
    hit takes its weight from the struck material (synth.material_hit)."""
    t = T(secs)
    return pulse(f1 + (f0 - f1) * decay(t, kf), duty) * steps(decay(t, k) * vol)


def rumble(secs=1.5, vol=0.45, rate=14, k=1.6, sub=70, subvol=0.35, seed=3):
    """The low noise body of a hit, with a falling triangle under it."""
    t = T(secs)
    b = noise(len(t), rate, seed=seed) * steps(decay(t, k) * vol)
    if subvol:
        b = b + tri(sub * decay(t, 0.8) + 40) * steps(decay(t, k * 0.75) * subvol)
    return b


def knock(vol=0.25, seed=1, rate=9, secs=0.06, k=55, weight=0.0):
    """A stone or clod landing: a short burst of long-mode noise (lower rate = heavier), with a tiny drop under it."""
    t = T(secs)
    s = noise(len(t), rate, seed=seed) * steps(decay(t, k) * vol)
    if weight:
        s += pulse(55 + 120 * decay(t, 40), 0.5) * steps(decay(t, k * 0.8) * vol * weight)
    return s


def earth(weight=0.8, seed=1, vol=0.7):
    """Heavy stone or earth struck (a slam, a landing, a hammer): the material's dry knock and crunch, with a short
    low-rate noise thud under it for the mass. No tone that glides: the weight is the ground's, not a drum's."""
    t = T(0.15 + 0.3 * weight)
    thud = noise(len(t), 12 + int(round(2 * weight)), seed=seed + 7) * steps(decay(t, 24 - 13 * weight) * vol * 0.8)
    return S(material_hit("stone", weight, seed, vol), thud)


def ring(f, secs=0.8, vol=0.3, k=4.0, beat=7.0, ratio=1.53):
    """Struck steel: two inharmonic pulse partials (not a musical interval) and a detuned copy beating against the
    first, so it shimmers like a blade and not like a note."""
    t = T(secs)
    env = decay(t, k)
    s = pulse(f, 0.125) * steps(env * vol * 0.55)
    s += pulse(f + beat, 0.125) * steps(env * vol * 0.35)
    s += pulse(f * ratio, 0.25) * steps(decay(t, k * 1.8) * vol * 0.4)
    return s


def clank(f=1300, vol=0.3, secs=0.35, k=9, seed=8):
    """A short steel clank: the ring with a short-mode (metallic) noise hit on top."""
    t = T(secs)
    return ring(f, secs, vol, k, beat=11) + noise(len(t), 0, short=True, seed=seed) * steps(decay(t, 40) * vol * 1.3)


def glide(f0, f1, secs, vol=0.2, duty=0.125, k=0.0, curve=4.0):
    """A thin tone gliding (exponentially) from f0 to f1: energy and whines, never notes."""
    t = T(secs)
    u = t / secs
    k_ = (1 - np.exp(-curve * u)) / (1 - np.exp(-curve)) if curve else u        # fast first, then settling
    f = f0 * (f1 / f0) ** k_
    return pulse(f, duty) * steps(decay(t, k) * vol if k else np.full(len(t), vol))


def air(secs, r0, r1, vol=0.4, seed=3, shape="bell"):
    """Moving air (noise whose rate slides). shape: bell (whoosh), rise (grows to its cut end), fall (fades out)."""
    t = T(secs)
    u = np.clip(t / secs, 0, 1)
    rate = np.round(np.interp(t, [0, secs], [r0, r1])).astype(int)
    env = {"bell": np.sin(np.pi * u), "rise": u ** 1.6, "fall": (1 - u) ** 1.5}[shape] * vol
    return noise(len(t), rate, seed=seed) * steps(env)


def breath(secs, r0=12, r1=8, vol=0.1, seed=5):
    """The act's windup: a quiet low breath of air that rises toward the swing. Anticipation, no notes."""
    t = T(secs)
    u = np.clip(t / secs, 0, 1)
    rate = np.round(np.interp(t, [0, secs], [r0, r1])).astype(int)
    return noise(len(t), rate, seed=seed) * steps(u ** 1.5 * vol)


def fly(vx, vy, x0=0.0, y0=-1.0, g=1.0, drag=0.0, e=0.38, life=9.0, rest=70.0):
    """Landings of one bit thrown from (x0, y0) at (vx, vy) px/s, as the effect's Bits move it (src/core/sim.js:
    gravity, drag on both axes, bounce while the impact speed is over 70 px/s). [(t, impact speed, x)]."""
    dt, t, x, y, out = 1 / 600, 0.0, x0, y0, []
    while t < life:
        vy += G * g * dt
        vx -= vx * drag * dt
        vy -= vy * drag * dt
        x += vx * dt
        y += vy * dt
        t += dt
        if y >= 0 and vy > 0:
            out.append((t, vy, x))
            if e > 0 and vy > rest:
                vy, vx, y = -vy * e, vx * 0.7, -0.01
            else:
                break
    return out


def grit_lands(vx, vy, x0=0.0, y0=-1.0, rng=None):
    """A grit particle (src/core/sim.js P.GRIT): lands, maybe bounces once at a quarter speed, then lies still."""
    out = fly(vx, vy, x0, y0, drag=0.0, e=0.0)
    if out and out[0][1] > 130 and rng is not None and rng.random() < 0.4:
        t0, v, x = out[0]
        more = fly(vx * 0.5, -v * 0.25, x, -0.25, e=0.0)
        out += [(t0 + t, s, xx) for t, s, xx in more]
    return out


def debris(m, landings, vol=0.3, rate=9, short=False, weight=0.0, vref=300.0, seed=1, secs=None, mat=None):
    """A tail of landings [(t, speed, x)]: each a knock as loud as it hits, panned with its x. Starts at t 0.
    mat: each landing is that material's hit at `weight` (a rock: "stone") instead of a plain knock."""
    rng = np.random.default_rng(seed)
    end = max([t for t, _, _ in landings] + [0]) + 0.2
    buf = blank(secs or end)
    for t, v, x in landings:
        a = min(1.0, v / vref)
        if a < 0.08:
            continue
        r = int(np.clip(rate + rng.integers(-1, 2), 0, 15))
        sd = int(rng.integers(1, 99))
        if mat:
            s = material_hit(mat, weight, sd, vol * a)
        else:
            s = tick(vol * a, sd, short=True) if short else knock(vol * a, sd, r, weight=weight)
        put(buf, st(s, pan_of(m, x)), t)
    return buf


# ------------------------------------------------------------------ the effects
def blunt_hit(m):
    """A heavy blunt blow on a body at t 0 (the white blob): a dull crack (lower noise rate than a bright hit) and a
    heavy flesh smack with its short low push; the squash ring of dust is a soft puff in the body; the clods drop as
    small earth knocks (life 0.35-0.85 s)."""
    sd = seed_of(m)
    rng = np.random.default_rng(sd)
    hit = st([crack(0.05, 5, 0.75, 45, sd), flesh_hit(0.9, sd + 3, 0.85)], 0)
    t = T(0.7)
    puff = noise(len(t), np.round(np.interp(t, [0, 0.7], [6, 9])).astype(int), seed=sd + 2) * steps(
        np.sin(np.pi * np.clip(t / 0.5, 0, 1)) * 0.1)
    body = st([rumble(0.3, 0.28, 13, 10, 0, 0, sd + 1), puff], 0)
    lands = [(rng.uniform(0.28, 0.75), rng.uniform(150, 280), rng.uniform(-30, 30)) for _ in range(4)]
    tail = debris(m, sorted(lands), 0.3, 11, weight=0.35, seed=sd, mat="earth")
    full = mix([(hit, 0), (body, 0.03), (tail, 0)], m["duration"])
    return out(full, {"hit": hit, "body": body, "tail": tail},
                 "dull crack + heavy flesh smack at the blob (t 0), soft dust puff in the body, 4 earth clods knock down "
                 "0.28-0.75 s", 0.75)


def bullet_impact(m):
    """A round strikes the wall at t 0 (the hot half-star): a very bright short crack and a high stone 'tak'; a puff of
    grit hisses; the 8 wall chips (thrown back left, from 24 px up) knock on the floor where their flight lands them."""
    sd = seed_of(m)
    rng = np.random.default_rng(sd)
    p = pan_of(m, 0)
    hit = st([crack(0.03, 0, 0.9, 90, sd), stone_hit(0.2, sd + 3, 0.4), knock(0.4, sd + 1, 6, 0.05, 70)], p)
    body = st(crack(0.25, 3, 0.25, 12, sd + 2), p - 0.1)
    lands = []
    for i in range(8):
        a = np.pi + rng.uniform(-0.8, 0.6)
        v = rng.uniform(60, 190)
        lands += grit_lands(np.cos(a) * v, np.sin(a) * v - rng.uniform(20, 70), -1, -24 + rng.uniform(-1, 1), rng)
    tail = debris(m, lands, 0.28, 7, vref=250, seed=sd)
    full = mix([(hit, 0), (body, 0.02), (tail, 0)], m["duration"])
    return out(full, {"hit": hit, "body": body, "tail": tail},
                 "bright crack + stone tak on the wall (t 0, panned right), grit hiss, 8 chips knock where they land", 0.8)


def crit_hit(m):
    """A critical hit at t 0: a full crack, a steel edge ringing short and a heavy flesh smack under it (a blow on a
    body, not an explosion), a bright 'tsing' glide down for the jagged white starburst, the ring breaking into arcs (t
    0.03+) as a wide outward rush; 10 shards fall from 26 px up and tick on the floor, short (glassy) and panned along
    the blow (aim right)."""
    sd = seed_of(m)
    rng = np.random.default_rng(sd)
    p = pan_of(m, 0)
    hit = st([crack(0.06, 1, 0.5, 45, sd), metal_hit(0.35, sd + 5, 0.45), flesh_hit(1.0, sd + 6, 0.9),
              glide(2600, 1150, 0.14, 0.22, 0.125, 18)], p)
    burst = st(air(0.3, 1, 6, 0.3, sd + 2), (p - 0.3, p - 0.7)) + st(air(0.3, 1, 6, 0.3, sd + 3), (p + 0.3, p + 0.7))
    body = st(rumble(0.4, 0.32, 13, 8, 0, 0, sd + 4), p)
    A, lands = m["options"].get("aim", 0.12), []
    for i in range(10):
        a = A + rng.uniform(-1, 1) * 1.1 - 0.35
        v = rng.uniform(110, 280)
        lands += fly(np.cos(a) * v, np.sin(a) * v - 40, 0, -m["options"].get("height", 26), 0.8, 0.7, 0.35,
                     rng.uniform(0.55, 0.85))
    tail = debris(m, lands, 0.22, 0, short=True, vref=220, seed=sd)
    full = mix([(hit, 0), (burst, 0.03), (body, 0.05), (tail, 0)], m["duration"])
    return out(full, {"hit": hit, "burst": burst, "body": body, "tail": tail},
                 "crack + steel ring + heavy flesh smack + tsing glide at the starburst (t 0), arcs rush out "
                 "(0.03), short body, 10 shards tick down", 0.55)


def ground_slam(m):
    """Something lands hard on stone at t 0: the biggest crack here and the heaviest earth knock and crunch; the two
    shock fronts run out left and right along the floor for WAVE 0.6 s (noise sliding to rumble, panned outward); a
    short low ground body; the 20 rocks erupt from the dent (3 heavy ones barely clearing it), land, bounce at 0.38 and
    settle, as stone knocks sized by the rock."""
    sd = seed_of(m)
    rng = np.random.default_rng(sd)
    hit = st([crack(0.07, 1, 0.6, 35, sd + 4), earth(1.0, sd, 1.0)], 0)
    fronts = st(air(0.6, 5, 11, 0.32, sd + 1, "fall"), (-0.15, -0.85)) + \
        st(air(0.6, 5, 11, 0.32, sd + 2, "fall"), (0.15, 0.85))
    body = st(rumble(0.7, 0.6, 14, 5, 0, 0, sd + 3), 0)
    lands, sizes = [], []
    for i in range(20):
        s = 4 if i < 3 else int(rng.integers(1, 4))
        a = -np.pi / 2 + rng.uniform(-0.5, 0.5)
        sp = rng.uniform(110, 190) if s > 3 else rng.uniform(170, 380) * (0.8 if s > 2 else 1)
        L = fly(np.cos(a) * sp, np.sin(a) * sp, rng.uniform(-7, 7), -2, 1, 0.4, 0.38, rng.uniform(1.9, 2.7))
        lands.append((L, s))
    tail = blank(2.8)
    for L, s in lands:
        put(tail, debris(m, L, 0.12 + 0.04 * s, 12 - s, weight=0.15 * s, vref=350, seed=int(rng.integers(1, 999)),
                         mat="stone"), 0)
    full = mix([(hit, 0), (fronts, 0.015), (body, 0.05), (tail, 0)], m["duration"])
    return out(full, {"hit": hit, "fronts": fronts, "body": body, "tail": tail},
                 "huge crack + heavy earth knock/crunch at the floor flash (t 0), two shock fronts rush out L/R "
                 "(0.015-0.6), short ground body, 20 rocks land/bounce/settle as stone knocks", 0.635)


def heavy_landing(m):
    """A character lands at the act's hit (t 0.005, hit-stop 0.13). start: the fall (windup 0.26), air rushing up past
    them. hit: boots on stone, a crack and a heavy earth knock and crunch. body after the freeze: the first dust ring
    (0.01) as a short low body, the second lumpier ring (0.12) as a soft whump; tail: the 12 pebbles hop away (bounce
    0.55) as small stone knocks."""
    sd = seed_of(m)
    rng = np.random.default_rng(sd)
    (th, fz), = hits_of(m)
    w = windup_of(m, 0.26)
    start = st(air(w, 9, 3, 0.18, sd, "rise"), 0)
    hit = st([crack(0.05, 3, 0.5, 45, sd + 4), earth(0.8, sd, 0.9)], 0)
    body = st(rumble(0.5, 0.5, 14, 6, 0, 0, sd + 2), 0)
    put(body, st(air(0.35, 11, 13, 0.16, sd + 3), 0), 0.11)
    lands = []
    for i in range(12):
        s = rng.choice([-1, 1])
        lands += fly(s * rng.uniform(50, 130), -rng.uniform(140, 230), s * rng.uniform(3, 8), -1, 1, 0.5, 0.55,
                     rng.uniform(1, 1.45))
    tail = debris(m, lands, 0.24, 8, weight=0.1, vref=230, seed=sd, mat="stone")
    b0 = th + fz
    full = mix([(hit, th), (body, b0), (tail, b0)], m["duration"])
    return out(full, {"start": start, "hit": hit, "body": body, "tail": tail},
                 "start = the fall (air rising); boots crack + earth knock at the hit (0.005); short body and "
                 "second-ring whump after the 0.13 hit-stop; 12 pebbles hop away", 0.7)


def hit_flash(m):
    """The character takes a blow at t 0 (hit-stop 0.07): flesh, so a dull smack and its short low push, the short body
    after the freeze. The red/white blinks are the picture only. No start: in its windup the target just stands
    there."""
    sd = seed_of(m)
    (th, fz), = hits_of(m)
    p = 0.2 * m["options"].get("side", 1)
    hit = st([crack(0.03, 4, 0.75, 70, sd), crack(0.015, 1, 0.35, 120, sd + 1),
              flesh_hit(0.6, sd + 3, 0.75)], p)
    body = st(rumble(0.25, 0.26, 12, 12, 0, 0, sd + 2), p)
    full = mix([(hit, th), (body, th + fz)], m["duration"])
    return out(full, {"hit": hit, "body": body}, "crack + flesh smack at the blow (t 0), short body after the 0.07 hit-stop", 0.69)


def hit_spark(m):
    """The everyday hit at t 0 (the cross flare, sparks: steel on armour): a bright crack and a short steel ring; the 6
    hot chips (from 20 px up, aimed along the blow) tick off the floor where they land."""
    sd = seed_of(m)
    rng = np.random.default_rng(sd)
    p = pan_of(m, 0)
    hit = st([crack(0.04, 1, 0.8, 60, sd), metal_hit(0.2, sd + 3, 0.45), crack(0.05, 2, 0.3, 60, sd + 1, short=True)], p)
    body = st(rumble(0.22, 0.2, 10, 14, 0, 0, sd + 2), p)
    A, lands = m["options"].get("aim", 0.1), []
    for i in range(6):
        a = A + rng.uniform(-1.1, 0.5) - 0.3
        v = rng.uniform(70, 170)
        lands += grit_lands(np.cos(a) * v, np.sin(a) * v - rng.uniform(30, 80), 1, -m["options"].get("height", 20), rng)
    tail = debris(m, [l for l in lands if l[0] < 0.45], 0.2, 0, short=True, vref=200, seed=sd)
    full = mix([(hit, 0), (body, 0.02), (tail, 0)], m["duration"])
    return out(full, {"hit": hit, "body": body, "tail": tail},
                 "bright crack + short steel ring at the flare (t 0), 6 hot chips tick down", 0.7)


def impact_frame(m):
    """An anime impact frame, screen-wide: the two white frames (0-0.067) are the crack and a heavy blow landing on a
    body (a big flesh smack), the two inverted frames carry a short low push of air, and the burst lines pulling out
    past the edges (0.133-0.267) are an outward rush spreading to both sides."""
    sd = seed_of(m)
    F = 1 / 30
    hit = st([crack(2 * F, 1, 0.9, 30, sd), flesh_hit(1.0, sd + 1, 1.0)], 0)
    rush = st(air(4 * F, 2, 8, 0.32, sd + 2), (-0.2, -0.9)) + st(air(4 * F, 2, 8, 0.32, sd + 3), (0.2, 0.9))
    body = st(rumble(0.35, 0.4, 13, 8, 0, 0, sd + 4), 0)
    full = mix([(hit, 0), (body, 0.04), (rush, 4 * F)], m["duration"])
    return out(full, {"hit": hit, "body": body, "rush": rush},
                 "crack + heavy flesh smack on the white frames (t 0), short low push, an outward rush as the lines pull "
                 "out (0.133)", 0.47)


def parry(m):
    """Two blades clash at t 0 (the X flash): steel on steel, a metallic crack and a bright scrape over the first two
    frames, then the struck blades ring on, shimmering (two inharmonic partials and a beating copy), as the star rings
    out and fades. The gold sparks rain down silently."""
    sd = seed_of(m)
    rng = np.random.default_rng(sd)
    f = 1150 * rng.uniform(0.94, 1.06)
    hit = st([crack(0.035, 1, 0.7, 70, sd, short=True), crack(0.12, 0, 0.35, 22, sd + 1, short=True),
              clank(f * 1.3, 0.3, 0.2, 18, sd + 2), metal_hit(0.45, sd + 3, 0.4)], 0)
    body = st([ring(f, 1.2, 0.34, 3.2, 9, 1.53), ring(f * 0.73, 0.9, 0.14, 4.5, 6, 1.61)], 0)
    full = mix([(hit, 0), (body, 0)], m["duration"])
    return out(full, {"hit": hit, "body": body},
                 "steel clash: metallic crack + scrape at the X flash (t 0), the blades ring and shimmer ~1 s", 0.66)


def ricochet(m):
    """The tracer races in (0-0.05, a faint hiss) and glances off the floor at HIT 0.05: a bright crack and a stone
    tick, then the classic whine gliding down as the round skips away to the right (pan follows it off the frame);
    the 7 grit bits kicked up knock where they land, and the sparks skitter along the floor to the right."""
    sd = seed_of(m)
    rng = np.random.default_rng(sd)
    HIT = 0.05
    p = pan_of(m, 0)
    inc = st(air(HIT, 0, 0, 0.12, sd, "rise"), (p - 0.3, p))
    hit = st([crack(0.03, 0, 0.85, 90, sd + 1), knock(0.35, sd + 2, 5, 0.04, 80)], p)
    whine = st(glide(2300 * rng.uniform(0.92, 1.08), 720, 0.42, 0.26, 0.125, 5.5, 2.2), (p, 0.85))
    lands = []
    for i in range(7):
        a = -np.pi / 2 + rng.uniform(-0.2, 0.9)
        v = rng.uniform(60, 170)
        lands += grit_lands(np.cos(a) * v, np.sin(a) * v, rng.uniform(0, 4), -1, rng)
    tail = debris(m, lands, 0.22, 7, vref=170, seed=sd)
    for i in range(4):                              # sparks skipping on along the floor, further right each time
        u = (i + rng.uniform(0.2, 0.8)) / 4
        put(tail, st(tick(0.1 * (1 - 0.5 * u), int(rng.integers(1, 99))), pan_of(m, 30 + 120 * u)), 0.03 + 0.3 * u)
    full = mix([(inc, 0), (hit, HIT), (whine, HIT), (tail, HIT)], m["duration"])
    return out(full, {"hit": hit, "whine": whine, "tail": tail},
                 "faint incoming hiss, crack + stone tick at the glance (0.05), a whine gliding down as it skips off "
                 "right, grit knocks and sparks skittering", 1.0)


def shield_block(m):
    """An energy dome takes a blow at the act's hit (0.005, hit-stop 0.09): the dome is energy, so its weight is an
    energy hit (a zap gliding down and a noise whoomp) with a buzz, over a short crack and the weapon's steel tick on
    the shell; after the freeze a fizzing ripple runs over the dome and dies away. start (windup 0.36): a thin tone
    gliding up as the dome braces. end: the dome blinking out cell by cell (GONE 0.5 -> ~1.05), a thin glide down with
    crackles thinning out (a status ending: a one-shot)."""
    sd = seed_of(m)
    rng = np.random.default_rng(sd)
    (th, fz), = hits_of(m)
    w = windup_of(m, 0.36)
    p = pan_of(m, 25)
    t = T(w)
    start = st(pulse(170 * (420 / 170) ** (t / w), 0.125) * steps((t / w) ** 1.5 * 0.08)
               + noise(len(t), 4, seed=sd) * steps((t / w) ** 2 * 0.05), p)
    t = T(0.2)
    buzz = pulse(110 * (1 + 0.3 * decay(t, 20)), 0.125) * steps(decay(t, 14) * 0.35)
    hit = st([crack(0.035, 3, 0.65, 60, sd + 1, short=True), energy_hit(0.5, sd + 3, 0.45), buzz,
              metal_hit(0.15, sd + 4, 0.25)], p)
    t = T(0.45)
    rip = (pulse(140 * (1 + 0.02 * np.sin(2 * np.pi * 11 * t)), 0.125) * 0.5 + noise(len(t), 5, seed=sd + 2)) \
        * steps(decay(t, 6) * 0.17)
    body = st(rip, (p, p + 0.25))
    end = blank(0.6)
    put(end, st(glide(420, 120, 0.55, 0.07, 0.125, 5, 0), p), 0)
    for i in range(9):                              # cells blinking out: crackles getting sparser
        at = 0.55 * (i / 9) ** 0.6
        put(end, st(tick(0.12 * (1 - i / 11), int(rng.integers(1, 99))), p + rng.uniform(-0.25, 0.25)), at)
    full = mix([(hit, th), (body, th + fz), (end, 0.5 + fz)], m["duration"])
    return out(full, {"start": start, "hit": hit, "body": body, "end": end},
                 "start = thin glide up (brace); energy zap + crack + steel tick at the hit (0.005); fizzing ripple after the 0.09 "
                 "hit-stop; dome blinks out at 0.5 with a glide down and thinning crackles", 0.965)


SOUNDS = {
    "blunt-hit": blunt_hit,
    "bullet-impact": bullet_impact,
    "crit-hit": crit_hit,
    "ground-slam": ground_slam,
    "heavy-landing": heavy_landing,
    "hit-flash": hit_flash,
    "hit-spark": hit_spark,
    "impact-frame": impact_frame,
    "parry": parry,
    "ricochet": ricochet,
    "shield-block": shield_block,
}
