# reimagined-from: src/fx/holy/divine-shield.js@0fb54d67ab10c4b06c3255562c441a709480fbe2
# Divine shield: A bubble of gold light round the character: a bright rim and a thin gold film, meridians turning like a slow globe, a sheen sweeping across and sparkles winking on it.
# loop, 2.40 s, 88x84 canvas, origin [44.0, 68.0], backdrop ground
# ramp palette: #3b1d2a #7a3a2c #c4652e #f0a040 #ffd25e #fff0a0 #fffbe0 #ffffff
# The bubble is one shader on the soft layer (fx/holy/_shield.gdshader), once behind the character (the far half:
# film, faint lattice, the far half of the floor seal) and once in front (film, lattice, rim, shine, lit crossings,
# the near seal); it finds the lattice by casting each pixel back onto the turning sphere. Its light is
# fx/holy/_shield_light.gdshader plus a 1 px light round the character (drawn at build time from the stand-in). The
# pole's sparkle and the two glints chasing round the rim are the original's sparkle, keyed; sparkles winking on
# the skin and motes rising inside are particles with light twins.
extends "res://build/fx/holy/_holy.gd"

const CY := -22.0
const TILT := 0.34


func make() -> void:
	var T: float = meta.duration
	var r: float = meta.options.radius
	var sz := Vector2(2 * r + 8, 2 * r + 8)
	var at := Vector2(0, CY)
	var far := shape("BubbleFar", holy_shader("shield"), sz, {"r": r, "cy": CY, "back": true, "pal": C, "translucent": true}, {"at": at, "back": true})
	loop_t(far)
	var near := shape("BubbleNear", holy_shader("shield"), sz, {"r": r, "cy": CY, "back": false, "pal": C, "translucent": true}, {"at": at})
	loop_t(near)
	var lg := shape("BubbleLight", holy_shader("shield_light"), sz + Vector2(16, 16), {"r": r, "cy": CY, "pal": C}, {"at": at})
	loop_t(lg)

	# the bubble lights the character from all round: the 1 px ring just outside the silhouette
	var img: Image = load(EFFECT.STAND_INS[maxi(1, root.actor)]).get_image()
	var w := img.get_width()
	var h := img.get_height()
	var out := Image.create(w + 2, h + 2, false, Image.FORMAT_RGBA8)
	var inside := func(i: int, j: int) -> bool: return i >= 0 and j >= 0 and i < w and j < h and img.get_pixel(i, j).a >= 0.5
	for j in range(-1, h + 1):
		for i in range(-1, w + 1):
			if not inside.call(i, j) and (inside.call(i - 1, j) or inside.call(i + 1, j) or inside.call(i, j - 1) or inside.call(i, j + 1)):
				out.set_pixel(i + 1, j + 1, Color(C[5], 0.3))
	sprite("BodyRim", asset("rim.png", out), {"centered": false, "at": Vector2(-floorf(w / 2.0) - 1, -h - 1), "layer": "light"})

	# the pole, where the meridians all turn round, and two glints chasing each other round the rim
	var pole := Vector2(0, CY - r * cos(TILT))
	var ps := sparkle("Pole", pole, 3, Color.WHITE, C[6])
	var parm := func(t: float) -> float: return 2.0 + roundf(1.5 + 1.5 * sin(t / T * TAU * 2.0))
	keyn(ps, "material:shader_parameter/arm", parm)
	var pl := glow("PoleLight", 16, {"radius": 12, "color": Color.WHITE, "alpha": 0.45}, {"at": pole})
	keyn(pl, "material:shader_parameter/radius", func(t: float) -> float: return 4.0 + 2.0 * parm.call(t))
	var i := 0
	for off in [0.0, PI]:
		var gp := func(t: float) -> Vector2:
			var g: float = t / T * TAU + off + 0.8
			return Vector2(cos(g) * r, CY + sin(g) * r)
		var gs := sparkle("Glint%d" % i, Vector2.ZERO, 2, Color.WHITE, C[6])
		keyn(gs, "position", func(t: float) -> Vector2: return (gp.call(t) as Vector2).floor() + Vector2(0.5, 0.5))
		var gl := glow("GlintLight%d" % i, 9, {"radius": 8, "color": Color.WHITE, "alpha": 0.4})
		keyn(gl, "position", gp)
		i += 1

	# sparkles winking on its skin as it turns
	var NF := 9
	var winks := particles("Winks", {"at": at, "amount": 2, "lifetime": 0.6, "life_random": 0.4, "emit": {"circle": r * 0.85},
		"alpha_curve": [[0.0, 0.0], [0.5, 1.0], [1.0, 0.0]],
		"texture": asset("wink.png", sparkle_strip(NF, func(u: float) -> float: return 1.0 + 2.0 * sin(u * PI), Color.WHITE, C[6], 4))})
	flip(winks, NF)
	twin(winks, {"texture": "glow16", "modulate": Color(1, 1, 1, 0.45), "scale": 0.8})
	# motes rising inside
	var motes := particles("Motes", {"at": Vector2(0, CY + r * 0.6), "amount": 8, "lifetime": 2.0, "life_random": 0.4, "emit": {"box": Vector2(r * 0.55, 2)},
		"dir": -90, "speed": [17, 22], "texture": "dot1", "turbulence": {"strength": 1.0, "scale": 3.0, "influence": [0.01, 0.02]},
		"ramp": gradient([Color(C[6], 0.0), C[6], C[5], Color(C[5], 0.0)], [0.0, 0.2, 0.5, 0.85])})
	twin(motes, {"modulate": Color(C[5], 0.4)})
