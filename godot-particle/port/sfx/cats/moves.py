# moves: chain the parts' sounds on the move's cue sheet (src/fx/moves/<name>.js), on the effect's clock.
import numpy as np
from synth import *  # noqa: F401,F403
from cats.explosions import small_explosion_parts


def fireball_throw(m):
    """charge 0.08-0.95 (fire palette: lower, rougher, no notes), throw 0.95 (release), flight 0.95-1.41 (a roar
    panned from caster to target), blast 1.41 (small-explosion), its body after the 0.18 s hit-stop."""
    full = blank(m["duration"])
    place(full, charge(0.95 - 0.08, seed=3, f0=130, f1=650), 0.08, -0.6)
    rel = blank(0.5)
    place(rel, whoosh(0.35, 2, 9, 0.5, 1), 0)
    place(rel, blip(520, 0.3, 0.25, 0.22, 7, slide=-0.7), 0)
    place(full, rel[:, 0], 0.95, -0.6)
    t = T(0.46)
    roar = noise(len(t), np.round(np.interp(t, [0, 0.46], [9, 6])).astype(int), seed=11) * steps(0.35 + 0.2 * t / 0.46)
    roar += pulse(NOTE(40) * (1 + 0.3 * t / 0.46), 0.25) * steps(np.full(len(t), 0.12))
    i0 = int(0.95 * SR)
    pan = np.linspace(-0.7, 0.6, len(roar))
    full[i0:i0 + len(roar), 0] += roar * np.sqrt((1 - pan) / 2)
    full[i0:i0 + len(roar), 1] += roar * np.sqrt((1 + pan) / 2)
    hit, body, tail = small_explosion_parts(2)
    place(full, hit[:, 0], 1.41, 0.55, 1.1)
    place(full, body[:, 0], 1.41 + 0.18, 0.55)
    place(full, tail[:, 0], 1.41 + 0.9, 0.55)
    place(full, whoosh(0.18, 8, 12, 0.08, 6), 6.21, 0.55)
    return Sound(full, {}, "charge (no notes) -> release -> panned flight roar -> small-explosion hit, body after the hit-stop")


import importlib
import json
import os

_META = json.load(open(os.path.join(os.path.dirname(__file__), "..", "..", "meta.json")))


def _sound_of(fid):
    """The sub-effect's own Sound (or None when it is Silent), from its category's SOUNDS."""
    cat, name = fid.split("/")
    fn = getattr(importlib.import_module("cats." + cat), "SOUNDS", {}).get(name)
    if fn is None:
        return None
    r = fn(dict(_META[fid], id=fid))
    return None if isinstance(r, Silent) else r


def chain(m, cues, notes):
    """A move as the original builds it (core chain.js): each cue starts its effect's sound at `t`, cut off with a
    short fade at `until`; x (px from the move's origin, or a function of the move's time) sets the pan, following a
    projectile across. A looping part (a projectile in flight) fills its span with its loop, after its launch."""
    w, ox = m["size"][0], m["origin"][0]
    full = blank(m["duration"] + 1.5)
    for c in cues:
        r = _sound_of(c["fx"])
        if r is None:
            continue
        t0 = c.get("t", 0.0)
        end = c.get("until")
        sub = _META[c["fx"]]
        mono = np.asarray(r.full, float).mean(1)
        if sub["loop"]:
            span = (end if end is not None else m["duration"]) - t0
            mono = np.tile(mono, int(np.ceil(span / sub["duration"])) + 1)[: int(span * SR)]
            if "launch" in r.phases:
                launch = np.asarray(r.phases["launch"], float).mean(1)
                mono[: len(launch)] += launch[: len(mono)]
        elif end is not None:
            mono = mono[: int((end - t0) * SR)].copy()
        if end is not None and len(mono):
            k = min(len(mono), int(0.03 * SR))
            mono[-k:] *= np.linspace(1, 0, k)
        x = c.get("x", 0.0)
        ts = t0 + np.arange(len(mono)) / SR
        xs = np.array([x(u) for u in ts[:: 441]]).repeat(441)[: len(mono)] if callable(x) else np.full(len(mono), float(x))
        pan = np.clip((ox + xs - w / 2) / (w / 2), -0.9, 0.9)
        i = int(round(t0 * SR))
        seg = full[i:i + len(mono)]
        n = len(seg)
        seg[:, 0] += mono[:n] * np.sqrt((1 - pan[:n]) / 2) * np.sqrt(2)
        seg[:, 1] += mono[:n] * np.sqrt((1 + pan[:n]) / 2) * np.sqrt(2)
    # parts that land together add up: round off only those peaks (a soft knee from 1.4 up to a ceiling of 1.9,
    # under make.py's master gain) instead of turning the whole move down
    a = np.abs(full)
    over = a > 1.4
    full[over] = np.sign(full[over]) * (1.4 + 0.5 * np.tanh((a[over] - 1.4) / 0.5))
    return Sound(full, {}, notes)


def cue_move(cues, notes):
    return lambda m: chain(m, cues, notes)


SOUNDS = {
    "fireball-throw": fireball_throw,
    "arrow-shot": cue_move([
        {"fx": "projectiles/arrow", "t": 0.56, "until": 0.80, "x": lambda t: 30 + (t - 0.56) * (150 / 0.24)},
        {"fx": "impacts/hit-spark", "t": 0.80, "x": 170}], "arrow loosed and flying across, hit spark at the target"),
    "dash-strike": cue_move([
        {"fx": "melee/sword-slash", "t": 0.16, "x": 116},
        {"fx": "impacts/crit-hit", "t": 0.22, "x": 166}], "the cut where the dash ends, a critical hit on the target"),
    "earth-stomp": cue_move([{"fx": "nature/earth-spike", "t": 0.06, "x": 112}], "the spike under the target as the boot lands"),
    "ground-pound": cue_move([{"fx": "impacts/ground-slam", "t": 0.62}], "the slam where he lands"),
    "holy-smite": cue_move([{"fx": "holy/smite", "t": 0.0, "x": 118}], "the smite on the target"),
    "ice-lance-throw": cue_move([
        {"fx": "arcane/spell-charge", "t": 0.06, "until": 0.8},
        {"fx": "ice/ice-lance", "t": 0.8, "until": 1.14, "x": lambda t: 34 + (t - 0.8) * (136 / 0.34)},
        {"fx": "ice/snowflake-burst", "t": 1.14, "x": 170}], "charge, the lance across, a snowflake burst on the target"),
    "lightning-call": cue_move([{"fx": "lightning/lightning-strike", "t": 0.0, "x": 130}], "the strike on the target"),
    "meteor-call": cue_move([
        {"fx": "arcane/magic-circle-cast", "t": 0.0},
        {"fx": "fire/meteor", "t": 2.05 - 0.62, "x": 170}], "the circle under the caster, the meteor coming down on the target"),
    "pistol-shots": cue_move([c for t0 in (0.14, 0.42, 0.7) for c in (
        {"fx": "projectiles/muzzle-pistol", "t": t0, "x": 28},
        {"fx": "projectiles/bullet-tracer", "t": t0, "until": t0 + 0.12, "x": (lambda a: lambda u: 32 + (u - a) * (138 / 0.12))(t0)},
        {"fx": "impacts/hit-spark", "t": t0 + 0.12, "x": 170})], "three shots: muzzle, tracer across, spark on the target"),
    "rocket-launcher": cue_move([
        {"fx": "projectiles/muzzle-shotgun", "t": 0.6, "x": 34},
        {"fx": "projectiles/rocket", "t": 0.6, "until": 1.16, "x": lambda t: 44 + (max(0.0, t - 0.6) ** 1.5) * (150 / 0.56 ** 1.5)},
        {"fx": "explosions/small-explosion", "t": 1.16, "x": 200}], "launch blast, the rocket speeding across, the explosion"),
    "sword-combo": cue_move([
        {"fx": "melee/sword-slash", "t": 0.0},
        {"fx": "melee/double-slash", "t": 0.5, "x": 10},
        {"fx": "melee/heavy-cleave", "t": 1.04, "x": 20}], "a slash, a double slash a step on, a heavy cleave"),
}
