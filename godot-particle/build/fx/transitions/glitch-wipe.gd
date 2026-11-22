# reimagined-from: src/fx/transitions/glitch-wipe.js@f6cfb7df143c02e540d169b564b9bbb0dbd9964d
# Glitch wipe: Torn bands of black stutter across the screen, freezing and jerking back, their ragged edges split into magenta and cyan ghosts spitting data slivers; then they tear on through.
# one-shot, 1.80 s, 320x180 canvas, origin [0.0, 0.0], backdrop sky
# The original's bands (rolled from its seed) and how far each has torn at every frame (its stuttering, freezing,
# jerking tear(), worked out at build time) are data textures; one screen shader tears each band's ragged edge with
# its white line and magenta / cyan ghosts and throws the specks, data slivers and broken tiles round it from the
# original's own hashes on its 18 Hz ticks (fx/transitions/_glitch.gdshader); its light twin lights the edges, the
# slivers and the glow riding each edge.
extends "res://build/fx/transitions/_transitions.gd"

const TICK := 1.0 / 18.0
const IN0 := 0.03
const IN1 := 0.78
const OUT0 := 0.98
const OUT1 := 1.66


static func tear(b: Dictionary, t: float, t0: float, t1: float, salt: int) -> float:
	if t <= t0:
		return 0.0
	if t >= t1:
		return 1.0
	var n := floorf((t + b.off * TICK) / TICK)
	while n > 0.0 and rand([n, b.i, salt]) < 0.22:
		n -= 1.0
	var tq: float = n * TICK - b.off * TICK
	var u := clampf((tq - t0) / (t1 - t0), 0.0, 1.0)
	return clampf(in_out_quad(u) + (rand([n, b.i, salt + 1]) - 0.6) * 0.12 * sin(PI * u), 0.0, 1.0)


func make() -> void:
	var seed: int = meta.options.seed
	var red := Color(meta.options.split)
	var B := []
	var y := 0
	var i := 0
	while y < int(SHH):
		var r := rand([i, seed])
		var h := mini(int(SHH) - y, (5 + int(floorf(rand([i, seed + 1]) * 6.0))) if r < 0.4 else ((10 + int(floorf(rand([i, seed + 1]) * 10.0))) if r < 0.85 else (20 + int(floorf(rand([i, seed + 1]) * 12.0)))))
		var a := clampf(0.5 + 0.55 * noise1(y / 40.0, seed + 9) + (rand([i, seed + 2]) - 0.5) * 0.25, 0.0, 1.0)
		var bb := clampf(0.5 + 0.55 * noise1(y / 40.0, seed + 19) + (rand([i, seed + 3]) - 0.5) * 0.25, 0.0, 1.0)
		var span := 0.32 + rand([i, seed + 6]) * 0.12
		var t0 := IN0 + a * (IN1 - IN0 - span)
		var o0 := OUT0 + bb * (OUT1 - OUT0 - span)
		B.append({"i": i, "y": y, "h": h, "dir": 1.0 if rand([i, seed + 4]) < 0.82 else -1.0, "off": rand([i, seed + 5]),
			"t0": t0, "t1": t0 + span, "o0": o0, "o1": o0 + span})
		y += h
		i += 1
	var bimg := Image.create(B.size(), 1, false, Image.FORMAT_RGBAF)
	for n in B.size():
		bimg.set_pixel(n, 0, Color(B[n].i, B[n].y, B[n].h, B[n].dir))
	var timg := Image.create(B.size(), NF, false, Image.FORMAT_RF)
	for f in NF:
		var t := ft(f)
		for n in B.size():
			var b: Dictionary = B[n]
			var k := tear(b, t, b.o0, b.o1, 7) if t >= OUT0 else tear(b, t, b.t0, b.t1, 3)
			timg.set_pixel(n, f, Color(k, 0, 0))
	var p := {"bands": asset("_bands", bimg), "tears": asset("_tears", timg), "nb": B.size(), "red": red}
	for nd in [screen("Bands", "glitch", p), screen("Light", "glitch_light", p)]:
		per_frame(nd, "material:shader_parameter/f", func(fi: int, _t: float) -> float: return float(fi))
		per_frame(nd, "material:shader_parameter/fr", func(_i: int, t: float) -> float: return floorf(t / TICK))
		per_frame(nd, "material:shader_parameter/outp", func(_i: int, t: float) -> float: return 1.0 if t >= OUT0 else 0.0)
