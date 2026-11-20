# reimagined-from: src/fx/critters/wisp.js
# Wisp: A will-o'-the-wisp loops a figure-eight over the floor: a little soul-flame with a face, its flame tail
# licking up and streaming behind, shedding puffs and sparks.
# loop, 3.20 s, 128x104 canvas, origin [64, 96], backdrop ground
# The wisp has no body to lift: its tail of flame tongues, its head of cold fire and its face are a canvas shader
# running the original's flame, ball and face off keyed uniforms (fx/critters/_wisp.gdshader: where it is, its lean
# and stretch, where it looks, the blink). The flame puffs it sheds along its path and the sparks wandering up are
# particles placed frame by frame on the original's cycles, each with its glow; its cold light and the floor lit
# under it are keyed lights; its shadow a keyed soft ellipse.
extends "res://build/fx/critters/_critters.gd"

const HOVER := 36.0


func at(t: float) -> Dictionary:
	var a := (t / D) * TAU
	return {"x": 34.0 * sin(a), "y": -HOVER - 10.0 * sin(2.0 * a), "vx": ((34.0 * TAU) / D) * cos(a), "vy": ((-20.0 * TAU) / D) * cos(2.0 * a)}


func make() -> void:
	var heat := [C[6], C[6], C[5], C[5], C[4], C[4], C[3], C[3], C[3]]
	var sparks := [C[6], C[5], C[4], C[3]]
	blob("Shadow", 0.0, 1.2, C[0], 44.0, func(i: int, t: float) -> Array: return [at(t).x, 7.0, 0.4])
	var puffs := []
	var embers := []
	for f in NF:
		var t := ft(f)
		var pr := []
		cycle(t, D, 30, 8, func(g: JsRng) -> float: return g.range(0.3, 0.6), func(age: float, L: float, r: JsRng, _i: int) -> void:
			var S0 := at(jmod(t - age, D))
			var x0: float = S0.x + r.range(-3, 3)
			var y0: float = S0.y - r.range(0, 4)
			var vx0 := r.range(-8, 8)
			var p := fly(x0, y0, vx0, -r.range(6, 16), age, -40.0, 2.5)
			var sz := r.range(1.2, 2.6)
			pr.append_array(fire_puff_es(p.x, p.y, 1.0 - age / L, sz, r.next() * 100.0, heat)))
		puffs.append(pr)
		var er := []
		cycle(t, D, 26, 9, func(g: JsRng) -> float: return g.range(0.8, 1.6), func(age: float, L: float, r: JsRng, _i: int) -> void:
			var S0 := at(jmod(t - age, D))
			var s := r.next() * 100.0
			var x0: float = S0.x + r.range(-5, 5)
			var y0: float = S0.y - r.range(4, 12)
			var vx0 := r.range(-20, 20)
			var p := fly(x0, y0, vx0, -r.range(20, 45), age, -15.0, 1.6)
			var x := p.x + sin(age * 2.3 + s) * 3.0 * minf(1.0, age)
			var size := 2.0 if r.chance(0.3) else 1.0
			var kk := (L - age) / L
			var c: Color = sparks[0] if kk > 0.6 else (sparks[1] if kk > 0.3 else sparks[2])
			if kk < 0.25 and sin(t * 40.0 + s) < 0.0:
				return
			er.append(dot_e(x, p.y, c, 1.0, [x, p.y, 3.0 + size, c, 0.35 * kk]))
			if size > 1.5:
				er.append(dot_e(x, p.y + 1.0, sparks[3])))
		embers.append(er)
	var pp := soft_split(puffs)
	table("PuffsDying", K_DISC, pp[1], {"soft": true, "light": false})
	table("Puffs", K_DISC, pp[0])
	var w := shape("Wisp", csh("wisp"), Vector2(root.canvas_size), {"period": D, "pal": C}, {"at": -Vector2(root.origin) + Vector2(root.canvas_size) / 2.0})
	per_frame(w, "material:shader_parameter/t", func(i: int, t: float) -> float: return t)
	per_frame(w, "material:shader_parameter/X", func(i: int, t: float) -> float: return at(t).x)
	per_frame(w, "material:shader_parameter/Y", func(i: int, t: float) -> float: return at(t).y)
	per_frame(w, "material:shader_parameter/lean", func(i: int, t: float) -> float: return clampf(-at(t).vx / 80.0, -0.9, 0.9))
	per_frame(w, "material:shader_parameter/stretch", func(i: int, t: float) -> float: return clampf(at(t).vy / 120.0, -0.3, 0.4))
	per_frame(w, "material:shader_parameter/look", func(i: int, t: float) -> float: return jround(clampf(at(t).vx / 60.0, -1.0, 1.0)))
	per_frame(w, "material:shader_parameter/blink", func(i: int, t: float) -> bool: return jmod(t, D) > 2.2 and jmod(t, D) < 2.28)
	table("Sparks", K_DOT, embers)
	glows("Light", func(i: int, t: float) -> Array:
		var S := at(t)
		var lean := clampf(-S.vx / 80.0, -0.9, 0.9)
		var fl := 0.85 + 0.15 * lnoise(t, D, 22, 0.0, 9.0)
		var near := clampf(1.0 - (-S.y - 24.0) / 30.0, 0.0, 1.0)
		var out := [{"c": C[4], "p": Vector2(S.x + lean * 3.0, S.y - 6.0), "r": 46.0 * fl, "k": 0.38}, {"c": C[5], "p": Vector2(S.x, S.y - 1.0), "r": 13.0, "k": 0.35 * fl}]
		for x in range(-24, 25, 6):
			out.append({"c": C[4], "p": Vector2(S.x + x, -1.0), "r": 16.0, "k": (0.08 + 0.1 * near) * (1.0 - absf(x) / 32.0)})
		return out)
