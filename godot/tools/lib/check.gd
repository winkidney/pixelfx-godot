# ./pfx check: the mistakes eyes miss. Missing meta, drawing outside the canvas, one-shots that don't end clean, loops
# with a seam, randomness that isn't seeded, slow frames, and in an act: keys out of order, unknown pose fields and
# hands that teleport.
# port-of: tools/check.mjs (upstream)
extends RefCounted

const Px := preload("res://addons/pixelfx/core/px.gd")
const Lib := preload("fxlib.gd")
const M := 24  # margin around the canvas, to catch pixels drawn outside it
## GDScript runs these effects some 10 to 30 times slower than V8: over this, a frame is worth a look.
const SLOW_MS := 25.0
const POSE_KEYS := ["x", "y", "crouch", "lean", "twist", "turn", "yaw", "hx", "hy", "fx", "fy", "fz", "bx", "by", "bz", "ffx", "ffy", "fbx", "fby", "fzz", "bzz", "weapon", "sa", "two", "offWeapon", "sb", "armsFront", "toeF", "toeB", "face", "ghost", "wl", "wz", "pull", "nocked"]


static func _hands(q: Dictionary) -> Array:
	return [float(q.get("fx", 7.0)), float(q.get("fy", -14.0)), float(q.get("bx", -8.0)), float(q.get("by", -14.0))]


func checkAct(fx: Dictionary, errs: Array, notes: Array) -> void:
	var meta: Dictionary = fx.meta
	var a: Dictionary = Px.Fx.actOf(fx.mod)
	var k: Variant = a.get("poses")
	if not (k is Array) or k.is_empty():
		errs.append("act.poses is empty")
		return
	for i in k.size():
		var t: Variant = k[i][0]
		if not (typeof(t) == TYPE_INT or typeof(t) == TYPE_FLOAT):
			errs.append("act key %d: no time" % i)
		if i and float(t) < float(k[i - 1][0]):
			errs.append("act keys out of order at %s" % t)
		for n in k[i][1]:
			if not (n in POSE_KEYS):
				errs.append("act key at %s: unknown pose field \"%s\"" % [t, n])
	# arms don't stretch: a hand asked to go further than it can falls short of where the effect needs it
	for key in k:
		var short := Px.Rig.shortfall(key[1])
		if short > 3.5:
			notes.append("act: at t = %s a hand falls %d px short of where the pose wants it: step the body in" % [key[0], roundi(short)])
			break
	var first: float = k[0][0]
	var last: float = k[k.size() - 1][0]
	var D: float = meta.duration
	for h in a.get("hits", []):
		if not (h.t >= first and h.t <= maxf(last, D)):
			errs.append("act hit at %s is outside the act" % h.t)
		if h.get("stop", 0.0) > 0.3:
			notes.append("act hit at %s freezes for %s s: past 0.3 s it reads as a stall" % [h.t, h.stop])
	if meta.loop:
		if last != D:
			errs.append("a loop's poses end at its duration (%s), not %s" % [D, last])
		var from := -1
		for i in k.size():
			if float(k[i][0]) >= 0.0:
				from = i
				break
		if from < 0 or float(k[from][0]) != 0.0:
			errs.append("a loop's poses need a key at t = 0")
		else:
			var A := _hands(Px.Act.poseAt(k, 0.0))
			var B := _hands(Px.Act.poseAt(k, D))
			var qa := Px.Act.poseAt(k, 0.0)
			var qb := Px.Act.poseAt(k, D)
			var seam := absf(float(qa.get("crouch", 0)) - float(qb.get("crouch", 0)))
			seam = maxf(seam, absf(float(qa.get("x", 0)) - float(qb.get("x", 0))))
			for i in 4:
				seam = maxf(seam, absf(A[i] - B[i]))
			if seam > 2.0:
				notes.append("act's loop has a seam: the body jumps %d px from its last pose to its first" % roundi(seam))
	elif last < D - 1e-3 and last < 0.0:
		errs.append("an act's poses end before the effect starts")
	# the smooth stretches: a hand moving more than this in one 12 fps step is a pop nobody asked for
	for i in range(1, k.size()):
		var t0: float = k[i - 1][0]
		var t1: float = k[i][0]
		var how: Variant = k[i][2] if k[i].size() > 2 else null
		if how == "snap" or t1 - t0 < 1.0 / 12.0:
			continue
		var t := t0
		while t < t1 - 1.0 / 12.0:
			var p := _hands(Px.Act.poseAt(k, t))
			var q := _hands(Px.Act.poseAt(k, t + 1.0 / 12.0))
			var d := maxf(Px.hypot(p[0] - q[0], p[1] - q[1]), Px.hypot(p[2] - q[2], p[3] - q[3]))
			if d > 30.0:
				notes.append("act: a hand jumps %d px in one step at t = %.2f: add a key or mark it \"snap\"" % [roundi(d), t])
				break
			t += 1.0 / 12.0
	# it runs, ends and doesn't throw
	var inst := Px.Act.createAct(fx.mod, {"x": 100.0, "y": 100.0})
	var f := Px.createFrame(400, 300)
	for i in 900:
		if inst.done():
			break
		inst.update(1.0 / 30.0)
		if i % 3 == 0:
			inst.draw(f.clear())
	if not meta.loop and not inst.done():
		errs.append("the act never ends")


static func _count(buf: PackedInt32Array, test: Callable) -> int:
	var n := 0
	for i in buf.size():
		if test.call(buf[i], i):
			n += 1
	return n


func _drawAt(fx: Dictionary, t: float, frame: Px.Frame, opts: Dictionary) -> void:
	var p := Px.painterFor(frame.clear())
	p.place(fx.meta.origin[0], fx.meta.origin[1])
	if Px.Fx.info(fx.mod).back:
		fx.mod.drawBack(p, t, opts)
	fx.mod.draw(p, t, opts)


func run(ids: PackedStringArray, _flags: Dictionary) -> int:
	var fails := 0
	var warns := 0
	for id in ids:
		var errs := []
		var notes := []
		var fx := Lib.loadEffect(id)
		if fx.has("error"):
			errs.append(fx.error)
		else:
			_check(fx, errs, notes)
		if errs.size():
			fails += 1
		if notes.size():
			warns += 1
		var tag := "FAIL" if errs.size() else ("warn" if notes.size() else "ok  ")
		if errs.size() or notes.size() or ids.size() < 40:
			print("%s  %s%s" % [tag, id, "".join((errs + notes).map(func(s): return "\n      " + s))])
	print("\n%d effects: %d pass, %d fail, %d with warnings" % [ids.size(), ids.size() - fails, fails, warns])
	return 1 if fails else 0


func _check(fx: Dictionary, errs: Array, notes: Array) -> void:
	var meta: Dictionary = fx.meta
	var mod: Script = fx.mod
	var src := FileAccess.get_file_as_string(fx.path)
	if not (meta.get("name") is String) or not meta.name:
		errs.append("meta.name missing")
	if not (meta.get("desc") is String) or String(meta.desc).length() < 12:
		errs.append("meta.desc missing or too short")
	elif String(meta.desc).length() > 180:
		notes.append("desc is %d chars (keep it under 180)" % String(meta.desc).length())
	if not (meta.get("tags") is Array) or meta.tags.is_empty():
		errs.append("meta.tags missing")
	var size: Variant = meta.get("size")
	if not (size is Array) or size.size() != 2 or size.any(func(v): return typeof(v) != TYPE_INT or v < 8 or v > 480):
		errs.append("meta.size must be [w, h], whole pixels 8..480")
	if not (meta.get("origin") is Array) or meta.origin.size() != 2:
		errs.append("meta.origin must be [x, y]")
	if not (float(meta.duration) > 0.0 and float(meta.duration) <= 12.0):
		errs.append("meta.duration must be 0..12 s")
	if not (meta.bg in Px.Scene.BACKDROPS):
		errs.append("meta.bg must be one of %s" % ", ".join(Px.Scene.BACKDROPS))
	var taken := (meta.get("options", {}) as Dictionary).keys().filter(func(k): return k in ["x", "y", "flip", "angle", "light"])
	if taken.size():
		errs.append("option %s is reserved for placement and glow: rename it" % ", ".join(taken))
	for bad in ["randf(", "randi(", "randf_range(", "randi_range(", "RandomNumberGenerator", "Time.get_", "OS.get_ticks"]:
		if bad in src:
			errs.append("uses %s: use Px.rng/rand/burst/cycle so frames repeat" % bad.trim_suffix("("))
	if Px.Fx.actOf(mod) != null:
		checkAct(fx, errs, notes)
	if errs.size():
		return
	var W: int = meta.size[0]
	var H: int = meta.size[1]
	var frame := Px.createFrame(W + M * 2, H + M * 2, -M, -M)
	var fw := frame.w
	var inside := func(i: int) -> bool:
		var x := (i % fw) - M
		var y := floori(i / float(fw)) - M
		return x >= 0 and y >= 0 and x < W and y < H
	var opts: Dictionary = (meta.get("options", {}) as Dictionary).duplicate(true)
	opts = Px.resolveOptions(meta, {"seed": opts.get("seed", 1.0)})
	var n := maxi(2, roundi(meta.duration * meta.fps))
	var maxPx := 0
	var spill := 0
	var spillLight := 0
	var ms := []
	var box := [INF, INF, -INF, -INF]
	var bounds := func():
		for j in frame.color.size():
			if (frame.color[j] >> 24) & 255:
				var x := (j % fw) - M
				var y := floori(j / float(fw)) - M
				box[0] = minf(box[0], x)
				box[2] = maxf(box[2], x)
				box[1] = minf(box[1], y)
				box[3] = maxf(box[3], y)
	var drawn := func(c, j): return ((c >> 24) & 255) and inside.call(j)
	var outside := func(c, j): return ((c >> 24) & 255) and not inside.call(j)
	var lit := func(c, j): return (c & 0xffffff) and inside.call(j)
	var glare := func(c, j): return (c & 255) + ((c >> 8) & 255) + ((c >> 16) & 255) > 90 and not inside.call(j)
	var kind: int = Px.Fx.info(mod).kind
	if kind == Px.Fx.Kind.PURE:
		for i in n + 1:
			var t: float = (float(i % n) / n) * meta.duration if meta.loop else (float(i) / n) * meta.duration
			var t0 := Time.get_ticks_usec()
			_drawAt(fx, t, frame, opts)
			ms.append((Time.get_ticks_usec() - t0) / 1000.0)
			maxPx = maxi(maxPx, maxi(_count(frame.color, drawn), _count(frame.light, lit)))
			spill = maxi(spill, _count(frame.color, outside))
			bounds.call()
			spillLight = maxi(spillLight, _count(frame.light, glare))
		# other seeds can throw particles further: look for spills with a few more
		for seed in [2.0, 3.0, 7.0]:
			var o2 := opts.duplicate()
			o2.seed = seed
			var i := 0
			while i <= n:
				_drawAt(fx, (float(i % n) / n) * meta.duration if meta.loop else (float(i) / n) * meta.duration, frame, o2)
				var sp := _count(frame.color, outside)
				if sp > spill:
					spill = sp
					bounds.call()
				i += 2
		if maxPx == 0:
			errs.append("draws nothing")
		if not meta.loop:
			_drawAt(fx, meta.duration, frame, opts)
			var left := _count(frame.color, drawn)
			if left > 0:
				notes.append("%d px still drawn at t = duration: one-shots should end empty" % left)
		else:
			var shots := []
			for i in n:
				_drawAt(fx, (float(i) / n) * meta.duration, frame, opts)
				shots.append(frame.color.duplicate())
			var diffs := []
			for i in n - 1:
				diffs.append(_diff(shots[i], shots[i + 1]))
			diffs.sort()
			var typical: int = diffs[floori(diffs.size() * 0.9)] if diffs.size() else 0
			var seam := _diff(shots[n - 1], shots[0])
			if seam > maxi(typical * 2, 12):
				notes.append("loop seam: %d px change from the last frame to the first (a normal step is %d)" % [seam, typical])
		# any palette works: a short one (resampled by resolveOptions) leaves no holes
		var short := Px.resolveOptions(meta, {"palette": ["#141024", "#5a3c8c", "#c8a0f0", "#ffffff"], "seed": opts.get("seed", 1.0)})
		for i in 9:
			_drawAt(fx, (i / 8.0) * meta.duration * (0.999 if meta.loop else 1.0), frame, short)
		# deterministic: the same t twice gives the same frame
		var tt: float = meta.duration * 0.37
		_drawAt(fx, tt, frame, opts)
		var once := frame.color.duplicate()
		_drawAt(fx, tt, frame, opts)
		if once != frame.color:
			errs.append("not deterministic: the same t drew different frames")
	else:
		# a simulation: step it in order, as a game would, and check every frame
		var runs := []
		for seed in [opts.get("seed", 1.0), opts.get("seed", 1.0), 2.0, 3.0, 7.0]:
			var o := opts.duplicate()
			o.merge({"x": float(meta.origin[0]), "y": float(meta.origin[1]), "seed": seed}, true)
			var inst := Px.createFx(mod, o)
			var shots := []
			for i in n + 1:
				if i:
					inst.update(1.0 / meta.fps)
				frame.clear()
				var t0 := Time.get_ticks_usec()
				inst.draw(frame)
				ms.append((Time.get_ticks_usec() - t0) / 1000.0)
				shots.append(frame.color.duplicate())
				maxPx = maxi(maxPx, maxi(_count(frame.color, drawn), _count(frame.light, lit)))
				var sp := _count(frame.color, outside)
				if sp > spill:
					spill = sp
					bounds.call()
				spillLight = maxi(spillLight, _count(frame.light, glare))
			runs.append(shots)
		if maxPx == 0:
			errs.append("draws nothing")
		if runs[0] != runs[1]:
			errs.append("not deterministic: two runs with the same seed differ")
		if not meta.loop:
			var left := _count(runs[0][runs[0].size() - 1], drawn)
			if left > 0:
				notes.append("%d px still drawn at t = duration: one-shots should end empty" % left)
	if spill > 0:
		notes.append("%d px drawn outside the %dx%d canvas (drawing spans x %d..%d, y %d..%d): grow size or move origin" % [spill, W, H, box[0], box[2], box[1], box[3]])
	if spillLight > 60:
		notes.append("glow spills %d px past the canvas" % spillLight)
	ms.sort()
	var med: float = ms[ms.size() >> 1] if ms.size() else 0.0
	if med > SLOW_MS:
		notes.append("slow: %.1f ms a frame (bake it, or play it LIVE sparingly)" % med)


static func _diff(a: PackedInt32Array, b: PackedInt32Array) -> int:
	var n := 0
	for i in a.size():
		if a[i] != b[i]:
			n += 1
	return n
