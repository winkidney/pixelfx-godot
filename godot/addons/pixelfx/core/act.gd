# An act: an effect performed. The character winds up, lets go and recovers, a target takes the hit, and everything
# freezes for a moment on contact. Effects describe it as data (`static var act := {...}`), so a game with its own
# character can read the same timing (actTiming). The freeze, the shake, the springy target and poses held on 12 fps
# steps are how Hollow Crown plays its skills (https://github.com/rehan-remade/hollow-crown), MIT License,
# Copyright (c) 2026 rehan-remade.
# port-of: src/core/act.js@731e56c89512650bb56dcc9318e495a2b14dd85e
extends RefCounted

const Px := preload("px.gd")
const Rig := preload("rig.gd")


static func _num(v: Variant) -> bool:
	return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT


static func _lerp(a: float, b: float, u: float) -> float:
	return a + (b - a) * u


## Between two poses: numbers move, everything else changes at the later key.
static func lerpPose(a: Dictionary, b: Dictionary, u: float) -> Dictionary:
	var out := Px.merge(Rig.STAND, a)
	var B := Px.merge(Rig.STAND, b)
	for k in B:
		var v: Variant = B[k]
		if _num(v) and _num(out.get(k)):
			out[k] = _lerp(out[k], v, u)
		elif out.get(k) == null and _num(v):
			out[k] = v
	# what the later pose doesn't mention eases back to its default
	for k in ["hx", "hy", "lean", "crouch"]:
		if B.get(k) == null and _num(out.get(k)):
			out[k] = _lerp(out[k], 0.0, u)
	if B.get("wl") == null and _num(out.get("wl")):
		out.wl = _lerp(out.wl, 1.0, u)
	return out


static func _ease(how: Variant, u: float) -> float:
	match how:
		"out":
			return 1.0 - (1.0 - u) * (1.0 - u)
		"in":
			return u * u
		"line":
			return u
	return u * u * (3.0 - 2.0 * u)


## The pose at time t on a track of keys [t, pose, how]: how a pose arrives: smoothly by default, "out" fast then
## settling, "in" slowly then fast, "snap" holding the last pose and jumping on the key. Limbs move in whole 12 fps
## steps counted from each key; the feet's position over the floor (x, y) stays smooth.
static func poseAt(track: Array, t: float) -> Dictionary:
	if t <= track[0][0]:
		return track[0][1]
	for i in track.size() - 1:
		var t0: float = track[i][0]
		var a: Dictionary = track[i][1]
		var t1: float = track[i + 1][0]
		var b: Dictionary = track[i + 1][1]
		var how: Variant = track[i + 1][2] if track[i + 1].size() > 2 else null
		if t >= t1:
			continue
		if how == "snap":
			return a
		var stepped := t0 + floorf((t - t0) * 12.0 + 1e-6) / 12.0
		var out := lerpPose(a, b, _ease(how, (stepped - t0) / (t1 - t0)))
		var u := _ease(how, (t - t0) / (t1 - t0))
		out.x = _lerp(a.get("x", 0.0) if a.get("x") != null else 0.0, b.get("x", 0.0) if b.get("x") != null else 0.0, u)
		out.y = _lerp(a.get("y", 0.0) if a.get("y") != null else 0.0, b.get("y", 0.0) if b.get("y") != null else 0.0, u)
		return out
	return track[track.size() - 1][1]


## Is the body between keys that hardly differ, or past the last?
static func isHeld(track: Array, t: float) -> bool:
	if t >= track[track.size() - 1][0] or t < track[0][0]:
		return true
	for i in track.size() - 1:
		if t >= track[i + 1][0]:
			continue
		var a := Px.merge(Rig.STAND, track[i][1])
		var b := Px.merge(Rig.STAND, track[i + 1][1])
		if not (track[i + 1][0] - track[i][0] > 0.4):
			return false
		for k in ["fx", "fy", "bx", "by", "crouch", "lean", "x", "y"]:
			if absf(float(a.get(k, 0.0) if a.get(k) != null else 0.0) - float(b.get(k, 0.0) if b.get(k) != null else 0.0)) >= 1.5:
				return false
		return true
	return true


## When an act's poses begin and end, in effect time (a loop ends when it's told to).
static func actSpan(mod: Script) -> Dictionary:
	var a: Variant = Px.Fx.actOf(mod)
	var meta := Px.Fx.metaOf(mod)
	var D: float = meta.duration
	var k: Variant = a.get("poses") if a != null else null
	var first: float = k[0][0] if (k != null and k.size()) else 0.0
	var last: float = k[k.size() - 1][0] if (k != null and k.size()) else 0.0
	return {"from": minf(0.0, first), "to": INF if meta.loop else maxf(D, last)}


static func _targets(a: Dictionary) -> Array:
	if a.get("targets") != null:
		return a.targets
	if a.get("target"):
		return [a.target]
	return []


## An act as plain data, for a game with its own character: how long the wind-up and recovery are, when to freeze and
## shake, what a target should do, and the poses themselves. Times are in the effect's own seconds: start it at 0.
static func actTiming(mod: Script) -> Variant:
	var a: Variant = Px.Fx.actOf(mod)
	if a == null:
		return null
	var span := actSpan(mod)
	var meta := Px.Fx.metaOf(mod)
	var D: float = meta.duration
	var targets := []
	for g in _targets(a):
		targets.append(g.x if g.get("x") != null else 66)
	var hits := []
	for h in a.get("hits", []):
		var push: Variant = 0 if h.get("target") == false else (h.push if h.get("push") != null else 1.2)
		hits.append({"t": h.t, "freeze": h.get("stop", 0) if h.get("stop") != null else 0, "shake": h.get("shake", 0) if h.get("shake") != null else 0, "amp": h.get("amp", 0) if h.get("amp") != null else 0, "push": push, "skin": h.get("skin"), "at": h.get("at")})
	var poses := []
	for key in a.get("poses", []):
		poses.append({"t": key[0], "how": key[2] if key.size() > 2 and key[2] != null else "smooth", "pose": key[1]})
	return {
		"windup": -span.from,
		"recovery": 0 if meta.loop else maxf(0.0, span.to - D),
		"onBody": true if a.get("onBody") else false,
		"targets": targets,
		"hits": hits,
		"poses": poses,
	}
