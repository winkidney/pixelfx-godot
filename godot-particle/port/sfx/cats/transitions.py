# transitions: a screen wipe is a strong dynamic moment, so each is one gesture that follows the wipe's own progress
# curve (references/sound.md): a sweep, a whoosh, a glide, a crumble, never a tune (rule 1). Its level follows how fast
# the wipe moves (the derivative of the original's ease), its pan where the moving edge is across the screen. Material
# where the picture has one (rule 3): blinds clack as their wooden slats shut, a fire wipe crackles as much as it is
# burning (the pixels its front crosses each frame, from the original's own fields), a glass pane lands, cracks and
# breaks (glass: cats/ice.py voices, synth glass_hit), a blade edge rings and grinds sparks (metal); a CRT dies the
# classic way, a falling glide and a pop. A wipe is not a blow: none carries the pitch-dropping thump (a blast's,
# sound.md rule 2), and most carry no weight at all.
# Beats from src/fx/transitions/<name>.js, its fields and hashes (src/core/math.js) recomputed here.
import numpy as np
from synth import *  # noqa: F401,F403
from cats.explosions import burst, wash
from cats.impacts import crack, knock, ring, air, st, put, S, seed_of
from cats.arcane import JsRng, glitter, sweep, twinkles, TAU
from cats.ice import q, icecrack, tinkle, iceknock, shatter, crackles, leveled
from cats.fire import crackle
from cats.projectiles import shot, st_path

W, H, FPS = 320, 180, 30
M32 = np.uint64(0xFFFFFFFF)


# ------------------------------------------------------------------ the original's hashes and noise, vectorized
def vhash(*ns):
    """src/core/math.js hash() over arrays (uint32 arithmetic): the same values as cats/water.py jhash."""
    h = np.uint64(0x9E3779B9)
    for n in ns:
        n = (np.asarray(n).astype(np.int64) & 0xFFFFFFFF).astype(np.uint64)
        h = ((h ^ n) * np.uint64(0x85EBCA6B)) & M32
        h ^= h >> np.uint64(13)
        h = (h * np.uint64(0xC2B2AE35)) & M32
        h ^= h >> np.uint64(16)
    return h


def vrand(*ns):
    return vhash(*ns).astype(float) / 4294967296


def vnoise(x, seed):
    i = np.floor(x)
    f = x - i
    u = f * f * (3 - 2 * f)
    return (vrand(i, seed) + (vrand(i + 1, seed) - vrand(i, seed)) * u) * 2 - 1


def vnoise2(x, y, seed):
    ix, iy = np.floor(x), np.floor(y)
    fx, fy = x - ix, y - iy
    ux, uy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
    a, b = vrand(ix, iy, seed), vrand(ix + 1, iy, seed)
    c, d = vrand(ix, iy + 1, seed), vrand(ix + 1, iy + 1, seed)
    top, bot = a + (b - a) * ux, c + (d - c) * ux
    return (top + (bot - top) * uy) * 2 - 1


def vfbm(x, y, seed, octaves=3):
    s, a, n = 0.0, 0.5, 0.0
    for o in range(octaves):
        s = s + vnoise2(x, y, seed + o * 101) * a
        n += a
        x, y, a = x * 2.03, y * 2.03, a * 0.5
    return s / n


# ------------------------------------------------------------------ eases (src/core/math.js)
def clamp(x, a=0.0, b=1.0):
    return np.clip(x, a, b)


def in_out_cubic(u):
    return np.where(u < 0.5, 4 * u ** 3, 1 - (-2 * u + 2) ** 3 / 2)


def in_out_quad(u):
    return np.where(u < 0.5, 2 * u * u, 1 - (-2 * u + 2) ** 2 / 2)


def out_back(u, s=1.70158):
    return 1 + (s + 1) * (u - 1) ** 3 + s * (u - 1) ** 2


def speed_of(f, t):
    """|d/dt| of a motion f(t) sampled on t, normalized to its own peak (0 .. 1)."""
    v = np.abs(np.gradient(f, t))
    return v / (v.max() or 1)


def gesture(speed, r_fast, r_slow, vol, seed, am=None):
    """Air moved by the wipe: noise as loud as the wipe is fast (speed 0..1 per sample), at rate r_fast when it rushes
    and r_slow as it eases (mono)."""
    sp = np.clip(speed, 0, 1)
    rate = np.round(r_slow + (r_fast - r_slow) * sp).astype(int)
    return noise(len(sp), rate, seed=seed) * q(sp if am is None else sp * am) * vol


def px_pan(x, k=0.85):
    return float(np.clip((x / W * 2 - 1) * k, -1, 1))


# ------------------------------------------------------------------ blinds
def blinds(m):
    """12 slats tilt shut top to bottom (slat i from SHUT0 0.08 + i STEP 0.038 over TURN 0.42, outBack 1.6): each clacks
    shut on the frame its turn first reaches flat (u = 1 / 2.6, 0.24 + i 0.038), a wooden clatter running down, over
    the swish of all of them turning; OPEN0 1.02 they tilt open (+ i 0.03 over 0.4, inOutCubic): a softer swish with
    faint ticks as they part; FADE 1.72 silent."""
    s = seed_of(m)
    rng = np.random.default_rng(s)
    N, SHUT0, OPEN0, STEP, TURN, OSTEP, OTURN, BK = 12, 0.08, 1.02, 0.038, 0.42, 0.03, 0.4, 1.6
    t = T(OPEN0 + 0.3)
    tot = np.zeros(len(t))
    for i in range(N):
        tot += speed_of(np.pi / 2 * out_back(clamp((t - SHUT0 - i * STEP) / TURN), BK), t)
    start = stereo(gesture(tot / tot.max(), 4, 7, 0.22, s))
    for i in range(N):
        at = SHUT0 + i * STEP + TURN / (BK + 1)
        a, sd, r = rng.uniform(0.6, 1), int(rng.integers(1, 999)), int(rng.integers(6, 9))
        c = S(knock(0.4 * a, sd, r, 0.05, 70), wood_hit(0.1 + 0.03 * (r - 6), sd + 1, 0.3 * a),   # a light wooden clack
              tick(0.15, int(rng.integers(1, 999)), short=False))
        place(start, c, at, rng.uniform(-0.3, 0.3))
    t = T(OTURN + N * OSTEP + 0.1)
    tot = np.zeros(len(t))
    for i in range(N):
        tot += speed_of(np.pi / 2 * (1 - in_out_cubic(clamp((t - i * OSTEP) / OTURN))), t)
    rel = stereo(gesture(tot / tot.max(), 4, 7, 0.16, s + 1))
    for i in range(N):
        place(rel, tick(0.07 * rng.uniform(0.5, 1), int(rng.integers(1, 999)), short=False), i * OSTEP + 0.04, rng.uniform(-0.3, 0.3))
    full = shot(m, [(start, 0), (rel, OPEN0)])
    return leveled(m, full, {"start": start, "release": rel},
                   "slats swish shut with a wooden clack each running down the screen (0.24-0.66); a softer swish "
                   "and faint ticks as they tilt open (1.02-1.75)", -26)


# ------------------------------------------------------------------ burn away
def burn_away(m):
    """The screen burns in from its edges (the original's in-field, kIn 0 .. CLOSE 1.18): a fire roar and crackles as
    loud as the pixels the ember front crosses each frame, left and right as they burn there; CLOSE 1.18 it closes with
    a flare (a soft whump of air, embers bursting); dark at COVER 1.35; SMOULDER 1.5 faint smouldering; POP 1.8 it
    burns open from the middle (an ignition whoosh, its low rush the only weight), the front racing out then slowing (outQuad to OPEN 2.62),
    crackling as it burns; embers die after."""
    s = seed_of(m)
    rng = np.random.default_rng(s)
    D, CLOSE, COVER, SMOULDER, POP, OPEN, SC = m["duration"], 1.18, 1.35, 1.5, 1.8, 2.62, 90
    seed = s * 13
    y, x = np.mgrid[0:H, 0:W] + 0.5
    ux, uy = (x - W / 2) / (W / 2), (y - H / 2) / (H / 2)
    mm = (ux ** 4 + uy ** 4) ** 0.25
    A = (1 - mm) * SC + 14 * vfbm(x / 44, y / 44, seed, 3) + 2.4 * vfbm(x / 7, y / 7, seed + 9, 2) + 7 * (0.5 - y / H)
    R = JsRng((seed + 1) * 31 + 5)
    ox, oy = W / 2 + R.range(-26, 26), H / 2 + R.range(-14, 6)
    sats = []
    for sg in (-1, 1):
        sats.append((ox + sg * R.range(70, 110), oy + R.range(-40, 40), R.range(30, 44)))
    B = np.hypot((x - ox) / (W / 2), (y - oy) / (H / 2)) * SC
    for sx, sy, d in sats:
        B = np.minimum(B, d + np.hypot((x - sx) / (W / 2), (y - sy) / (H / 2)) * SC * 1.15)
    B = B + 13 * vfbm(x / 40, y / 40, seed + 1 + 21, 3) + 2.4 * vfbm(x / 7, y / 7, seed + 1 + 33, 2)

    def k_in(t):
        return A.min() - 8 + (A.max() - A.min() + 8) * (max(0.0, t) / CLOSE) ** 1.25

    def k_out(t):
        u = np.clip((t - POP) / (OPEN - POP), 0, 1)
        return B.min() + (B.max() - B.min() + 16) * (1 - (1 - u) ** 2)

    # per frame: the pixels the front crosses, how many on each side and a few of their x for the crackles' pans
    nfr = int(D * FPS) + 1
    lo_, hi_ = np.zeros(nfr), np.zeros(nfr)
    picks = [[] for _ in range(nfr)]
    left = x < W / 2
    prev_in, prev_out = A < k_in(0.0), B < B.min()
    for i in range(nfr):
        t = i / FPS
        if t < COVER:
            burnt = A < k_in(t)
            new, prev_in = burnt & ~prev_in, burnt
        elif t >= POP:
            burnt = B < k_out(t)
            new, prev_out = burnt & ~prev_out, burnt
        else:
            continue
        lo_[i], hi_[i] = (new & left).sum(), (new & ~left).sum()
        xs = x[new]
        if len(xs):
            picks[i] = list(rng.choice(xs, min(6, len(xs)), replace=False))
    tot = lo_ + hi_
    peak = np.percentile(tot[tot > 0], 95)
    secs = D + 0.4
    t = T(secs)
    fr = np.minimum((t * FPS).astype(int), nfr - 1)
    kern = np.ones(4) / 4
    envL = np.interp(t * FPS, np.arange(nfr), np.convolve(np.clip(lo_ / peak * 2, 0, 1), kern, "same")) ** 0.6
    envR = np.interp(t * FPS, np.arange(nfr), np.convolve(np.clip(hi_ / peak * 2, 0, 1), kern, "same")) ** 0.6
    wob = 0.85 + 0.15 * np.sin(TAU * 3.1 * t) * np.sin(TAU * 1.7 * t + 1)
    full_bed = blank(secs)
    for ch, env in ((0, envL), (1, envR)):
        sig = noise(len(t), np.where(fr % 7 < 3, 11, 10), seed=s + ch) * q(env * wob) * 0.3
        sig += noise(len(t), 3, seed=s + 2 + ch) * q(env * wob) * 0.09
        full_bed[:, ch] += sig
    cr = blank(secs)
    for i in range(nfr):
        n = rng.poisson(tot[i] / peak * 2.2)
        for _ in range(n):
            xx = picks[i][int(rng.integers(len(picks[i])))] if picks[i] else W / 2
            c = burst(rng.uniform(0.015, 0.035), int(rng.integers(0, 4)), 0.22 * rng.uniform(0.4, 1), 90, int(rng.integers(1, 999)))
            place(cr, c, i / FPS + rng.uniform(0, 1 / FPS), px_pan(xx))
    start = full_bed[: int(COVER * SR)] + cr[: int(COVER * SR)]
    flare = blank(1.0)
    place(flare, wash(0.6, 9, 12, 0.3, 0.015, 5, s + 4), 0)
    place(flare, wash(0.25, 14, 10, 0.3, 0.01, 12, s + 7), 0)
    crackle(flare, rng, 12, (0.0, 0.5), 0.2, (-0.3, 0.3))
    smoul = blank(POP - SMOULDER)
    tt = T(POP - SMOULDER)
    place(smoul, noise(len(tt), 11, seed=s + 5) * q((tt / (POP - SMOULDER)) ** 2) * 0.05, 0)
    crackle(smoul, rng, 2, (0.03, 0.25), 0.09, (-0.4, 0.4))
    hit = blank(1.0)
    pp = px_pan(ox)
    place(hit, wash(0.7, 13, 6, 0.6, 0.02, 3.5, s + 6), 0, pp)
    twinkles(hit, rng, 12, (0.05, 0.45), 0.12, (pp - 0.5, pp + 0.5), 0.2)
    i0 = int(POP * SR)
    body = full_bed[i0:] + cr[i0:]
    full = shot(m, [(start, 0), (flare, CLOSE), (smoul, SMOULDER), (hit, POP), (body, POP)])
    return leveled(m, full, {"start": start, "flare": flare, "smoulder": smoul, "hit": hit, "body": body},
                   "fire roar + crackles as much as the front burns in from the edges (0-1.18, L/R where it burns), "
                   "closing whump at 1.18, dark, smoulder 1.5-1.8, ignition whoosh at 1.8, crackling front racing "
                   "out (1.8-2.62)", -24)


# ------------------------------------------------------------------ CRT off
def crt_off(m):
    """Off: the picture squeezes into a line (SQ0 0.06 .. SQ1 0.34, inCubic) and the line into a dot (.. LN1 0.56,
    inQuad): the classic tube collapse, a glide falling with the picture's height then the line's length, the
    picture's static hissing out with it, a pop as it collapses to the dot; the dot's afterglow fades with a faint
    whine (.. 0.86). On (ON0 1.06): a relay click and a dull noise thunk, a glide rising with the line (outExpo .. 1.16) and the
    picture opening (outCubic .. OPEN1 1.42), static swelling in and settling."""
    s = seed_of(m)
    SQ0, SQ1, LN1, DOT1, ON0, ON1, OPEN1 = 0.06, 0.34, 0.56, 0.86, 1.06, 1.16, 1.42
    secs = LN1 - SQ0
    t = T(secs) + SQ0
    h = np.where(t < SQ1, 1 - ((t - SQ0) / (SQ1 - SQ0)) ** 3, 0)
    w = np.where(t < SQ1, 1, 1 - np.clip((t - SQ1) / (LN1 - SQ1), 0, 1) ** 2)
    prog = np.where(t < SQ1, 0.6 * h + 0.4, 0.4 * w)                 # the glide falls with the height, then the line
    f = 55 * (1600 / 55) ** prog
    off = pulse(f, 0.25) * q(0.5 + 0.5 * (1 - prog) ** 0.5) * 0.22
    off += tri(f * 0.5) * q(np.full(len(t), 1.0)) * 0.12
    off += noise(len(t), 1, seed=s) * q(h ** 1.5) * 0.12
    offb = blank(DOT1 - SQ0 + 0.3)
    place(offb, off, 0)
    place(offb, S(crack(0.03, 2, 0.6, 70, s + 1), knock(0.35, s + 4, 10, 0.08, 40)), secs)
    tg = T(DOT1 - LN1)
    place(offb, tri(np.full(len(tg), 3950.0)) * q(decay(tg, 9)) * 0.025, secs + 0.01)
    on = blank(OPEN1 - ON0 + 0.4)
    place(on, S(tick(0.35, s + 2, short=False), knock(0.35, s + 5, 12, 0.12, 30)), 0)
    t2 = T(OPEN1 - ON0)
    a = t2 + ON0
    lin = np.where(a < ON1, 1 - 2 ** (-10 * (a - ON0) / (ON1 - ON0)), 1)
    opn = np.where(a < ON1, 0, 1 - (1 - np.clip((a - ON1) / (OPEN1 - ON1), 0, 1)) ** 3)
    rise = 0.5 * lin + 0.5 * opn
    place(on, pulse(70 * (1400 / 70) ** rise, 0.125) * q(1 - 0.7 * opn) * 0.1, 0.01)
    place(on, noise(len(t2), 1, seed=s + 3) * q(np.sin(np.pi * np.clip(rise, 0, 1)) ** 0.7) * 0.18, 0.01)
    full = shot(m, [(offb, SQ0), (on, ON0)])
    return leveled(m, full, {"off": offb, "on": on},
                   "tube off: glide falling with the squeeze (0.06-0.34) and the line (-0.56), static hissing out, "
                   "pop at the dot (0.56), faint whine fading; on at 1.06: click + thunk, rising glide and static "
                   "swell as the line and picture open (-1.42)", -25)


# ------------------------------------------------------------------ diamond wipe
def _lattice(seed):
    S_, HD, IN0, IN1, OUT0, OUT1 = 32, 17, 0.04, 0.66, 1.05, 1.56
    out = []
    for j in range(-1, int(np.ceil(H / (S_ / 2))) + 2):
        for i in range(-1, int(np.ceil(W / S_)) + 2):
            cx, cy = i * S_ + (S_ / 2 if j & 1 else 0), j * S_ / 2
            if cx + HD < 0 or cy + HD < 0 or cx - HD > W or cy - HD > H:
                continue
            u = min(1, max(0, (cx + 0.45 * cy) / (W + 0.45 * H)))
            jr = float(vrand(i, j, seed))
            out.append(dict(cx=cx, cy=cy, glint=jr < 0.3,
                            tin=IN0 + (IN1 - IN0) * min(1, max(0, u + (jr - 0.5) * 0.08)),
                            tout=OUT0 + (OUT1 - OUT0) * min(1, max(0, u + (float(vrand(i, j, seed + 1)) - 0.5) * 0.08))))
    return out


def diamond_wipe(m):
    """A wave of diamonds swells across the screen on a slant, left to right (tin 0.04 .. 0.66, each swelling over
    GROW 0.24): a glassy shimmer as loud as how many are swelling and panned where they are, the glinting ones (30 %)
    tinking as they snap to size; locked and cooled, silent; then (tout 1.05 .. 1.56) they rise again and shrink away
    with a lighter shimmer and their last glints winking."""
    s = seed_of(m)
    rng = np.random.default_rng(s)
    L = _lattice(s)
    GROW = 0.24
    secs = 2.0
    t = T(secs)
    tf = np.arange(0, secs, 1 / 120)
    parts = []
    for key, d0, d1, vol in (("tin", 0.0, 0.6, 1.0), ("tout", 0.0, 1.0, 0.6)):
        cnt, xs = np.zeros(len(tf)), np.zeros(len(tf))
        for d in L:
            k = (tf - d[key]) / GROW
            on = (k > d0) & (k < d1)
            cnt += on
            xs += on * d["cx"]
        pan = np.where(cnt > 0, xs / np.maximum(cnt, 1) / W * 2 - 1, 0) * 0.8
        env = np.interp(t, tf, cnt / cnt.max())
        sig = glitter(secs, env, 1, s + len(parts), 0.6, True) * 0.2 * vol + gesture(env, 3, 6, 0.12 * vol, s + 9 + len(parts))
        parts.append(st_path(sig, np.interp(np.linspace(0, secs, 400), tf, pan)))
    full_ = parts[0] + parts[1]
    for d in L:
        if d["glint"]:
            place(full_, tinkle(0.3 * rng.uniform(0.4, 1), int(rng.integers(1, 999)), rng.uniform(2800, 4500)),
                  d["tin"] + 0.09, px_pan(d["cx"]))
            place(full_, tinkle(0.16 * rng.uniform(0.4, 1), int(rng.integers(1, 999)), rng.uniform(3200, 4800)),
                  d["tout"] + 0.7 * GROW, px_pan(d["cx"]))
    i1 = int(1.0 * SR)
    start, rel = full_[:i1], full_[i1:]
    full = shot(m, [(start, 0), (rel, 1.0)])
    return leveled(m, full, {"start": start, "release": rel},
                   "glassy shimmer sweeping L->R with the swelling diamonds (0.04-0.9), glint tinks as they snap; "
                   "silent while locked; lighter shimmer and winking glints as they shrink away (1.05-1.9)", -26)


# ------------------------------------------------------------------ glitch wipe
def glitch_wipe(m):
    """Torn bands of black stutter across the screen on the original's 18 Hz ticks (IN 0.03 .. 0.78, OUT 0.98 .. 1.66):
    every jump a band makes is a digital burst (its own noise rate, length and mode, as loud as the jump and the band
    is thick, panned at its edge), a freeze is a dropout, a jerk back a little data chirp; while it is all black the
    signal spits a faint blip now and then."""
    s = seed_of(m)
    rng = np.random.default_rng(s)
    TICK, IN0, IN1, OUT0, OUT1 = 1 / 18, 0.03, 0.78, 0.98, 1.66
    bands, y, i = [], 0, 0
    while y < H:
        r = float(vrand(i, s))
        h = min(H - y, 5 + int(vrand(i, s + 1) * 6) if r < 0.4 else 10 + int(vrand(i, s + 1) * 10) if r < 0.85
                else 20 + int(vrand(i, s + 1) * 12))
        a = np.clip(0.5 + 0.55 * vnoise(np.array(y / 40), s + 9) + (float(vrand(i, s + 2)) - 0.5) * 0.25, 0, 1)
        b = np.clip(0.5 + 0.55 * vnoise(np.array(y / 40), s + 19) + (float(vrand(i, s + 3)) - 0.5) * 0.25, 0, 1)
        span = 0.32 + float(vrand(i, s + 6)) * 0.12
        t0 = IN0 + a * (IN1 - IN0 - span)
        o0 = OUT0 + b * (OUT1 - OUT0 - span)
        bands.append(dict(i=i, h=h, dir=1 if vrand(i, s + 4) < 0.82 else -1, off=float(vrand(i, s + 5)),
                          t0=float(t0), t1=float(t0 + span), o0=float(o0), o1=float(o0 + span)))
        y += h
        i += 1

    def tear(b, t, t0, t1, salt):
        if t <= t0:
            return 0.0
        if t >= t1:
            return 1.0
        n = int(np.floor((t + b["off"] * TICK) / TICK))
        while n > 0 and vrand(n, b["i"], salt) < 0.22:
            n -= 1
        tq = n * TICK - b["off"] * TICK
        u = min(1, max(0, (tq - t0) / (t1 - t0)))
        return float(np.clip(in_out_quad(u) + (float(vrand(n, b["i"], salt + 1)) - 0.6) * 0.12 * np.sin(np.pi * u), 0, 1))

    buf = blank(m["duration"] + 0.2)
    dt = 1 / 180
    for b in bands:
        for out in (False, True):
            t0, t1, salt = (b["o0"], b["o1"], 7) if out else (b["t0"], b["t1"], 3)
            prev = tear(b, t0, t0, t1, salt)
            for t in np.arange(t0, t1 + dt, dt):
                k = tear(b, t, t0, t1, salt)
                dk = k - prev
                if abs(dk) > 1e-4:
                    e = k * W if b["dir"] > 0 else W - k * W
                    p = px_pan(e)
                    a = min(1.0, abs(dk) * 6) ** 0.6 * (0.5 + 0.5 * min(1, b["h"] / 20))
                    n = int(rng.uniform(0.012, 0.045) * SR)
                    rt = int(rng.choice([0, 1, 2, 4, 6, 9]))
                    g = noise(n, rt, bool(rng.random() < 0.4), int(rng.integers(1, 999))) * q(np.ones(n) * (1 - 0.6 * np.arange(n) / n))
                    place(buf, g * 0.3 * a, t, p)
                    if dk < 0 or rng.random() < 0.15:          # a jerk back, a data sliver: a chirp
                        cn = int(rng.uniform(0.012, 0.03) * SR)
                        f0 = rng.uniform(500, 3500)
                        c = pulse(np.full(cn, f0) * (1 + rng.choice([-0.4, 0.5]) * np.arange(cn) / cn), 0.125)
                        place(buf, c * q(np.ones(cn)) * 0.1, t, p)
                prev = k
    for fr in range(int(IN1 / TICK), int((OUT0 + 0.05) / TICK) + 1):
        for k in range(3):
            if vrand(fr, k, 90) <= 0.4:
                cn = int(0.012 * SR)
                c = pulse(np.full(cn, 600 + 3000 * float(vrand(fr, k, 93))), 0.125) * 0.05
                place(buf, c, fr * TICK, px_pan(float(vrand(fr, k, 92)) * W))
    i1 = int(0.9 * SR)
    start, rel = buf[:i1], buf[i1:]
    full = shot(m, [(start, 0), (rel, 0.9)])
    return leveled(m, full, {"start": start, "release": rel},
                   "digital stutter: a burst per band jump on the original's 18 Hz ticks (dropouts on freezes, chirps "
                   "on jerks back), panned at each edge, 0.03-0.78 in, 0.98-1.66 out; faint blips in the black", -25)


# ------------------------------------------------------------------ iris
def iris(m):
    """A lit iris closes on the focus (0 .. CLOSE 0.62, inOutCubic: a swoosh as fast as the rim moves, brightening as
    the hole shrinks), holds on the spotlight with its rim twinkling (faint glints), snaps shut (SNAP 0.9 .. SHUT 0.99,
    inCubic: a quick rising rush and a glint's click); dark; POP 1.2 it pops open from a flash (a crack and a light
    pop, no weight; a whoosh out with the rim, outQuart to OPEN 1.75), the white-hot rim throwing sparks."""
    s = seed_of(m)
    o = m.get("options", {})
    rng = np.random.default_rng(s)
    CLOSE, SNAP, SHUT, POP, OPEN, RS = 0.62, 0.9, 0.99, 1.2, 1.75, 24
    fx, fy = o.get("focus", [160, 100])
    R0 = max(np.hypot(cx - fx, cy - fy) for cx, cy in ((0, 0), (W, 0), (0, H), (W, H))) + 7
    pf = px_pan(fx)
    t = T(CLOSE)
    r = RS + (R0 - RS) * (1 - in_out_cubic(t / CLOSE))
    sp = speed_of(r, t)
    start = stereo(gesture(sp, 2, 6, 0.4, s) * (0.6 + 0.4 * (1 - r / R0)), pf)
    for _ in range(4):
        place(start, burst(0.012, 0, 0.1 * rng.uniform(0.5, 1), 160, int(rng.integers(1, 999)), True), rng.uniform(CLOSE - 0.1, SNAP), pf + rng.uniform(-0.15, 0.15))
    t = T(SHUT - SNAP)
    snap = stereo(gesture((t / (SHUT - SNAP)) ** 2, 1, 4, 0.3, s + 1), pf)
    hit = blank(0.3)
    place(hit, S(crack(0.015, 0, 0.35, 140, s + 2, True), tinkle(0.35, s + 3, 3600)), 0, pf)
    rel = blank(1.0)
    place(rel, S(crack(0.03, 0, 0.75, 70, s + 4), material_hit("pop", 0.2, s + 6, 0.4)), 0, pf)
    t = T(OPEN - POP + 0.1)
    rr = R0 * (1 - (1 - np.clip(t / (OPEN - POP), 0, 1)) ** 4)
    place(rel, gesture(speed_of(rr, t), 0, 6, 0.4, s + 5), 0.005, pf)
    twinkles(rel, rng, 16, (0.05, 0.5), 0.1, (-0.7, 0.7), 0.6)
    full = shot(m, [(start, 0), (snap, SNAP), (hit, SHUT), (rel, POP)])
    return leveled(m, full, {"start": start, "snap": snap, "hit": hit, "release": rel},
                   "closing swoosh following the rim (0-0.62), faint rim glints, snap rush (0.9) and a glint click at "
                   "0.99; dark; flash pop at 1.2 with an opening whoosh (outQuart) and sparks", -25)


# ------------------------------------------------------------------ pixel dissolve
def _blocks(seed):
    CELL, P, IN0, IN1, OUT0, OUT1 = 20, 0.17, 0.04, 0.8, 1.12, 1.85
    bl = []
    for cy in range(H // CELL):
        for cx in range(W // CELL):
            h = float(vrand(cx, cy, seed))
            n = 1 if h < 0.32 else 2 if h < 0.74 else 4
            sz = CELL / n
            for j in range(n):
                for i in range(n):
                    bl.append((cx * CELL + i * sz, cy * CELL + j * sz, sz))
    x = np.array([b[0] for b in bl])
    y = np.array([b[1] for b in bl])
    sz = np.array([b[2] for b in bl])

    def rank(v):
        out = np.empty(len(v))
        out[np.argsort(v, kind="stable")] = np.arange(len(v)) / (len(v) - 1)
        return out
    at = lambda sd: vfbm((x + sz / 2) / 64, (y + sz / 2) / 64, sd, 3)
    uin = rank(at(seed) + 0.22 * vrand(x, y, seed + 1) + np.where(sz == 20, 0.12, np.where(sz == 5, -0.08, 0)))
    uout = rank(at(seed + 7) + 0.22 * vrand(x, y, seed + 2) + np.where(sz == 20, -0.14, np.where(sz == 5, 0.1, 0)))
    return x, sz, IN0 + uin * (IN1 - IN0), OUT0 + uout * (OUT1 - OUT0), vrand(x, y, seed + 3) < np.where(sz >= 10, 0.32, 0.1)


def pixel_dissolve(m):
    """Blocks wink in (0.04 .. 0.8), small ones scattering first and big ones filling in, each on its own time from the
    original's clumpy field: a crumble of 8-bit grains, a tiny metallic tick for a 5 px block, a click for 10 px, a
    knock for 20 px, panned where each sits; then (1.12 .. 1.85) they wink out, big ones first, each a softer grain as
    its black drops away, the last small ones sparkling off."""
    s = seed_of(m)
    rng = np.random.default_rng(s)
    P = 0.17
    x, sz, tin, tout, gl = _blocks(s)
    buf = blank(2.2)
    for k in range(len(x)):
        p = px_pan(x[k] + sz[k] / 2)
        sd = int(rng.integers(1, 999))
        a = rng.uniform(0.6, 1)
        if sz[k] == 20:
            c = knock(0.24 * a, sd, 7, 0.05, 60)
        elif sz[k] == 10:
            c = tick(0.14 * a, sd, short=False)
        else:
            c = burst(0.015, 0, 0.1 * a, 160, sd, True)
        place(buf, c, tin[k] + 0.01, p)
        o = 0.35 * P
        c = burst(0.02, 2 if sz[k] == 20 else 0, 0.06 * a, 120, sd + 1, sz[k] < 10)
        if sz[k] == 5 and gl[k]:
            c = S(c, tinkle(0.12 * a, sd + 2, rng.uniform(3000, 4500)))
        place(buf, c, tout[k] + o, p)
    i1 = int(1.0 * SR)
    start, rel = buf[:i1], buf[i1:]
    full = shot(m, [(start, 0), (rel, 1.0)])
    return leveled(m, full, {"start": start, "release": rel},
                   "8-bit crumble: a grain per block winking in on its own time (ticks for small, knocks for big, "
                   "panned), 0.04-0.85; softer grains as they wink out, big first, small ones sparkling last, "
                   "1.12-1.9", -26)


# ------------------------------------------------------------------ shatter wipe
def shatter_wipe(m):
    """A dark glass pane drops over the screen (0 .. LAND 0.55: air rushing ahead of it) and lands: a glass slab on
    stone (glass: a crisp crack and high tinks, no low weight; the floor's hard knock, a glassy ring) with chips
    springing off along the bottom; it bounces twice (0.88,
    0.98: smaller knocks, fewer chips); CRACK 1.32 an impact (crisp crack, knock) and cracks racing out from it (fast
    crackles spreading from the impact's pan); BREAK 1.62 it bursts (the ice shatter: crack, glass weight, short-mode
    shatter, ring, spray), the cells breaking outward on a 520 px/s wave each with a crack and splinters; the shards tumble
    away off the bottom glinting (no floor: no landings)."""
    s = seed_of(m)
    rng = np.random.default_rng(s)
    LAND, CRACK, BREAK, WAVE = 0.55, 1.32, 1.62, 520
    REST = 0.3
    Rj = JsRng(s)
    Ix, Iy = W * Rj.range(0.4, 0.6), H * Rj.range(0.36, 0.54)
    pi_ = px_pan(Ix)
    start = stereo(air(LAND, 9, 5, 0.32, s, "rise"))
    bounces, t0, k = [], LAND, 1.0
    for _ in range(3):
        bounces.append((t0, k))
        t0 += 2 * LAND * REST * k
        k *= REST
    land = blank(1.2)
    for bt, k in bounces:
        at = bt - LAND
        place(land, S(material_hit("glass", 0.8 * k, s + 20 + int(10 * k), 0.8 * k),
                      iceknock(0.8 * k, int(rng.integers(1, 999)), 1200, 0.8),
                      ring(2100 * rng.uniform(0.95, 1.05), 0.5, 0.14 * k, 6, 9, 1.37)), at)
        for _ in range(int(round(26 * k))):
            place(land, tinkle(0.3 * k * rng.uniform(0.4, 1), int(rng.integers(1, 999)), rng.uniform(2600, 4400)),
                  at + rng.uniform(0.0, 0.25), rng.uniform(-0.85, 0.85))
    hit = blank(0.4)
    place(hit, S(icecrack(1.0, s + 1, 0.06), iceknock(0.5, s + 2, 1500, 0.5)), 0, pi_)
    crackles(hit, rng, 0.0, 0.24, 140, 25, 0.3, 0.08, lambda u: pi_ + (rng.random() * 2 - 1) * (0.1 + 0.7 * u), True)
    for _ in range(3):
        place(hit, tinkle(0.12, int(rng.integers(1, 999)), rng.uniform(3000, 4500)), rng.uniform(0.1, 0.3), rng.uniform(-0.6, 0.6))
    brk = blank(1.4)
    place(brk, shatter(1.0, s + 3, rng, 330, 0.6), 0, pi_)
    place(brk, burst(0.6, 1, 0.2, 5, s + 4, True), 0.02, pi_)
    RING_ = [0, 9, 21, 37, 58, 86, 122, 168, 232]
    for i in range(13):
        a = (i + 0.5) / 13 * TAU
        for j in range(1, len(RING_)):
            r = (RING_[j - 1] + RING_[j]) / 2
            cx, cy = Ix + np.cos(a) * r, Iy + np.sin(a) * r
            if not (-10 < cx < W + 10 and -10 < cy < H + 10):
                continue
            tb = r / WAVE + rng.uniform(0, 0.04)
            big = RING_[j] - RING_[j - 1] > 24
            place(brk, icecrack(0.22 if big else 0.14, int(rng.integers(1, 999)), 0.04), tb, px_pan(cx))
            for _ in range(4 if big else 2):
                place(brk, tinkle(0.12 * rng.uniform(0.4, 1), int(rng.integers(1, 999)), rng.uniform(2600, 4600)),
                      tb + rng.uniform(0.0, 0.15), px_pan(cx))
    tail = blank(1.2)
    for _ in range(14):
        at = rng.uniform(0.1, 1.0)
        place(tail, tinkle(0.1 * (1 - at) * rng.uniform(0.5, 1), int(rng.integers(1, 999)), rng.uniform(3200, 4800)), at, rng.uniform(-0.8, 0.8))
    full = shot(m, [(start, 0), (land, LAND), (hit, CRACK), (brk, BREAK), (tail, BREAK + 0.1)])
    return leveled(m, full, {"start": start, "land": land, "hit": hit, "shatter": brk, "tail": tail},
                   "air rushing as the pane drops; glass slab lands at 0.55 (glass crack + tinks, knock, ring, chips) and bounces at "
                   "0.88/0.98; impact crack at 1.32 with cracks racing out; shatter at 1.62, cells breaking outward on "
                   "the wave with splinters; falling shards glinting", -22)


# ------------------------------------------------------------------ slash wipe
def slash_wipe(m):
    """A white-hot blade edge slices across (T0 0.06 .. + SWEEP 0.62, outCubic: fastest at the start): a whoosh as loud
    and as bright as the edge is fast, a steel ring shimmering under it and sparks grinding off as thick as its speed,
    all panned with the edge left to right; CUT 0.84 a second cut flashes through in 0.07 s (a sharp swish, a steel
    shing), sparks off its tip at 0.91; SLIP 0.96 the cover slips (a low scrape); SPLIT 1.08 it splits apart (a heavy
    whoosh and the cut steel ringing out, metal: no thump; sparks)."""
    s = seed_of(m)
    rng = np.random.default_rng(s)
    T0, SWEEP, CUT, CSW = 0.06, 0.62, 0.84, 0.07
    SL = 0.55
    E0, E1 = -(H / 2) * SL - 4, W + (H / 2) * SL + 24
    SLIP, SPLIT = CUT + 0.12, CUT + CSW + 0.05 + 0.12
    t = T(SWEEP)
    u = t / SWEEP
    spd = (1 - u) ** 2
    e = E0 + (E1 - E0) * (1 - (1 - u) ** 3)
    pans = np.clip((e / W * 2 - 1) * 0.85, -1, 1)
    sig = gesture(spd, 0, 6, 0.5, s) + ring(2300, SWEEP, 0.1, 3.5, 9, 1.41)
    start = st_path(sig, pans[:: max(1, len(pans) // 300)])
    cdf = np.cumsum(spd) / spd.sum()
    for _ in range(40):
        at = float(np.interp(rng.random(), cdf, t))
        place(start, tick(0.14 * rng.uniform(0.4, 1), int(rng.integers(1, 999))), at, max(-1.0, float(np.interp(at, t, pans)) - 0.1))
    hit = blank(0.8)
    place(hit, S(air(CSW, 0, 2, 0.55, s + 1), crack(0.02, 0, 0.35, 100, s + 2, True)), 0)
    place(hit, ring(3000, 0.6, 0.22, 5, 11, 1.37), 0.01)
    for _ in range(12):
        place(hit, tick(0.12 * rng.uniform(0.4, 1), int(rng.integers(1, 999))), CSW + rng.uniform(0, 0.25), rng.uniform(-0.5, 0.5))
    slip = blank(0.2)
    tt = T(0.12)
    place(slip, noise(len(tt), 9, seed=s + 3) * q(np.sin(np.pi * tt / 0.12)) * 0.12, 0)
    rel = blank(0.9)
    place(rel, S(wash(0.6, 10, 7, 0.35, 0.03, 3, s + 4), material_hit("metal", 0.7, s + 6, 0.3)), 0)
    for _ in range(18):
        place(rel, tick(0.1 * rng.uniform(0.4, 1), int(rng.integers(1, 999))), rng.uniform(0, 0.4), rng.uniform(-0.8, 0.8))
    full = shot(m, [(start, T0), (hit, CUT), (slip, SLIP), (rel, SPLIT)])
    return leveled(m, full, {"start": start, "hit": hit, "slip": slip, "release": rel},
                   "blade sweep L->R (0.06-0.68): whoosh + steel ring + grinding sparks following its outCubic speed; "
                   "second cut swish + shing at 0.84, tip sparks; low slip scrape 0.96; split whoosh + steel ring at 1.08", -24)


# ------------------------------------------------------------------ star iris
def _spin(t, close):
    """star-iris.js starAt: (radius, turn) closing over [0, CLOSE] or opening over [OPEN0, OPEN1] (t from its start)."""
    RMAX = 430
    if close:
        u = t / 0.98
        return RMAX * (1 - in_out_quad(u)) ** 1.3, -np.pi / 2 + in_out_cubic(u) * 1.6 * TAU
    u = np.clip(t / (2.0 - 1.16), 0, 1)
    return RMAX * in_out_cubic(u) ** 1.15, -np.pi / 2 - in_out_cubic(u) * 1.6 * TAU


def star_iris(m):
    """A five-point star iris spins shut on the focus (0 .. CLOSE 0.98: r inOutQuad^1.3, 1.6 turns inOutCubic): a swoosh
    as fast as its rim and spin move, fluttering each time a point sweeps past (the flutter's rate glides with the
    spin, never a beat), its tips shedding faint glints; it closes on a glint (a click and a tink); dark; OPEN0 1.16 it
    spins open from a flash (a light pop, a spray of stars) with the same fluttering swoosh to OPEN1 2.0."""
    s = seed_of(m)
    o = m.get("options", {})
    rng = np.random.default_rng(s)
    CLOSE, OPEN0, OPEN1 = 0.98, 1.16, 2.0
    pf = px_pan(o.get("focus", [160, 96])[0])

    def swoosh(secs, close, seed):
        t = T(secs)
        r, a = _spin(t, close)
        sp = 0.6 * speed_of(r, t) + 0.4 * speed_of(a, t)
        am = 0.45 + 0.55 * np.abs(np.cos(5 * (a + np.pi / 2) / 2)) ** 2
        return gesture(sp, 2, 6, 0.42, seed, am)
    start = stereo(swoosh(CLOSE, True, s), pf)
    twinkles(start, rng, 7, (0.25, 0.95), 0.08, (pf - 0.5, pf + 0.5), 0.6)
    hit = blank(0.4)
    place(hit, S(crack(0.015, 0, 0.35, 140, s + 1, True), tinkle(0.4, s + 2, 3800)), 0, pf)
    place(hit, glitter(0.2, decay(T(0.2), 15), 0, s + 3) * 0.08, 0, pf)
    rel = blank(OPEN1 - OPEN0 + 0.3)
    place(rel, S(crack(0.03, 0, 0.7, 70, s + 4), material_hit("pop", 0.15, s + 8, 0.35)), 0, pf)
    place(rel, swoosh(OPEN1 - OPEN0, False, s + 5), 0.005, pf)
    twinkles(rel, rng, 14, (0.04, 0.6), 0.1, (pf - 0.7, pf + 0.7), 0.6)
    full = shot(m, [(start, 0), (hit, CLOSE), (rel, OPEN0)])
    return leveled(m, full, {"start": start, "hit": hit, "release": rel},
                   "fluttering spin swoosh as the star closes (0-0.98, flutter gliding with the spin), faint tip "
                   "glints, closing glint click at 0.98; dark; flash pop at 1.16 and the swoosh spinning open (-2.0) "
                   "with a spray of stars", -25)


SOUNDS = {
    "blinds": blinds,
    "burn-away": burn_away,
    "crt-off": crt_off,
    "diamond-wipe": diamond_wipe,
    "glitch-wipe": glitch_wipe,
    "iris": iris,
    "pixel-dissolve": pixel_dissolve,
    "shatter-wipe": shatter_wipe,
    "slash-wipe": slash_wipe,
    "star-iris": star_iris,
}
