# reimagined-from: src/fx/scifi/scanner.js@84d1d0e2cd5ca81e15025dcea84db441cadab3cc
# Scanner: Brackets snap onto the hero, a scan line sweeps head to toe leaving a cooling outline, and a readout counts up to OK before it all lets go.
# loop, 3.20 s, 112x78 canvas, origin [42.0, 58.0], backdrop ground, stand-in 2
# The HUD is a shader over the stand-in's own pixels keyed by the loop clock (fx/scifi/_scanner.gdshader): brackets
# snapping in with the original's overshoot, the lock box flashing out, the outline lit row by row as the scan passes
# and cooling behind it, the scan line with its translucent slice, the readout's leader and bar; its light is
# _scanner_light.gdshader. The readout's words are text nodes (the mini font at 2x, a dark shadow under them) keyed a
# frame at a time. Data bits flicked off the body's edges as the line crosses them are the original's own Ghosts
# (motes, _ghost.gdshader).
extends "res://build/fx/scifi/_scifi.gd"

const PFont := preload("res://addons/pixelfx_particles/core/pixel_font.gd")
const LOCK := 0.3
const SCAN0 := 0.42
const SCAN1 := 1.6
const DONE := 1.75
const LET := 2.5

var AX := -12
var AY := -38
var AW := 24
var AH := 38


func scan_t(y: float) -> float:
	return SCAN0 + ((SCAN1 - SCAN0) * acos(1.0 - 2.0 * clampf((y + 0.5 - (AY - 3)) / (4.0 - AY), 0.0, 1.0))) / PI


func spread_at(t: float) -> float:
	var lock := out_back(clampf(t / LOCK, 0.0, 1.0), 2.2)
	var o := in_cubic(clampf((t - LET) / 0.45, 0.0, 1.0))
	return (1.0 - lock) * 14.0 + o * 12.0


func gone_at(t: float) -> bool:
	return t > LET + 0.45 or (t > LET + 0.25 and int(floor((t - LET) * 20.0)) % 2 == 1)


func label_at(t: float) -> String:
	var lead := clampf((t - LOCK) / 0.1, 0.0, 1.0)
	if gone_at(t) or lead < 1.0:
		return ""
	var k := clampf((t - SCAN0) / (SCAN1 - SCAN0), 0.0, 1.0)
	var del := clampf((t - LET) / 0.25, 0.0, 1.0)
	var full := "OK" if t > DONE else "%d%%" % int(floor(k * 100.0))
	return full.substr(0, int(ceil(full.length() * (1.0 - del))))


func make() -> void:
	var tex: Texture2D = load(EFFECT.STAND_INS[2])
	var img := tex.get_image()
	AW = img.get_width()
	AH = img.get_height()
	AX = -int(floor(AW / 2.0))
	AY = -AH
	var D: float = root.duration
	var canvas := Vector2(root.canvas_size)
	var mid := -Vector2(root.origin) + canvas / 2.0
	var hud := shape("Hud", sh("scanner"), canvas, {"tex": tex, "t": 0.0, "period": D, "pal": C}, {"at": mid})
	clock(hud)

	# the readout's words: the shadow, then the word, left-aligned at the panel
	var words := []
	for w in [["Shadow", C[1], Vector2(1, 1)], ["Word", C[6], Vector2.ZERO]]:
		var n := text("Readout" + w[0], "", {"font": "mini", "sx": 2.0, "sy": 2.0, "fill": [w[1]]})
		var off: Vector2 = w[2]
		frames_key(n, "text", func(t: float) -> String: return label_at(t))
		frames_key(n, "position", func(t: float) -> Vector2:
			var s := label_at(t)
			var sp := spread_at(t)
			var left := floorf(AX + AW + 3 + sp + 6.0 + 2.0 + 0.5)
			var top := floorf(AY - 4 - sp + 2.0 + 0.5)
			return Vector2(left + PFont.textWidth(s, "mini") * 2.0 / 2.0, top + 10.0) + off)
		words.append(n)
	keep_colour(C[6])
	frames_key(words[1], "fill", func(t: float) -> PackedColorArray:
		var blink := t > DONE and int(floor((t - DONE) * 8.0)) % 2 == 0 and t < DONE + 0.5
		return PackedColorArray([Color.WHITE if blink else C[6]]))

	# data bits flicked off the body's edges as the line crosses them
	ghosts_begin(D)
	var rows := {}
	for y in AH:
		for x in AW:
			if img.get_pixel(x, y).a > 0.5:
				var r: Array = rows.get(AY + y, [AX + x, AX + x])
				rows[AY + y] = [mini(r[0], AX + x), maxi(r[1], AX + x)]
	var S := 22
	for y in range(AY, 0, 3):
		if not rows.has(y):
			continue
		var r: Array = rows[y]
		for e in [[r[0] - 1, -1], [r[1] + 1, 1]]:
			var s: int = e[1]
			if rand([S, y, s]) < 0.6:
				ghost(scan_t(y), MOTE, e[0], y, s * (30.0 + 50.0 * rand([y, s, 3])), -10.0 + 20.0 * rand([y, s, 4]), 0.2 + 0.15 * rand([y, s, 5]),
					Color.WHITE if rand([y, s, 6]) < 0.4 else C[5], 0.6)
	ghosts({"box": [-40, -58, 68, 9], "floor": 0.0})

	var lit := shape("HudLight", sh("scanner_light"), canvas, {"tex": tex, "t": 0.0, "pal": C}, {"at": mid})
	clock(lit)
