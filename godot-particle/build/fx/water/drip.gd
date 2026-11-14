# reimagined-from: src/fx/water/drip.js@ac2ede2ee25d1751b63f9f1cc6d4a75eb686e812
# Drip: A bead swells under a wet stone tip and catches the light, pinches off, falls stretched by its speed and plinks into a puddle with a crown, a ring and a tiny rebound.
# loop, 1.60 s, 72x88 canvas, origin [36.0, 78.0], backdrop ground
# ramp palette: #0a1630 #123063 #1b5596 #2a7fc4 #45a9e3 #86d3f5 #cdf1ff #ffffff
# The dripstone and the still puddle under it are the original's pixels (port/props.py). The bead is a small shader
# (fx/water/_bead.gdshader) keyed from the original's swell, wobble and neck; it falls on the original's curve with a
# tail stretched by its speed, plinks with a white fleck, a crown of flecks (a burst), two ripple rings
# (fx/water/_ring.gdshader) and a tiny rebound bead; light gathers under the tip and in the puddle.
extends "res://build/fx/water/_water.gd"

const D := 1.6
const SY := 0.28
const G := 760.0
const LET := 0.78
const REBOUND := 0.06
const BACK := 0.2


func make() -> void:
	var H: float = meta.options.height
	var land := LET + sqrt(2.0 * H / G)
	prop()

	# the wet light under the tip and in the puddle
	glow("TipLight", 8, {"radius": 8, "color": C[5], "alpha": 0.16}, {"at": Vector2(0, -H + 2)})
	glow("PuddleLight", 26, {"radius": 26, "color": C[3], "alpha": 0.14})

	# the rings: the drop's, then the rebound's
	var r1 := water_ring("Ring", 22, {"sy": SY, "n": 2.0, "gap": 2.5, "seed": 1.0, "wob": 0.4})
	sample_shader(r1, func(t: float) -> Dictionary:
		var u := t - land
		if u < 0.0 or u > 0.75:
			return {"r": 2.0, "k": 0.0, "hot": false, "glint": 0.0}
		return {"r": 2.0 + 17.0 * out_cubic(u / 0.75), "k": 1.1 * (1.0 - u / 0.75), "hot": u < 0.08, "glint": (1.0 - u * 2.0) if u < 0.5 else 0.0})
	var r2 := water_ring("Ring2", 12, {"sy": SY, "n": 1.0, "seed": 2.0})
	sample_shader(r2, func(t: float) -> Dictionary:
		var v := t - land - REBOUND - BACK
		if v < 0.0 or v > 0.5:
			return {"r": 1.5, "k": 0.0, "hot": false}
		return {"r": 1.5 + 9.0 * out_cubic(v / 0.5), "k": 0.9 * (1.0 - v / 0.5), "hot": v < 0.06})

	# the bead swelling at the tip, wobbling, catching the light; its neck stretches before it lets go
	var hang := shape("Bead", water_shader("bead"), Vector2(12, 20), {"pal": C, "style": 1.0}, {"at": Vector2(0, -H)})
	var hang_light := glow("BeadLight", 12, {"radius": 4, "color": C[5], "alpha": 0.0}, {"at": Vector2(0, -H)})
	var pos := []
	var lpos := []
	var lrad := []
	var lalpha := []
	var vis := []
	var rxs := []
	var rys := []
	var necks := []
	for f in int(roundf(D * 30.0)) + 1:
		var t := f / 30.0
		var k := minf(t / LET, 1.0)
		var r := 0.7 + 2.3 * in_quad(k)
		var wob := 0.15 * sin(t * 26.0) * k
		var neck := smooth(0.82, 1.0, k) * 2.5
		var cy := -H + r + neck
		pos.append([t, Vector2(0, roundf(cy))])
		lpos.append([t, Vector2(0, cy)])
		lrad.append([t, 4.0 + r * 2.0])
		lalpha.append([t, (0.14 + 0.14 * k) if t < LET else 0.0])
		vis.append([t, t < LET])
		rxs.append([t, r * (1.0 - wob)])
		rys.append([t, r * (1.0 + wob) + 0.3 * k])
		necks.append([t, neck])
	key(hang, "position", pos, "nearest")
	key(hang, "visible", vis, "nearest")
	key(hang, "material:shader_parameter/rx", rxs, "nearest")
	key(hang, "material:shader_parameter/ry", rys, "nearest")
	key(hang, "material:shader_parameter/neck", necks, "nearest")
	key(hang_light, "position", lpos, "nearest")
	key(hang_light, "material:shader_parameter/radius", lrad, "nearest")
	key(hang_light, "material:shader_parameter/alpha", lalpha, "nearest")

	# a little of it springs back up the tip after it lets go
	var spring := shape("Spring", water_shader("bead"), Vector2(8, 8), {"pal": C, "style": 2.0, "offset": Vector2(0, 0.8)}, {"at": Vector2(0, -H)})
	var sv := []
	var srx := []
	var sry := []
	for f in int(roundf(D * 30.0)) + 1:
		var t := f / 30.0
		var s := (t - LET) / 0.15
		sv.append([t, s >= 0.0 and s < 1.0])
		srx.append([t, 1.2 * (1.0 - clampf(s, 0.0, 1.0) * 0.6)])
		sry.append([t, 1.0 + sin(clampf(s, 0.0, 1.0) * PI) * 0.8])
	key(spring, "visible", sv, "nearest")
	key(spring, "material:shader_parameter/rx", srx, "nearest")
	key(spring, "material:shader_parameter/ry", sry, "nearest")

	# the fall, stretched by its speed
	var drop := shape("Drop", water_shader("bead"), Vector2(8, 16), {"pal": C, "style": 0.0}, {"at": Vector2(0, -H + 3)})
	var drop_light := glow("DropLight", 6, {"radius": 6, "color": C[5], "alpha": 0.2}, {"at": Vector2(0, -H + 3)})
	var dp := []
	var dv := []
	var tl := []
	for f in int(roundf(D * 30.0)) + 1:
		var t := f / 30.0
		var ff := t - LET
		var y := -H + 3.0 + 0.5 * G * ff * ff
		dv.append([t, ff > 0.0 and t < land])
		dp.append([t, Vector2(0, roundf(y))])
		tl.append([t, minf(5.0, G * maxf(ff, 0.0) * 0.011)])
	key(drop, "position", dp, "nearest")
	key(drop, "visible", dv, "nearest")
	key(drop, "material:shader_parameter/tail", tl, "nearest")
	key(drop_light, "position", dp, "nearest")
	key(drop_light, "visible", dv, "nearest")

	# the plink: a white fleck and a flash of light, a crown of flecks thrown out and back, a tiny rebound
	var fleck := group("Fleck")
	dot("FleckSides", C[6], Vector2(-1, 0), {"parent": fleck, "size": Vector2(3, 1)})
	dot("FleckCore", C[7], Vector2(0, 0), {"parent": fleck})
	show(fleck, land, land + 0.06)
	var flash := glow("Flash", 10, {"radius": 10, "color": C[5], "alpha": 0.0}, {"at": Vector2(0, -1)})
	key(flash, "material:shader_parameter/alpha", [[0.0, 0.0], [land - 0.001, 0.0], [land, 0.5], [land + 0.06, 0.0]])
	var pool := glow("PoolFlash", 18, {"radius": 18, "color": C[4], "alpha": 0.0})
	key(pool, "material:shader_parameter/alpha", [[0.0, 0.0], [land - 0.001, 0.0], [land, 0.22], [land + 0.6, 0.0]])
	var crown := particles("Crown", {"at": Vector2(0, -1), "amount": 3, "lifetime": 0.3, "one_shot": true, "explosiveness": 1.0,
		"emitting": false, "texture": "dot1", "dir": -90, "spread": 22, "speed": [70, 92], "gravity": Vector2(0, G),
		"ramp": gradient([C[7], C[6]], [0.0, 0.33])})
	emit(crown, land)
	var rb := group("Rebound")
	dot("Stem", C[5], Vector2(0, -1), {"parent": rb})
	dot("Head", C[6], Vector2(-1, -1), {"parent": rb, "size": Vector2(2, 2)})
	dot("Shine", C[7], Vector2(0, -2), {"parent": rb})
	var rv := []
	var rp := []
	for f in int(roundf(D * 30.0)) + 1:
		var t := f / 30.0
		var r := t - land - REBOUND
		var h := 52.0 * r - 0.5 * G * 0.5 * r * r * 2.0
		rv.append([t, r > 0.0 and h > 0.0])
		rp.append([t, Vector2(0, -floorf(h))])
	key(rb, "visible", rv, "nearest")
	key(rb, "position", rp, "nearest")

	# the tip and the falling drop shimmer in the puddle
	var tip := dot("TipShimmer", C[4], Vector2(-1, 2))
	var shim := dot("DropShimmer", C[5], Vector2(0, 2))
	var tp := []
	var sp := []
	var svis := []
	for f in int(roundf(D * 30.0)) + 1:
		var t := f / 30.0
		var sh := 0.0 if sin(t * 20.0) > 0.0 else 1.0
		var ff := t - LET
		tp.append([t, Vector2(-1.0 + sh, 2)])
		sp.append([t, Vector2(sh, floorf(minf(4.0, 2.0 + 0.5 * G * ff * ff * 0.04)))])
		svis.append([t, ff > 0.0 and t < land])
	key(tip, "position", tp, "nearest")
	key(shim, "position", sp, "nearest")
	key(shim, "visible", svis, "nearest")
