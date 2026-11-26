# scifi: machines and energy (references/sound.md). Energy is a buzz, a zap or a glide, never a beep tune (rule 1): a
# beam held on screen is a low pulse whose pitch jitters frame by frame under a noise rasp, a charge is noise and a
# glide climbing together, a power-down is a glide falling. What lands follows the hit recipe (rule 2): its weight is
# the struck material's (synth.material_hit): energy slams and shots on a field zap and whoomp, rocks knock stone, a
# latch ticks steel. Nothing here explodes, so nothing uses the pitch-dropping thump; a jet lighting is a gas whoomp.
# Props that just stand there humming to themselves (a reactor core, a hologram, a pad, a laser fence) are silent; their
# strong moments (a shot hitting the field, a scan, a warp) get sound. Beats from src/fx/scifi/<name>.js and act.timing
# in port/meta.json.
import numpy as np
from synth import *  # noqa: F401,F403
from cats.impacts import seed_of, hits_of, windup_of, pan_of, S, st, put, crack, air, breath, fly, grit_lands, debris, \
    mix as imix
from cats.projectiles import shot, lput, st_path, per_frame, ignite
from cats.ice import leveled, q
from cats.lightning import zap, buzz, zip_in, crackle as arcs
from cats.arcane import JsRng, glitter, sweep, gather, twinkles
from cats.explosions import burst, wash, spit
from cats.water import jrand

FPS = 30
TAU = 2 * np.pi


# ------------------------------------------------------------------ helpers (shared with cats/spawn.py)
class Rng(JsRng):
    """The original's Rng with sign() and pick(), so the JS's own draws (where a rock sits, when a coin lands) replay."""

    def sign(self):
        return -1 if self.next() < 0.5 else 1

    def pick(self, lst):
        return lst[int(np.floor(self.next() * len(lst)))]


def lay(*parts):
    """(stereo part, at) pairs mixed into one buffer long enough for all of them."""
    return imix(list(parts), 0)


def in_out_sine(u):
    return -(np.cos(np.pi * np.clip(u, 0, 1)) - 1) / 2


def drone(secs, env, f, seed, rate=3, jitter=0.05, nmix=0.55):
    """Energy held on screen (a beam, a bubble): a thin low pulse whose pitch jitters frame by frame (a buzz that never
    settles into a note) under a noise rasp. env and f: a number or one value per sample; rate: the rasp's noise rate
    (a number or per sample)."""
    rng = np.random.default_rng(seed)
    t = T(secs)
    jit = per_frame(1 + rng.uniform(-jitter, jitter, int(np.ceil(secs * FPS)) + 2), secs)
    f = np.broadcast_to(np.asarray(f, float), t.shape)
    rate = np.broadcast_to(np.asarray(rate, int), t.shape)
    e = q(np.broadcast_to(np.asarray(env, float), t.shape))
    return (pulse(f * jit, 0.125) * (1 - nmix) + noise(len(t), rate, seed=seed) * nmix) * e


def spark_rain(m, x0, y0, n, rng, sp, spread, vol, up=-np.pi / 2):
    """Sparks thrown from (x0, y0) around angle `up` as the toolkit's P.SPARK moves them (gravity 0.45, drag 2.2, bounce
    0.45): a faint tick at each landing, panned with its x (stereo, from t 0)."""
    lands = []
    for _ in range(n):
        a = up + rng.uniform(-spread, spread)
        v = rng.uniform(*sp)
        life = rng.uniform(0.25, 0.7)
        lands += [l for l in fly(np.cos(a) * v, np.sin(a) * v, x0, y0, 0.45, 2.2, 0.45, life) if l[0] < life]
    if not lands:
        return blank(0.1)
    return debris(m, lands, vol, 0, short=True, vref=120, seed=int(rng.integers(1, 999)))


# ------------------------------------------------------------------ silent: props that make no noise of their own
def energy_core(m):
    return Silent("a reactor core idling in its cage, beating and arcing to the bars on a fixed loop: a steady prop "
                  "like the plasma lamp (rule 2); sounding its two beats a loop would only make a heartbeat rhythm "
                  "(rule 1)")


def hologram(m):
    return Silent("an idle hologram turning over its projector, flickering and tearing as it always does: a steady "
                  "display with no noise of its own (rule 2)")


def laser_grid(m):
    return Silent("a laser fence sliding and sweeping between its posts on a loop: a steady hazard, like a burning torch "
                  "its scorching is part of the idle state (rule 2)")


def teleporter_pad(m):
    return Silent("a teleporter pad idling, rings rippling and light rising off it: a steady glow, silent (rule 2); a "
                  "warp in or out is its strong moment (scifi/warp-in, warp-out)")


# ------------------------------------------------------------------ one-shots
def emp_blast(m):
    """start (0 .. POP 0.42): the puck charges: noise climbing from rumble to hiss and a thin glide rising, fluttering
    faster with the JS's blink (sin 2pi(2t + 10t^2)), arcs off it crackling denser. hit (POP): an energy pulse, not an
    explosion: a white zap, a crack and a heavy energy hit (a zap gliding down and a noise whoomp). body: the star of
    arcs buzzing out on its own length (0.26 s), a whoosh as the ring races out, the bubble's hum swelling with its
    radius (outExpo over 0.32) and cut out on the frames it strobes off (rand(seed, frame) < 0.2 + 0.5 k, 1.25 .. 1.58),
    arcs crawling its skin as small zaps (every 0.05-0.11 s, then 0.02-0.05 s), sparks ticking where they land. break
    (1.58): it shorts out: a zap, a buzz flare and a glide falling (power down), dead pixels glittering out; tail: the
    dead puck spitting now and then."""
    sd = seed_of(m)
    rng = np.random.default_rng(sd)
    o = m["options"]
    S_ = int(o.get("seed", 33))
    POP, GROW, STROBE, BREAK = 0.42, 0.32, 1.25, 1.58
    RM = o.get("radius", 56)
    p0 = pan_of(m, 0)
    # start: the charge
    t = T(POP)
    u = t / POP
    blink = (np.sin(TAU * (2 * t + 10 * t * t)) > 0).astype(float)
    env = 0.12 + 0.88 * u ** 1.8
    sig = noise(len(t), np.round(12 - 10 * u).astype(int), seed=sd) * q(env) * 0.45
    sig += pulse(170 * (1100 / 170) ** u, 0.125) * q(env * (0.7 + 0.3 * blink)) * 0.2
    sig += arcs(POP, lambda a: 8 + 70 * (a / POP) ** 1.5, lambda a: 0.06 + 0.22 * a / POP, sd + 1)
    start = st(sig, p0)
    # hit
    hit = st([zap(1.0, sd + 2, 0.12, 50), crack(0.05, 1, 0.7, 50, sd + 3), energy_hit(1.0, sd + 11, 0.75)], p0)
    # body: star, ring, bubble hum, crawling arcs, sparks
    lv = []
    for k in range(9):
        sa = k / FPS
        lv.append(min(1.2, 1.0 + 0.2 * (1 - sa / 0.05)) * sa / 0.05 if sa < 0.05 else max(0.0, 1 - (sa - 0.05) / 0.26))
    star = buzz(lv, 0.5, sd + 4, 150, 1)
    ring = air(0.4, 1, 8, 1.0, sd + 5, "fall") * 0.3
    L = BREAK - POP
    t = T(L)
    tt = t + POP
    ease = 1 - 2 ** (-10 * np.clip((tt - POP) / GROW, 0, 1))
    r = 0.12 + 0.88 * ease
    fr = np.floor(tt * FPS).astype(int)
    k = np.clip((tt - STROBE) / (BREAK - STROBE), 0, 1)
    off = np.array([(STROBE < a < BREAK) and jrand(S_, f) < 0.2 + 0.5 * kk for a, f, kk in zip(tt[::SR // 60], fr[::SR // 60], k[::SR // 60])])
    off = off.repeat(SR // 60)[:len(t)]
    off = np.concatenate([off, np.zeros(len(t) - len(off), bool)])
    hum_env = (0.35 + 0.65 * r) * (1 - off) * np.minimum(1, t / 0.05)
    hum = drone(L, hum_env, 82 * (1 + 0.15 * r), sd + 6, 5, 0.06, 0.5) * 0.12
    body = lay((blank(L + 0.3), 0), (spark_rain(m, 0, -7, 24, rng, (90, 220), 1.5, 0.07), 0))
    put(body, st(star, p0), 0)
    put(body, st(ring, p0), 0.01)
    put(body, st(hum, p0), 0)
    at = POP
    while True:
        at += rng.uniform(0.02, 0.05) if at > STROBE else rng.uniform(0.05, 0.11)
        if at >= BREAK:
            break
        rr = RM * (0.12 + 0.88 * (1 - 2 ** (-10 * min(1, (at - POP) / GROW))))
        x = np.cos(rng.uniform(0.1, np.pi - 0.1)) * rr
        c = S(zap(rng.uniform(0.08, 0.16), int(rng.integers(1, 999)), 0.05, 90),
              buzz([1, 0.6, 0.3][:int(rng.integers(2, 4))], 0.06, int(rng.integers(1, 999)), 140, 2))
        put(body, st(c, pan_of(m, x)), at - POP)
        if rng.random() < 0.35:
            put(body, st(tick(rng.uniform(0.05, 0.1), int(rng.integers(1, 99))), pan_of(m, x)), at - POP + rng.uniform(0.15, 0.3))
    # the break: it shorts out
    t = T(0.6)
    down = pulse(700 * (90 / 700) ** np.clip(t / 0.5, 0, 1), 0.125) * q(decay(t, 5)) * 0.2
    dead = glitter(1.0, decay(T(1.0), 3.2), 0, sd + 7, 0.85, True) * 0.1
    brk = st([zap(0.75, sd + 8, 0.12, 45), buzz([1, 0.8, 0.55, 0.3, 0.12], 0.4, sd + 9, 120, 1), down, dead,
              burst(0.4, 9, 0.12, 8, sd + 10)], p0)
    tail = lay((blank(1.0), 0), (spark_rain(m, 0, -3, 6, rng, (40, 120), 0.6, 0.05), 0.3))
    for _ in range(5):
        put(tail, st(spit(rng.uniform(0.08, 0.14), int(rng.integers(1, 99)), 0.04), p0), rng.uniform(0.1, 0.82))
    full = shot(m, [(start, 0), (hit, POP), (body, POP), (brk, BREAK), (tail, BREAK)])
    return leveled(m, full, {"start": start, "hit": hit, "body": body, "break": brk, "tail": tail},
                   "charge climbing (noise + glide fluttering with the blink, arcs denser) 0-0.42; zap + crack + energy hit at "
                   "the pop 0.42; star arcs, ring whoosh, bubble hum swelling and strobing off 1.25-1.58, skin arcs; "
                   "short-out at 1.58 (zap, falling glide, dead pixels glittering), dead puck spitting", -22)


def warp_in(m):
    """start (0 .. SLAM 0.34): energy streaks in to the spot: a quiet gather (noise climbing, a thin glide rising,
    streak ticks denser), the column dropping out of the sky in its last 0.06 s as a fast falling glide. hit (SLAM): the
    beam slams down: a crack, a zap, a heavy energy hit (zap gliding down, noise whoomp), vapour gushing out both ways,
    34 sparks ticking where they land. body: the beam's hum (a jittering low buzz on the beam's width, overshooting
    x1.45 at the slam and settling), thinner once its core hollows into a tube (OPEN 0.52); the scanline paints the hero
    head to toe (0.62 .. 1.4, ease in-out): a thin glide falling with it under a bright fizz, motes spat off the body's
    edge as ticks; at DONE 1.82 a soft glint. release (CLOSE 1.9 .. SNAP 2.16): the beam narrows to a thread, its buzz
    gliding up and thinning; SNAP: it snaps back up into the sky (a zip) with a crack and a small energy hit and 22
    sparks; tail: sparks landing."""
    sd = seed_of(m)
    rng = np.random.default_rng(sd)
    SLAM, OPEN, SCAN0, SCAN1, DONE, CLOSE, SNAP = 0.34, 0.52, 0.62, 1.4, 1.82, 1.9, 2.16
    Y0 = -38                                              # the hero's top row (local y)
    p0 = pan_of(m, 0)
    start = blank(SLAM)
    put(start, gather(SLAM - 0.05, 0.3, sd, 10, 2, 300, 1100, 2.0, 9, rng, 0.6), 0)
    t = T(0.06)
    put(start, st(sweep(2200, 500, 0.06, np.linspace(0.6, 1, len(t))) * 0.22 + noise(len(t), 1, seed=sd + 1) * q(np.linspace(0.3, 1, len(t))) * 0.2, p0), SLAM - 0.06)
    hit = lay((st([crack(0.05, 0, 0.8, 50, sd + 2), zap(0.6, sd + 3, 0.1, 60),
                   energy_hit(0.9, sd + 13, 0.75)], p0), 0),
              (st(wash(0.6, 3, 9, 1.0, 0.02, 4.5, sd + 4) * 0.22, (p0, p0 - 0.6)), 0),
              (st(wash(0.6, 3, 9, 1.0, 0.02, 4.5, sd + 5) * 0.22, (p0, p0 + 0.6)), 0),
              (spark_rain(m, 0, -1, 34, rng, (110, 270), 1.45, 0.07), 0))
    # body: the beam's hum and the scan
    L = CLOSE - SLAM
    t = T(L)
    tt = t + SLAM
    width = (1 + 0.45 * np.exp(-(tt - SLAM) * 14)) / 1.45
    hum = drone(L, width * np.minimum(1, t / 0.03), 110, sd + 6, np.where(tt < OPEN, 4, 2), 0.05, 0.5) * 0.18
    body = lay((st(hum, p0), 0), (blank(DONE - SLAM + 0.45), 0))
    ls = SCAN1 - SCAN0
    t = T(ls)
    u = t / ls
    env = np.sin(np.pi * u) ** 0.5
    paint = sweep(1800, 600, ls, env, 0.125, in_out_sine) * 0.07 + glitter(ls, env, 0, sd + 7, 0.6) * 0.06
    put(body, st(paint, p0), SCAN0 - SLAM)
    for y in range(Y0, 0):
        if rng.random() < 0.7:
            ts = SCAN0 + ls * np.arccos(1 - 2 * np.clip((y + 0.5 - (Y0 - 2)) / (3 - Y0), 0, 1)) / np.pi
            for s in (-1, 1):
                if rng.random() < 0.6:
                    put(body, st(tick(rng.uniform(0.04, 0.08), int(rng.integers(1, 99))), pan_of(m, s * 8)), ts - SLAM)
    put(body, st(glitter(0.4, decay(T(0.4), 8), 0, sd + 8, 0.7) * 0.08, p0), DONE - SLAM)
    # release: the beam pinches to a thread and snaps up
    lr = SNAP - CLOSE
    t = T(lr)
    u = t / lr
    pinch = drone(lr, 1 - 0.6 * u, 110 * (420 / 110) ** u, sd + 9, np.round(2 - 2 * u).astype(int), 0.05, 0.4) * 0.2
    rel = lay((st(pinch, p0), 0), (st([zip_in(0.14, 0.28, sd + 10, 600, 2400), crack(0.03, 0, 0.4, 80, sd + 11),
                                      energy_hit(0.1, sd + 14, 0.3)], p0), lr))
    tail = spark_rain(m, 0, -1, 22, rng, (90, 260), 1.4, 0.06)
    full = shot(m, [(start, 0), (hit, SLAM), (body, SLAM), (rel, CLOSE), (tail, SNAP)])
    return leveled(m, full, {"start": start, "hit": hit, "body": body, "release": rel, "tail": tail},
                   "gather + column dropping (0-0.34); slam crack + energy hit + vapour + sparks at 0.34; beam hum (overshoot, "
                   "thinner from 0.52), scan glide falling head to toe 0.62-1.4 with spat motes, glint 1.82; beam "
                   "pinching up 1.9-2.16, snap zip + crack + small energy hit at 2.16, sparks landing", -23)


def warp_out(m):
    """start: the act's windup (0.3 s, a quiet breath), then the charge (0 .. FLASH 0.42): motes gathering to the body
    and its outline flickering on denser: noise and a glide climbing, crackle getting denser. hit (FLASH): the hero
    flashes white: a zap and a light energy hit (it's light, not a landing). body (BREAK0 0.5 .. 1.1, head first): the
    body breaks into bits of light hauled up the beam: a bright fizz of bits letting go over a rush climbing toward
    hiss, the beam's hum opening with its width (0.5 .. 0.85) and holding. release (LIFT 1.3): the beam's foot lifts off
    the floor with a small pop (a crack, a quick upward blip and a puff) and 22 sparks; it pinches shut climbing (..
    GONE 1.62): the hum gliding up and thinning, cut. tail: sparks landing, stars winking out."""
    sd = seed_of(m)
    rng = np.random.default_rng(sd)
    FLASH, BREAK0, BREAK1, LIFT, GONE = 0.42, 0.5, 1.1, 1.3, 1.62
    w = windup_of(m, 0.3)
    p0 = pan_of(m, 0)
    ch = st(charge(FLASH, 12, 2, 260, 1000, 0.3, sd), p0)
    put(ch, st(arcs(FLASH, lambda a: 10 + 70 * (a / FLASH) ** 1.4, lambda a: 0.05 + 0.15 * a / FLASH, sd + 1), p0), 0)
    start = np.concatenate([st(breath(w, 12, 9, 0.08, sd + 2), p0), ch])
    hit = st([zap(0.8, sd + 3, 0.12, 55), energy_hit(0.2, sd + 13, 0.4), glitter(0.3, decay(T(0.3), 9), 0, sd + 4, 0.7) * 0.15],
             p0)
    L = LIFT - BREAK0
    t = T(L)
    tt = t + BREAK0
    wid = np.where(tt < BREAK0 + 0.35, (2 + 7 * (1 - (1 - np.clip((tt - BREAK0) / 0.35, 0, 1)) ** 3)) / 9, 1.0)
    hum = drone(L, wid, 120 * (1 + 0.3 * (wid - 0.2)), sd + 5, 3, 0.05, 0.5) * 0.24
    ub = np.clip((tt - BREAK0) / (BREAK1 + 0.12 - BREAK0), 0, 1)
    letgo = np.where(ub < 1, 0.4 + 0.6 * np.sin(np.pi * ub) ** 0.6, np.maximum(0, 1 - (tt - BREAK1 - 0.12) / 0.15))
    fizz = glitter(L, letgo, 0, sd + 6, 0.75) * 0.13
    rush = noise(len(t), np.round(7 - 6 * ub).astype(int), seed=sd + 7) * q(letgo * (0.4 + 0.6 * ub)) * 0.14
    rise = sweep(350, 1500, L, letgo * 0.6) * 0.06
    body = st((hum + fizz + rush + rise) * 0.7, p0)
    put(body, st(arcs(BREAK1 + 0.12 - BREAK0, lambda a: 40, lambda a: 0.07, sd + 8), p0), 0)
    lr = GONE - LIFT
    t = T(lr)
    u = t / lr
    pinch = drone(lr, 1 - 0.7 * u, 140 * (900 / 140) ** u, sd + 9, np.round(2 - 2 * u).astype(int), 0.05, 0.4) * 0.24
    rel = lay((st(pinch, p0), 0), (st([crack(0.03, 0, 0.45, 80, sd + 10), pop_hit(0.4, sd + 10, 0.4),
                                       air(0.4, 6, 1, 1.0, sd + 11, "fall") * 0.12], p0), 0),
              (st(zip_in(0.06, 0.18, sd + 12, 1500, 3000), p0), lr - 0.06))
    tail = lay((blank(1.0), 0), (spark_rain(m, 0, -1, 22, rng, (80, 220), 1.4, 0.06), 0))
    twinkles(tail, rng, 10, (0.2, 0.9), 0.05, (p0 - 0.2, p0 + 0.2))
    full = shot(m, [(ch, 0), (hit, FLASH), (body, BREAK0), (rel, LIFT), (tail, LIFT)])
    return leveled(m, full, {"start": start, "hit": hit, "body": body, "release": rel, "tail": tail},
                   "windup breath; charge climbing, outline crackle denser (0-0.42); white flash zap at 0.42; body breaking "
                   "into light 0.5-1.1 (fizz, rush, rising glide) over the beam's hum; foot lifts with a pop at 1.3, hum "
                   "gliding up and cut at 1.62; sparks landing", -23)


# ------------------------------------------------------------------ loops
def force_field(m):
    """The dome standing is silent (rule 2); the loop is its two hits. Each shot's tracer streaks in from the right edge
    in the 0.1 s before it lands (a zip panned from the edge to the impact). hit 1 (0.42, hit-stop 0.07, the heavy one):
    a zap and a short metallic sizzle on the shell, the energy hit's whoomp under it (no pitched drop); after the freeze
    the shell's buzz flares and settles, the fractures race out as a crackle thinning over 0.35 s, 24 sparks glance off
    up and right and tick where they land. hit 2 (1.5, hit-stop 0.03): the same, lighter and higher, no fractures."""
    sd = seed_of(m)
    rng = np.random.default_rng(sd)
    P = m["duration"]
    R = m["options"].get("radius", 44)
    W = m["size"][0] - m["origin"][0]
    SA = 0.13
    CA = np.sqrt(1 - SA * SA)
    (h1, f1), (h2, f2) = hits_of(m)
    loop = blank(P + X)
    out = {}
    for i, (ht, fz, lon, lat, big) in enumerate(((h1, f1, 0.66, 0.62, True), (h2, f2, 0.95, 0.26, False))):
        n = 1.0 if big else 0.55
        hx = R * np.cos(lat) * np.sin(lon)
        hy = -R * (np.sin(lat) * CA - np.cos(lat) * np.cos(lon) * SA)
        ph = pan_of(m, hx)
        tracer = st(zip_in(0.1, 0.22, sd + 10 * i, 900, 2300), (pan_of(m, W - 3), ph))
        hit = st([zap(0.95 * n + 0.05, sd + 10 * i + 1, 0.1, 55), burst(0.14, 1, 0.35 * n, 28, sd + 10 * i + 2, short=True),
                  energy_hit(0.8 if big else 0.35, sd + 10 * i + 5, 0.55 * n + 0.1)], ph)
        t = T(0.6)
        flare = drone(0.6, decay(t, 5.5) * n, 150 * (1 - 0.25 * t / 0.6), sd + 10 * i + 3, 2, 0.06, 0.5) * 0.3
        body = lay((st(flare, ph), 0), (spark_rain(m, hx, hy, int(24 * n), rng, (100 * (0.7 + 0.3 * n), 280 * (0.7 + 0.3 * n)),
                                                 0.7, 0.07, -1.25), 0))
        if big:
            put(body, st(arcs(0.35, lambda a: 10 + 130 * (1 - a / 0.35), lambda a: 0.26 * (1 - a / 0.4), sd + 10 * i + 4), ph), 0)
        lput(loop, tracer, ht - 0.1, P)
        lput(loop, hit, ht, P)
        lput(loop, body, ht + fz, P)
        one = lay((tracer, 0), (hit, 0.1), (body, 0.1 + fz))
        out["hit" if big else "hit_light"] = one
    loop = wrap(loop, P)
    return leveled(m, loop, dict(loop=loop, **out),
                   "silent dome; tracer zips in from the right (0.32, 1.40); heavy hit at 0.42 (zap, sizzle, energy whoomp; "
                   "after the 0.07 hit-stop shell buzz, fractures crackling, sparks glancing); light hit at 1.5", -25)


def glitch(m):
    """The hero's signal breaks up in three bursts a loop (frames 9-16 at 0.8, 33-37 at 0.5, 51-62 at 1, the JS's
    BURSTS): digital static, frame by frame on the JS's own draws (rand(seed, frame, ...)): its loudness from that
    frame's split and tears, short (metallic) mode when it interlaces, its rate jumping with the roll, panned toward
    the side the split throws the colours. Each burst opens with a small zap and snaps back clean with a click; dead
    pixels thrown off tick faintly. Calm between bursts: silent (a lone row slipping is not an event)."""
    sd = seed_of(m)
    rng = np.random.default_rng(sd)
    S_ = int(m["options"].get("seed", 7))
    P = m["duration"]
    BURSTS = [(9, 16, 0.8), (33, 37, 0.5), (51, 62, 1.0)]
    p0 = pan_of(m, 0)
    loop = blank(P + X)
    first = None
    for a, b, k in BURSTS:
        lv, rate, short, pans = [], [], [], []
        for f in range(a, b + 1):
            r = lambda *n: jrand(S_, f, *n)
            split = round(1 + r(1) * 3 * k) * (-1 if r(2) < 0.5 else 1)
            tears = 1 + int(np.floor(r(3) * 4 * k))
            roll = r(12) < 0.15
            poster = r(14) < 0.15 * k
            lv.append(min(1.0, 0.3 + 0.1 * abs(split) + 0.06 * tears + 0.15 * roll + 0.15 * poster))
            rate.append(int(np.floor(r(13) * 3)) + (6 if roll else 1))
            short.append(r(11) < 0.3)
            pans.append(float(np.clip(p0 + 0.12 * split, -0.8, 0.8)))
        secs = (b - a + 1) / FPS
        t = T(secs)
        env = per_frame(lv, secs) * k
        rt = per_frame(rate, secs).astype(int)
        sh = per_frame(short, secs) > 0.5
        sig = np.where(sh, noise(len(t), rt, True, sd + a), noise(len(t), rt, False, sd + a + 1)) * q(env) * 0.3
        sig += pulse(per_frame(rng.uniform(70, 110, len(lv)), secs), 0.125) * q(env) * 0.08   # the mains buzz under it
        part = st_path(sig, per_frame(pans, secs))
        put(part, st(zap(0.45 * k + 0.1, sd + a + 2, 0.05, 80), pans[0]), 0)
        snap = blank(0.35)
        place(snap, burst(0.012, 0, 0.3 * k, 200, sd + a + 3, short=True), 0, p0)
        part = np.concatenate([part, snap])
        for i in range(int(10 * k)):
            life = 4 + int(np.floor(jrand(S_, a, i) * 6))
            at = int(np.floor(jrand(S_, a, i, 1) * (b - a + 1)))
            put(part, st(tick(0.04, int(rng.integers(1, 99))), p0 + (-0.3 if jrand(S_, a, i, 4) < 0.5 else 0.3)), (at + life) / FPS)
        lput(loop, part, a / FPS, P)
        first = first if first is not None else part
    loop = wrap(loop, P)
    return leveled(m, loop, {"loop": loop, "burst": first},
                   "static bursts on frames 9-16, 33-37, 51-62 (level/mode/pan per frame from the JS's draws), a zap in, "
                   "a click out, dead pixels ticking; silent calm between", -28)


def jetpack(m):
    """Loop (2 s): twin thrusters firing down, each panned to its own nozzle (x +-8): a white-hot hiss at the nozzle and
    a roar down the plume, both breathing with the JS's flame length (0.92 + 0.08 sin(2pi 7 ph + side) + a random step
    per frame, rand(seed, frame, side, 1)), a low rumble under them, sparks spat out of the exhaust as little spits at
    random. start: ignition (a pop, a gas whoomp, a rush rising into the roar); stop: the jets cutting out, a puff."""
    sd = seed_of(m)
    rng = np.random.default_rng(sd)
    S_ = int(m["options"].get("seed", 30))
    P = m["duration"]
    NF = int(round(P * FPS))
    t = T(P + X)
    loop = blank(P + X)
    for s in (-1, 1):
        lv = [0.92 + 0.08 * np.sin(TAU * 7 * (f % NF) / NF + s) + 0.06 * (jrand(S_, f % NF, s, 1) - 0.5) for f in range(NF + 3)]
        env = per_frame(lv, P + X)
        sig = noise(len(t), 1, seed=sd + s) * q(env) * 0.16 + noise(len(t), 10, seed=sd + 3 + s) * q(env) * 0.26
        place(loop, sig, 0, pan_of(m, s * 8))
    place(loop, noise(len(t), 14, seed=sd + 7) * 0.08, 0, pan_of(m, 0))
    for _ in range(20):
        s = rng.choice((-1, 1))
        lput(loop, st(spit(rng.uniform(0.05, 0.1), int(rng.integers(1, 99)), 0.03), pan_of(m, s * rng.uniform(8, 30))),
             rng.uniform(0, P), P)
    loop = wrap(loop, P)
    start = st([crack(0.04, 3, 0.4, 60, sd + 8), ignite(sd + 13, 0.4, 0.4), air(0.35, 9, 2, 0.3, sd + 9, "rise")],
               pan_of(m, 0))
    t = T(0.5)
    stop = st([noise(len(t), 10, seed=sd + 10) * q(decay(t, 8)) * 0.26, noise(len(t), 1, seed=sd + 11) * q(decay(t, 12)) * 0.16,
               burst(0.08, 5, 0.25, 30, sd + 12)], pan_of(m, 0))
    return leveled(m, loop, {"loop": loop, "start": start, "stop": stop},
                   "twin nozzle hiss + plume roar breathing with the flame length per frame, low rumble, random spits; "
                   "start = ignition, stop = cut-out puff", -27)


def scanner(m):
    """Loop (3.2 s), a scan with its own beats. The brackets fly in and snap on (0 .. LOCK 0.3, outBack): a short rise
    (noise and a thin glide), a latch click at the lock (a tiny steel tick) with the box flashing out (a soft breath of
    air). The scan line sweeps head to toe (SCAN0 0.42 .. SCAN1 1.6, ease in-out): a thin jittering buzz gliding down
    with it, data bits flicked off the body's edges as faint ticks at the times the line crosses their rows (rand(seed,
    y, side) < 0.6). DONE 1.75: the OK, the one UI confirmation allowed: one short blip on each of the brackets' two
    flashes (1.75, 1.87), same pitch, the second softer. LET 2.5: the brackets let go: a short falling glide, a breath.
    Nothing between."""
    sd = seed_of(m)
    rng = np.random.default_rng(sd)
    S_ = int(m["options"].get("seed", 22))
    P = m["duration"]
    LOCK, SCAN0, SCAN1, DONE, LET = 0.3, 0.42, 1.6, 1.75, 2.5
    AY = -38                                              # the hero's top row (local y)
    p0, pr = pan_of(m, 0), pan_of(m, 40)
    loop = blank(P + X)
    t = T(LOCK)
    u = t / LOCK
    fly_in = noise(len(t), np.round(5 - 4 * u).astype(int), seed=sd) * q(0.2 + 0.8 * u ** 2) * 0.08 + \
        sweep(500, 1400, LOCK, 0.2 + 0.8 * u ** 2) * 0.05
    lput(loop, st(fly_in, p0), 0, P)
    latch = S(burst(0.02, 0, 0.35, 160, sd + 1, short=True), metal_hit(0.0, sd + 5, 0.2))
    lput(loop, st(latch, p0), LOCK, P)
    lput(loop, st(air(0.3, 2, 7, 1.0, sd + 2, "fall") * 0.08, p0), LOCK, P)
    ls = SCAN1 - SCAN0
    t = T(ls)
    u = t / ls
    env = np.minimum(1, t / 0.06) * np.minimum(1, (ls - t) / 0.08)
    f = 1500 * (520 / 1500) ** in_out_sine(u)
    beam = drone(ls, env, f, sd + 3, 1, 0.02, 0.35) * 0.05
    lput(loop, st(beam, p0), SCAN0, P)
    for y in range(AY, 0, 3):
        ts = SCAN0 + ls * np.arccos(1 - 2 * np.clip((y + 0.5 - (AY - 3)) / (4 - AY), 0, 1)) / np.pi
        for s in (-1, 1):
            if jrand(S_, y, s) < 0.6:
                lput(loop, st(tick(rng.uniform(0.05, 0.09), int(rng.integers(1, 99))), pan_of(m, s * 9)), ts, P)
    ok = blank(0.25)
    place(ok, blip(1320, 0.07, 0.25, 0.45, 40), 0, pr)
    place(ok, blip(1320, 0.07, 0.25, 0.28, 40), 0.12, pr)
    lput(loop, ok, DONE, P)
    t = T(0.45)
    let = sweep(1200, 300, 0.45, decay(t, 5)) * 0.07 + noise(len(t), 3, seed=sd + 4) * q(decay(t, 7)) * 0.05
    lput(loop, st(let, p0), LET, P)
    loop = wrap(loop, P)
    return leveled(m, loop, {"loop": loop, "ok": ok},
                   "brackets rise in, latch click at 0.3; scan buzz gliding down head to toe 0.42-1.6 with data-bit ticks; "
                   "two same-pitch OK blips on the flashes 1.75/1.87 (UI confirmation); falling glide as they let go 2.5",
                   -28)


def tractor_beam(m):
    """Loop (3 s): the cone hums faintly (a low jittering buzz: it's working). Seven rocks a loop torn up at the JS's
    own times and spots (born i/7 D + rn.range(+-0.06), x = cos(th0) r0, the original's Rng): each pops out of the floor
    with a stony crack, a stone knock sized by the rock and a puff of dust, its grit thrown up ticking down; after its
    hover it spirals up the beam quickening (lift^1.8): a rush climbing from rumble to hiss, panned round the spiral it
    takes (1.3 turns, closing in); swallowed at the lens (LIFE - 0.08) with a soft pop of light (a quick upward blip and
    a puff)."""
    sd = seed_of(m)
    rng = np.random.default_rng(sd)
    o = m["options"]
    P = m["duration"]
    POP, HOVER, RISE = 0.1, 0.32, 1.4
    LIFE = POP + HOVER + RISE
    rn = Rng(int(o.get("seed", 9)))
    rocks = []
    for i in range(7):
        born = (i / 7) * P + rn.range(-0.06, 0.06)
        r0 = rn.range(8, 25)
        th0 = (0 if i % 2 else np.pi) + rn.range(-0.45, 0.45)
        d = rn.sign()
        s = rn.range(2.4, 4.4)
        rn.range(0, TAU)
        rn.range(-7, 7)
        rocks.append((born, r0, th0, d, s))
    loop = blank(P + X)
    t = T(P + X)
    place(loop, drone(P + X, 1.0, 72, sd, 6, 0.05, 0.6) * 0.035, 0, pan_of(m, 0))
    for i, (born, r0, th0, d, s) in enumerate(rocks):
        x = np.cos(th0) * r0
        w = s / 4.4
        tear = S(crack(0.03, 4, 0.25 * w, 70, sd + 10 * i), stone_hit(0.15 + 0.3 * w, sd + 10 * i + 1, 0.3 * w),
                 air(0.35, 8, 11, 1.0, sd + 10 * i + 2, "fall") * 0.12)
        lput(loop, st(tear, pan_of(m, x)), born, P)
        lands = []
        for _ in range(6):
            lands += grit_lands(rng.uniform(-45, 45), -rng.uniform(60, 150), x, -2, rng)
        lput(loop, debris(m, lands, 0.12, 7, seed=sd + 10 * i + 3), born + 0.02, P)
        t = T(RISE)
        k = t / RISE
        sp = k ** 1.8
        speed = np.gradient(sp) * SR * RISE / 1.8
        th = th0 + d * TAU * 1.3 * sp
        rr = r0 * (1 - 0.5 * sp) * (1 - 0.8 * sp)
        env = np.clip(0.15 + 0.85 * speed, 0, 1) * np.minimum(1, (RISE - t) / 0.06)
        rush = noise(len(t), np.round(11 - 9 * sp).astype(int), seed=sd + 10 * i + 4) * q(env) * 0.12
        lput(loop, st_path(rush, np.array([pan_of(m, v) for v in np.cos(th) * rr])), born + POP + HOVER, P)
        lput(loop, st(S(crack(0.03, 0, 0.22, 80, sd + 10 * i + 5), pop_hit(0.2, sd + 10 * i + 5, 0.28)), pan_of(m, 0)),
             born + LIFE - 0.08, P)
    loop = wrap(loop, P)
    return leveled(m, loop, {"loop": loop},
                   "faint beam hum; 7 rocks torn loose at the JS's times (crack, stone knock, dust, grit ticks), each spiralling "
                   "up as a rush climbing to hiss panned round its spiral, a soft pop at the lens", -29)


SOUNDS = {
    "emp-blast": emp_blast,
    "energy-core": energy_core,
    "force-field": force_field,
    "glitch": glitch,
    "hologram": hologram,
    "jetpack": jetpack,
    "laser-grid": laser_grid,
    "scanner": scanner,
    "teleporter-pad": teleporter_pad,
    "tractor-beam": tractor_beam,
    "warp-in": warp_in,
    "warp-out": warp_out,
}
