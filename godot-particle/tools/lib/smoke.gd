# ./pfxp smoke [ids]: every built effect through the nodes a game uses, for real (under xvfb-run): PixelFxParticles2D
# (pixel view, a recolour, flipped) played to its end, and PixelFxParticlesAct2D for the effects with an act. A
# one-shot must say `finished`; an effect with sound (addons/pixelfx_particles/sfx/index.json) must be playing it (the
# Dummy audio driver: nothing is heard); nothing may error (Godot prints errors itself; the exit code counts what this
# sees).
extends RefCounted


func run(tree: SceneTree, ids: PackedStringArray, flags: Dictionary) -> int:
	var REG: Script = load("res://addons/pixelfx_particles/fx/registry.gd")
	var effects: Dictionary = REG.EFFECTS
	var bad := 0
	var n := 0
	for id in ids:
		if not effects.has(id):
			continue
		n += 1
		var e: Dictionary = effects[id]
		var fx := Node2D.new()
		fx.set_script(load("res://addons/pixelfx_particles/nodes/pixel_fx_particles_2d.gd"))
		fx.zoom = 2
		fx.flip = true
		fx.palette_preset = "arcane"
		fx.position = Vector2(200, 200)
		var said := [false]
		fx.finished.connect(func(): said[0] = true)
		tree.root.add_child(fx)
		fx.effect = id
		var frames := int(ceil((float(e.duration) + 0.5) * 30.0))
		if e.loop:
			frames = 20
		var sounds: bool = PfxEffect.sound_info(id).get("sound", false)
		for i in frames:
			await tree.process_frame
			if i == 2 and sounds and not _sounding(fx):
				print("FAIL  %s: its sound isn't playing" % id)
				bad += 1
		if e.loop:
			fx.stop()
			for i in 15:
				await tree.process_frame
		if not said[0]:
			print("FAIL  %s: no finished signal" % id)
			bad += 1
		fx.queue_free()
		if e.act:
			var act := Node2D.new()
			act.set_script(load("res://addons/pixelfx_particles/nodes/pixel_fx_particles_act_2d.gd"))
			act.zoom = 2
			act.position = Vector2(300, 300)
			var done := [false]
			act.finished.connect(func(): done[0] = true)
			tree.root.add_child(act)
			act.effect = id
			var heard := false
			for i in 900:
				await tree.process_frame
				heard = heard or _sounding(act)
				if done[0]:
					break
			if not done[0]:
				print("FAIL  %s act: no finished signal" % id)
				bad += 1
			if sounds and not heard:
				print("FAIL  %s act: its sound never played" % id)
				bad += 1
			act.queue_free()
		await tree.process_frame
		if not flags.has("quiet"):
			print("ok    ", id)
	# the audio server lets go of the last players freed on its own thread: give it a moment, so quitting leaks nothing
	OS.delay_msec(100)
	await tree.process_frame
	print("\n%d effects through the nodes, %d failed" % [n, bad])
	return 1 if bad else 0


## A player of the effect's sound is playing (PfxEffect hosts them under the node, as internal children).
static func _sounding(n: Node) -> bool:
	for c in n.get_children(true):
		if c is AudioStreamPlayer2D and c.playing:
			return true
	return false
