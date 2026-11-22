# reimagined-from: src/fx/status/haste.js@d2aed910ebdf4925e2bbd2568af5aa6d049e88d6
# Haste: Sped up: striped after-images stream out behind, speed lines whip past, dust kicks off the heels and the leading edge catches the wind. Faces right.
# loop, 1.20 s, 100x56 canvas, origin [64.0, 48.0], backdrop ground, stand-in 2
# ramp palette: #4c25ab #773ae4 #5b6cff #5eb0ff #a3dcff #ccf6ff #ffffff
# Three after-images trail back (drawn here from the stand-in's shape and shading: an outline, colder and more
# broken further back, cut into stripes; the stripes scroll through a strip of frames, the images jitter on the
# original's dice). Emitters do the rest: a smear streaming off the trailing edge, speed lines whipping past behind
# and in front (a streak texture drawn here: bright head, dotted tail), dust rolling off the heels (soft), and the
# leading edge flickering bright (particles on the outline's right-hand pixels).
extends "res://build/fx/status/_status.gd"


func make() -> void:
	var D: float = root.duration
	var C := fit("palette", 7)
	var S := shape_of()

	# ---- the after-images
	var every := [0, 3, 4, 0]
	for g in [3, 2, 1]:
		var n: int = maxi(1, every[g])
		var strip := Image.create((AW + 2) * n, AH + 2, false, Image.FORMAT_RGBA8)
		strip.fill(Color(0, 0, 0, 0))
		for ph in n:
			var img := outline_image(func(mx: int, my: int) -> Color: return Color(0, 0, 0, 0) if (g == 3 and posmod(mx + my, 2) == 1) else C[5 - g])
			if every[g] > 0:
				for q in S.body:
					if posmod(q.y + ph, every[g]) != 0:
						continue
					var v := luma(col_at(q.x, q.y))
					var lv := 1 if v < 0.24 else (2 if v < 0.66 else 3)
					img.set_pixel(q.x + 1, q.y + 1, C[clampi(5 - g + lv - 2, 0, 6)])
			strip.blit_rect(img, Rect2i(0, 0, AW + 2, AH + 2), Vector2i(ph * (AW + 2), 0))
		var im := sprite("After%d" % g, asset("_after%d" % g, strip), {"centered": false, "back": true, "hframes": n})
		var gl := glow("AfterLight%d" % g, 18, {"radius": 16.0, "color": C[3], "alpha": 0.12 * (1.0 - g * 0.25)})
		var pos := []
		var fr := []
		var gp := []
		for t in frame_times():
			var f := int(roundf(t * 30.0))
			var dx: int = -g * 14 - int(jround(jrand([f >> 1, g, 3]) * 1.6))
			pos.append([t, Vector2(AX + dx - 1, AY - 1)])
			fr.append([t, posmod(f, n)])
			gp.append([t, Vector2(AX + AW / 2.0 + dx, AY + AH * 0.45)])
		key(im, "position", pos, "nearest")
		if n > 1:
			key(im, "frame", fr, "nearest")
		key(gl, "position", gp, "nearest")

	# ---- a smear streaming off the trailing edge
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for s in S.side:
		if s[2] < 0:
			left.append(apos(s[0] - 0.5, s[1] + 0.5))
		else:
			right.append(apos(s[0] + 0.5, s[1] + 0.5))
	particles("Smear", {"back": true, "amount": 40, "lifetime": 0.12, "life_random": 0.5, "texture": "dot1", "emit": {"points": left},
		"dir": 180, "speed": [25, 75], "ramp": gradient([C[5], C[4]], [0.0, 0.35]), "alpha_curve": [[0, 1], [1, 0.15]]})

	# ---- speed lines: a bright head, a coloured body, a dotted tail thinning out behind
	var L := 22
	var streak := Image.create(L, 1, false, Image.FORMAT_RGBA8)
	streak.fill(Color(0, 0, 0, 0))
	for d in L:
		if d > L * 0.45 and d % 2:
			continue
		var c := C[6] if d < 2 else (C[5] if d < L * 0.4 else C[3])
		streak.set_pixel(d, 0, Color(c, minf(1.0, (1.0 - d / float(L)) * 1.1)))
	var tex := asset("_streak", streak)
	for c in [C[3], C[5], C[6]]:
		keep_colour(c)
	var mid := AY + AH / 2.0
	var lines := {"at": Vector2(-5 + L / 2.0, mid - 0.5), "amount": 3, "lifetime": 0.24, "life_random": 0.5, "texture": tex,
		"emit": {"box": Vector2(9, AH / 2.0 - 2.5)}, "dir": 180, "speed": [160, 240], "scale": [0.55, 1.15],
		"alpha_curve": [[0, 1], [1, 0.0]], "back": true}
	var lb := particles("LinesBack", lines)
	twin(lb, {"modulate": Color(C[4], 0.3), "texture": "glow8"})
	var lf := lines.duplicate()
	lf.back = false
	lf.amount = 1
	lf.scale = [0.4, 0.8]
	lf.modulate = Color(1, 1, 1, 0.7)
	particles("LinesFront", lf)

	# ---- dust kicked off the heels, rolling away behind
	var dust := Color(meta.options.dust)
	keep_colour(dust)
	for foot in [-7.0, 3.0]:
		particles("Dust%d" % int(foot), {"layer": "soft", "back": true, "at": Vector2(foot, -1.5), "amount": 3, "lifetime": 0.6, "life_random": 0.3,
			"texture": "disc7", "dir": 188, "spread": 6, "speed": [50, 100], "drag": 3.5, "color": dust,
			"scale_curve": [[0, 0.6], [1, 1.9]], "alpha_curve": [[0, 0.0], [0.1, 0.55], [1, 0.0]]})

	# ---- the leading edge catches the wind: a bright rim, flickering
	particles("Rim", {"amount": 90, "lifetime": 0.07, "texture": "dot1", "emit": {"points": right}, "speed": [0, 0],
		"initial": gradient([C[5], C[5], C[5], C[6]])})

	# ---- a cool glow streaming off the back
	glow("BackLight", 24, {"radius": 22.0, "color": C[3], "alpha": 0.16}, {"at": Vector2(-6, AY + AH * 0.5)})
	glow("BodyLight", 32, {"radius": 30.0, "color": C[3], "alpha": 0.16}, {"at": Vector2(0, AY + AH * 0.45)})
	var front := glow("FrontLight", 12, {"radius": 10.0, "color": C[5], "alpha": 0.12}, {"at": Vector2(AX + AW, AY + AH * 0.5)})
	sample(front, "material:shader_parameter/alpha", func(t: float) -> float: return 0.12 + 0.06 * sin(t / D * TAU * 3.0), "linear")
