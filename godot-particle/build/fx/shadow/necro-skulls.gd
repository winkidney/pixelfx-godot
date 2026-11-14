# reimagined-from: src/fx/shadow/necro-skulls.js@fbc8262598a79bd193eab4ecac05d60829065e91
# Necro skulls: Spectral skulls circle a cold green flame on a tilted orbit, passing behind and before it, eyes lit, trailing curls of ghost smoke.
# loop, 3.00 s, 136x116 canvas, origin [68.0, 108.0], backdrop ground
# ramp bone: #0c1a1c #2c4a4a #5c847c #a6cdb8 #e4fff0
# ramp palette: #040e10 #0a2228 #0f3d44 #16615f #23907f #45c4a0 #9af0c8 #e8fff4
# The cold flame is a canvas shader (fx/shadow/_necro-skulls_flame.gdshader: the original's noise-licked body in ramp
# steps, scrolling up once a loop) with a checkerboard light pass; five skulls (the original's sprite, drawn into a
# 3-frame texture at build time: far, near, near with white-hot eyes) ride the tilted orbit on keyed positions, each
# in a group whose z_index flips it behind or before the flame; each trails ghost smoke (a soft emitter riding with
# it) and carries its eye and body glows. Motes rise off the flame with light twins; the glows are the original's.
extends "res://build/fx/shadow/_shadow.gd"

const CY := -52.0
const FB := -32.0
const FH := 34.0
const RX := 42.0
const RY := 11.0
const TILT := -0.12
const D := 3.0
const N := 5
const SKULL := [
	"...kkkkk...",
	".kkhhhllkk.",
	"khhhhlllmmk",
	"khhllllllmk",
	"kleeeleeemk",
	"kleeeleeedk",
	"kmleelleedk",
	".kmllnllmk.",
	".kmmlnlmdk.",
	"..kmmmmmk..",
	"..ktgtgtk..",
	"...kkkkk...",
]


func skull_at(i: int, t: float) -> Dictionary:
	var a := TAU * t / D + i * TAU / N
	var ex := cos(a) * RX
	var ey := sin(a) * RY
	var bob := sin(TAU * 2.0 * t / D + i * 1.7) * 2.0
	return {"x": ex * cos(TILT) - ey * sin(TILT), "y": CY + ex * sin(TILT) + ey * cos(TILT) + bob, "z": sin(a)}


func eye_k(i: int, t: float) -> float:
	return (0.5 + 0.5 * sin(TAU * 3.0 * t / D + i * 2.1)) * 0.5 + 0.5


func skull_image() -> Image:
	var K: PackedColorArray = root.ramps.bone
	var pals := [
		{"k": K[0], "d": K[0], "m": K[1], "l": K[2], "h": K[3], "e": C[0], "n": C[0], "t": K[2], "g": K[0]},
		{"k": K[0], "d": K[1], "m": K[2], "l": K[3], "h": K[4], "e": C[0], "n": C[0], "t": K[3], "g": K[0]},
		{"k": K[0], "d": K[1], "m": K[2], "l": K[3], "h": K[4], "e": C[0], "n": C[0], "t": K[3], "g": K[0]},
	]
	var img := Image.create(33, 12, false, Image.FORMAT_RGBA8)
	for f in 3:
		for y in SKULL.size():
			var row: String = SKULL[y]
			for x in row.length():
				var ch := row[x]
				if ch != ".":
					img.set_pixel(f * 11 + x, y, pals[f][ch])
		for ex in [3, 7]:
			if f == 0:
				img.set_pixel(f * 11 + ex, 5, C[6])
			else:
				img.set_pixel(f * 11 + ex, 5, C[7] if f == 1 else Color.WHITE)
				img.set_pixel(f * 11 + ex, 4, C[5])
	keep_colour(Color.WHITE)
	return img


func make() -> void:
	# light under it all, then the flame's own
	glow("BackGlow", 41, {"radius": 40, "color": C[4], "alpha": 0.2}, {"at": Vector2(0, -1), "back": true})
	glow("FlameGlow", 41, {"radius": 40, "color": C[5], "alpha": 0.45}, {"at": Vector2(0, FB - FH * 0.35)})
	glow("HeartGlow", 13, {"radius": 12, "color": C[7], "alpha": 0.25}, {"at": Vector2(0, FB - 5)})
	glow("Halo", 47, {"radius": 46, "color": C[4], "alpha": 0.12}, {"at": Vector2(0, CY)})

	# motes and cold sparks rising off the flame, each with a little light of its own
	var mote := {"at": Vector2(0, FB - 6), "amount": 8, "lifetime": 1.4, "texture": "dot1", "emit": {"box": Vector2(6, 0.5)},
		"dir": -90, "spread": 5, "speed": [33, 50], "ramp": gradient([C[7], C[6]], [0.0, 0.5]),
		"alpha_curve": [[0, 1], [0.7, 1], [1, 0]], "turbulence": {"strength": 2.0, "scale": 3.0, "influence": [0.01, 0.02]}}
	var motes := particles("Motes", mote)
	life_rand(motes, 0.43)
	var ml := mote.duplicate()
	ml.layer = "light"
	ml.texture = "glow8"
	ml.modulate = Color(1, 1, 1, 0.3)
	var mote_light := particles("MoteLight", ml)
	life_rand(mote_light, 0.43)
	mote_light.seed = motes.seed

	# the cold flame
	var sz := Vector2(32, 44)
	var at := Vector2(0, FB - FH / 2.0 - 1.0)
	var params := {"fb": FB, "fh": FH, "w0": 10.0, "pal": C, "white": Color.WHITE}
	var fl := shape("Flame", shadow_shader("necro-skulls_flame"), sz, params, {"at": at})
	loop_t(fl)
	var fll := shape("FlameLight", shadow_shader("necro-skulls_flamelight"), sz, params, {"at": at})
	loop_t(fll)

	# the skulls, their ghost smoke and their light
	var tex := asset("skull.png", skull_image())
	for i in N:
		var g := group("Skull%d" % i)
		keyf(g, "position", func(t: float):
			var s := skull_at(i, t)
			return Vector2(roundf(s.x), roundf(s.y)), 0.0, D, 30.0, "nearest")
		keyf(g, "z_index", func(t: float): return 0 if skull_at(i, t).z >= 0.0 else -3, 0.0, D, 30.0, "nearest")
		var smoke := particles("Smoke", {"parent": g, "layer": "soft", "at": Vector2(0, 2), "amount": 8, "lifetime": 0.4,
			"texture": "disc11", "dir": -90, "speed": [17.5, 17.5], "scale_curve": [[0, 0.36], [1, 1.0]],
			"ramp": gradient([C[5], C[4], C[3]], [0.0, 0.4, 0.7]), "alpha_curve": [[0, 0.5], [1, 0.0]]})
		keyf(smoke, "modulate:a", func(t: float): return 0.6 + 0.4 * (skull_at(i, t).z + 1.0) / 2.0, 0.0, D, 15.0)
		var body := sprite("Body", tex, {"parent": g, "centered": false, "offset": Vector2(-5, -6), "hframes": 3})
		keyf(body, "frame", func(t: float):
			if skull_at(i, t).z < 0.0:
				return 0
			return 2 if eye_k(i, t) > 0.75 else 1, 0.0, D, 30.0, "nearest")
		for ex in [-1.0, 3.0]:
			var eg := glow("Eye%d" % int(ex + 1), 7, {"radius": 6, "color": C[5], "alpha": 0.3}, {"parent": g, "at": Vector2(ex, 0)})
			keyf(eg, "material:shader_parameter/alpha", func(t: float):
				return 0.45 * (0.55 + 0.45 * (skull_at(i, t).z + 1.0) / 2.0) * eye_k(i, t), 0.0, D, 30.0)
		var bg := glow("Glow", 12, {"radius": 11, "color": C[4], "alpha": 0.18}, {"parent": g})
		keyf(bg, "material:shader_parameter/alpha", func(t: float): return 0.18 * (0.55 + 0.45 * (skull_at(i, t).z + 1.0) / 2.0), 0.0, D, 15.0)
