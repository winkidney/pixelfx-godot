# reimagined-from: src/fx/shadow/black-hole.js@d2a0e717b21dbb38198a246bef8f5505f421137f
# Black hole: A tilted disk of banded rings turns round a black hole, its far side bent up over the top and under the bottom; debris spirals in, stretches and is swallowed.
# loop, 4.00 s, 184x132 canvas, origin [92.0, 124.0], backdrop ground
# ramp palette: #06040b #150c26 #2a1150 #461a84 #6f2cc0 #9d5cec #cfa6ff #f6eaff
# ramp rock: #120d1c #2e2440 #544468 #857399
# The disk, its bent far side, the shadow and the photon ring are a canvas shader (fx/shadow/_black-hole.gdshader)
# ray-traced as the original does, in its dithered ramp steps, off the loop's clock; a light pass gives the ring and
# the disk's hot streaks their light; the shadow is drawn again above the light layer (the original unlights it).
# Pebbles torn off the floor, motes streaking in and debris spiralling in (lumps lit on the side toward the hole,
# stretched into hot streaks, gone in a flash at the ring) are GPU particles on a process shader of our own
# (_black-hole_bits.gdshader) that places each one where the original's cycle() does; a light twin rides each.
# Glows: the bloom behind, the halo hugging the hole, breathing with the gulp twice a loop.
extends "res://build/fx/shadow/_shadow.gd"

const BITS := "res://addons/pixelfx_particles/fx/shadow/_black-hole_bits.gdshader"
const Y := -70.0
const RS := 13.5
const D := 4.0
const S := 4


static func pulse(t: float) -> float:
	return pow(maxf(0.0, cos(TAU * 2.0 * t / D)), 12.0)


## One part of the original's particles (see _black-hole_bits.gdshader): `count` slots, placed from the loop clock.
func bits(name: String, mode: int, part: int, count: int, seed_: int, params: Dictionary, o: Dictionary = {}) -> GPUParticles2D:
	var pp := {"mode": mode, "part": part, "seed": seed_, "col": Color.WHITE, "col2": Color.WHITE}
	pp.merge(params, true)
	var oo := {"amount": count, "lifetime": D, "explosiveness": 1.0, "local": true, "texture": "dot1",
		"process_shader": BITS, "process_params": pp}
	oo.merge(o, true)
	var p := particles(name, oo)
	var m: ShaderMaterial = p.process_material
	for k in ["mode", "part", "seed"]:
		m.set_shader_parameter(k, int(pp[k]))
	for k in pp:
		if pp[k] is Color and o.get("layer", "color") != "light":
			keep_colour(pp[k])
	p.interpolate = false
	key(p, "process_material:shader_parameter/t", [[0.0, 0.0], [D, 1.0]])
	return p


func img(rows: Array, cols: Dictionary) -> Image:
	var im := Image.create(rows[0].length(), rows.size(), false, Image.FORMAT_RGBA8)
	for y in rows.size():
		for x in rows[y].length():
			var ch: String = rows[y][x]
			im.set_pixel(x, y, cols[ch] if cols.has(ch) else Color(0, 0, 0, 0))
	return im


func make() -> void:
	var K: PackedColorArray = root.ramps.rock
	var white := Color.WHITE
	var ice := Color("#e4f7ff")
	keep_colour(white)
	keep_colour(ice)
	# the in-between colours the disk mixes: ice over its hot steps on the near side, C[3] over the receding side
	for c in [C[6], C[7], white]:
		for m in [0.33, 0.67]:
			keep_colour(c.lerp(ice, m))
	for c in [C[4], C[5], C[6]]:
		keep_colour(c.lerp(C[3], 0.35))

	# light behind: a pool on the floor, the violet bloom round the hole
	glow("FloorGlow", 46, {"radius": 44, "color": C[4], "alpha": 0.12}, {"at": Vector2(0, -1)})
	glow("Bloom", 82, {"radius": 80, "color": C[4], "alpha": 0.32}, {"at": Vector2(0, Y)})
	glow("Bloom2", 48, {"radius": 46, "color": C[6].lerp(C[5], 0.5), "alpha": 0.45}, {"at": Vector2(0, Y)})

	# pebbles torn off the floor, rising to join the disk (under the disk)
	bits("Pebbles", 2, 0, 10, S + 3, {"col": K[2], "col2": K[3]})
	bits("PebbleDust", 2, 1, 10, S + 3, {"col": K[2], "tex": 13.0}, {"texture": "disc13", "layer": "soft"})

	# the disk, the bent far side, the photon ring
	var pal := [C[0], C[1], C[2], C[3], C[4], C[5], C[6], C[7], white, ice]
	var sz := Vector2(128, 88)
	var hole := shape("Hole", shadow_shader("black-hole"), sz, {"pal": pal}, {"at": Vector2(0, Y)})
	loop_t(hole)
	var hole_light := shape("HoleLight", shadow_shader("black-hole_light"), sz, {"pal": pal}, {"at": Vector2(0, Y)})
	loop_t(hole_light)

	# motes streaking in from all round, a line from where each was a moment ago, its head in its own colour
	var picks := [white, C[7], C[6], C[5]]
	bits("MoteTail", 0, 0, 40, S + 7, {"col": C[4], "pick": picks})
	bits("MoteHead", 0, 1, 40, S + 7, {"pick": picks})
	bits("MoteLight", 0, 2, 40, S + 7, {"pick": picks, "tex": 16.0}, {"texture": "glow16", "layer": "light"})

	# debris spiralling in: lumps with a wake, lit toward the hole; hot streaks; a flash at the ring
	var small := asset("lump2", img(["ab", "b."], {"a": K[2], "b": K[1]}))
	var big := asset("lump3", img([".a.", "bab", ".bc"], {"a": K[2], "b": K[1], "c": K[0]}))
	for c in [K[0], K[1], K[2]]:
		keep_colour(c)
	bits("Wake3", 1, 5, 22, S, {"col": C[2]})
	bits("Wake2", 1, 4, 22, S, {"col": C[3]})
	bits("Wake1", 1, 3, 22, S, {"col": C[3]})
	bits("LumpSmall", 1, 0, 22, S, {}, {"texture": small})
	bits("LumpBig", 1, 1, 22, S, {}, {"texture": big})
	bits("LumpLit", 1, 2, 22, S, {"col": C[5], "col2": C[6]})
	bits("Streak", 1, 6, 22, S, {"col": C[4]})
	bits("StreakMid", 1, 7, 22, S, {"col": C[6]})
	bits("StreakHot", 1, 8, 22, S, {"col": white})
	bits("Flash", 1, 9, 22, S, {"col": white})
	bits("DebrisLight", 1, 10, 22, S, {"col": C[5], "col2": C[6], "tex": 16.0}, {"texture": "glow16", "layer": "light"})

	# the halo hugging the hole, swelling with each gulp
	var hl := halo("Halo", Vector2(0, Y), RS + 6, RS - 0.4, RS + 4, C[6], 0.35)
	keyf(hl, "material:shader_parameter/k", func(t: float): return 0.35 + 0.3 * pulse(t))

	# the shadow again, above the light (the original unlights it)
	var shadow := shape("Shadow", shadow_shader("black-hole"), Vector2(32, 32), {"pal": pal, "mode": 1.0}, {"at": Vector2(0, Y)})
	loop_t(shadow)
	over_light(shadow)
