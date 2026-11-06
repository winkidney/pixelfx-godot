# Core parity tests: the Godot core against values and painter output recorded from the JS core
# (tests/fixtures/core.json, written by `node godot/port/ref.mjs --fixtures`).
#   godot --headless --path godot -s res://tests/core_test.gd      (or ./pfx test)
extends SceneTree

const Px := preload("res://addons/pixelfx/core/px.gd")

var fails := 0
var checks := 0


func _initialize() -> void:
	var code: Variant = run()
	quit(code if code is int else 1)


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		if fails <= 40:
			push_error("PFX_FAIL " + what)
			print("FAIL ", what)


func near(a: float, b: float) -> bool:
	return a == b or (is_nan(a) and is_nan(b))


func ulp(a: float, b: float) -> bool:
	return near(a, b) or absf(a - b) <= 4e-16 * maxf(1.0, absf(b))


func run() -> int:
	var fx := FileAccess.get_file_as_string("res://tests/fixtures/core.json")
	var F: Dictionary = _exact(JSON.parse_string(fx))
	for c in F.hash:
		var a: Array = c.a
		var v: int
		match a.size():
			1: v = Px.hash(_n(a[0]))
			2: v = Px.hash(_n(a[0]), _n(a[1]))
			5: v = Px.hash(_n(a[0]), _n(a[1]), _n(a[2]), _n(a[3]), _n(a[4]))
			6: v = Px.hash(_n(a[0]), _n(a[1]), _n(a[2]), _n(a[3]), _n(a[4]), _n(a[5]))
		check(v == int(c.v), "hash%s = %d, want %d" % [a, v, int(c.v)])
	for c in F.rand:
		var v := Px.rand(_n(c.a[0]), _n(c.a[1]), _n(c.a[2]))
		check(near(v, c.v), "rand%s = %s, want %s" % [c.a, v, c.v])
	for c in F.rng:
		var r := Px.Rng.new(_n(c.seed))
		var ok := true
		for x in c.seq:
			if not near(r.next(), x):
				ok = false
		check(ok, "Rng(%s) sequence" % c.seed)
		check(near(r.range(-3, 9), c.range), "Rng(%s).range" % c.seed)
		check(r.int_(2, 11) == int(c.int), "Rng(%s).int" % c.seed)
		check(r.chance(0.4) == c.chance, "Rng(%s).chance" % c.seed)
		check(r.sign() == int(c.sign), "Rng(%s).sign" % c.seed)
		check(near(r.gauss(), c.gauss), "Rng(%s).gauss" % c.seed)
		check(int(r.pick([10, 20, 30, 40, 50])) == int(c.pick), "Rng(%s).pick" % c.seed)
	for c in F.noise:
		check(near(Px.noise(c.a[0], _n(c.a[1])), c.v), "noise%s" % [c.a])
	for c in F.noise2:
		check(near(Px.noise2(c.a[0], c.a[1], _n(c.a[2])), c.v), "noise2%s" % [c.a])
	for c in F.fbm:
		check(near(Px.fbm(c.a[0], c.a[1], c.a[2], c.a[3]), c.v), "fbm%s" % [c.a])
	for c in F.tile:
		check(near(Px.tileNoise(c.a[0], c.a[1], c.a[2], c.a[3], _n(c.a[4])), c.v), "tileNoise%s" % [c.a])
		check(near(Px.tileFbm(c.a[0], c.a[1], c.a[2], c.a[3], c.a[4], 3), c.f), "tileFbm%s" % [c.a])
	for c in F.loop:
		check(near(Px.loopNoise(c.a[0], c.a[1], _n(c.a[2])), c.v), "loopNoise%s" % [c.a])
	for c in F.hypot:
		check(near(Px.hypot(c.a[0], c.a[1]), c.v), "hypot%s = %s want %s" % [c.a, Px.hypot(c.a[0], c.a[1]), c.v])
		check(near(Px.hypot(c.a3[0], c.a3[1], c.a3[2]), c.v3), "hypot3%s" % [c.a3])
	for c in F.round:
		check(near(Px.round(c.a), c.v), "round(%s) = %s want %s" % [c.a, Px.round(c.a), c.v])
	var R := Px.ramp(Px.PAL.fire)
	var i := 0
	for c in F.color:
		var t: float = c.t
		check(_ints(Px.fit(Px.PAL.ice, 5)) == _ints(c.fit5), "fit5")
		check(_ints(Px.fit(Px.PAL.ice, 11)) == _ints(c.fit11), "fit11")
		check(Px.at(R, t) == int(c.at), "at(%s)" % t)
		check(Px.blend(R, t) == int(c.blend), "blend(%s)" % t)
		check(Px.mix(R[1], R[6], t) == int(c.mix), "mix(%s)" % t)
		check(Px.scale(R[4], 0.3 + t * 2.0) == int(c.scale), "scale(%s)" % t)
		check(near(Px.luma(R[i % R.size()]), c.luma), "luma")
		check(Px.hex(Px.PAL.candy[i % 7]) == int(c.hex), "hex")
		i += 1
	for c in F.ease:
		var E: Variant = Px.Ease
		# sin/cos/pow come from the C library here and from V8's fdlibm there: allow the last bit
		check(ulp(E.call(c.name, c.t), c.v), "ease.%s(%s)" % [c.name, c.t])
	var hc := HashingContext.new()
	for c in F.painter:
		var f := Px.createFrame(48, 40)
		var p := Px.painterFor(f)
		var pl: Dictionary = PLACEMENTS[int(c.pi)]
		var cs: Array = CASES[int(c.si)]
		p.place(24, 22, pl.get("flip", false), pl.get("angle", 0.0))
		if pl.has("fade"):
			p.fade = pl.fade
		drawCase(p, cs[0], cs[1])
		check(_sha1(hc, f.color) == c.c, "painter color " + c.name)
		check(_sha1(hc, f.light) == c.l, "painter light " + c.name)
	for c in F.get("rig", []):
		var r := Px.Rig.posed(c.q)
		var col := PackedInt32Array()
		col.resize(r.n)
		for q in r.n:
			col[q] = r.color[q]
		var ink := PackedInt32Array()
		ink.resize(r.n)
		for q in r.n:
			ink[q] = r.ink[q]
		var tag := "rig %s" % JSON.stringify(c.q)
		check(r.n == int(c.n), tag + " n %d want %d" % [r.n, int(c.n)])
		check([r.x0, r.y0, r.x1, r.y1] == c.box.map(func(v): return int(v)), tag + " box")
		check(_sha1(hc, r.xs) == c.xs and _sha1(hc, r.ys) == c.ys, tag + " pixel positions")
		check(_sha1(hc, col) == c.color, tag + " colors")
		check(_sha1(hc, r.src) == c.src, tag + " src")
		check(_sha1(hc, ink) == c.ink, tag + " ink")
	print("core: %d checks, %d failed" % [checks, fails])
	return 1 if fails else 0


## JSON numbers come back as floats: whole ones go back to ints, like JS's own numbers would hash.
func _n(v: Variant) -> Variant:
	return v


## Undo ref.mjs's exact(): { "$d": hex of the double's bytes } back to the very same float.
static func _exact(v: Variant) -> Variant:
	if v is Dictionary:
		if v.has("$d"):
			return String(v["$d"]).hex_decode().decode_double(0)
		var o := {}
		for k in v:
			o[k] = _exact(v[k])
		return o
	if v is Array:
		return v.map(func(x): return _exact(x))
	return v


func _ints(a: Array) -> Array:
	return a.map(func(x): return int(x))


static func _sha1(hc: HashingContext, buf: PackedInt32Array) -> String:
	hc.start(HashingContext.HASH_SHA1)
	hc.update(buf.to_byte_array())
	return hc.finish().hex_encode()


# The painter cases, in the same order as ref.mjs's table (fixtures carry the indices).
const PLACEMENTS := [{}, {"flip": true}, {"angle": 0.6}, {"flip": true, "angle": -2.2}, {"fade": 0.55}]
const CASES := [
	["circle", [0, 0, 9, "#ff4020"]], ["circle", [3, -2, 7, "fn:dcol", "fn:dalpha"]], ["circle", [1, 1, 0.4, "#ffffff"]],
	["ellipse", [0, 2, 14, 5, "fn:dcol"]], ["ring", [0, 0, 12, 3, "fn:vcol"]], ["arc", [0, 0, 15, 5, -2.5, 0.9, "fn:uvcol", "fn:ualpha"]],
	["arc", [0, 0, 15, "fn:taper", -1, 2, "#a0e0ff"]], ["line", [-18, -12, 16, 9, "fn:ucol"]], ["line", [10, -15, -12, 14, "#ffee88", 0.5]],
	["beam", [-14, 6, 15, -8, 5, "fn:uvcol"]], ["rect", [-10, -6, 17, 9, "#40c060", 0.7]], ["poly", [[[-12, 8], [0, -14], [13, 6], [2, 1]], "fn:xycol"]],
	["tri", [-5, -5, 9, -2, 1, 11, "#8040ff"]], ["glow", [0, 0, 16, "#ff8a2a", 0.8]], ["glowLine", [-15, 10, 14, -11, 6, "#3f8cff", 0.6]],
	["glowRing", [0, 0, 11, 4, "#ffd84a", 0.7]], ["disc", [-3, 2, 9, "#7b6f72", 0.5]], ["disc", [4, -3, 6, "fn:dcol", "fn:dalpha"]],
	["dot", [5, 5, "#ffffff", 0.4]], ["blend", [-6, 4, "#20a0ff", 0.6]], ["text", ["LV 12!", -18, -10, "#ffe066", {"font": "mini", "scale": 2, "outline": "#140c18", "align": "left"}]],
	["text", ["GO", 0, -6, "fn:xycol", {"font": "big", "align": "center", "shadow": "#000000"}]], ["sprite", [["..##..", ".#oo#.", "#oOOo#", ".#oo#."], {"#": "#222034", "o": "#f0b424", "O": "#fff6c4"}, -6, -4, {"scale": 2}]],
	["sparkle", [2, -3, 7, "#9bdcff", "#2f7fcc", 0.6]], ["flare", [0, 0, 14, 0.5, "PAL:holy"]], ["band", [0, 4, 16, 0.3, 4, 0.9, "PAL:ice", "fn:far", true]],
	["crystal", [0, 12, 26, 9, 4, "PAL:ice", {"glint": 0.4}]], ["crystal", [6, 10, 14, 6, -3, "PAL:arcane", {"a": 0.7}]],
]


func drawCase(p: Px.Painter, m: String, args: Array) -> void:
	var R := Px.ramp(Px.PAL.fire)
	var fns := {
		"dcol": func(d): return Px.at(R, 1.0 - d),
		"dalpha": func(d, a): return 1.0 - d * 0.6 + sin(a) * 0.1,
		"vcol": func(v, a): return R[2 + floori(v * 4.0)] if cos(a * 3.0) > 0.0 else R[7],
		"uvcol": func(u, v): return Px.at(R, 1.0 - u * 0.5 - v * 0.4),
		"ualpha": func(u): return minf(1.0, u * 2.0),
		"taper": func(u): return 6.0 * sin(PI * u),
		"ucol": func(u): return Px.mix(R[2], Px.WHITE, u),
		"xycol": func(x, y): return R[5] if (floori(x) + floori(y)) & 1 else R[3],
		"far": func(g): return sin(g) < 0.0,
	}
	var a := []
	for v in args:
		if v is String and v.begins_with("fn:"):
			a.append(fns[v.substr(3)])
		elif v is String and v.begins_with("#"):
			a.append(Px.hex(v))
		elif v is String and v.begins_with("PAL:"):
			a.append(Px.PAL[v.substr(4)])
		else:
			a.append(v)
	if m == "text":
		var o: Dictionary = a[4].duplicate()
		if o.has("outline"):
			o.outline = Px.hex(o.outline)
		if o.has("shadow"):
			o.shadow = Px.hex(o.shadow)
		a[4] = o
	match m:
		"sparkle": Px.sparkle(p, a[0], a[1], a[2], a[3], a[4], a[5])
		"flare": Px.flare(p, a[0], a[1], a[2], a[3], a[4])
		"band": Px.band(p, a[0], a[1], a[2], a[3], a[4], a[5], a[6], a[7], a[8])
		"crystal": Px.crystal(p, a[0], a[1], a[2], a[3], a[4], a[5], a[6])
		_: p.callv(m, a)
