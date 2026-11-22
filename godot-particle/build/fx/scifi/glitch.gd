# reimagined-from: src/fx/scifi/glitch.js@55da9344b2f859b41d3970892c50d8daec636bf6
# Glitch: The hero's signal breaks up in bursts: an RGB split, slices torn sideways, rows smeared out, junk blocks and dead pixels, then snaps back clean.
# loop, 2.40 s, 88x64 canvas, origin [44.0, 54.0], backdrop ground, stand-in 2
# The original draws the hero itself, clean or broken, so the stand-in (the effect's Actor) is hidden and a shader
# (fx/scifi/_glitch.gdshader) redraws its pixels each frame from that frame's corruption, rolled here from the
# original's rand(seed, frame, ...): the RGB split's ghosts, torn and tinted rows, interlace, roll, posterise, the
# calm bar rolling down, smears, junk blocks. The dead pixels a burst throws off are particles (_ghost.gdshader,
# PIXEL: stepping a frame at a time, blinking out); the split's coloured light, the burst's flash and the bar's glow
# are keyed glows.
extends "res://build/fx/scifi/_scifi.gd"

const FPS := 30
const BURSTS := [[9, 16, 0.8], [33, 37, 0.5], [51, 62, 1.0]]
const S := 7

var AX := -12
var AY := -38
var AW := 24
var AH := 38


func burst_of(f: int) -> Array:
	for b in BURSTS:
		if f >= b[0] and f <= b[1]:
			return b
	return []


func make() -> void:
	C = fit(C, 7)
	var tex: Texture2D = load(EFFECT.STAND_INS[2])
	var img := tex.get_image()
	AW = img.get_width()
	AH = img.get_height()
	AX = -int(floor(AW / 2.0))
	AY = -AH
	var NF := int(round(root.duration * FPS))
	var RED := C[2]
	var CYAN := C[4]
	# the colours the original mixes: torn rows tinted, the bar's tint, the roll's darkened repeat
	for y in AH:
		for x in AW:
			var pc := img.get_pixel(x, y)
			if pc.a < 0.5:
				continue
			var c := Color(pc.r, pc.g, pc.b)
			keep_colour(c)
			keep_colour(mixc(c, RED, 0.6))
			keep_colour(mixc(c, CYAN, 0.6))
			keep_colour(mixc(c, C[5], 0.35))
			keep_colour(mixc(c, C[1], 0.5))

	# the hero stays as the effect's own node, hidden: the shader draws it
	var body := actor_node()
	body.self_modulate = Color(1, 1, 1, 0)

	# each frame's corruption, as the original rolls it
	var data := Image.create(NF, 64, false, Image.FORMAT_RGBAF)
	var splits := []
	var ks := []
	for f in NF:
		var t := f / float(FPS)
		var b := burst_of(f)
		var k: float = b[2] if b.size() else 0.0
		var r := func(n: Array) -> float: return rand([S, f] + n)
		var split := 0
		if b.size():
			split = int(floor(1.0 + r.call([1]) * 3.0 * k + 0.5)) * (-1 if r.call([2]) < 0.5 else 1)
		var tears := []
		if b.size():
			for i in 1 + int(floor(r.call([3]) * 4.0 * k)):
				tears.append([AY + int(floor(r.call([4, i]) * AH)), 1 + int(floor(r.call([5, i]) * 5.0)), int(floor((r.call([6, i]) - 0.5) * 16.0 * k + 0.5)), r.call([7, i])])
		if not b.size() and r.call([8]) < 0.07:
			tears.append([AY + int(floor(r.call([9]) * AH)), 1, -2 if r.call([10]) < 0.5 else 2, 1.0])
		var interlace: bool = b.size() > 0 and r.call([11]) < 0.3
		var roll := 0
		if b.size() and r.call([12]) < 0.15:
			roll = -2 - int(floor(r.call([13]) * 2.0))
		var poster: bool = b.size() > 0 and r.call([14]) < 0.15 * k
		var bar: float = AY + fposmod((t / root.duration) * 2.0 * (AH + 12), AH + 12) - 6.0
		data.set_pixel(f, 0, Color(split, roll, 1.0 if interlace else 0.0, 1.0 if poster else 0.0))
		for my in AH:
			var ry := AY + my
			var tr: Array = []
			for q in tears:
				if ry >= q[0] and ry < q[0] + q[1]:
					tr = q
					break
			var dx: int = tr[2] if tr.size() else 0
			var tint := 0
			if tr.size() and tr[3] < 0.35:
				tint = 1 if tr[3] < 0.18 else 2
			var smear := 0
			if tr.size() and absi(dx) > 2 and rand([S, f, ry]) < 0.6:
				smear = 4 + int(floor(rand([S, f, ry, 1]) * 10.0))
			data.set_pixel(f, 2 + my, Color(dx, tint, smear, 0.0))
		var nj := 0
		if b.size():
			nj = 2 + int(floor(r.call([20]) * 5.0 * k))
			for i in nj:
				var w := 2 + int(floor(r.call([21, i]) * 9.0))
				var h := 1 + int(floor(r.call([22, i]) * 3.0))
				var x := AX - 6 + int(floor(r.call([23, i]) * (AW + 12)))
				var y := AY + int(floor(r.call([24, i]) * AH))
				var ci: int = [6, 2, 4, 5, 3][int(floor(r.call([25, i]) * 5.0))]
				data.set_pixel(f, 48 + i, Color(x, y, w, h))
				data.set_pixel(f, 56 + i, Color(ci, 1.0 if r.call([26, i]) < 0.4 else 0.0, 0.0, 0.0))
		data.set_pixel(f, 1, Color(bar, nj, 0.0, 0.0))
		splits.append(split)
		ks.append(k)

	var canvas := Vector2(root.canvas_size)
	var at := -Vector2(root.origin) + canvas / 2.0
	var hero := shape("Hero", sh("glitch"), canvas, {"tex": tex, "data": asset("_glitch_data", data), "frame": 0.0, "pal": C}, {"at": at})
	frames_key(hero, "material:shader_parameter/frame", func(t: float) -> float: return float(int(floor(t * FPS + 1e-6)) % NF))

	# dead pixels thrown off by a burst, drifting and blinking out
	ghosts_begin(root.duration)
	for bb in BURSTS:
		var a: int = bb[0]
		for i in int(ceil(10.0 * bb[2])):
			if i >= 10.0 * bb[2]:
				break
			var life := 4 + int(floor(rand([S, a, i]) * 6.0))
			var at_f := int(floor(rand([S, a, i, 1]) * (bb[1] - a + 1)))
			var x0: float = AX + rand([S, a, i, 2]) * AW
			var y0: float = AY + rand([S, a, i, 3]) * AH
			var side := -1.0 if rand([S, a, i, 4]) < 0.5 else 1.0
			var sp := 1.0 + rand([S, a, i, 5]) * 2.0
			ghost((a + at_f) / float(FPS), PIXEL, x0, y0, side * sp, -0.5, (life + 0.5) / FPS, [Color.WHITE, RED, CYAN][i % 3], 1.0, 0, {"frames": float(life), "layer": "front"})
	ghosts()

	# light: a cold flicker on a burst's first frame, the split's colours glowing either side, the bar's glow
	var mid := Vector2(AX + AW / 2.0, AY + AH / 2.0)
	var flash := glow("BurstFlash", 27, {"radius": 26, "color": C[5], "alpha": 0.0}, {"at": mid})
	frames_key(flash, "material:shader_parameter/alpha", func(t: float) -> float:
		var f := int(floor(t * FPS + 1e-6)) % NF
		var b := burst_of(f)
		return 0.4 if b.size() and f == b[0] else 0.0)
	for side in [[-1.0, RED, "SplitRed"], [1.0, CYAN, "SplitCyan"]]:
		var g := glow(side[2], 19, {"radius": 18, "color": side[1], "alpha": 0.0}, {"at": mid})
		var sg: float = side[0]
		frames_key(g, "material:shader_parameter/alpha", func(t: float) -> float: return 0.18 * ks[int(floor(t * FPS + 1e-6)) % NF])
		frames_key(g, "position", func(t: float) -> Vector2: return mid + Vector2(sg * splits[int(floor(t * FPS + 1e-6)) % NF] * 4.0, 0.0))
	var bl := glow_path("BarLight", Vector2(AX - 2, AY - 6), Vector2(AX + AW + 2, AY + AH + 6), 4, C[4])
	frames_key(bl, "material:shader_parameter/a", func(t: float) -> Vector2: return Vector2(AX - 2, _bar(t)))
	frames_key(bl, "material:shader_parameter/b", func(t: float) -> Vector2: return Vector2(AX + AW + 2, _bar(t)))
	frames_key(bl, "material:shader_parameter/k", func(t: float) -> float: return 0.12 if absf(_bar(t) - (AY + AH / 2.0)) < AH / 2.0 + 3.0 else 0.0)


func _bar(t: float) -> float:
	var tt := floorf(t * FPS + 1e-6) / FPS
	return AY + fposmod((tt / root.duration) * 2.0 * (AH + 12), AH + 12) - 6.0
