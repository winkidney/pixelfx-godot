# reimagined-from: src/fx/lightning/lightning-strike.js
# Lightning strike: a targeted strike: a sigil charges on the floor, the scene darkens, a thick bolt slams into it,
# arcs race out along the cracks it splits, the channel crumbles to a scorch.
# The sigil is a shader (fx/lightning/_sigil.gdshader), its far half behind, static crackling up off it; the stepped
# leader and the three strokes are the same forked bolt (fx/lightning/_volt.gd): the leader feels its way down in
# steps, a streamer climbs to meet it, then each stroke flickers on the original's beat with its brightness (its
# body thins, its forks and white core drop out as it dims), a dart runs down the channel before each re-strike,
# the channel cools between them and crumbles from the top down after the last. The cracks are grown here and
# baked into a data texture that a shader (fx/lightning/_cracks.gdshader) opens, electrifies and cools; arcs crawl
# along them; a scorch (fx/lightning/_scorch.gdshader), sparks, hot sparks, embers, grit, dust and smoke at each
# stroke; the scene darkens a beat before it.
extends "res://build/fx/lightning/_base.gd"

const W := 120.0
const TOP := -224.0
const RX := 28.0
const SY := 0.22
const REACH := 52.0
const LEAD0 := 0.48
const STEPS := 9
const MEET := -30.0
const STROKES := [[0.76, 1.0], [1.04, 0.8], [1.26, 0.55]]
const FLICK := [1.0, 0.72, 0.3, 0.95, 0.5, 0.8, 0.22]
const S1 := 0.76
const NF := 91
const SEED := 5


static func lvl(a: float) -> float:
	if a < 0.0:
		return 0.0
	var i := int(floor(a * 30.0 + 1e-4))
	return FLICK[i] if i < FLICK.size() else 0.0


static func out_cubic(x: float) -> float:
	return 1.0 - pow(1.0 - x, 3.0)


## The stroke under way at t: [index, its start, a (s since), k (brightness)], or [] before the first.
static func now(t: float) -> Array:
	for i in range(STROKES.size() - 1, -1, -1):
		if t >= STROKES[i][0]:
			return [i, STROKES[i][0], t - STROKES[i][0], lvl(t - STROKES[i][0]) * STROKES[i][1]]
	return []


func make() -> void:
	ground()
	var C := pal()
	var R := RandomNumberGenerator.new()
	R.seed = SEED
	var X0 := roundf(R.randf_range(8, 18) * (1.0 if R.randf() < 0.5 else -1.0))
	var bolt_o := {"jag": 0.17, "forks": 0.5, "rate": 0.0, "seed": _forked_seed(X0), "visible": false}

	# the scene darkens a beat before the strike
	var night := rect("Night", Rect2(-Vector2(root.origin), Vector2(root.canvas_size)), Color("#04030a"), {"layer": "soft", "back": true})
	key(night, "modulate:a", frames_keys(0.0, 3.0, func(t): return 0.5 * smoothstep(0.46, 0.66, t) * (1.0 - smoothstep(S1 - 0.01, S1 + 0.02, t))), "nearest")

	# the sigil: the far half behind, the near half in front
	var sig_p := {"c2": C[2], "c3": C[3], "c4": C[4], "c5": C[5], "c6": C[6], "strike": S1, "rx": RX, "sy": SY}
	var sig_shader := load("res://addons/pixelfx_particles/fx/lightning/_sigil.gdshader")
	var far_p := sig_p.duplicate()
	far_p.near = false
	var sig_far := shape("SigilFar", sig_shader, Vector2(75, 25), far_p, {"at": Vector2(0.5, 0.5), "back": true})
	var near_p := sig_p.duplicate()
	near_p.near = true
	var sig_near := shape("SigilNear", sig_shader, Vector2(75, 25), near_p, {"at": Vector2(0.5, 0.5)})
	var charge := func(t: float) -> float: return pow(clampf(t / S1, 0.0, 1.0), 1.5)
	for s in [sig_far, sig_near]:
		key(s, "material:shader_parameter/t", [[0.0, 0.0], [3.0, 3.0]])
		key(s, "material:shader_parameter/k", frames_keys(0.0, 3.0, charge), "nearest")
	var sig_light := glow("SigilLight", 32, {"radius": 30, "squash": 0.3, "color": C[4], "alpha": 0.0})
	key(sig_light, "material:shader_parameter/alpha", frames_keys(0.0, 3.0, func(t): return (0.25 * charge.call(t) if t < S1 else 0.25 * (1.0 - clampf((t - S1) / 0.45, 0.0, 1.0)))), "nearest")
	var heart_light := glow("HeartLight", 22, {"radius": 10, "color": C[5], "alpha": 0.0}, {"at": Vector2(0, -1)})
	key(heart_light, "material:shader_parameter/radius", frames_keys(0.0, 3.0, func(t): return 10.0 + 10.0 * charge.call(t)), "nearest")
	key(heart_light, "material:shader_parameter/alpha", frames_keys(0.0, 3.0, func(t): return (0.3 + 0.4 * charge.call(t) * (0.6 + 0.4 * sin(t * (10.0 + 30.0 * charge.call(t))))) if t < S1 else 0.0), "nearest")

	# the cracks, the scorch, the heat
	var tree := _cracks(R)
	_crack_floor(tree, C)
	var sc := scorch("Scorch", 0, 12)
	var heat_at := _heat
	key(sc, "material:shader_parameter/heat", frames_keys(0.0, 3.0, heat_at), "nearest")
	key(sc, "material:shader_parameter/fade", frames_keys(0.0, 3.0, func(t): return (1.0 - smoothstep(2.3, 2.95, t)) if t >= S1 else 0.0), "nearest")
	var heat_light := glow("HeatLight", 36, {"radius": 34, "color": Color("#ffc23d"), "alpha": 0.0}, {"at": Vector2(0, -2)})
	key(heat_light, "material:shader_parameter/alpha", frames_keys(0.0, 3.0, func(t): return 0.3 * heat_at.call(t)), "nearest")

	# static rising off the charging sigil, more and more of it; the streamer climbing to meet the leader
	var stat := []
	for i in 5:
		stat.append(volt("Static%d" % i, Vector2.ZERO, Vector2(0, -5), {"style": 1, "jag": 0.45, "forks": 0.3, "rate": 30.0, "light": 0.3, "visible": false}))
	var stat_light := glow("StaticLight", 38, {"radius": 36, "color": C[4], "alpha": 0.0}, {"at": Vector2(0, -2)})
	var streamer := volt("Streamer", Vector2(0, -1), Vector2(0, -3), {"style": 1, "k": 0.85, "jag": 0.3, "forks": 0.3, "rate": 30.0, "light": 0.45, "visible": false})
	var tip_light := glow("StreamerTip", 11, {"radius": 9, "color": C[5], "alpha": 0.0})

	# the bolt: the leader, three strokes, the darts before the re-strikes, the channel cooling and crumbling
	var top := Vector2(X0, TOP)
	var foot := Vector2(0, -1)
	var leader := volt("Leader", top, foot, bolt_o.merged({"style": 3, "keep_w": W, "drift_top": TOP}, true))
	var leader_tip := glow("LeaderTip", 9, {"radius": 7, "color": C[5], "alpha": 0.0})
	var strokes := []
	var darts := []
	var chans := []
	for i in 3:
		var o := bolt_o.merged({"keep_w": W, "drift_top": TOP, "trunk_only": i > 0, "drift": [0.0, 1.5, 3.0][i], "thick": 1.5 if i == 0 else 1.2}, true)
		strokes.append(volt("Stroke%d" % i, top, foot, o))
		chans.append(volt("Channel%d" % i, top, foot, o.merged({"style": 4 if i == 2 else 2, "trace_color": C[5], "trunk_only": true}, true)))
		if i > 0:
			darts.append([volt("DartPath%d" % i, top, foot, o.merged({"style": 2, "trace_color": C[3], "trunk_only": true}, true)),
				volt("Dart%d" % i, top, foot, o.merged({"style": 2, "trace_color": C[6], "trunk_only": true}, true))])
	var dart_light := glow("DartLight", 40, {"radius": 30, "squash": 2.0, "color": C[4], "alpha": 0.0})
	var foot_orb := orb("Foot", Vector2(0, -1), [[8.5, C[2]], [7.5, C[5]], [4.5, Color.WHITE]])
	var glint := sprite("Glint", "spark7", {"at": Vector2(0, -2), "modulate": C[6], "visible": false})
	var big := glow("StrokeSky", 98, {"radius": 96, "color": C[3], "alpha": 0.0}, {"at": Vector2(0, -16)})
	var small := glow("StrokeFoot", 24, {"radius": 22, "color": C[5], "alpha": 0.0}, {"at": Vector2(0, -3)})
	var hero_sky := glow("HeroSky", 172, {"radius": 170, "color": C[3], "alpha": 0.0}, {"at": Vector2(X0 * 0.5, -110)})
	var crawl := []
	for i in 6:
		crawl.append(volt("Crawl%d" % i, Vector2.ZERO, Vector2(4, 0), {"style": 1, "jag": 0.25, "forks": 0.0, "rate": 30.0, "light": 0.35, "visible": false}))

	# the trunk's points as the volts draw them (for the darts' light and the motes the crumbling channel sheds)
	var probe: Node2D = VOLT.new()
	for kk in ["from", "to"]:
		probe.set(kk, top if kk == "from" else foot)
	probe.jag = 0.17
	probe.forks = 0.5
	probe.rate = 0.0
	probe.bolt_seed = bolt_o.seed
	probe.keep_w = W
	probe.drift_top = TOP
	probe.trunk_only = true
	probe.drift = 3.0
	probe._rebuild()
	var trunk: PackedVector2Array = probe._paths[0].pts
	probe.free()

	var K := {}
	for n in ["lv", "ly", "lp", "lf", "ltp", "lta", "sv", "sf", "st", "sk", "sl", "mv", "mt", "mk", "tp", "ta", "fr0", "fr1", "fr2", "gl", "gls",
			"big", "small", "hero", "dl", "dlp"]:
		K[n] = []
	var S := []
	for i in 3:
		S.append({"v": [], "k": [], "hero": [], "core": [], "cv": [], "cc": [], "cr": [], "dv": [], "ds": [], "du": []})
	var CR := []
	for i in 6:
		CR.append({"v": [], "a": [], "b": [], "k": []})
	var SV := []
	for i in 5:
		SV.append({"v": [], "a": [], "b": [], "k": []})
	var rs := RandomNumberGenerator.new()
	rs.seed = 61
	for f in NF:
		var t := f / FPS
		var st := maxf(0.0, (f - 0.5) / FPS)
		var k: float = charge.call(t)
		# static off the sigil
		var nst := int(roundf(1.0 + 4.0 * k)) if (t > 0.15 and t < S1) else 0
		for i in 5:
			var a := rs.randf_range(0, TAU)
			var p := Vector2(cos(a) * RX, sin(a) * RX * SY)
			SV[i].v.append([st, i < nst])
			SV[i].a.append([st, p])
			SV[i].b.append([st, p + Vector2(rs.randf_range(-2.5, 2.5), -rs.randf_range(4, 9) * (0.6 + k))])
			SV[i].k.append([st, 0.45 + 0.4 * k])
		K.sl.append([st, (0.12 + 0.3 * k) if nst > 0 else 0.0])
		# the stepped leader and the streamer
		var leading := t >= LEAD0 and t < S1
		var u := clampf((t - LEAD0) / (S1 - LEAD0), 0.0, 1.0)
		var stp := mini(STEPS, int(floor(u * STEPS)) + 1)
		var fresh := 1.0 - fmod(u * STEPS, 1.0)
		var reach := TOP + (MEET - TOP) * pow(stp / float(STEPS), 1.2)
		K.lv.append([st, leading])
		K.ly.append([st, reach])
		K.lp.append([st, TOP + (MEET - TOP) * pow((stp - 1) / float(STEPS), 1.2)])
		K.lf.append([st, fresh])
		var tip := Vector2(X0, TOP)
		for q in trunk:
			if q.y <= reach:
				tip = q
		K.ltp.append([st, tip])
		K.lta.append([st, (0.5 * fresh + 0.15) if leading else 0.0])
		var streaming := leading and t > 0.62
		var h := -MEET * (1.0 - pow(1.0 - (t - 0.62) / (S1 - 0.62), 2.0)) if streaming else 3.0
		var sx := rs.randf_range(-2, 2)
		K.sv.append([st, streaming])
		K.st.append([st, Vector2(sx, -maxf(3.0, h))])
		K.tp.append([st, Vector2(sx, -maxf(3.0, h))])
		K.ta.append([st, 0.5 if streaming else 0.0])
		# the strokes, the darts, the cooling channel
		var s := now(t)
		var nxt := -1
		for i in STROKES.size():
			if STROKES[i][0] > t:
				nxt = i
				break
		var darting: bool = nxt > 0 and t > STROKES[nxt][0] - 0.06
		var sk: float = s[3] if s.size() else 0.0
		for i in 3:
			var striking: bool = not darting and s.size() and s[0] == i and sk > 0.0
			var hero: bool = striking and i == 0 and s[2] < 1.0 / 30.0
			S[i].v.append([st, striking])
			S[i].k.append([st, sk if striking else 0.0])
			S[i].hero.append([st, hero])
			S[i].core.append([st, ((1.2 if hero else 0.8) if sk > 0.6 else 0.0)])
			var cooling: bool = not darting and s.size() and s[0] == i and sk <= 0.0
			S[i].cv.append([st, cooling])
			if cooling:
				var cool := clampf((s[2] - 0.23) / 0.45, 0.0, 1.0)
				var hh := 1.0 - cool
				S[i].cc.append([st, C[5] if hh > 0.7 else (C[4] if hh > 0.4 else (C[3] if hh > 0.15 else C[2]))])
				S[i].cr.append([st, s[2]])
			if i > 0:
				var dv: bool = darting and nxt == i
				S[i].dv.append([st, dv])
				var du: float = (t - (STROKES[i][0] - 0.06)) / 0.06 if dv else 0.0
				S[i].ds.append([st, maxf(0.0, du - 18.0 / trunk.size())])
				S[i].du.append([st, maxf(0.02, du)])
				if dv:
					K.dlp.append([st, trunk[clampi(int(du * trunk.size()) - 9, 0, trunk.size() - 1)]])
		K.dl.append([st, 0.35 if darting else 0.0])
		var striking_any: bool = not darting and s.size() and sk > 0.0
		var r := 4.5 * sk
		K.fr0.append([st, r + 1.5 if striking_any else 0.0])
		K.fr1.append([st, r + 0.5 if striking_any else 0.0])
		K.fr2.append([st, r * 0.65 if striking_any else 0.0])
		var glinting: bool = striking_any and s[2] < 0.07
		K.gl.append([st, glinting])
		K.gls.append([st, Vector2.ONE * maxf(0.3, 12.0 * sk * (1.0 - s[2] / 0.07) / 3.0) if glinting else Vector2.ONE])
		K.big.append([st, 0.42 * sk if striking_any else 0.0])
		K.small.append([st, 0.3 * sk if striking_any else 0.0])
		K.hero.append([st, 0.3 if (striking_any and s[0] == 0 and s[2] < 1.0 / 30.0) else 0.0])
		# arcs crawl out along the cracks as they split, and again with every flicker
		var crawling: bool = s.size() > 0 and s[2] < 0.4
		var run: float = 0.0
		if crawling:
			run = REACH * out_cubic(clampf(s[2] / 0.35, 0.0, 1.0)) if s[0] == 0 else REACH * clampf(s[2] / 0.22, 0.0, 1.0)
		var mains := tree.filter(func(b): return b.w >= 1.0)
		for i in 6:
			var on := crawling and i < mains.size() and rs.randf() >= 0.3
			var a := Vector2.ZERO
			var b := Vector2.ZERO
			if on:
				var pts: Array = mains[i].pts
				var j1 := pts.size()
				for j in pts.size():
					if pts[j].z > run:
						j1 = j
						break
				var j0 := maxi(0, j1 - rs.randi_range(7, 13))
				if j1 - j0 < 2:
					on = false
				else:
					a = Vector2(pts[j0].x, pts[j0].y - 1.5 - rs.randf_range(0, 2.5))
					b = Vector2(pts[j1 - 1].x, pts[j1 - 1].y - 1.5 - rs.randf_range(0, 2.5))
			CR[i].v.append([st, on])
			CR[i].a.append([st, a])
			CR[i].b.append([st, b])
			CR[i].k.append([st, 0.9 * (1.0 - (s[2] if s.size() else 0.0) / 0.4) + 0.1])
	for i in 5:
		key(stat[i], "visible", SV[i].v, "nearest")
		key(stat[i], "from", SV[i].a, "nearest")
		key(stat[i], "to", SV[i].b, "nearest")
		key(stat[i], "k", SV[i].k, "nearest")
	key(stat_light, "material:shader_parameter/alpha", K.sl, "nearest")
	key(leader, "visible", K.lv, "nearest")
	key(leader, "y_reach", K.ly, "nearest")
	key(leader, "y_prev", K.lp, "nearest")
	key(leader, "fresh", K.lf, "nearest")
	key(leader_tip, "position", K.ltp, "nearest")
	key(leader_tip, "material:shader_parameter/alpha", K.lta, "nearest")
	key(streamer, "visible", K.sv, "nearest")
	key(streamer, "to", K.st, "nearest")
	key(tip_light, "position", K.tp, "nearest")
	key(tip_light, "material:shader_parameter/alpha", K.ta, "nearest")
	for i in 3:
		key(strokes[i], "visible", S[i].v, "nearest")
		key(strokes[i], "k", S[i].k, "nearest")
		key(strokes[i], "hero", S[i].hero, "nearest")
		key(strokes[i], "core", S[i].core, "nearest")
		key(chans[i], "visible", S[i].cv, "nearest")
		if i == 2:
			key(chans[i], "crumble", S[i].cr, "nearest")
		else:
			key(chans[i], "trace_color", S[i].cc, "nearest")
		if i > 0:
			for d in darts[i - 1]:
				key(d, "visible", S[i].dv, "nearest")
			key(darts[i - 1][1], "start_at", S[i].ds, "nearest")
			key(darts[i - 1][1], "up_to", S[i].du, "nearest")
	key(dart_light, "material:shader_parameter/alpha", K.dl, "nearest")
	key(dart_light, "position", K.dlp, "nearest")
	for j in 3:
		key(foot_orb[j], "material:shader_parameter/radius", K["fr%d" % j], "nearest")
	key(glint, "visible", K.gl, "nearest")
	key(glint, "scale", K.gls, "nearest")
	key(big, "material:shader_parameter/alpha", K.big, "nearest")
	key(small, "material:shader_parameter/alpha", K.small, "nearest")
	key(hero_sky, "material:shader_parameter/alpha", K.hero, "nearest")
	for i in 6:
		key(crawl[i], "visible", CR[i].v, "nearest")
		key(crawl[i], "from", CR[i].a, "nearest")
		key(crawl[i], "to", CR[i].b, "nearest")
		key(crawl[i], "k", CR[i].k, "nearest")

	# at each stroke: light, sparks, hot sparks, embers, grit, dust, smoke
	var hot_ramp := gradient(["#fff3a6", "#ffe26b", "#ff8a2a", "#f2561d"], [0.0, 0.4, 0.7, 0.85])
	var ash := Color("#5b5566").lerp(C[2], 0.3)
	var smoke_ramp := gradient([Color(ash, 0.0), Color(ash, 0.5), Color(Color("#433d48"), 0.35), Color(Color("#433d48"), 0.0)], [0.0, 0.06, 0.6, 0.95])
	for i in 3:
		var t0: float = STROKES[i][0] - 0.5 / FPS
		var k: float = STROKES[i][1]
		flash("StrikeLight%d" % i, Vector2(0, -50), 120, C[4], 0.55 * k, 0.4, t0)
		flash("StrikeWhite%d" % i, Vector2(0, -3), 24, Color.WHITE, 0.5 * k, 0.1, t0)
		var sp := sparks("Sparks%d" % i, {"at": Vector2(0, -2), "amount": int(roundf(44 * k)), "lifetime": 0.55, "randomness": 0.6,
			"emit": {"box": Vector2(1.5, 0.5)}, "dir": -90, "spread": 75, "speed": [110 * (0.65 + 0.35 * k), 320 * (0.65 + 0.35 * k)], "damping": [200, 350]})
		emit(sp, t0)
		var hs := sparks("HotSparks%d" % i, {"at": Vector2(0, -1), "amount": int(roundf(12 * k)), "lifetime": 1.0, "randomness": 0.5,
			"emit": {"box": Vector2(2, 0.5)}, "dir": -90, "spread": 69, "speed": [70, 220], "ramp": hot_ramp})
		emit(hs, t0)
		var em := particles("Embers%d" % i, {"at": Vector2(0, -2), "amount": int(roundf(5 * k)), "lifetime": 1.5, "randomness": 0.45, "one_shot": true,
			"explosiveness": 1.0, "emitting": false, "texture": "dot1", "emit": {"box": Vector2(4, 1)}, "dir": -90, "spread": 20, "speed": [30, 80],
			"damping": [20, 40], "gravity": Vector2(0, -10), "ramp": hot_ramp, "turbulence": {"strength": 3.0, "scale": 3.0, "influence": [0.01, 0.03]}})
		emit(em, t0)
		var grit := particles("Grit%d" % i, {"at": Vector2(0, -1), "amount": int(roundf(18 * k)), "lifetime": 1.5, "randomness": 0.33, "one_shot": true,
			"explosiveness": 1.0, "emitting": false, "texture": "dot1", "emit": {"box": Vector2(3, 0.5)}, "dir": -90, "spread": 63, "speed": [50, 190],
			"gravity": Vector2(0, 950), "initial": gradient(["#655b7a", "#4a4263", "#342d45"]), "collide": {"bounce": 0.25, "friction": 0.8}})
		emit(grit, t0)
		var dust := particles("Dust%d" % i, {"layer": "soft", "at": Vector2(0, -1), "amount": 8, "lifetime": 0.8, "randomness": 0.5, "one_shot": true,
			"explosiveness": 1.0, "emitting": false, "texture": "disc5", "emit": {"box": Vector2(3, 0.5)}, "dir": -90, "spread": 86, "speed": [30, 110],
			"damping": [60, 100], "gravity": Vector2(0, -8), "scale_curve": [[0, 0.8], [1, 1.4]],
			"ramp": gradient([Color(Color("#6e6382"), 0.7), Color(Color("#6e6382"), 0.4), Color(Color("#6e6382"), 0.0)], [0.0, 0.5, 0.95])})
		emit(dust, t0)
		var smoke := particles("Smoke%d" % i, {"layer": "soft", "at": Vector2(0, -4), "amount": int(roundf(4 * k)), "lifetime": 1.6, "randomness": 0.3,
			"one_shot": true, "explosiveness": 1.0, "emitting": false, "texture": "disc11", "emit": {"box": Vector2(8, 1)}, "dir": -90, "spread": 25,
			"speed": [10, 25], "damping": [5, 10], "gravity": Vector2(0, -12), "scale": [0.5, 1.0], "scale_curve": [[0, 0.65], [0.4, 1.0], [1, 1.35]],
			"ramp": smoke_ramp})
		emit(smoke, t0)
	var wisps := particles("Wisps", {"layer": "soft", "at": Vector2(0, -2), "amount": 7, "lifetime": 1.2, "randomness": 0.2, "texture": "disc7",
		"emitting": false, "emit": {"box": Vector2(8, 1)}, "dir": -90, "spread": 15, "speed": [9, 17], "scale_curve": [[0, 0.65], [0.4, 1.0], [1, 1.3]],
		"ramp": smoke_ramp, "preprocess": 0.0})
	emit(wisps, S1, 1.7)
	# the crumbling channel sheds motes that drift down
	var motes := particles("Motes", {"amount": 24, "lifetime": 0.6, "randomness": 0.33, "texture": "streak3", "align": true, "emitting": false,
		"emit": {"points": trunk}, "dir": 90, "spread": 30, "speed": [6, 22], "initial": gradient([C[5], C[4]], [0.0, 0.5]), "preprocess": 0.0})
	emit(motes, STROKES[2][0] + 0.25, STROKES[2][0] + 1.0)


## A seed whose bolt keeps two or three good forks once they're trimmed to the canvas (as the original's does).
func _forked_seed(x0: float) -> int:
	for sd in range(1, 200):
		var probe: Node2D = VOLT.new()
		probe.from = Vector2(x0, TOP)
		probe.to = Vector2(0, -1)
		probe.jag = 0.17
		probe.forks = 0.5
		probe.rate = 0.0
		probe.bolt_seed = sd
		probe.keep_w = W
		probe.drift_top = TOP
		probe._rebuild()
		var good := 0
		for q in probe._paths.slice(1):
			if q.w > 0.5 and (q.pts as PackedVector2Array).size() > 12:
				good += 1
		var n: int = probe._paths.size() - 1
		probe.free()
		if good >= 2 and n <= 4:
			return sd
	return 77


## The cracks the strike splits in the floor: Lichtenberg branches lying on the floor's face. Returns the branches
## ({pts: [Vector3(x, y, d)], w}).
func _cracks(R: RandomNumberGenerator) -> Array:
	var out := []
	for i in 6:
		var a := R.randf_range(-0.5, 0.7) if i % 2 else PI + R.randf_range(-0.7, 0.5)
		_grow(R, out, R.randf_range(-1, 1), R.randf_range(0, 1), a, REACH * R.randf_range(0.55, 1.0), 1.0, 0.0, 0)
	return out


func _grow(R: RandomNumberGenerator, out: Array, x: float, y: float, a: float, length: float, w: float, d: float, depth: int) -> void:
	var pts := [Vector3(x, y, d)]
	var s := 0.0
	while s < length:
		a += R.randf_range(-0.32, 0.32)
		x += cos(a) * 1.5
		y = clampf(y + sin(a) * 0.45, 0.0, 5.0)
		d += 1.5
		pts.append(Vector3(x, y, d))
		if depth < 2 and s > 3.0 and R.randf() < 0.09:
			_grow(R, out, x, y, a + (1.0 if R.randf() < 0.5 else -1.0) * R.randf_range(0.5, 1.2), (length - s) * R.randf_range(0.3, 0.6), w * 0.6, d, depth + 1)
		s += 1.5
	out.append({"pts": pts, "w": w})


## Bake the cracks into a data texture (distance, kind, grain) for fx/lightning/_cracks.gdshader, key it open.
func _crack_floor(tree: Array, C: PackedColorArray) -> void:
	var px := {}
	var gr := RandomNumberGenerator.new()
	gr.seed = 9
	for br in tree:
		for p in br.pts:
			var q := Vector2i(floori(p.x), floori(p.y))
			px[q + Vector2i(0, 1)] = Color(p.z / 64.0, 1.0, 0.0, 1.0)
			px[q] = Color(p.z / 64.0, 0.5 if br.w < 1.0 else 0.0, gr.randf(), 1.0)
			if br.w >= 1.0 and p.z < 9.0:
				px[q + Vector2i(0, 2)] = Color(p.z / 64.0, 1.0, 0.0, 1.0)
	var lo := Vector2i(-64, -2)
	var sz := Vector2i(128, 12)
	var img := Image.create(sz.x, sz.y, false, Image.FORMAT_RGBA8)
	for q in px:
		var v: Vector2i = q - lo
		if v.x >= 0 and v.y >= 0 and v.x < sz.x and v.y < sz.y:
			img.set_pixel(v.x, v.y, px[q])
	var cr := shape("Cracks", load("res://addons/pixelfx_particles/fx/lightning/_cracks.gdshader"), Vector2(sz),
		{"data": ImageTexture.create_from_image(img), "reach": REACH, "fire": fire_ramp(), "soot": Color("#110c16"), "soot2": Color("#1c1522"), "c6": C[6]},
		{"at": Vector2(lo) + Vector2(sz) / 2.0, "back": true})
	key(cr, "material:shader_parameter/front", frames_keys(0.0, 3.0, func(t): return REACH * out_cubic(clampf((t - S1) / 0.35, 0.0, 1.0)) if t >= S1 else 0.0), "nearest")
	key(cr, "material:shader_parameter/heat", frames_keys(0.0, 3.0, _heat), "nearest")
	key(cr, "material:shader_parameter/elec", frames_keys(0.0, 3.0, _elec), "nearest")
	key(cr, "material:shader_parameter/fade", frames_keys(0.0, 3.0, func(t): return 1.0 - smoothstep(2.3, 2.95, t)), "nearest")


## The heat left at the foot: the hottest of the strokes so far, each cooling over 1.6 s.
func _heat(t: float) -> float:
	var h := 0.0
	for s in STROKES:
		if t >= s[0]:
			h = maxf(h, s[1] * pow(clampf(1.0 - (t - s[0]) / 1.6, 0.0, 1.0), 1.4))
	return h


## How electrified the cracks are: a white flash for 0.14 s after every stroke.
func _elec(t: float) -> float:
	var s := now(t)
	if s.is_empty() or s[2] >= 0.14:
		return 0.0
	return STROKES[s[0]][1] * (1.0 - s[2] / 0.14)
