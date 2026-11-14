# reimagined-from: src/fx/holy/halo.js@cd89a1b1703a0a88a94bd76d18577d657bff8c50
# Halo: A ring of gold light floats over the head with a glint running round it; fine dust sifts down from it and the head catches its light.
# loop, 2.00 s, 56x80 canvas, origin [28.0, 70.0], backdrop ground
# ramp palette: #3b1d2a #7a3a2c #c4652e #f0a040 #ffd25e #fff0a0 #fffbe0 #ffffff
# The ring is a shader (fx/holy/_halo.gdshader: thick near side, thin far side, shimmer, the hot stretch) bobbing a
# pixel with its glows; the glint that runs round it is the original's sparkle keyed along the ellipse with its
# light; the hair that catches the light is drawn at build time from the stand-in's own pixels (a warm rim and
# light falling off below it); little stars wink about the ring (particles stepping through the sparkle) and dust
# sifts down off it (particles from the ring's own points, each with a light twin).
extends "res://build/fx/holy/_holy.gd"

const HY := -46.0
const RX := 9.5
const RY := 2.6


func make() -> void:
	var T: float = meta.duration
	var ph := func(t: float) -> float: return t / T * TAU
	var bob := func(t: float) -> Vector2: return Vector2(0, HY + (-1.0 if sin(ph.call(t)) > 0.55 else 0.0))

	# the hair under it catches the light
	var img: Image = load(EFFECT.STAND_INS[maxi(1, root.actor)]).get_image()
	var w := img.get_width()
	var h := img.get_height()
	var rim := Image.create(w, 16, false, Image.FORMAT_RGBA8)
	var lit := Image.create(w, 16, false, Image.FORMAT_RGBA8)
	for i in w:
		for j in mini(h, 9):
			var c := img.get_pixel(i, j)
			if c.a < 0.5 or c.get_luminance() < 0.15:
				continue
			rim.set_pixel(i, j, Color(c.lerp(C[6], 0.45), 1.0))
			var c2 := img.get_pixel(i, j + 1)
			if c2.a >= 0.5 and c2.get_luminance() >= 0.15:
				rim.set_pixel(i, j + 1, Color(c2.lerp(C[5], 0.18), 1.0))
			for d in 5:
				lit.set_pixel(i, j + d, Color(C[4], 0.3 * (1.0 - d / 5.0)))
			break
	var top := Vector2(-floorf(w / 2.0), -h)
	sprite("HairRim", asset("rim.png", rim), {"centered": false, "at": top, "layer": "prop"})
	sprite("HairLight", asset("hairlight.png", lit), {"centered": false, "at": top, "layer": "light"})

	# the ring and its glows, bobbing a pixel
	var halo := group("Halo", {"at": Vector2(0, HY)})
	keyn(halo, "position", bob)
	var ring_far := shape("Ring", holy_shader("halo"), Vector2(24, 10), {"rx": RX, "ry": RY, "pal": C}, {"parent": halo})
	key(ring_far, "material:shader_parameter/ph", [[0.0, 0.0], [T, TAU]])
	glow("Glow", 22, {"radius": 20, "color": C[4], "alpha": 0.4}, {"parent": halo})
	glow("GlowWhite", 11, {"radius": 9, "color": Color.WHITE, "alpha": 0.16}, {"parent": halo, "at": Vector2(0, 1)})
	shape("Fall", holy_shader("smite_glowseg"), Vector2(22, 30), {"a": Vector2(0, 2), "b": Vector2(0, 9), "radius": 9.0, "color": C[4], "k": 0.16},
		{"parent": halo, "at": Vector2(0, 5)})

	# the glint running round it
	var gl := func(t: float) -> float: return PI / 2.0 + ph.call(t)
	var gpos := func(t: float) -> Vector2: return Vector2(cos(gl.call(t)) * RX, sin(gl.call(t)) * RY) + bob.call(t)
	var glint := sparkle("Glint", Vector2.ZERO, 0.0, Color.WHITE, C[6])
	keyn(glint, "position", func(t: float) -> Vector2: return (gpos.call(t) + Vector2(0, 0.5)).floor() + Vector2(0.5, 0.5))
	var arm := func(t: float) -> float: return roundf(1.5 + 2.5 * maxf(0.0, sin(gl.call(t)))) if sin(gl.call(t)) > -0.2 else 0.0
	keyn(glint, "material:shader_parameter/arm", arm)
	var gll := glow("GlintLight", 14, {"radius": 8, "color": Color.WHITE, "alpha": 0.0})
	keyn(gll, "position", gpos)
	keyn(gll, "material:shader_parameter/radius", func(t: float) -> float: return 4.0 + 2.0 * arm.call(t) if arm.call(t) > 0.0 else 5.0)
	keyn(gll, "material:shader_parameter/alpha", func(t: float) -> float: return 0.45 if arm.call(t) > 0.0 else 0.3)
	keyn(gll, "material:shader_parameter/color", func(t: float) -> Color: return Color.WHITE if arm.call(t) > 0.0 else C[6])

	# little stars wink on and off about the ring
	var around := PackedVector2Array()
	var on_ring := PackedVector2Array()
	for j in 64:
		var g := j / 64.0 * TAU
		around.append(Vector2(cos(g) * RX * 1.3, HY + sin(g) * RY * 1.3 - 2.5))
		on_ring.append(Vector2(cos(g) * RX * 0.9, HY + sin(g) * RY + 1.0))
	var NF := 9
	var stars := particles("Stars", {"amount": 2, "lifetime": 0.5, "life_random": 0.4, "emit": {"points": around},
		"alpha_curve": [[0.0, 0.0], [0.5, 1.0], [1.0, 0.0]], "texture": asset("star.png", sparkle_strip(NF, func(u: float) -> float: return 1.0 + 2.0 * sin(u * PI), Color.WHITE, C[6], 3))})
	flip(stars, NF)
	stars.process_material.anim_speed_min = 1.0
	twin(stars, {"texture": "glow16", "modulate": Color(1, 1, 1, 0.4), "scale": 0.7})

	# dust sifting down off the ring, twinkling
	var dust := particles("Dust", {"amount": 9, "lifetime": 1.5, "life_random": 0.45, "emit": {"points": on_ring},
		"dir": 90, "spread": 6, "speed": [6, 11], "texture": "dot1",
		"ramp": gradient([Color(C[6], 0.0), C[6], Color.WHITE, C[6], Color.WHITE, C[6], Color(C[6], 0.0)], [0.0, 0.12, 0.3, 0.38, 0.6, 0.68, 0.9])})
	twin(dust, {"modulate": Color(C[5], 0.5)})
