# reimagined-from: src/fx/water/water-orb.js@eca9dab09cf0ac79ba80e6f6afb266756d19fe2f
# Water orb: A sphere of water floats and wobbles: a current circles inside it, the floor shows upside down through it, it shines, light gathers on the floor under it, and drips fall and plink.
# loop, 3.00 s, 100x108 canvas, origin [50.0, 100.0], backdrop ground
# ramp palette: #0a1630 #123063 #1b5596 #2a7fc4 #45a9e3 #86d3f5 #cdf1ff #ffffff
# The orb is a canvas shader (fx/water/_orb.gdshader) bobbing once a loop: its see-through body on the soft layer,
# and on the colour layer its wobbling, sagging skin, the current circling inside on three tilted planes, the shine
# and the lens' focus. Bubbles drift up inside it (an emitter riding with it), motes of spray circle it on tilted
# orbits passing in front and behind, a drip falls from its belly every 1.5 s (fx/water/_bead.gdshader) and plinks
# into a ring (fx/water/_ring.gdshader); light gathers under it on the floor.
extends "res://build/fx/water/_water.gd"

const D := 3.0
const SY := 0.3
const G := 700.0
const DRIP := 1.5
const LET := 0.5
const Y0 := -52.0


static func cy_at(t: float) -> float:
	return Y0 + sin(t / D * TAU) * 2.0


func make() -> void:
	var R: float = meta.options.radius
	var frames := int(roundf(D * 30.0))

	# light gathers on the floor under it: the orb's caustic
	glow("FloorLight", 22, {"radius": 22, "color": C[5], "alpha": 0.32})
	rect("CausticEdge", Rect2(-7, -1, 14, 2), C[5], {"back": true, "modulate": Color(1, 1, 1, 0.45)})
	rect("Caustic", Rect2(-5, -1, 10, 2), C[6], {"back": true})
	rect("CausticCore", Rect2(-2, -1, 4, 2), C[7], {"back": true})
	var halo := glow("Halo", R * 3.2, {"radius": R * 3.2, "color": C[4], "alpha": 0.3}, {"at": Vector2(0, Y0)})
	sample(halo, "position", func(t: float) -> Vector2: return Vector2(0, cy_at(t)))
	sample(halo, "material:shader_parameter/alpha", func(t: float) -> float: return 0.3 + 0.05 * sin(t / D * TAU * 2.0))

	# the body, then its skin, current, shine and focus
	var size := Vector2(2.0 * (R + 6.0), 2.0 * (R + 9.0))
	var at := Vector2(0, Y0 + 1.0)
	var params := {"pal": C, "dur": D, "R": R, "y0": Y0, "bob": 2.0, "drip": DRIP, "let_go": LET}
	var body := params.duplicate()
	body.merge({"mode": 0.0, "translucent": true})
	loop_t(shape("Body", water_shader("orb"), size, body, {"at": at}))
	var skin := params.duplicate()
	skin.mode = 1.0
	loop_t(shape("Skin", water_shader("orb"), size, skin, {"at": at}))

	# bubbles drift up inside it, riding with it as it bobs
	var inside := group("Inside", {"at": Vector2(0, Y0)})
	sample(inside, "position", func(t: float) -> Vector2: return Vector2(0, cy_at(t)))
	particles("Bubbles", {"parent": inside, "local": true, "at": Vector2(0, R * 0.6), "amount": 4, "lifetime": 1.4,
		"randomness": 0.3, "texture": "dot1", "emit": {"box": Vector2(R * 0.45, 0.5)}, "dir": -90, "spread": 4,
		"speed": [14, 18], "ramp": gradient([C[6], C[7]], [0.0, 0.8]),
		"turbulence": {"strength": 1.0, "scale": 2.0, "influence": [0.005, 0.01]}})

	# motes of spray on tilted orbits round it: white in front with a glint of light, dim behind it
	for i in 7:
		var front := group("Mote%d" % i)
		dot("Core", C[7], Vector2.ZERO, {"parent": front})
		dot("Side", C[5], Vector2(-1.0 if i % 2 else 1.0, 0.0) * -1.0, {"parent": front})
		var back := dot("MoteBack%d" % i, C[4], Vector2.ZERO, {"back": true})
		var shine := glow("MoteLight%d" % i, 4, {"radius": 4, "color": C[5], "alpha": 0.35})
		var fv := []
		var bv := []
		var pos := []
		var gpos := []
		for f in frames + 1:
			var t := f / 30.0
			var ph := t / D
			var a := i / 7.0 * TAU + ph * TAU * (1.0 if i % 2 else -1.0)
			var r := R + 5.0 + (i % 3) * 3.0
			var tilt := (i - 3) * 0.22
			var x := cos(a) * r
			var z := sin(a)
			var m := Vector2(x * cos(tilt), x * sin(tilt) + z * r * 0.28) + Vector2(0, cy_at(t))
			fv.append([t, z >= 0.0])
			bv.append([t, z < 0.0])
			pos.append([t, m.floor()])
			gpos.append([t, m.floor() + Vector2(0.5, 0.5)])
		key(front, "visible", fv, "nearest")
		key(back, "visible", bv, "nearest")
		key(shine, "visible", fv, "nearest")
		key(front, "position", pos, "nearest")
		key(back, "position", pos, "nearest")
		key(shine, "position", gpos, "nearest")

	# a drip lets go of its belly every DRIP s, falls and plinks into a ring
	var drop := shape("Drip", water_shader("bead"), Vector2(8, 16), {"pal": C, "style": 3.0, "dir": Vector2(0, 1)})
	var fleck := dot("Plink", C[7], Vector2.ZERO)
	var ring1 := water_ring("Ring", 10, {"sy": SY, "n": 1.0, "side": 1.0, "seed": 3.0})
	var dv := []
	var dp := []
	var tl := []
	var fv2 := []
	for f in frames + 1:
		var t := f / 30.0
		var cy := cy_at(t)
		var fall := fmod(t, DRIP) - DRIP * LET
		var y0 := cy + R + 3.0
		var land := sqrt(2.0 * -y0 / G)
		var falling := fall >= 0.0 and fall < land
		dv.append([t, falling])
		dp.append([t, Vector2(0, floorf(y0 + 0.5 * G * fall * fall)) if falling else Vector2(0, floorf(y0))])
		tl.append([t, minf(5.0, G * maxf(fall, 0.0) * 0.011)])
		fv2.append([t, fall >= land and fall - land < 0.08])
	key(drop, "visible", dv, "nearest")
	key(drop, "position", dp, "nearest")
	key(drop, "material:shader_parameter/tail", tl, "nearest")
	key(fleck, "visible", fv2, "nearest")
	sample_shader(ring1, func(t: float) -> Dictionary:
		var fall := fmod(t, DRIP) - DRIP * LET
		var land := sqrt(2.0 * -(cy_at(t) + R + 3.0) / G)
		var since := fall - land
		if fall < land or since > 0.4:
			return {"r": 1.5, "k": 0.0, "hot": false}
		return {"r": 1.5 + since * 18.0, "k": 1.1 * (1.0 - since / 0.4), "hot": since < 0.05})

	# light: the lens' focus pulsing, the orb's own shine
	var focus := glow("FocusLight", 9, {"radius": 9, "color": C[5], "alpha": 0.45})
	sample(focus, "position", func(t: float) -> Vector2: return Vector2(R * 0.36, cy_at(t) + R * 0.4))
	sample(focus, "material:shader_parameter/alpha", func(t: float) -> float: return 0.45 * (0.8 + 0.2 * sin(t / D * TAU * 4.0)))
	var shine_all := glow("OrbLight", R * 1.4, {"radius": R * 1.4, "color": C[5], "alpha": 0.22})
	sample(shine_all, "position", func(t: float) -> Vector2: return Vector2(0, cy_at(t)))
	var spot := glow("ShineLight", 6, {"radius": 6, "color": C[7], "alpha": 0.25})
	sample(spot, "position", func(t: float) -> Vector2: return Vector2(-R * 0.4, cy_at(t) - R * 0.5))
