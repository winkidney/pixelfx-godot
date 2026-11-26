# critters: a creature idling or hovering in its loop is a steady thing (references/sound.md, rule 2): a bat on its even
# wingbeats, a butterfly, a floating eye, fish holding station, a ghost, a jellyfish, a snake's slither and a wisp are
# silent. Only a creature's strong moments sound, quiet and sparse, in its material (rule 5): a bird's burst of
# wingbeats is moving air, a frog's leap, tongue snap and squashed landing are flesh and a wet smack, a slime squelches,
# a skull's teeth clack like bone. A landing's weight is its material (synth material_hit: flesh, wet goo), never the
# explosions' falling pulse thump (sound.md rule 2). Never a call that sings (rule 1): no chirps, no croak tunes. Every
# event sits on the original's beats (src/fx/critters/<name>.js), the bits it flings landing on its own physics
# (critters/_lib.js toss).
import numpy as np
from synth import *  # noqa: F401,F403
from cats.impacts import seed_of, pan_of, st, put, knock, air, S
from cats.projectiles import lput, db
from cats.water import jrng, splat, plink, wet_hit
from cats.shadow import gulp
from cats.ice import q

FPS = 30
MASTER = 0.5


def at_db(buf, target):
    """buf scaled so it measures `target` dB RMS after make.py's master gain."""
    return buf * 10 ** ((target - db(buf * MASTER)) / 20)


def toss_at(x, y, vx, vy, g, floor):
    """critters/_lib.js toss(): when (and where) a bit thrown from (x, y) at (vx, vy) reaches the floor."""
    tl = (-vy + np.sqrt(max(0.0, vy * vy + 2 * g * (floor - y)))) / g
    return tl, x + vx * tl, vy + g * tl


def pat(vol, seed, secs=0.03, rate=5, k=120):
    """A drop of something wet landing: a soft dull pat."""
    t = T(secs)
    return noise(len(t), rate, seed=seed) * q(decay(t, k)) * vol


def loop_of(m, events, target, phases, notes):
    """A critter's loop: its events [(stereo, at)] put on the loop clock (tails wrapping round), set to `target` dB
    RMS; the phases scaled by the same gain, so the game's one-shots keep the loop's balance."""
    P = m["duration"]
    buf = blank(P + X)
    for s, at in events:
        lput(buf, s, at, P)
    loop = wrap(buf, P)
    g = 10 ** ((target - db(loop * MASTER)) / 20)
    return Sound(loop * g, {k: v * g for k, v in phases.items()}, notes)


# ------------------------------------------------------------------ voices
def flap(vol, seed, secs=0.15):
    """A wing's downstroke: a soft rush of air brightening as the feathers bite, with a faint low push of air under
    it (low noise, not a tone)."""
    t = T(secs)
    s = air(secs, 8, 3, 1.0, seed, "bell")
    s += noise(len(t), 13, seed=seed + 1) * q(np.sin(np.pi * np.clip(t / secs, 0, 1)) ** 2) * 0.12
    return s * vol


def teeth(vol, seed, rng):
    """Teeth clacking shut: a dry bone click, very short, its own pitch every time (never a note); under it a tiny
    hollow 'tok' at a fixed pitch (bone is hard and hollow like wood; no pitch drop)."""
    t = T(0.035)
    s = noise(len(t), 2, seed=seed) * q(decay(t, 190))
    s += pulse(np.full(len(t), rng.uniform(1300, 1900)), 0.25) * q(decay(t, 220)) * 0.3
    s += tri(np.full(len(t), np.random.default_rng(seed).uniform(380, 520))) * q(decay(t, 140)) * 0.3
    return s * vol


def jaw_clack(vol, seed, rng):
    """The jaw slamming shut on a gape: a dry knock of bone, a hollow wood-like 'tok' (synth wood_hit, its own pitch)
    and a click on top (mono). Replaces shadow.clack, whose little pitch drop is a thump."""
    t = T(0.06)
    s = noise(len(t), 3, seed=seed) * q(decay(t, 85))
    s += pulse(np.full(len(t), rng.uniform(700, 1100)), 0.25) * q(decay(t, 110)) * 0.3
    return S(s, material_hit("wood", 0.15, seed + 1, 0.35)) * vol


def goo_splat(vol, seed):
    """Goo hitting the floor: a wet burst going from bright to dull and the goo's own weight, wet and soft (water's
    noise whomp without a bloop, a flesh-like push), no falling tone (mono)."""
    t = T(0.25)
    r = np.round(np.interp(t, [0, 0.25], [3, 10])).astype(int)
    s = noise(len(t), r, seed=seed) * q(np.minimum(1, t / 0.004) * decay(t, 16))
    return S(s, wet_hit(0.3, seed + 1, 0.5), material_hit("flesh", 0.4, seed + 2, 0.4)) * vol


# ------------------------------------------------------------------ the creatures with strong moments
def bird(m):
    """Loop (2.4 s): the bird flaps FLAPS 4 times until GLIDE 1.5 (each 0.375 s, the downstroke the first 40 %), then
    glides on spread wings to the loop's end. The burst of wingbeats is its strong moment: each downstroke a soft rush
    of air (0, 0.375, 0.75, 1.125), each its own take and strength so the burst never ticks like a clock; the glide is
    silent. No chirps: a song is music (rule 1). phase flaps: the burst on its own."""
    sd = seed_of(m)
    rng = np.random.default_rng(sd)
    FLAPS, GLIDE = 4, 1.5
    burst = blank(GLIDE)
    for k in range(FLAPS):
        a = k * GLIDE / FLAPS
        put(burst, st(flap(rng.uniform(0.75, 1.0) * (1, 0.85, 0.9, 0.7)[k], sd + k, 0.4 * GLIDE / FLAPS + 0.02),
                      pan_of(m, rng.uniform(-3, 3))), a)
    return loop_of(m, [(burst, 0)], -33, {"flaps": burst},
                   "burst of 4 wingbeats (0, 0.375, 0.75, 1.125), a soft rush of air on each downstroke; glide silent")


def flying_skull(m):
    """Loop (2.4 s): the fire roaring off its crown is a steady flame, silent like a torch (rule 2). Its jaw is bone
    and makes noise: two bursts of chatter a loop (0.15-0.75, 1.3-1.95; the jaw opens on sin(t/D TAU 22), 9 a second),
    each time the jaw shuts on screen (frame by frame, as the JS rounds it) a dry teeth clack as hard as the jaw was
    open; the wide gape after the second burst (1.95-2.3) snaps shut at 2.3 with a harder bone clack. Each clack its
    own take, so the chatter rattles instead of ticking. phases: chatter (one burst), snap (the gape shutting)."""
    sd = seed_of(m)
    rng = np.random.default_rng(sd)
    D = m["duration"]

    def burst(t, a, b):
        return 0 if t <= a or t >= b else np.sin(np.pi * (t - a) / (b - a)) ** 0.5

    def jaw(t):
        ch = max(0.0, np.sin(t / D * 2 * np.pi * 22))
        return round(max(ch * 2.4 * max(burst(t, 0.15, 0.75), burst(t, 1.3, 1.95)), burst(t, 1.95, 2.3) * 3.4))

    nf = int(round(D * FPS))
    js = [jaw(f / FPS) for f in range(nf)]
    events, chatter, snap_ = [], blank(0.7), None
    for f in range(nf):
        prev = js[f - 1]
        if js[f] == 0 and prev > 0:
            at = f / FPS
            x = 3 * np.sin(at / D * 2 * np.pi)
            if at > 2.2:                                   # the gape shutting
                snap_ = st(S(jaw_clack(1.0, sd + f, rng), teeth(0.8, sd + 100 + f, rng)), pan_of(m, x))
                events.append((snap_, at))
            else:
                c = st(teeth(min(1.0, prev / 2.4) * rng.uniform(0.6, 1.0), sd + f, rng), pan_of(m, x))
                events.append((c, at))
                if at < 0.8:
                    put(chatter, c, at - 0.15)
    return loop_of(m, events, -32, {"chatter": chatter, "snap": snap_},
                   "jaw chatter: a bone clack each time the jaw shuts in the bursts 0.15-0.75 and 1.3-1.95; the gape "
                   "snapping shut at 2.3; the crown fire silent")


def frog(m):
    """Loop (2.6 s): the throat puffing (0.05-0.85), the blink and the buzzing fly are steady and silent. Its strong
    moment, quiet: the push off at T_UP 1.2 (a soft scuff, dust), the tongue whipping out from 1.34, smacking the fly at
    its reach (1.41) and zipping back by 1.48, the landing at T_LAND 1.62 (a small body landing: a soft flesh smack and push, a wet squash, the
    dust puff, the 8 bits of grit it throws ticking down where toss() drops them), the gulp as the throat works
    (1.75-1.95). phases: leap (push and tongue), land (landing and gulp)."""
    sd = seed_of(m)
    rng = np.random.default_rng(sd)
    T_UP, T_SNAP, T_LAND = 1.2, 1.4, 1.62
    fx = 16
    p0, pf = pan_of(m, 0), pan_of(m, fx)
    push = st(S(knock(1.0, sd, 10, 0.06, 60) * 0.3, air(0.12, 10, 6, 1.0, sd + 1, "fall") * 0.35), p0)
    whip = st(air(0.07, 4, 0, 1.0, sd + 2, "rise") * 0.22, (p0, pf))
    smack = st(S(splat(1.0, sd + 3, 0.05, 2, 90) * 0.45, plink(rng.uniform(900, 1300), 1.0, sd + 4, 0.03, 1.4, 120, 0.3) * 0.12), pf)
    reel = st(air(0.07, 2, 7, 1.0, sd + 5, "fall") * 0.18, (pf, p0))
    leap = blank(0.4)
    put(leap, push, 0)
    put(leap, whip, T_SNAP - 0.06 - T_UP)
    put(leap, smack, T_SNAP + 0.01 - T_UP)
    put(leap, reel, T_SNAP + 0.015 - T_UP)
    land = blank(0.6)
    put(land, st(S(material_hit("flesh", 0.25, sd * 7 + 701, 0.6), splat(1.0, sd + 6, 0.12, 5, 30) * 0.5,
                   air(0.35, 9, 12, 1.0, sd + 7, "fall") * 0.18), p0), 0)
    for i in range(8):                                     # the grit thrown on landing (rng(seed, i, 909), toss g 700)
        r = jrng(sd, i, 909)
        x = r.range(-8, 8)
        vx, vy = r.range(-40, 40), -r.range(30, 70)
        tl, lx, v = toss_at(x, -1, vx, vy, 700, -0.5)
        put(land, st(tick(1.0, int(rng.integers(1, 99)), short=False) * 0.05 * min(1, v / 70), pan_of(m, lx)), tl)
    put(land, st(gulp(1.0, sd + 8, 0.17, 60, 150) * 0.5, p0), 1.76 - T_LAND)
    return loop_of(m, [(leap, T_UP), (land, T_LAND)], -31, {"leap": leap, "land": land},
                   "push off (1.2), tongue whips out (1.34), smacks the fly (1.41), zips back; landing flesh smack + wet squash "
                   "+ dust + grit ticks (1.62), gulp (1.76); idle throat, blink and fly silent")


def slime(m):
    """Loop (1.8 s): a hop, all of it goo. It squashes to wind up (T_SQ 0.5 - T_UP 0.84): a low wet squeeze swelling,
    quivering as the JS's 16 Hz shiver comes in; springs up (0.84-0.9): a sucking squelch rising; the goo string snaps
    at SNAP 0.965 (a small wet pop) and its drip falls back; two drips fall off it in the air (1.02, 1.18) and pat the
    floor where toss() drops them. The splat at T_LAND 1.44: a heavy wet splash, goo's soft wet weight (no tone); the 12 droplets it
    flings (rng(seed, i, 7)) land as little pats, louder for the bigger ones. The wobble, blinks and puddle bubbles are
    silent. phases: hop (squeeze to snap), splat (landing and droplets)."""
    sd = seed_of(m)
    rng = np.random.default_rng(sd)
    T_SQ, T_UP, T_LIFT, T_LAND, SNAP, G, HOP = 0.5, 0.84, 0.9, 1.44, 0.965, 640, m["options"].get("hop", 24)
    p0 = pan_of(m, 0)

    def by(t):
        if T_LIFT <= t < T_LAND:
            u = (t - T_LIFT) / (T_LAND - T_LIFT)
            return -HOP * 4 * u * (1 - u)
        return 0.0

    hop = blank(T_LAND - T_SQ)
    d = T_UP - T_SQ
    t = T(d)
    u = t / d
    quiver = 1 - 0.3 * np.clip((u - 0.55) / 0.45, 0, 1) * (np.sin(2 * np.pi * 16 * (t + T_SQ)) > 0)
    squeeze = noise(len(t), 11, seed=sd) * q((0.15 + 0.85 * u ** 1.5) * quiver) * 0.6
    squeeze += noise(len(t), 6, seed=sd + 1) * q(u ** 2 * quiver) * 0.2
    put(hop, st(squeeze * 0.35, p0), 0)
    put(hop, st(gulp(1.0, sd + 2, 0.12, 90, 260) * 0.55, p0), T_UP - T_SQ)
    put(hop, st(S(splat(1.0, sd + 3, 0.03, 2, 150) * 0.3, plink(rng.uniform(450, 650), 1.0, sd + 4, 0.05, 1.6, 60, 0.3) * 0.2), p0),
        SNAP - T_SQ)
    ys = by(SNAP) - 1
    tl, _, _ = toss_at(-1, ys * 0.45, 0, 0, G * 1.3, -2)
    put(hop, st(pat(0.2, sd + 5), pan_of(m, -1)), SNAP - T_SQ + tl)
    for t0, dx in ((1.02, -4), (1.18, 3)):
        tl, _, _ = toss_at(dx, by(t0) - 0.5, 0, 12, G, -1)
        if t0 + tl < T_LAND:
            put(hop, st(pat(0.22, sd + 6 + dx), pan_of(m, dx)), t0 + tl - T_SQ)
    spl = blank(1.0)
    put(spl, st(goo_splat(1.0, sd * 7 + 709), p0), 0)
    for i in range(12):                                    # the droplets flung off the splat, landing
        r = jrng(sd, i, 7)
        a = -np.pi / 2 + r.range(-1.2, 1.2)
        sp = r.range(60, 118)
        size = 1 if r.chance(0.35) else 2 if r.chance(0.7) else 3
        fa = a + np.pi / 2
        x0, y0 = np.sin(fa) * 21, -1 - np.cos(fa) * 12.5
        tl, lx, _ = toss_at(x0, y0, np.cos(a) * sp * 0.75, np.sin(a) * sp, G, -1)
        put(spl, st(pat((0.12, 0.2, 0.3)[size - 1] * rng.uniform(0.8, 1.1), int(rng.integers(1, 999)), 0.035, 4), pan_of(m, lx)), tl)
    return loop_of(m, [(hop, T_SQ), (spl, T_LAND)], -30, {"hop": hop, "splat": spl},
                   "wet squeeze winding up (0.5-0.84), squelch springing up (0.84), goo string pops (0.965), drips pat "
                   "down; splat (1.44) + 12 droplets patting down where they land")


# ------------------------------------------------------------------ silent
def bat(m):
    return Silent("a bat flying its figure-eight on 6 even wingbeats a loop: it never bursts or rests, so its flaps are a "
                  "steady thing (rule 2) and a flap on each would tick like a clock (rule 1)")


def butterfly(m):
    return Silent("a butterfly's wings make no noise you could hear: a steady thing (rule 2)")


def eyeball(m):
    return Silent("an eye floating and bobbing, its iris snapping round and its lids blinking: a hovering idle thing with "
                  "no noise of its own (rule 2)")


def fish_school(m):
    return Silent("fish holding station under water, bubbles rising: a steady thing, nothing heard (rule 2)")


def ghost(m):
    return Silent("a sheet ghost bobbing over the floor: a hovering idle thing with no noise of its own (rule 2)")


def jellyfish(m):
    return Silent("a jellyfish pulsing under water: a steady thing, nothing heard (rule 2); its pulses are an even beat "
                  "(rule 1)")


def snake(m):
    return Silent("a snake slithering in place, humps rolling down its body, its tongue flicking: steady movement with "
                  "no strong moment (rule 2); no hiss, it isn't threatening anyone")


def wisp(m):
    return Silent("a will-o'-the-wisp looping a figure-eight, its flame tail licking: a hovering flame, silent like a "
                  "torch (rule 2)")


SOUNDS = {
    "bat": bat,
    "bird": bird,
    "butterfly": butterfly,
    "eyeball": eyeball,
    "fish-school": fish_school,
    "flying-skull": flying_skull,
    "frog": frog,
    "ghost": ghost,
    "jellyfish": jellyfish,
    "slime": slime,
    "snake": snake,
    "wisp": wisp,
}
