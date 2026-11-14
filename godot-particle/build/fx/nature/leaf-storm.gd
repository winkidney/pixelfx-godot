# reimagined-from: src/fx/nature/leaf-storm.js@1921a4a3e6c544d875655b2d1b84281e9c93e370
# Leaf storm: Leaves tumble up a rising spiral round the character, passing behind and in front, turning and
# flipping, wrapped in bright bands of wind; litter swirls at their feet.
# Leaves are particles riding the original's spiral (a particle process shader of our own, fx/nature/_spiral.gdshader:
# each leaf's angle, height and radius as the original lays them out, tumbling and flipping through edge-on), three
# palettes, each a pair of emitters: one behind the character showing the far half of every turn, one in front
# showing the near half. The leaves are drawn the way the original draws them (build-time textures). The wind bands
# and the scuffs on the floor are a shader (fx/nature/_leafwind.gdshader) with the original's own bands (its seeded
# numbers, build/fx/nature/_lib_wind.gd), far halves behind, near halves in front; litter swirls round the feet as
# soft discs on the same spiral shader; two dim glows.
# loop, 2.40 s, 112x104 canvas, origin [56, 92], backdrop ground, stand-in 2
extends "res://addons/pixelfx_particles/core/build.gd"

const N := preload("res://build/fx/nature/_lib.gd")
const W := preload("res://build/fx/nature/_lib_wind.gd")
const SPIRAL := preload("res://addons/pixelfx_particles/fx/nature/_spiral.gdshader")
const WIND := preload("res://addons/pixelfx_particles/fx/nature/_leafwind.gdshader")
const SEED := 5
const TOP := 64.0


static func ring_r(y: float) -> float:
	return 15.0 + 9.0 * clampf(-y / TOP, 0.0, 1.0)


## Two emitters (behind, in front) running the spiral shader with the same numbers: every particle shows on one.
func pair(name: String, amount: int, tex_back: Texture2D, tex_front: Texture2D, layer: String, params: Dictionary) -> Array:
	var out := []
	for s in [-1.0, 1.0]:
		var p := particles(name + ("Back" if s < 0 else "Front"), {"amount": amount, "lifetime": meta.duration,
			"texture": tex_back if s < 0 else tex_front, "local": true, "back": s < 0, "layer": layer})
		var m := ShaderMaterial.new()
		m.shader = SPIRAL
		m.set_shader_parameter("side", s)
		for k in params:
			var v: Variant = params[k]
			m.set_shader_parameter(k, float(v) if v is int and k != "mode" else v)
		p.process_material = m
		out.append(p)
	return out


func make() -> void:
	var C: PackedColorArray = root.ramps.palette
	var L: PackedColorArray = root.ramps.leaves
	keep_colour(Color.WHITE)

	glow("Air", 48, {"radius": 46, "color": C[4], "alpha": 0.12}, {"at": Vector2(0, -30)})
	glow("Feet", 28, {"radius": 26, "color": L[2], "alpha": 0.12}, {"at": Vector2(0, -2)})

	# the wind: the original's 16 bands (rng(seed * 5 + 2, j)) and 6 scuffs on the floor (rng(seed * 3 + 1 + 9, j))
	var ba := PackedVector4Array()
	var bb := PackedVector4Array()
	for j in 16:
		var R := W.rng([SEED * 5 + 2, j])
		var y0 := -R.range(4, TOP - 4)
		var r := ring_r(y0) * R.range(1.0, 1.25)
		var K := R.int_(2, 3)
		var span := R.range(1.1, 2.4)
		var head := R.range(0, TAU)
		var rise := R.range(-0.18, 0.18)
		ba.append(Vector4(y0, r, head, span))
		bb.append(Vector4(K, rise, 0.3, 0))
	for j in 6:
		var R := W.rng([SEED * 3 + 1 + 9, j])
		var rr := R.range(12, 24)
		var th0 := R.range(0, TAU)
		var span := R.range(0.5, 1.0)
		ba.append(Vector4(0.5, rr, th0, span))
		bb.append(Vector4(3, 0, 0.2, 1))
	for s in [-1.0, 1.0]:
		var w := shape("Wind" + ("Back" if s < 0 else "Front"), WIND, Vector2(76, 90), {"t": 0.0, "side": s,
			"band_a": ba, "band_b": bb, "count": 22, "c2": C[2], "c3": C[3], "c4": C[4], "c5": C[5], "translucent": true},
			{"at": Vector2(0, -32), "back": s < 0})
		loop_t(w)
	var heads := shape("WindLight", load("res://addons/pixelfx_particles/fx/nature/_leafwind_glow.gdshader"), Vector2(76, 90),
		{"t": 0.0, "band_a": ba, "band_b": bb, "count": 22, "color": C[4], "alpha": 0.25}, {"at": Vector2(0, -32)})
	loop_t(heads)

	# litter swirled round the feet
	pair("Litter", 14, N.disc(3.5, C[2]), N.disc(3.5, C[3]), "soft",
		{"mode": 1, "seed": 3.0, "life_min": 0.6, "life_max": 1.1, "tex_size": Vector2(3.5, 3.5)})
	# the leaves: green, gold, red; the far side a step darker
	var counts := [10, 9, 9]
	for o in 3:
		var b := o * 4
		var front := N.leaf(8, 2.8, 0.0, [L[b], L[b + 1], L[b + 2], L[b + 3]])
		var back := N.leaf(8, 2.8, 0.0, [L[b], L[b], L[b + 1], L[b + 2]])
		var lp := {"mode": 0, "seed": 11.0 + o * 7.0, "life_min": 1.5, "life_max": 2.3, "tex_size": Vector2(8, 2.8),
			"len_range": Vector2(6.5, 9), "wid_range": Vector2(2.4, 3.3)}
		pair("Leaves%d" % o, counts[o], back, front, "color", lp)
		# a glint as it turns face on to the light: a white pixel and a little light
		for g in [["Glint", "dot1", "color", 1.0, Color.WHITE], ["GlintLight", "glow16", "light", 0.6, Color(L[b + 3], 0.35)]]:
			var q := particles("%s%d" % [g[0], o], {"amount": counts[o], "lifetime": meta.duration, "texture": g[1], "local": true, "layer": g[2]})
			var m := ShaderMaterial.new()
			m.shader = SPIRAL
			var gp := lp.duplicate()
			gp.merge({"side": 1.0, "glint": g[3], "tint": g[4]}, true)
			for k in gp:
				m.set_shader_parameter(k, gp[k])
			q.process_material = m
