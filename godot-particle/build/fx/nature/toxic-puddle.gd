# reimagined-from: src/fx/nature/toxic-puddle.js@0b2c48177c9583fc2209d40d7ef2a14a39eb69d4
# Toxic puddle: Black tar lit from inside by chartreuse veins and a glowing rim, an oily sheen drifting on it; glossy
# bubbles dome, stretch and pop, vapour curls up in fraying ribbons.
# The pool is a shader (fx/nature/_tar.gdshader: the original's lens of tar with swells rolling through it, the
# oily skin and its sliding sheen, veins of light writhing under the crust, the glowing rim and lips) with a light
# pass of its own (_tar_light.gdshader) where the veins and glints shine; the bubbles dome, stretch and pop in a flat
# ripple ring in a third shader (_tar_bubbles.gdshader) on the original's cycle; their light, the pop's flash and
# the pool's glow are glows keyed every frame; spatter thrown up at each pop is a burst; vapour ribbons are
# emitters that sway as they breathe out a rising stream (each particle keeps the x it was born at, so the stream
# draws a curling ribbon), greying as they climb.
extends "res://addons/pixelfx_particles/core/build.gd"

const GREY := Color("#b4b8ae")
var W := 42.0
var D := 4.0


func surf(x: float, t: float) -> float:
	var d := minf(1.0, absf(x) / W)
	var ph := TAU * t / D
	var lens := sqrt(1.0 - d * d) * 6.6 + (1.6 * smoothstep(0.8, 0.9, d) if d > 0.8 else 0.0)
	var swell := pow(maxf(0.0, sin(x * 0.09 - ph)), 6.0) * 1.2 + pow(maxf(0.0, sin(x * 0.06 + ph * 2.0 + 1.0)), 8.0) * 0.9
	return -roundf(lens + swell * (1.0 - d))


static func out_cubic(x: float) -> float:
	return 1.0 - pow(1.0 - clampf(x, 0.0, 1.0), 3.0)


## Keys for something that lives from `born` for `life` seconds of every loop (wrapping round its end): f(age) at 30 Hz.
func cyc(born: float, life: float, f: Callable) -> Array:
	var out := []
	for j in int(D * 30.0) + 1:
		var t := j / 30.0
		var age := fposmod(t - born, D)
		out.append([t, f.call(age) if age < life else f.call(-1.0)])
	return out


## Emitting from `on` to `off` seconds of the loop, wrapping round its end.
func window(p: GPUParticles2D, on: float, off: float) -> void:
	on = fposmod(on, D)
	off = fposmod(off, D)
	var at0 := on > off
	var keys := [[0.0, at0]]
	if off > 0.0:
		keys.append([off, false])
	keys.append([on, true])
	keys.sort_custom(func(a, b): return a[0] < b[0])
	p.emitting = at0
	key(p, "emitting", keys, "nearest")


## A vapour ribbon: a stream breathed out at (x0, y0) for len / rise s from `born`, swaying, rising at `rise`, lit
## green low down and greying as it climbs, fading in and out over its life.
func ribbon(name: String, x0: float, y0: float, born: float, life: float, rng: RandomNumberGenerator, k: float) -> void:
	var C: PackedColorArray = root.ramps.palette
	var length := rng.randf_range(16, 26)
	var rise := rng.randf_range(9, 14)
	var amp := rng.randf_range(2, 4.5)
	var w := rng.randf_range(0.18, 0.3)
	var ph := rng.randf() * TAU
	var dur := minf(life, length / rise)
	var lit := GREY.lerp(C[6], 0.75)
	var p := particles(name, {"layer": "soft", "at": Vector2(x0, y0), "amount": maxi(8, int(dur * 30.0)), "lifetime": life,
		"texture": "dot1", "dir": -90, "spread": 0, "speed": [rise, rise],
		"ramp": gradient([Color(GREY.lerp(C[6], 0.55), 0.42), Color(GREY.lerp(C[6], 0.3), 0.4), Color(GREY.lerp(C[6], 0.12), 0.36), Color(GREY, 0.3)]),
	})
	window(p, born, born + dur)
	var sway := func(tau: float) -> float:
		return x0 + amp * 1.2 * sin(maxf(tau, 0.0) * w * rise * 1.6 + ph)
	# a ribbon already rising when the loop starts: what it breathed out before is laid out where it would be by now
	# (a one-shot burst from points along it, fired once when the effect starts; later loops carry their own over)
	var age0 := fposmod(-born, D)
	p.preprocess = 0.02 if p.emitting else 0.0
	if age0 > 0.0 and age0 < life:
		var pts := PackedVector2Array()
		var tau := 0.0
		while tau < minf(age0, dur):
			pts.append(Vector2(sway.call(tau) - x0, -rise * (age0 - tau)))
			tau += 1.0 / 30.0
		if pts.size() > 0:
			var q := particles(name + "Start", {"layer": "soft", "at": Vector2(x0, y0), "amount": pts.size(), "lifetime": life - age0,
				"one_shot": true, "explosiveness": 1.0, "texture": "dot1", "emit": {"points": pts}, "dir": -90,
				"speed": [rise, rise], "ramp": p.process_material.color_ramp})
			key(q, "modulate:a", cyc(born, life, func(age: float) -> float:
				if age < 0.0:
					return 0.0
				var u := age / life
				return k * smoothstep(0.0, 0.12, u) * (1.0 - smoothstep(0.5, 1.0, u)) / 0.9))
	var om := w * rise * 1.6
	key(p, "position", cyc(born, life, func(age: float) -> Vector2:
		return Vector2(x0 + amp * 1.2 * sin(maxf(age, 0.0) * om + ph), y0)))
	key(p, "modulate:a", cyc(born, life, func(age: float) -> float:
		if age < 0.0:
			return 0.0
		var u := age / life
		return k * smoothstep(0.0, 0.12, u) * (1.0 - smoothstep(0.5, 1.0, u)) / 0.9))


func make() -> void:
	var C: PackedColorArray = root.ramps.palette
	var Sh: PackedColorArray = root.ramps.sheen
	W = float(meta.options.width)
	D = meta.duration
	var seed_: float = float(meta.options.seed)
	ground(-6.0)

	# the light comes from inside the pool and its rim
	var pulse := func(a: float) -> Array:
		var out := []
		for j in 17:
			var t := j / 16.0 * D
			out.append([t, a * (0.85 + 0.15 * sin(TAU * t * 2.0 / D))])
		return out
	var g1 := glow("PoolLight", W * 1.25 + 2, {"radius": W * 1.25, "color": C[5]}, {"at": Vector2(0, -3), "back": true})
	key(g1, "material:shader_parameter/alpha", pulse.call(0.22))
	var g2 := glow("PoolLightHigh", W * 1.1 + 2, {"radius": W * 1.1, "color": C[6]}, {"at": Vector2(0, -10), "back": true})
	key(g2, "material:shader_parameter/alpha", pulse.call(0.1))
	for s in [-1, 1]:
		var g := glow("LipLight%s" % ("L" if s < 0 else "R"), 14, {"radius": 12, "color": C[6]}, {"at": Vector2(s * W, -1), "back": true})
		key(g, "material:shader_parameter/alpha", pulse.call(0.35))

	# the pool, and its own light
	var common := {"period": D, "W": W, "seed": seed_, "ramp": ramp("palette", {"stops": 8}), "sheen": ramp("sheen", {"stops": 4})}
	var pool := shape("Pool", load("res://addons/pixelfx_particles/fx/nature/_tar.gdshader"), Vector2(112, 20), common,
		{"at": Vector2(0, -6), "back": true})
	loop_t(pool)
	var pool_light := shape("PoolShine", load("res://addons/pixelfx_particles/fx/nature/_tar_light.gdshader"), Vector2(112, 20), common,
		{"at": Vector2(0, -6), "back": true})
	loop_t(pool_light)

	# bubbles: dome, stretch, pop; their light, the pop's flash and ring of light, spatter, a ribbon of vapour each
	var rng := RandomNumberGenerator.new()
	rng.seed = int(seed_) * 7 + 1
	var ba := PackedVector4Array()
	var bb := PackedVector4Array()
	var drop_hi := Image.create(1, 2, false, Image.FORMAT_RGBA8)
	drop_hi.set_pixel(0, 0, C[6])
	drop_hi.set_pixel(0, 1, C[1])
	var drop_sh := Image.create(1, 2, false, Image.FORMAT_RGBA8)
	drop_sh.set_pixel(0, 0, Sh[3])
	drop_sh.set_pixel(0, 1, C[1])
	var tex_hi := ImageTexture.create_from_image(drop_hi)
	var tex_sh := ImageTexture.create_from_image(drop_sh)
	for i in 8:
		var born := rng.randf() * D
		var L := rng.randf_range(2.4, 3.2)
		var swell := rng.randf_range(1.0, 1.6)
		var x := roundf(rng.randf_range(-0.7, 0.7) * W)
		var rmax := rng.randf_range(4.5, 8.0)
		ba.append(Vector4(born, L, swell, x))
		bb.append(Vector4(rmax, 0, 0, 0))
		var pop := fposmod(born + swell, D)
		var sy := surf(x, pop) + 0.5
		var dome := glow("BubbleLight%d" % i, 20, {"radius": 8, "color": C[6], "alpha": 0.0})
		var flash := glow("PopFlash%d" % i, 20, {"radius": 18, "color": C[6], "alpha": 0.0}, {"at": Vector2(x, sy - 2)})
		var halo := glow("PopRing%d" % i, 22, {"radius": 2, "thickness": 3, "color": C[6], "alpha": 0.0}, {"at": Vector2(x, sy)})
		key(dome, "position", cyc(born, L, func(age: float) -> Vector2:
			var a := clampf(age, 0.0, swell)
			var k := a / swell
			var ry := rmax * out_cubic(minf(1.0, k * 1.3)) * (1.0 + 0.5 * smoothstep(0.65, 1.0, k))
			return Vector2(x, surf(x, fposmod(born + a, D)) + 0.5 - ry * 0.5)))
		key(dome, "material:shader_parameter/radius", cyc(born, L, func(age: float) -> float:
			var k := clampf(age, 0.0, swell) / swell
			return 7.0 + 1.4 * rmax * out_cubic(minf(1.0, k * 1.3)) * (1.0 - 0.18 * smoothstep(0.65, 1.0, k))))
		key(dome, "material:shader_parameter/alpha", cyc(born, L, func(age: float) -> float:
			if age < 0.0 or age >= swell:
				return 0.0
			var k := age / swell
			return (0.2 + 0.35 * smoothstep(0.65, 1.0, k)) * out_cubic(minf(1.0, k * 1.3))))
		key(flash, "material:shader_parameter/alpha", cyc(born, L, func(age: float) -> float:
			var e := age - swell
			return 0.7 * (1.0 - e / 0.1) if age >= 0.0 and e >= 0.0 and e < 0.1 else 0.0))
		key(halo, "material:shader_parameter/alpha", cyc(born, L, func(age: float) -> float:
			var e := age - swell
			return 0.35 * (1.0 - e / 0.3) if age >= 0.0 and e >= 0.0 and e < 0.3 else 0.0))
		key(halo, "material:shader_parameter/radius", cyc(born, L, func(age: float) -> float:
			var e := clampf(age - swell, 0.0, 0.3)
			return 2.0 + 14.0 * out_cubic(e / 0.3)))
		for kind in [["Spatter%d" % i, tex_hi, 4], ["Spatter%dB" % i, tex_sh, 3]]:
			var sp := particles(kind[0], {"at": Vector2(x, sy - 2), "amount": kind[2], "lifetime": 0.6, "one_shot": true,
				"explosiveness": 1.0, "emitting": false, "texture": kind[1], "dir": -90, "spread": 38, "speed": [50, 120],
				"gravity": Vector2(0, 420), "collide": {"hide": true, "size": 1}})
			window(sp, pop, pop + 0.05)
		ribbon("Steam%d" % i, x, sy - 2, pop, L - swell, rng, 0.9)
	var bubbles := shape("Bubbles", load("res://addons/pixelfx_particles/fx/nature/_tar_bubbles.gdshader"), Vector2(112, 36),
		common.merged({"count": 8.0, "ba": ba, "bb": bb}), {"at": Vector2(0, -8)})
	loop_t(bubbles)
	root.move_child(bubbles, pool_light.get_index() + 1)

	# a steady breath of vapour ribbons off the whole pool
	var vr := RandomNumberGenerator.new()
	vr.seed = int(seed_) * 13 + 4
	for i in 9:
		var born := vr.randf() * D
		var L := vr.randf_range(2.4, 3.4)
		var x := roundf(vr.randf_range(-0.85, 0.85) * W)
		ribbon("Vapour%d" % i, x, surf(x, born) - 1, born, L, vr, 0.75)
