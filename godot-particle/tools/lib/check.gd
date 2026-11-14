# ./pfxp check: what can be caught without rendering. FAIL stops a port; warn is worth a look.
#   the scene loads, its root is a PfxEffect, and its meta matches the original (port/meta.json)
#   the "fx" animation is as long as the effect and loops when it does; every track's node exists
#   every emitter has a fixed seed, a process material and a texture; no shader reads TIME (time comes from the
#   animation, so a capture and a freeze are exact)
#   a one-shot's emitters are done by its end; a loop's continuous emitters are preprocessed (no empty first frame)
#   the colour layer has the dither material; a light-layer item is additive
#   budget: 4000 particles at once
extends RefCounted

const Build := preload("res://addons/pixelfx_particles/core/build.gd")
const EFFECT := preload("res://addons/pixelfx_particles/core/pfx_effect.gd")
const BUDGET := 4000


func run(ids: PackedStringArray, flags: Dictionary) -> int:
	var fails := 0
	var warns := 0
	for id in ids:
		var r := check(id)
		if r.fail.size():
			fails += 1
			print("FAIL  ", id)
		elif r.warn.size():
			warns += 1
			print("warn  ", id)
		elif not flags.has("quiet"):
			print("ok    ", id)
		for m in r.fail:
			print("      ", m)
		for m in r.warn:
			print("      ", m)
	print("\n%d effects: %d pass, %d fail, %d with warnings" % [ids.size(), ids.size() - fails, fails, warns])
	return 1 if fails else 0


func check(id: String) -> Dictionary:
	var fail := []
	var warn := []
	var path := "res://addons/pixelfx_particles/fx/%s.tscn" % id
	if not ResourceLoader.exists(path):
		return {"fail": ["no scene (./pfxp build %s)" % id], "warn": []}
	var packed: PackedScene = load(path)
	var fx: Node = packed.instantiate() if packed else null
	if fx == null or fx.get_script() != EFFECT:
		if fx:
			fx.free()
		return {"fail": ["the root isn't a PfxEffect"], "warn": []}
	var m := Build.meta_of(id)
	var want := {"effect_id": id, "source": m.source, "duration": float(m.duration), "loop": m.loop, "fps": int(m.fps),
		"canvas_size": Vector2i(m.size[0], m.size[1]), "origin": Vector2i(m.origin[0], m.origin[1]), "bg": m.bg, "actor": int(m.actor)}
	for k in want:
		var got: Variant = fx.get(k)
		if (got is float and absf(got - want[k]) > 1e-4) or (not got is float and got != want[k]):
			fail.append("%s is %s, the original's is %s" % [k, got, want[k]])
	var ap: AnimationPlayer = fx.get_node_or_null("AnimationPlayer")
	var anim: Animation = ap.get_animation("fx") if ap and ap.has_animation("fx") else null
	if anim == null:
		fail.append("no AnimationPlayer with an \"fx\" animation")
	else:
		if absf(anim.length - fx.duration) > 1e-3:
			fail.append("fx animation is %.3f s, the effect %.3f s" % [anim.length, fx.duration])
		if (anim.loop_mode != Animation.LOOP_NONE) != fx.loop:
			fail.append("fx animation %s but the effect %s" % ["loops" if anim.loop_mode != Animation.LOOP_NONE else "doesn't loop", "loops" if fx.loop else "doesn't"])
		for tr in anim.get_track_count():
			var tp := anim.track_get_path(tr)
			var target := fx.get_node_or_null(NodePath(tp.get_concatenated_names()))
			if target == null:
				fail.append("track %s: no such node" % tp)
	var total := 0
	for p in fx.find_children("*", "GPUParticles2D", true, false):
		var gp := p as GPUParticles2D
		var nm := String(fx.get_path_to(gp))
		total += gp.amount
		if not gp.use_fixed_seed:
			fail.append("%s: no fixed seed" % nm)
		if gp.process_material == null:
			fail.append("%s: no process material" % nm)
		if gp.sub_emitter != NodePath() or (gp.process_material is ParticleProcessMaterial and gp.process_material.sub_emitter_mode != ParticleProcessMaterial.SUB_EMITTER_DISABLED):
			fail.append("%s: sub-emitters don't work in the Compatibility renderer" % nm)
		if gp.trail_enabled:
			fail.append("%s: trails don't work in the Compatibility renderer" % nm)
		if gp.texture == null:
			warn.append("%s: no texture (draws 1 px squares)" % nm)
		if not fx.loop:
			var end := _last_on(anim, fx, gp) + gp.lifetime * (1.0 if gp.one_shot else 1.0)
			if end > fx.duration + 0.05:
				warn.append("%s: particles live on to %.2f s, past the end (%.2f s)" % [nm, end, fx.duration])
		elif not gp.one_shot and gp.emitting and gp.preprocess <= 0.0:
			warn.append("%s: a loop's emitter with no preprocess starts empty" % nm)
	if total > BUDGET:
		warn.append("%d particles at most, over the budget of %d" % [total, BUDGET])
	for n in fx.find_children("*", "CanvasItem", true, false):
		var ci := n as CanvasItem
		if ci is GPUParticles2D or ci is Sprite2D or ci is Line2D or ci is ColorRect or ci is TextureRect or ci is Polygon2D:
			if ci.material == null and not String(ci.name).begins_with("_"):
				warn.append("%s: no material (neither the dither colour layer nor the light layer)" % fx.get_path_to(ci))
			elif ci.material is ShaderMaterial and ci.material.shader:
				if _reads_time(ci.material.shader.code):
					fail.append("%s: its shader reads TIME (use a uniform the animation keys)" % fx.get_path_to(ci))
		if ci is GPUParticles2D and ci.process_material is ShaderMaterial and ci.process_material.shader:
			if _reads_time(ci.process_material.shader.code):
				fail.append("%s: its process shader reads TIME (use a uniform the animation keys)" % fx.get_path_to(ci))
	fx.free()
	return {"fail": fail, "warn": warn}


## When an emitter is last switched on (0 if it's never keyed).
static func _last_on(anim: Animation, fx: Node, gp: GPUParticles2D) -> float:
	if anim == null:
		return 0.0
	var tr := anim.find_track(NodePath(String(fx.get_path_to(gp)) + ":emitting"), Animation.TYPE_VALUE)
	if tr < 0:
		return 0.0 if gp.emitting else 0.0
	var last := 0.0
	for k in anim.track_get_key_count(tr):
		if anim.track_get_key_value(tr, k):
			last = anim.track_get_key_time(tr, k)
	if not gp.one_shot:
		# a continuous emitter runs until it's switched off
		for k in anim.track_get_key_count(tr):
			if not anim.track_get_key_value(tr, k) and anim.track_get_key_time(tr, k) > last:
				return anim.track_get_key_time(tr, k)
		return anim.length
	return last


static func _reads_time(code: String) -> bool:
	# comments don't count: strip /* ... */ and // ... first
	var bare := RegEx.create_from_string("(?s)/\\*.*?\\*/").sub(code, "", true)
	bare = RegEx.create_from_string("//[^\\n]*").sub(bare, "", true)
	return RegEx.create_from_string("\\bTIME\\b").search(bare) != null
