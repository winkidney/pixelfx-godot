# status: a status held on a character is its lingering glow, and a glow is silent (references/sound.md, rule 2):
# charm hearts, sleep Zs, haste lines, the slowed clock, stars round a stunned head, a curse's smoke, rage's throb,
# poison's waves and even the flames of burning (a steady fire is silent like a torch, cats/fire.py) and the drips of
# bleeding stay silent loops. Most of them also pulse on an even clock (a heartbeat, a flare every 0.6 s, a shiver a
# second), which as sound would be a beat (rule 1). A status loop is either silent or real noise for its whole length;
# never a silent bed with a sting on it. What sounds is the strong moment of a status setting in or breaking, as a
# one-shot (rule 2, exception 1): petrified is that moment, stone creeping up and the statue bursting, so it has
# sound. Beats from src/fx/status/<name>.js and act.timing in port/meta.json.
import numpy as np
from synth import *  # noqa: F401,F403
from cats.impacts import seed_of, hits_of, pan_of, st, put, crack, rumble, air, fly, grit_lands, debris, S
from cats.projectiles import shot
from cats.ice import leveled, q
from cats.nature import snaps, knock, ground

FPS = 30


def stone_lands(m, lands, vol, rng, rate=(8, 11), weight=0.0, vref=300.0, secs=0.06):
    """Bits of stone landing [(t, speed, x)]: a knock each as hard as it lands, panned with its x (stereo, from t 0).
    Built at full scale and mixed down, so the faint ones keep their shape."""
    end = max([t for t, _, _ in lands] + [0]) + 0.2
    buf = blank(end)
    for t, v, x in lands:
        a = min(1.0, v / vref)
        if a < 0.12:
            continue
        k = knock(1.0, int(rng.integers(1, 999)), int(rng.integers(rate[0], rate[1] + 1)), secs, 60, weight)
        put(buf, st(k * a * vol * rng.uniform(0.7, 1.0), pan_of(m, x)), t)
    return buf


def petrified(m):
    """One-shot (3.8 s). CREEP 0-0.95: stone creeps up from the feet: a low stone grinding that swells with the front's
    speed (smoothstep, fastest mid-way) and stutters with it (its 3 wobbles), the crackling edge as small stone snaps,
    the grit it spits ticking down along the floor. 0.95 it sets: a dull stone knock (stone's dry knock and crunch, no
    falling tone) and a breath of dust. The statue holds, silent but for a pebble or two dropping off. CRACK 1.75: a
    crack and the cracks running through it for 0.3 s (snaps, denser), chips popping off (12 a second) and landing, the
    statue juddering harder toward the break (sin(t 90): a rattle). Hit at SHATTER 2.2 (hit-stop 0.08): it bursts
    (stone: a crack, stone's dry knock and gritty crunch, a heavy knock, a low noise thud; never a falling pulse thump);
    after the stop the rubble rumbles and the dust rolls out both ways; 18 chunks knock down and tumble where they fly
    (g 1, drag 0.4, bounce 0.3), 16 pale flakes and the grit tick down."""
    sd = seed_of(m)
    rng = np.random.default_rng(sd)
    CREEP, CRACK, SHATTER = 0.95, 1.75, 2.2
    (th, fz), = hits_of(m)[:1] or [(SHATTER, 0.08)]
    H, W = 30, 14                                          # the stand-in's body, feet at the floor, centred
    OX, OY = W * 0.55 - W / 2, -H + H * 0.42
    p0 = pan_of(m, 0)

    # creep: the front climbing (level(t) = 1.2 smooth(0, CREEP, t) + 0.025 sin(t/CREEP TAU 3))
    t = T(CREEP)
    u = t / CREEP
    speed = 6 * u * (1 - u) + 0.15 * np.cos(u * 2 * np.pi * 3)
    env = np.clip(speed / 1.6, 0, 1)
    grind = noise(len(t), 12, seed=sd) * q(0.25 + 0.75 * env) * 0.5
    grind += noise(len(t), 9, short=True, seed=sd + 1) * q(env) * 0.12
    creep = st(grind * np.minimum(1, t / 0.04) * 0.45, p0)
    put(creep, snaps(CREEP, lambda a: 30 + 20 * a / CREEP, lambda a: 0.12 + 0.08 * a / CREEP, sd + 2, (p0 - 0.1, p0 + 0.1)), 0)
    lands = []
    for at in np.sort(rng.uniform(0, CREEP, 14)):         # grit spat off the edge, landing along the floor
        lvl = min(1.2, 1.2 * (at / CREEP) ** 2 * (3 - 2 * at / CREEP))
        x, y = rng.uniform(-W / 2, W / 2), -H * min(1, lvl)
        side = -1 if x < 0 else 1
        lands += [(at + tl, v, xx) for tl, v, xx in grit_lands(side * rng.uniform(15, 60), -rng.uniform(30, 90), x, y, rng)]
    put(creep, stone_lands(m, lands, 0.12, rng, (6, 9), 0, 250, 0.04), 0)

    sets = st(S(knock(1.0, sd + 3, 10, 0.1, 35, 0.6) * 0.5, material_hit("stone", 0.45, sd * 7 + 801, 0.45),
                air(0.6, 10, 13, 1.0, sd + 4, "fall") * 0.14), p0)
    hold = blank(CRACK - CREEP)
    for at in sorted(rng.uniform(0.3, CRACK - CREEP - 0.1, 2)):
        h = rng.uniform(8, 26)
        put(hold, st(knock(1.0, int(rng.integers(1, 999)), 7, 0.04, 70) * 0.1, pan_of(m, rng.uniform(-6, 6))), at + np.sqrt(2 * h / 950))

    # the cracks running, the chips, the judder
    d = SHATTER - CRACK
    crk = blank(d + 0.8)
    put(crk, st(S(crack(0.04, 1, 1.0, 70, sd + 5), knock(1.0, sd + 6, 6, 0.06, 50, 0.3)) * 0.45, p0), 0)
    put(crk, snaps(0.3, lambda a: 70, lambda a: 0.35 * (1 - a / 0.3) + 0.15, sd + 7, (p0 - 0.2, p0 + 0.2)), 0.02)
    put(crk, snaps(d - 0.3, lambda a: 18, lambda a: 0.15, sd + 8, (p0 - 0.15, p0 + 0.15)), 0.3)
    lands = []
    for at in np.sort(rng.uniform(0, d, int(12 * d))):
        x, y = rng.uniform(-W / 2, W / 2), rng.uniform(-H, -4)
        lands += [(at + tl, v, xx) for tl, v, xx in grit_lands(rng.uniform(-40, 40), -rng.uniform(30, 80), x, y, rng)]
    put(crk, stone_lands(m, lands, 0.16, rng, (6, 9), 0, 250, 0.04), 0)
    t = T(d)
    ramp = np.minimum(1, t / d)
    jud = np.abs(np.round(np.sin((t + CRACK) * 90) * ramp * 1.2))      # the statue's pixel shift, as the JS draws it
    rattle = noise(len(t), 10, seed=sd + 9) * q((0.2 + 0.8 * ramp) * (0.45 + 0.55 * np.minimum(1, jud)) * ramp ** 0.5) * 0.3
    put(crk, st(rattle, p0), 0)

    # the burst
    hit = st(S(crack(0.05, 1, 1.0, 50, sd + 10), material_hit("stone", 0.85 * rng.uniform(0.94, 1.06), sd * 7 + 809, 0.85),
               knock(1.0, sd + 11, 10, 0.1, 35, 0.6) * 0.5, ground(0.7, sd * 7 + 811, 0.45)), p0)
    body = st(S(rumble(1.3, 0.4, 14, 2.2, 60, 0, sd + 12), air(0.9, 7, 13, 0.25, sd + 13, "fall")), p0)
    put(body, st(air(0.8, 9, 13, 0.18, sd + 14, "fall"), (p0, p0 - 0.5)), 0.05)
    put(body, st(air(0.8, 9, 13, 0.18, sd + 15, "fall"), (p0, p0 + 0.5)), 0.05)
    chunks, flakes, grit = [], [], []
    for _ in range(18):                                   # chunks off the statue, flung out from the crack's heart
        x, y = rng.uniform(-W / 2, W / 2), rng.uniform(-H, 0)
        dx, dy = x - OX, y - OY
        dd = np.hypot(dx, dy) or 1
        sp = rng.uniform(35, 110)
        chunks += fly(dx / dd * sp, dy / dd * sp * 0.6 - rng.uniform(60, 160), x, y, 1, 0.4, 0.3, rng.uniform(1.1, 1.5))
    for _ in range(16):
        an = -np.pi / 2 + rng.uniform(-1.4, 1.4)
        sp = rng.uniform(50, 120)
        flakes += fly(np.cos(an) * sp, np.sin(an) * sp, OX + rng.uniform(-5, 5), OY + rng.uniform(-8, 8), 0.8, 0.6, 0.3,
                      rng.uniform(0.9, 1.4))
    for _ in range(50):
        x, y = rng.uniform(-W / 2, W / 2), rng.uniform(-H, 0)
        dx, dy = x - OX, y - OY
        dd = np.hypot(dx, dy) or 1
        sp = rng.uniform(40, 130)
        grit += grit_lands(dx / dd * sp, dy / dd * sp * 0.6 - rng.uniform(40, 140), x, y, rng)
    tail = stone_lands(m, chunks, 0.4, rng, (8, 11), 0.5, 320, 0.07)
    put(tail, stone_lands(m, flakes, 0.18, rng, (4, 6), 0, 250, 0.04), 0)
    put(tail, debris(m, grit, 0.14, 6, short=True, vref=260, seed=sd + 16), 0)

    full = shot(m, [(creep, 0), (sets, CREEP), (hold, CREEP), (crk, CRACK), (hit, th), (body, th + fz), (tail, th + fz)])
    return leveled(m, full, {"creep": creep, "set": sets, "crack": crk, "hit": hit, "body": body, "tail": tail},
                   "stone grinding up with the front + edge snaps + grit (0-0.95), a dull stone knock as it sets (0.95), a "
                   "pebble or two; cracks running + chips + juddering rattle (1.75-2.2); burst at 2.2, rubble rumble and "
                   "dust after the 0.08 hit-stop, chunks, flakes and grit knocking down", -24)


# ------------------------------------------------------------------ silent: a status held on a character
def bleeding(m):
    return Silent("a lingering status: beads swelling and dripping into a pool, a spurt on each heartbeat (every 1.2 s): "
                  "tiny drips on an even pulse would be a beat (rule 1), and the wound's sound is the hit that made it "
                  "(rule 2)")


def burning(m):
    return Silent("small flames licking off a character: a steady fire is silent like a torch (rule 2), and its flare "
                  "every 0.6 s would be a beat (rule 1); catching fire is the one-shot (the fire hit that set it)")


def charmed(m):
    return Silent("a heart beating over the head, little hearts floating up: a status glow (rule 2); its beat is a "
                  "rhythm (rule 1)")


def confused(m):
    return Silent("a spiral whirling over the head, question marks bobbing: a status glow (rule 2)")


def cursed(m):
    return Silent("violet smoke rising, a stain creeping up, a skull glitching in: a lingering status glow (rule 2)")


def frozen(m):
    return Silent("frost on the body, icicles dripping, a shiver every second: a lingering status (rule 2), its shiver "
                  "an even beat (rule 1); freezing over and breaking free are the one-shots (ice/freeze)")


def haste(m):
    return Silent("after-images and speed lines streaming behind: a status glow (rule 2); the steps are the "
                  "character's own footsteps, not the status")


def poisoned(m):
    return Silent("green waves rolling up the body, veins creeping, sweat hissing, a wobble every 0.8 s: a lingering "
                  "status (rule 2), its wobble and blister pops an even beat (rule 1)")


def rage(m):
    return Silent("the body juddering on each heartbeat, steam jetting off the head, an anger mark throbbing: a status "
                  "glow (rule 2) whose heartbeat is a rhythm (rule 1)")


def sleep(m):
    return Silent("Zs floating up, a slow breathing glow: a status glow (rule 2); no snore, it would be a rhythm (rule 1)")


def slowed(m):
    return Silent("a glassy clock ticking round in heavy steps: a status glow (rule 2), and ticks on its steps would be "
                  "a metronome (rule 1)")


def stunned(m):
    return Silent("stars and little birds circling the head: a status glow (rule 2); tweets would be a chirp melody "
                  "(rule 1)")


SOUNDS = {
    "bleeding": bleeding,
    "burning": burning,
    "charmed": charmed,
    "confused": confused,
    "cursed": cursed,
    "frozen": frozen,
    "haste": haste,
    "petrified": petrified,
    "poisoned": poisoned,
    "rage": rage,
    "sleep": sleep,
    "slowed": slowed,
    "stunned": stunned,
}
