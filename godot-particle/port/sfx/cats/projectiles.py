# projectiles: launch, flight, impact (references/sound.md). Flight loops are the projectile in its own frame: the loop
# is its flight sound, and the phases a game triggers when it fires one (launch) and when it lands (hit, the game's
# real moment of contact). One-shots put each event on the effect's own beats (src/fx/projectiles/<name>.js), the
# flight panned along the path across the canvas. Everything that lands follows the hit recipe (references/sound.md
# rule 2): a crack, then the weight of what is struck (synth.material_hit): an arrow toks into wood, a slug knocks
# stone, energy shots zap. The pitch-dropping thump is a blast's only: the gunshots, the cannon and the warheads
# (rocket, homing missile). A motor lighting is gas, not a blast: a noise whoomp (ignite).
import numpy as np
from synth import *  # noqa: F401,F403
from cats.impacts import (seed_of, S, pan_of, st, put, crack, thump, rumble, knock, glide, air, fly, grit_lands,
                          debris, mix as imix)
from cats.explosions import clink

MASTER = 0.5        # make.py's master gain: levels below are set as make.py prints them
RING = 1.45         # a one-shot may ring 1.5 s past its end


# ------------------------------------------------------------------ helpers (shared with cats/lightning.py)
def db(a):
    return 20 * np.log10(np.sqrt(np.mean(np.square(a))) + 1e-9)


def top(a, win=0.1):
    """dB RMS of a part's loudest 100 ms: how hard it hits, whatever its length."""
    n = int(win * SR)
    c = np.cumsum(np.r_[0, np.square(a).mean(1)])
    e = c[-1] / len(a) if len(a) <= n else ((c[n:] - c[:-n]) / n).max()
    return 10 * np.log10(e + 1e-12)


def leveled(m, full, phases, notes, target, tops=None):
    """The Sound with every part scaled by one gain so full sits at `target` dB RMS as make.py measures it (a one-shot
    padded to its duration, after the master gain). One gain keeps the phases' balance as designed. tops: phases that
    are not in full (a flight loop's launch and hit, triggered by the game) set on their own, by their loudest 100 ms
    after the master gain (small-explosion's hit is about -9.5, bullet-impact's -14.4)."""
    n = int(round(m["duration"] * SR))
    f = full if len(full) >= n else np.concatenate([full, np.zeros((n - len(full), 2))])
    g = 10 ** ((target - db(f * MASTER)) / 20)
    ph = {k: v * g for k, v in phases.items()}
    for k, v in (tops or {}).items():
        ph[k] = phases[k] * 10 ** ((v - top(phases[k] * MASTER)) / 20)
    return Sound(full * g, ph, notes)


def shot(m, parts):
    """A one-shot's full play: [(stereo part, at)] mixed on the effect's clock, at least its duration, cut (faded) at
    1.45 s past it, trailing silence trimmed."""
    D = m["duration"]
    n = max([int(round(D * SR))] + [int(round(a * SR)) + len(s) for s, a in parts])
    buf = np.zeros((n, 2))
    for s, a in parts:
        put(buf, s, a)
    loud = np.nonzero(np.abs(buf).max(1) > 2e-4)[0]
    n = max(int(round(D * SR)), loud[-1] + 1 if len(loud) else 0)
    cap = int(round((D + RING) * SR))
    if n > cap:
        n = cap
        buf[n - int(0.2 * SR): n] *= np.linspace(1, 0, int(0.2 * SR))[:, None]
    return buf[:n]


def lput(buf, s, at, P):
    """Put a stereo part into a loop buffer of period P (rendered P + X long): wherever it falls, its tail running
    past the end comes back in at the start, so the loop wraps clean."""
    at = at % P
    k0 = -int(np.ceil(len(s) / SR / P))
    for k in range(k0, 2):
        i = int(round((at + k * P) * SR))
        j0 = max(0, -i)
        i0 = max(0, i)
        if j0 >= len(s) or i0 >= len(buf):
            continue
        n = min(len(s) - j0, len(buf) - i0)
        buf[i0:i0 + n] += s[j0:j0 + n]


def st_path(sig, pans):
    """Mono -> stereo with a pan per sample (a moving source), constant power."""
    p = np.clip(np.interp(np.arange(len(sig)), np.linspace(0, len(sig) - 1, len(pans)), pans), -1, 1)
    return np.stack([sig * np.sqrt((1 - p) / 2), sig * np.sqrt((1 + p) / 2)], 1) * np.sqrt(2)


def per_frame(levels, secs, fps=30):
    """A value per video frame held as a per-sample envelope (the effect's own flicker table, frame by frame)."""
    t = T(secs)
    idx = np.minimum((t * fps).astype(int), len(levels) - 1)
    return np.asarray(levels, float)[idx]


def bed(secs, rate, vol, seed, flick=None, short=False):
    """A continuous noise layer at a fixed rate, its level following an optional per-sample envelope."""
    t = T(secs)
    env = np.full(len(t), vol) if flick is None else flick * vol
    return noise(len(t), rate, short=short, seed=seed) * steps(env)


def ticks(n_or_times, secs, vol, seed, short=True, spread=0.0):
    """Faint ticks (sparks, motes, grit) at the given times, or n of them at random, as mono."""
    rng = np.random.default_rng(seed)
    times = rng.uniform(0, secs, n_or_times) if np.isscalar(n_or_times) else n_or_times
    out = np.zeros(int(round(secs * SR)) + int(0.05 * SR))
    for at in times:
        c = tick(vol * rng.uniform(0.5, 1.0), int(rng.integers(1, 99)), short=short)
        j = int(at * SR)
        out[j:j + len(c)] += c[: len(out) - j]
    return out[: int(round(secs * SR))]


def ignite(seed, weight=0.5, vol=0.5):
    """A motor or a charge lighting (a rocket, a jetpack, a flare's launch): gas, not a blast, so a low noise whoomp
    opening from rumble toward a rush, with no tone under it."""
    secs = 0.15 + 0.25 * weight
    t = T(secs)
    rate = np.round(np.interp(t, [0, secs], [14, 8 - 3 * weight])).astype(int)
    return noise(len(t), rate, seed=seed) * steps(np.minimum(1, t / 0.012) * decay(t, 12 - 6 * weight) * vol)


def blast(seed, weight=0.6, vol=1.0):
    """A warhead going off (rocket, homing missile): a real explosion, so its weight is the pitch-dropping blast
    (synth.material_hit "blast") under a crack, and a low rumble body. Mono (hit, body), seeded per effect."""
    hit = S(crack(0.05, 1, 0.8 * vol, 45, seed + 1), material_hit("blast", weight, seed, vol))
    return hit, rumble(1.0, 0.4 * vol, 14, 2.6, 60, 0.3, seed + 2)


def casing_hits(vx, vy, y0, floor, bounce, g=850.0):
    """When a casing tossed from y0 at (vx, vy) strikes the floor, as src/fx/projectiles/_lib.js casing() moves it:
    bounces while vin * bounce >= 45, then slides to rest. [(t, impact speed, x offset)]."""
    out, t0, x, y = [], 0.0, 0.0, y0
    for _ in range(6):
        d = floor - y
        Tn = (-vy + np.sqrt(max(0.0, vy * vy + 2 * g * d))) / g
        t0 += Tn
        x += vx * Tn
        vin = vy + g * Tn
        out.append((t0, vin, x))
        y = floor
        if vin * bounce < 45:
            break
        vy, vx = -vin * bounce, vx * 0.55
    return out


# ------------------------------------------------------------------ flight loops (+ launch and hit for the game)
def arrow(m):
    """Flight loop: the fletching flutters (a new pose every frame, at random) as a soft low air flutter over a thin
    hiss of air peeling off the head. launch: the string lets go (a dull snap, a short thrum dropping, the shaft
    leaving). hit: the broadhead thunks into wood: a hollow wood tok and a dull knock, then the shaft quivers out."""
    sd = seed_of(m)
    rng = np.random.default_rng(sd)
    P = m["duration"]
    flut = per_frame(rng.choice([0.55, 0.8, 1.0], int((P + X) * 30) + 2), P + X)
    loop = stereo(bed(P + X, 8, 0.33, sd, flut) + bed(P + X, 1, 0.1, sd + 1))
    loop = wrap(loop, P)
    launch = st([crack(0.02, 3, 0.45, 90, sd + 2), glide(240, 95, 0.09, 0.3, 0.5, 22), air(0.22, 2, 8, 0.2, sd + 3, "fall")], 0)
    t = T(0.45)
    quiver = pulse(92 * (1 + 0.03 * np.sin(2 * np.pi * 14 * t)), 0.25) * steps(decay(t, 8) * 0.16 * (0.6 + 0.4 * np.abs(np.sin(2 * np.pi * 7 * t))))
    hit = st([wood_hit(0.6, sd + 6, 0.6), knock(0.4, sd + 4, 8, 0.07, 45), quiver], 0)
    return leveled(m, loop, {"launch": launch, "loop": loop, "hit": hit},
                   "loop: fletching flutter (a pose a frame) + thin air hiss; launch: string snap + thrum; "
                   "hit: wood tok + knock, shaft quivers", -30, {"launch": -19, "hit": -15})


def bullet_tracer(m):
    """Flight loop: the tracer compound burning, a hiss that sputters frame by frame (its heat ripples back along the
    trace), with the shed sparks as sparse faint crackles. No launch: the gunshot is the muzzle effect's. hit: the slug
    strikes stone (bullet-impact's material): a very bright crack and a stone tak, a grit hiss, chips ticking."""
    sd = seed_of(m)
    rng = np.random.default_rng(sd)
    P = m["duration"]
    sput = per_frame(rng.uniform(0.55, 1.0, int((P + X) * 30) + 2), P + X)
    b = bed(P + X, 1, 0.21, sd, sput) + bed(P + X, 4, 0.15, sd + 1, sput[::-1])
    b += ticks(9, P + X, 0.2, sd + 2)
    loop = wrap(stereo(b), P)
    hit = imix([(st([crack(0.03, 0, 0.9, 90, sd + 3), stone_hit(0.25, sd + 7, 0.5), knock(0.4, sd + 4, 6, 0.05, 70)], 0), 0),
                (st(crack(0.25, 3, 0.22, 12, sd + 5), 0), 0.02),
                (st(ticks([0.09, 0.16, 0.21, 0.3], 0.4, 0.14, sd + 6, short=False), 0), 0)], 0)
    return leveled(m, loop, {"loop": loop, "hit": hit},
                   "loop: burning tracer hiss sputtering per frame, faint spark crackles; hit: crack + stone tak + grit", -30,
                   {"hit": -14})


def laser_bolt(m):
    """Flight loop: energy, so a thin buzz (a low pulse) and a fizz, swelling a little each time a pulse races down the
    body (3 a loop) and with the head's glint (2 a loop): a flutter, not a beat. launch: the classic shot, a thin tone
    gliding down fast. hit: energy on what it strikes: a metallic crack, the energy hit (a zap gliding down and a noise
    whoomp) and a short sizzle."""
    sd = seed_of(m)
    P = m["duration"]
    t = T(P + X)
    ph = t / P
    am = 0.8 + 0.12 * np.sin(2 * np.pi * 3 * ph) + 0.08 * np.sin(2 * np.pi * 2 * ph)
    b = pulse(150 * (1 + 0.01 * np.sin(2 * np.pi * 3 * ph)), 0.125) * steps(am * 0.21) + bed(P + X, 4, 0.24, sd, am)
    loop = wrap(stereo(b), P)
    launch = st([glide(1900, 260, 0.18, 0.28, 0.25, 8, 3), crack(0.015, 1, 0.3, 120, sd + 1, short=True)], 0)
    t = T(0.3)
    hit = st([crack(0.03, 1, 0.7, 70, sd + 2, short=True), energy_hit(0.4, sd + 4, 0.55),
              noise(len(t), 2, seed=sd + 3) * steps(decay(t, 9) * 0.2)], 0)
    return leveled(m, loop, {"launch": launch, "loop": loop, "hit": hit},
                   "loop: thin buzz + fizz fluttering with the body's pulses; launch: glide-down shot; hit: zap", -30,
                   {"launch": -19, "hit": -15})


def energy_disc(m):
    """Flight loop: a sawblade of energy spinning 6 turns a second: a low whirr (a pulse near the tooth rate) with a
    metallic short-mode whine and the hub's filaments re-struck every frame as faint crackle; the glint riding the rim
    once a turn swells it a little. launch: thrown, a whoosh with the whirr spinning up. hit: the energy saw bites: a
    metallic crack, a small energy hit and a grind that winds down."""
    sd = seed_of(m)
    rng = np.random.default_rng(sd)
    P = m["duration"]
    t = T(P + X)
    turn = 0.85 + 0.15 * np.cos(2 * np.pi * 3 * t / P)
    b = pulse(np.full(len(t), 96.0), 0.25) * steps(turn * 0.18) + bed(P + X, 8, 0.15, sd, turn, short=True)
    b += bed(P + X, 2, 0.12, sd + 1, per_frame(rng.uniform(0.3, 1, int((P + X) * 30) + 2), P + X))
    loop = wrap(stereo(b), P)
    tl = T(0.3)
    launch = st([air(0.3, 6, 1, 0.28, sd + 2), pulse(60 * (96 / 60) ** (tl / 0.3), 0.25) * steps(np.sqrt(tl / 0.3) * 0.08)], 0)
    t = T(0.45)
    grind = (noise(len(t), 8, short=True, seed=sd + 4) * 0.6 + pulse(96 * (1 - 0.3 * t / 0.45), 0.25) * 0.4) * steps(decay(t, 6) * 0.3)
    hit = st([crack(0.03, 1, 0.75, 70, sd + 3, short=True), knock(0.35, sd + 5, 4, 0.05, 60), energy_hit(0.3, sd + 6, 0.4),
              grind], 0)
    return leveled(m, loop, {"launch": launch, "loop": loop, "hit": hit},
                   "loop: spinning saw whirr + metallic whine + filament crackle; launch: whoosh + spin-up; hit: bite + grind", -30,
                   {"launch": -19, "hit": -14})


def plasma_shot(m):
    """Flight loop: a plasma blob, wet and hot: a low churning gurgle (the knots' churn pulses the heart), the corona
    crackling over its skin every frame as a sizzle, and now and then a droplet tearing off the tail as a tiny pop.
    launch: a thick 'thoom' gliding down with a push of air. hit: energy splatting: a crack, the energy hit (zap and
    whoomp) and a sizzle that dies out."""
    sd = seed_of(m)
    rng = np.random.default_rng(sd)
    P = m["duration"]
    t = T(P + X)
    churn = 0.85 + 0.15 * np.sin(2 * np.pi * 4 * t / P)
    b = bed(P + X, 9, 0.33, sd, churn) + bed(P + X, 2, 0.15, sd + 1, per_frame(rng.uniform(0.4, 1, int((P + X) * 30) + 2), P + X))
    loop = stereo(b)
    for at in rng.uniform(0, P, 11):                         # 11 droplets a loop, born at random (cycle)
        lput(loop, st(knock(rng.uniform(0.15, 0.27), int(rng.integers(1, 99)), 5, 0.03, 90), rng.uniform(-0.6, -0.2)), at + 0.25, P)
    loop = wrap(loop, P)
    launch = st([glide(420, 110, 0.2, 0.3, 0.5, 6), air(0.25, 3, 9, 0.3, sd + 2)], 0)
    t = T(0.55)
    hit = st([crack(0.04, 4, 0.7, 50, sd + 3), energy_hit(0.6, sd + 6, 0.6),
              noise(len(t), np.round(np.interp(t, [0, 0.55], [1, 3])).astype(int), seed=sd + 4) * steps(decay(t, 5) * 0.25)], 0)
    hit = imix([(hit, 0), (st(ticks(6, 0.5, 0.08, sd + 5), 0), 0.05)], 0)
    return leveled(m, loop, {"launch": launch, "loop": loop, "hit": hit},
                   "loop: churning gurgle + corona sizzle + droplet pops; launch: thoom; hit: splat + sizzle", -30,
                   {"launch": -18, "hit": -14})


def rocket(m):
    """Flight loop: the motor: a low roar whose loudness follows the jet's length, new every frame, a hiss of the
    white-hot nozzle over it, faint crackles of the shed sparks. launch: ignition, a gas whoomp and the roar rushing in.
    hit: the warhead blows up, a real blast: crack, the pitch-dropping blast, a low rumbling body, three chunks knocking
    down."""
    sd = seed_of(m)
    rng = np.random.default_rng(sd)
    P = m["duration"]
    jet = per_frame(rng.uniform(0.84, 1.16, int((P + X) * 30) + 2), P + X) / 1.16
    b = bed(P + X, 12, 0.9, sd, jet) + bed(P + X, 4, 0.21, sd + 1, jet) + ticks(14, P + X, 0.18, sd + 2)
    loop = wrap(stereo(b), P)
    launch = st([ignite(sd + 5, 0.6, 0.55), crack(0.04, 3, 0.5, 60, sd + 3), air(0.6, 13, 9, 0.35, sd + 4, "rise")], 0)
    hit, body = blast(sd * 7 + 11, 0.6)
    chunks = [(st(stone_hit(rng.uniform(0.2, 0.5), int(rng.integers(1, 999)), 0.35), rng.uniform(-0.6, 0.6)), at)
              for at in sorted(rng.uniform(0.35, 0.9, 3))]
    impact = shot({"duration": 1.0}, [(st(hit), 0), (st(body), 0.05)] + chunks)
    return leveled(m, loop, {"launch": launch, "loop": loop, "hit": impact},
                   "loop: motor roar following the jet's flicker + nozzle hiss + spark crackle; launch: ignition; "
                   "hit: blast + rumble + 3 chunks", -28, {"launch": -17, "hit": -10})


def muzzle_smg(m):
    """Sustained fire, 12 rounds a second (shot s at s/12): each a crack, a short thump and a pop of gas, every round
    a little different (the flash is a new shape each shot); every casing flies up out of the port (from 27 px up) and
    clinks on the floor where casing() lands it, bouncing at 0.42, all wrapping round the loop."""
    sd = seed_of(m)
    rng = np.random.default_rng(sd)
    P, N = m["duration"], 12
    loop = blank(P + X)
    p0 = pan_of(m, 0)
    for s in range(N):
        v = rng.uniform(0.85, 1.0)
        sh = st([crack(0.035, 1, 0.8 * v, 70, sd + s), thump(300 * rng.uniform(0.92, 1.08), 70, 0.1, 0.5 * v, 28, 25),
                 crack(0.09, 9, 0.3 * v, 30, sd + 40 + s)], p0)
        lput(loop, sh, s * P / N, P)
        vx, vy = -rng.uniform(18, 48), -rng.uniform(85, 135)
        for th, vin, dx in casing_hits(vx, vy, -27, -0.5, 0.42):
            if th < P:
                lput(loop, st(clink(rng.uniform(2600, 3400), 0.16 * min(1, vin / 300), int(rng.integers(1, 99))),
                              pan_of(m, -7 + dx)), s * P / N + th, P)
    loop = wrap(loop, P)
    return leveled(m, loop, {"loop": loop}, "12 shots a loop (crack + thump + gas pop, each varied), brass casings "
                   "clinking where they land", -23)


# ------------------------------------------------------------------ one-shots
def muzzle_pistol(m):
    """One shot at t 0: the white-cored flash is the crack, a punchy thump and a short gas boom ringing off; the casing
    goes up and back from the port (27 px up) and clinks on the floor where casing() drops it, a bounce or two, then
    it slides still. Sparks, powder and smoke are silent."""
    sd = seed_of(m)
    rng = np.random.default_rng(sd)
    p = pan_of(m, 0)
    hit = st([crack(0.04, 1, 0.9, 60, sd), thump(320 * rng.uniform(0.94, 1.06), 55, 0.25, 0.7, 12, 18),
              crack(0.03, 0, 0.45, 100, sd + 1, short=True)], p)
    body = st(rumble(0.5, 0.28, 13, 6, 60, 0.2, sd + 2), p)
    tail = blank(1.4)
    vx, vy = -rng.uniform(25, 45), -rng.uniform(95, 130)
    for th, vin, dx in casing_hits(vx, vy, -27, -0.5, 0.42):
        put(tail, st(clink(rng.uniform(2700, 3300), 0.26 * min(1, vin / 300), int(rng.integers(1, 99))), pan_of(m, -7 + dx)), th)
    full = shot(m, [(hit, 0), (body, 0.02), (tail, 0)])
    return leveled(m, full, {"hit": hit, "body": body, "tail": tail},
                   "crack + thump at the flash (t 0), short gas boom, the casing clinks down and settles", -22)


def muzzle_shotgun(m):
    """The blast at t 0: a big crack and a deep dropping thump, the pellet spray hissing off to the right in a few
    frames, a heavy rolling body as the smoke shoves out. The pump: a rack back as the shell is kicked out (0.42) and
    forward again; the red shell lands where casing() drops it (bounce 0.35): a plastic knock with a brass edge."""
    sd = seed_of(m)
    rng = np.random.default_rng(sd)
    p = pan_of(m, 0)
    hit = st([crack(0.05, 1, 0.85, 45, sd), thump(240 * rng.uniform(0.94, 1.06), 40, 0.5, 0.7, 6, 12)], p)
    put(hit, st(air(0.12, 0, 3, 0.25, sd + 1, "fall"), (p, 0.8)), 0)
    body = st(rumble(1.0, 0.4, 14, 2.5, 55, 0.35, sd + 2), p)
    def click(seed, heavy):
        t = T(0.06)
        return S(noise(len(t), 1, short=True, seed=seed) * steps(decay(t, 70) * 0.3), knock(0.2 + 0.15 * heavy, seed + 1, 6, 0.05, 70),
                 pulse(np.full(len(t), 720.0), 0.25) * steps(decay(t, 90) * 0.12))
    pump = blank(1.3)
    put(pump, st(click(sd + 3, 0.2), pan_of(m, -9)), 0)
    put(pump, st(click(sd + 4, 0.5), pan_of(m, -9)), 0.13)
    vx, vy = -rng.uniform(30, 55), -rng.uniform(110, 150)
    for th, vin, dx in casing_hits(vx, vy, -26, -1, 0.35):
        a = min(1, vin / 300)
        put(pump, st([knock(0.26 * a, int(rng.integers(1, 99)), 7, 0.05, 60), clink(1900, 0.06 * a, int(rng.integers(1, 99)))],
                     pan_of(m, -9 + dx)), 0.02 + th)
    full = shot(m, [(hit, 0), (body, 0.03), (pump, 0.40)])
    return leveled(m, full, {"hit": hit, "body": body, "pump": pump},
                   "big crack + deep thump + pellet hiss (t 0), rolling body; pump racks at 0.40/0.53, shell lands", -22)


def cannonball(m):
    """The cannon fires at t 0, a blast: the biggest crack and the deep pitch-dropping blast; the ball (330 px/s at
    -0.32 rad) whooshes off, panned from the muzzle to the right edge where it leaves (~0.49 s); the gunsmoke rolls out
    as a long rumbling body; a few bits of burning wadding tick on the floor."""
    sd = seed_of(m)
    rng = np.random.default_rng(sd)
    p0 = pan_of(m, 4)
    hit = st([material_hit("blast", 1.0, sd + 7, 0.8), crack(0.06, 1, 0.4, 40, sd + 1)], p0)
    right = m["size"][0] - m["origin"][0] - 3
    fly_t = (right - 4) / (np.cos(-0.32) * 330)
    xs = 4 + np.cos(-0.32) * 330 * np.linspace(0, fly_t, 50)
    flight = st_path(air(fly_t, 9, 6, 0.25, sd + 2, "fall") + bed(fly_t, 13, 0.14, sd + 3), [pan_of(m, x) for x in xs])
    body = st([rumble(2.0, 0.5, 14, 1.4, 60, 0.4, sd + 4), air(1.6, 10, 13, 0.12, sd + 5, "fall")], p0)
    tail = st(ticks(sorted(rng.uniform(0.5, 1.3, 5)), 1.4, 0.12, sd + 6, short=False), p0 + 0.1)
    full = shot(m, [(hit, 0), (flight, 0.02), (body, 0.04), (tail, 0)])
    return leveled(m, full, {"hit": hit, "flight": flight, "body": body, "tail": tail},
                   "cannon blast (t 0), the ball whooshes off right (0-0.49), smoke rumble, wadding ticks", -21.5)


def magic_missile(m):
    """CHARGE 0-0.2: motes gather at the hand, a short rising build (noise climbing, a thin glide up, crackles), no
    notes. FLY 0.2-0.82: the orb weaves to its target: a thin hum whose pitch rides its height (a glide, not a tune) and
    a shimmer fluttering with the twisting ribbon, panned along its path. The burst at 0.82 lands on the target: a
    glassy crack, a bright glide down and a small energy hit (zap and whoomp); stars twinkle out as sparse ticks."""
    sd = seed_of(m)
    rng = np.random.default_rng(sd)
    CHARGE, FLY, H, X1 = 0.2, 0.62, m["options"].get("height", 26), m["options"].get("reach", 112)
    start = st(charge(CHARGE, 10, 3, 400, 1400, 0.2, sd), pan_of(m, 0))
    t = T(FLY)
    u = t / FLY
    x = X1 * (0.5 - 0.5 * np.cos(np.pi * u)) + np.sin(u * np.pi) * 6
    y = np.sin(u * 2 * np.pi * 1.5) * 9 * np.sin(u * np.pi)
    hum = pulse(620 * (1 - 0.012 * y), 0.125) * steps(np.full(len(t), 0.2))
    shim = noise(len(t), 1, seed=sd + 1) * steps((0.5 + 0.5 * np.abs(np.sin((CHARGE + t) * 26))) * 0.27)
    sig = (hum + shim + ticks(8, FLY, 0.18, sd + 2)) * 0.33          # voices built where the 16 steps resolve them, then mixed down
    flight = st_path(sig, [pan_of(m, v) for v in x[:: SR // 100]])
    pe = pan_of(m, X1)
    hit = st([crack(0.03, 1, 0.6, 80, sd + 3, short=True), glide(2400, 700, 0.2, 0.22, 0.25, 10),
              energy_hit(0.35, sd + 6, 0.45)], pe)
    body = st([air(0.45, 1, 5, 0.16, sd + 4), ticks(sorted(rng.uniform(0.05, 1.0, 14)), 1.1, 0.1, sd + 5)], pe)
    full = shot(m, [(start, 0), (flight, CHARGE), (hit, CHARGE + FLY), (body, CHARGE + FLY + 0.01)])
    return leveled(m, full, {"start": start, "flight": flight, "hit": hit, "body": body},
                   "gather build (0-0.2), weaving hum panned along the path (0.2-0.82), burst on the target (0.82), "
                   "stars twinkle out", -24)


def flare(m):
    """Fired at t 0: the flare's charge lights off the ground (a crack and a small gas whoomp); RISE 0-0.85: the flare's
    rocket hiss climbing (its rate rising) and thinning as it goes up, spark crackles under it; the burst at 0.85, a
    small pyrotechnic blast high up: a crack, a light blast and a puff of air; BURN 0.85-3.95: the star hangs and
    fizzes, sparks dripping as crackles (26 a second, fewer as it gutters from ~3.2), the fizz dying with it."""
    sd = seed_of(m)
    rng = np.random.default_rng(sd)
    RISE, BURN = 0.85, 3.1
    launch = st([ignite(sd + 6, 0.15, 0.45), crack(0.03, 3, 0.5, 70, sd)], 0)
    t = T(RISE)
    u = t / RISE
    hiss = noise(len(t), np.round(4 - 3 * u).astype(int), seed=sd + 1) * steps(np.minimum(1, t / 0.03) * (0.22 - 0.12 * u))
    rise = st(hiss + ticks(10, RISE, 0.07, sd + 2), 0)
    hit = st([crack(0.05, 2, 0.7, 45, sd + 3), material_hit("blast", 0.05, sd + 7, 0.4), air(0.3, 1, 7, 0.22, sd + 4)], 0)
    t = T(BURN)
    k = t / BURN
    power = 1 - np.clip((k - 0.75) / 0.25, 0, 1) ** 2 * (3 - 2 * np.clip((k - 0.75) / 0.25, 0, 1))
    burn = noise(len(t), 0, seed=sd + 5) * steps(power * 0.2 * (0.85 + 0.15 * np.sin(2 * np.pi * 3 * t))) * 0.25
    at = 0.0
    while True:
        at += rng.exponential(1 / 26)
        if at >= BURN:
            break
        pw = np.interp(at, t[:: 100], power[:: 100])
        if rng.random() < pw:
            c = tick(0.09 * pw * rng.uniform(0.5, 1), int(rng.integers(1, 99)))
            j = int(at * SR)
            burn[j:j + len(c)] += c[: len(burn) - j]
    burn = st(burn, 0)
    full = shot(m, [(launch, 0), (rise, 0.01), (hit, RISE), (burn, RISE + 0.05)])
    return leveled(m, full, {"launch": launch, "flight": rise, "hit": hit, "tail": burn},
                   "launch pop (t 0), rising hiss (0-0.85), burst crack (0.85), the star fizzes and drips sparks, "
                   "guttering out by 3.95", -26)


def homing_missile(m):
    """Kicks off at t 0 from (-130, -22): an ignition whoomp and a rush; FLY 0-1.15 along the curve, speeding up
    (progress t^1.45): the motor roar with a whine gliding up as it gathers speed, panned along the path and louder as
    it dives in; the hit at 1.15 on the target: the warhead blows up, a real blast (crack, pitch-dropping blast,
    rumble), its 16 rocks landing where they fly (bounce 0.3) as stone knocks, grit pattering."""
    sd = seed_of(m)
    rng = np.random.default_rng(sd)
    FLY = 1.15
    PATH = np.array([[-130, -22], [-114, -110], [-30, -120], [0, 0]], float)
    start = st([ignite(sd + 5, 0.5, 0.5), crack(0.03, 3, 0.45, 60, sd), air(0.3, 12, 8, 0.25, sd + 1, "rise")],
               pan_of(m, -130))
    t = T(FLY)
    u = np.clip(t / FLY, 0, 1) ** 1.45
    v = 1 - u
    x = v ** 3 * PATH[0, 0] + 3 * v * v * u * PATH[1, 0] + 3 * v * u * u * PATH[2, 0] + u ** 3 * PATH[3, 0]
    spd = np.clip(t / FLY, 0.02, 1) ** 0.45
    sig = noise(len(t), np.round(11 - 3 * spd).astype(int), seed=sd + 2) * steps(0.2 + 0.32 * spd)
    sig += pulse(300 * (1 + 2.0 * spd), 0.125) * steps(0.06 + 0.12 * spd)
    sig *= 0.25                                       # mixed down under the blast
    flight = st_path(sig, [pan_of(m, xx) for xx in x[:: SR // 100]])
    hit, body = blast(sd * 7 + 13, 0.75)
    lands = []
    for i in range(16):
        lands += fly(rng.uniform(-110, 110), -rng.uniform(140, 290), rng.uniform(-5, 5), -2, 1, 0.4, 0.3, rng.uniform(1.5, 2.2))
    rocks = debris(m, lands, 0.26, 10, weight=0.3, vref=300, seed=sd, mat="stone")
    grit = []
    for i in range(14):
        a = -np.pi / 2 + rng.uniform(-1, 1) * 0.55
        sp = rng.uniform(80, 220)
        grit += grit_lands(np.cos(a) * sp, np.sin(a) * sp, rng.uniform(-4, 4), -1, rng)
    rocks = imix([(rocks, 0), (debris(m, grit, 0.12, 6, vref=250, seed=sd + 1), 0)], 0)
    pe = pan_of(m, 0)
    hit, body = st(hit, pe), st(body, pe)
    full = shot(m, [(start, 0), (flight, 0), (hit, FLY), (body, FLY + 0.05), (rocks, FLY)])
    return leveled(m, full, {"start": start, "flight": flight, "hit": hit, "body": body, "tail": rocks},
                   "ignition whoomp (t 0), roar + whine rising with speed panned along the arc (0-1.15), blast at "
                   "the hit (1.15), rocks and grit land", -20)


SOUNDS = {
    "arrow": arrow,
    "bullet-tracer": bullet_tracer,
    "cannonball": cannonball,
    "energy-disc": energy_disc,
    "flare": flare,
    "homing-missile": homing_missile,
    "laser-bolt": laser_bolt,
    "magic-missile": magic_missile,
    "muzzle-pistol": muzzle_pistol,
    "muzzle-shotgun": muzzle_shotgun,
    "muzzle-smg": muzzle_smg,
    "plasma-shot": plasma_shot,
    "rocket": rocket,
}
