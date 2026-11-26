@tool
class_name PfxEffect
extends Node2D
## The root of every pixelfx particle effect scene (addons/pixelfx_particles/fx/<category>/<name>.tscn).
##
## A scene is GPUParticles2D emitters plus whatever else the effect needs (shader-drawn shapes, Line2D, sprites),
## timed by an AnimationPlayer named "AnimationPlayer" with an animation "fx" as long as the effect. This node plays
## it, stops it (a loop fades out), freezes it (speed 0, for hit-stop), flips it, recolours it by ramp name, and puts
## the stand-in character at its origin when the effect is about one. Its own position is the effect's origin:
## feet, point of impact, base of a torch.
##
## Layers: nodes with z_index < 0 draw behind the character, the rest in front. The colour layer uses the dither
## material (shaders/dither.gdshader: on/off alpha, palette snap), the light layer the light material
## (shaders/light.gdshader: additive).
##
## Sound: play() starts the effect's sound (addons/pixelfx_particles/sfx/<id>/full.ogg, on the effect's own clock) on
## an AudioStreamPlayer2D made at run time; a loop's sound loops, stop() fades it with the picture, speed 0 pauses it
## and speed scales its pitch. play_sound("hit") plays one phase on its own. See addons/pixelfx_particles/sfx/README.md.

signal finished

const FADE := 0.3
const DITHER := preload("../shaders/dither.gdshader")
const LIGHT := preload("../shaders/light.gdshader")
const SFX := "res://addons/pixelfx_particles/sfx/"
const MAX_TAILS := 2   # earlier plays of a one-shot still ringing out under the new one (3 voices with it at most)
const STAND_INS := ["", "res://addons/pixelfx_particles/actor/stock/hero1.png", "res://addons/pixelfx_particles/actor/stock/hero2.png"]

@export_group("Original")
## The effect's id, "category/name".
@export var effect_id := ""
## The upstream file this scene reimagines, path@git-blob (port/sync.mjs reads it).
@export var source := ""
@export var duration := 1.0
@export var loop := false
@export var fps := 30
## The original's canvas, and where this node's origin sits on it.
@export var canvas_size := Vector2i(64, 64)
@export var origin := Vector2i(32, 32)
## The original's preview backdrop: dark, ground, sky, black or light.
@export var bg := "dark"
## 0, or which stand-in the effect is about: 1 (12 x 19) or 2 (the 24 x 38 knight at rest).
@export var actor := 0
## The colour ramps, by the original's option names: name -> PackedColorArray, darkest first as in the original.
@export var ramps := {}
## Colours the palette snap keeps besides the ramps (white flashes, black ink, ...).
@export var palette_extra := PackedColorArray()
## Recolour the main ramp when the scene starts (set_palette): an effect cued in a move in other colours.
@export var palette_override := PackedColorArray()

@export_group("Play")
@export var autoplay := true
## Draw the stand-in at the origin (turn off when your own character is there).
@export var show_actor := true
@export var flip := false:
	set(v):
		flip = v
		scale.x = -absf(scale.x) if v else absf(scale.x)
## Strength of the additive light layer.
@export var light := 1.0:
	set(v):
		light = v
		_apply_light()
## Added to every emitter's own seed: another take of the same effect.
@export var take := 0:
	set(v):
		take = v
		_apply_seed()
## Time scale: 0 freezes everything (hit-stop), 1 is normal.
@export var speed := 1.0:
	set(v):
		speed = v
		_apply_speed()
## How visible the stand-in is (effects key it: a body that dissolves, a soul that leaves).
@export var actor_alpha := 1.0:
	set(v):
		actor_alpha = v
		if is_instance_valid(_stand_in):
			_stand_in.modulate.a = v

@export_group("Sound")
## Play the effect's sound. An effect cued inside another (a move's parts) stays quiet: the move has its own track.
@export var sound := true:
	set(v):
		sound = v
		if not v:
			_silence()
## The audio bus every voice of this effect plays on.
@export var sound_bus := &"Master":
	set(v):
		sound_bus = v
		for p in _voices + _tails:
			if is_instance_valid(p):
				p.bus = v
@export_range(-40.0, 12.0, 0.5, "suffix:dB") var sound_volume_db := 0.0:
	set(v):
		sound_volume_db = v
		for p in _voices:
			if is_instance_valid(p):
				p.volume_db = v

## Where the sound's players go when not under this node: an effect drawn in a SubViewport (pixel view) has no audio
## listener there, so the node showing it (PixelFxParticles2D) hosts them in the game's world, at the effect's origin.
var sound_parent: Node

static var _sfx_index := {}
static var _sfx_loaded := false

var t := 0.0
var _voices := []   # this play's: the full track and phases; they follow speed
var _tails := []    # earlier plays of a one-shot ringing out (stop() fades them too)
var _stop_at := -1.0
var _done := false
var _unique := false
var _particles: Array[GPUParticles2D] = []
var _seeds: Array[int] = []
var _speeds: Array[float] = []   # each emitter's own speed_scale (one can run on slowed time), times `speed`
var _emit_on: Array[bool] = []   # each emitter's `emitting` as saved: what play() puts back
var _nested: Array[PfxEffect] = []   # effects cued inside this one (a move's chain): each runs itself
var _anim: AnimationPlayer
var _stand_in: CanvasItem


func _ready() -> void:
	_collect()
	if palette_override.size():
		set_palette(palette_override)
	_apply_palette()
	_apply_light()
	_apply_seed()
	_apply_speed()
	if Engine.is_editor_hint():
		return
	if actor > 0 and show_actor and get_node_or_null("Actor") == null:
		var s := Sprite2D.new()
		s.name = "_StandIn"
		s.texture = load(STAND_INS[actor])
		s.centered = false
		s.offset = Vector2(-floorf(s.texture.get_width() / 2.0), -s.texture.get_height())
		s.modulate.a = actor_alpha
		add_child(s)
		_stand_in = s
	elif get_node_or_null("Actor") != null:
		_stand_in = get_node("Actor")
		_stand_in.visible = show_actor
	if autoplay:
		play()
	else:
		_hold()


func _collect() -> void:
	_particles.clear()
	_seeds.clear()
	_speeds.clear()
	_emit_on.clear()
	_nested.clear()
	for n in _own():
		if n is GPUParticles2D:
			_particles.append(n)
			_seeds.append(n.seed)
			_speeds.append(n.speed_scale)
			_emit_on.append(n.emitting)
	_anim = get_node_or_null("AnimationPlayer")


## Every node of this effect, leaving out the inside of effects cued in it (they look after themselves).
func _own() -> Array[Node]:
	var out: Array[Node] = []
	_walk(self, out)
	return out


func _walk(n: Node, out: Array[Node]) -> void:
	for c in n.get_children():
		if c is PfxEffect:
			_nested.append(c)
			continue
		out.append(c)
		_walk(c, out)


## Every ShaderMaterial in the scene whose shader has the given uniform (each shared one once).
func _materials(uniform: String) -> Array[ShaderMaterial]:
	var out: Array[ShaderMaterial] = []
	for n in _own():
		if not n is CanvasItem:
			continue
		var m: Material = n.material
		if m is ShaderMaterial and m.shader and not out.has(m):
			for u in m.shader.get_shader_uniform_list():
				if u.name == uniform:
					out.append(m)
					break
	return out


## Start (or restart) from the beginning.
func play() -> void:
	if _stop_at >= 0.0:
		_silence()   # still fading from stop(): that sound is over
	t = 0.0
	_stop_at = -1.0
	_done = false
	modulate.a = 1.0
	for i in _particles.size():
		# restart() switches emitting on: put back what the scene says (the animation turns the rest on when due)
		_particles[i].restart(true)
		_particles[i].emitting = _emit_on[i]
	for n in _nested:
		# a cue at 0 plays with this one; the rest wait for the animation to start them
		if n.autoplay:
			n.play()
		else:
			n._hold()
	if _anim and _anim.has_animation("fx"):
		_anim.play("fx")
		_anim.seek(0.0, true)
	_start_sound()


## Wait to be played: nothing emits, nothing left over from a previous run.
func _hold() -> void:
	t = 0.0
	_stop_at = -1.0
	_done = false
	for p in _particles:
		p.restart(true)
		p.emitting = false
	for n in _nested:
		n._hold()
	if _anim:
		_anim.stop()
	_silence()


## Let it end: emitters stop, and everything fades out over FADE seconds.
func stop() -> void:
	if _stop_at >= 0.0 or _done:
		return
	_stop_at = t
	for p in _particles:
		p.emitting = false
	for n in _nested:
		n.stop()


func is_done() -> bool:
	return _done


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _done:
		return
	t += delta * speed
	if _stop_at >= 0.0:
		var k := 1.0 - (t - _stop_at) / FADE
		modulate.a = clampf(k, 0.0, 1.0)
		for p in _voices + _tails:
			if is_instance_valid(p):
				p.volume_db = sound_volume_db + linear_to_db(clampf(k, 0.001, 1.0))
		if k <= 0.0:
			_silence()
			_finish()
	elif not loop and t >= duration:
		_finish()


func _finish() -> void:
	_done = true
	finished.emit()


func _apply_speed() -> void:
	for p in _voices:
		if is_instance_valid(p):
			# a freeze (hit-stop) does not pause the sound: the hit's crack rings on through it, and the body was
			# made to start after the freeze (port/sfx, references/sound.md). Slowed or sped-up time bends the pitch.
			if speed > 0.0:
				p.pitch_scale = speed
	if not is_inside_tree():
		return
	if _anim:
		_anim.speed_scale = speed
	for i in _particles.size():
		_particles[i].speed_scale = _speeds[i] * speed
	for n in _nested:
		n.speed = speed


## The effect's entry in the sound pack's index (addons/pixelfx_particles/sfx/index.json, read once): { sound: bool,
## why (when silent), loop, duration, length (full's seconds), phases: ["hit", "tail", ...], notes }. {} if unknown.
static func sound_info(id: String) -> Dictionary:
	if not _sfx_loaded:
		_sfx_loaded = true
		if FileAccess.file_exists(SFX + "index.json"):
			var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(SFX + "index.json"))
			if d is Dictionary:
				_sfx_index = d
	return _sfx_index.get(id, {})


## Play one phase of the effect's sound on its own (sound_info(effect_id).phases: "hit", "tail", "loop", ...), e.g. at
## the game's real moment of contact. It follows speed and stop() like the full track; a "loop" phase loops until
## stop(). Returns its player, or null (sound off, or no such phase).
func play_sound(phase: String) -> AudioStreamPlayer2D:
	if not sound or not is_inside_tree() or Engine.is_editor_hint():
		return null
	var st := _stream(phase)
	if st == null:
		push_warning("PfxEffect: %s has no sound phase \"%s\"" % [effect_id, phase])
		return null
	return _new_voice(st)


## Whether any of its sound is still playing (a one-shot's sound may ring on up to 1.5 s past its end).
func is_sounding() -> bool:
	for p in _voices + _tails:
		if is_instance_valid(p) and p.playing:
			return true
	return false


func _start_sound() -> void:
	for p in _voices.duplicate():
		if loop or not is_instance_valid(p) or not p.playing:
			_drop_voice(p)
		else:
			# a one-shot played again: the earlier play rings out under the new one, on its own
			_voices.erase(p)
			_tails.append(p)
			p.stream_paused = false
	while _tails.size() > MAX_TAILS:
		_drop_voice(_tails[0])
	if not sound or Engine.is_editor_hint() or not is_inside_tree() or _is_cued():
		return
	if not sound_info(effect_id).get("sound", false):
		return
	var st := _stream("full")
	if st:
		_new_voice(st)


## Cued inside another effect (a move's parts): the outer effect plays the sound.
func _is_cued() -> bool:
	var n := get_parent()
	while n:
		if n is PfxEffect:
			return true
		n = n.get_parent()
	return false


func _stream(phase: String) -> AudioStream:
	var path := SFX + effect_id + "/" + phase + ".ogg"
	if effect_id == "" or not ResourceLoader.exists(path):
		return null
	var st: AudioStream = load(path)
	if "loop" in st and (phase == "loop" or (phase == "full" and loop)):
		st.loop = true   # the import says so too; a file imported without the flag still loops
	return st


func _new_voice(st: AudioStream) -> AudioStreamPlayer2D:
	var p := AudioStreamPlayer2D.new()
	p.name = "_Sound"
	p.stream = st
	p.bus = sound_bus
	p.volume_db = sound_volume_db
	if speed > 0.0:
		p.pitch_scale = speed
	p.finished.connect(_drop_voice.bind(p))
	# internal: never saved with a scene, never among the effect's own nodes
	(sound_parent if is_instance_valid(sound_parent) else self).add_child(p, true, Node.INTERNAL_MODE_BACK)
	_voices.append(p)
	p.play()
	return p


func _drop_voice(p: Variant) -> void:   # untyped: it may be freed already
	_voices.erase(p)
	_tails.erase(p)
	if is_instance_valid(p):
		p.stop()
		p.queue_free()


## Every voice off, now.
func _silence() -> void:
	for p in _voices + _tails:
		_drop_voice(p)


func _notification(what: int) -> void:
	# voices hosted elsewhere (sound_parent) go with the effect
	if what == NOTIFICATION_PREDELETE:
		_silence()


func _apply_seed() -> void:
	if not is_inside_tree():
		return
	for i in _particles.size():
		_particles[i].seed = _seeds[i] + take
	for n in _nested:
		n.take = take


func _apply_light() -> void:
	if not is_inside_tree():
		return
	for m in _materials("strength"):
		m.set_shader_parameter("strength", light)
	for n in _nested:
		n.light = light


## The palette the dither material snaps to: every ramp colour plus palette_extra.
func _apply_palette() -> void:
	if not is_inside_tree():
		return
	var cols: Array[Color] = []
	for k in ramps:
		for c in ramps[k]:
			if not cols.has(c):
				cols.append(c)
	for c in palette_extra:
		if not cols.has(c):
			cols.append(c)
	var mats := _materials("palette_size")
	if cols.is_empty():
		for m in mats:
			m.set_shader_parameter("palette_size", 0)
		return
	var img := Image.create(cols.size(), 1, false, Image.FORMAT_RGBA8)
	for i in cols.size():
		img.set_pixel(i, 0, cols[i])
	var tex := ImageTexture.create_from_image(img)
	for m in mats:
		m.set_shader_parameter("palette", tex)
		m.set_shader_parameter("palette_size", cols.size())


## Recolour the ramp `name`: gradients built from it keep their place along it, and every other colour drawn in one of
## its colours (gradient stops, colour properties, shader uniforms, colour keys, the palette snap) takes the colour
## at the same step of the new ramp. The first recolour makes this instance's materials and animation its own, so
## other instances of the scene keep their colours.
func set_ramp(name: String, colors: PackedColorArray) -> void:
	if colors.is_empty():
		return
	_make_unique()
	var old: PackedColorArray = ramps.get(name, PackedColorArray())
	ramps[name] = colors
	var tagged: Array[Gradient] = []
	for g in _gradients():
		if String(g.get_meta("ramp", "")) != name:
			continue
		tagged.append(g)
		var at: PackedFloat32Array = g.get_meta("ramp_at", PackedFloat32Array())
		var cs := g.colors
		for i in cs.size():
			var u: float = at[i] if i < at.size() else (i / float(maxi(1, cs.size() - 1)))
			var c := colors[clampi(int(roundf(u * (colors.size() - 1))), 0, colors.size() - 1)]
			cs[i] = Color(c.r, c.g, c.b, cs[i].a)
		g.colors = cs
	if old.size():
		var swap := {}
		for i in old.size():
			var u := i / float(maxi(1, old.size() - 1))
			var key := old[i].to_html(false)
			if not swap.has(key):
				swap[key] = colors[clampi(int(roundf(u * (colors.size() - 1))), 0, colors.size() - 1)]
		_swap_colours(swap, tagged)
	_apply_palette()


## Every colour whose rgb is a key of `swap` becomes swap[key], keeping its alpha.
func _swap_colours(swap: Dictionary, skip: Array[Gradient]) -> void:
	var one := func(c: Color) -> Color:
		var k := c.to_html(false)
		if swap.has(k):
			var n: Color = swap[k]
			return Color(n.r, n.g, n.b, c.a)
		return c
	var many := func(v: Variant) -> Variant:
		if v is Color:
			return one.call(v)
		if v is PackedColorArray:
			var a: PackedColorArray = v.duplicate()
			for i in a.size():
				a[i] = one.call(a[i])
			return a
		if v is PackedVector4Array:
			var b: PackedVector4Array = v.duplicate()
			for i in b.size():
				var c: Color = one.call(Color(b[i].x, b[i].y, b[i].z, b[i].w))
				b[i] = Vector4(c.r, c.g, c.b, c.a)
			return b
		return v
	for g in _gradients():
		if not skip.has(g):
			g.colors = many.call(g.colors)
	var seen := {}
	for n in _own():
		for pr in n.get_property_list():
			if (pr.type == TYPE_COLOR or pr.type == TYPE_PACKED_COLOR_ARRAY) and pr.usage & PROPERTY_USAGE_STORAGE:
				n.set(pr.name, many.call(n.get(pr.name)))
		if n is GPUParticles2D and n.process_material is ParticleProcessMaterial and not seen.has(n.process_material):
			seen[n.process_material] = true
			n.process_material.color = one.call(n.process_material.color)
		if n is CanvasItem and n.material is ShaderMaterial and not seen.has(n.material):
			seen[n.material] = true
			for u in n.material.shader.get_shader_uniform_list():
				var v: Variant = n.material.get_shader_parameter(u.name)
				if v is Color or v is PackedColorArray or v is PackedVector4Array:
					n.material.set_shader_parameter(u.name, many.call(v))
	palette_extra = many.call(palette_extra)
	if _anim:
		for lib in _anim.get_animation_library_list():
			for an in _anim.get_animation_library(lib).get_animation_list():
				var a: Animation = _anim.get_animation_library(lib).get_animation(an)
				for tr in a.get_track_count():
					if a.track_get_type(tr) != Animation.TYPE_VALUE:
						continue
					for k in a.track_get_key_count(tr):
						var v: Variant = a.track_get_key_value(tr, k)
						if v is Color or v is PackedColorArray or v is PackedVector4Array:
							a.track_set_key_value(tr, k, many.call(v))


## Recolour the effect's main ramp ("palette" in most effects, else its first ramp).
func set_palette(colors: PackedColorArray) -> void:
	if ramps.has("palette"):
		set_ramp("palette", colors)
	elif ramps.size():
		set_ramp(ramps.keys()[0], colors)


func _gradients() -> Array[Gradient]:
	var out: Array[Gradient] = []
	var add := func(tex: Variant) -> void:
		if tex is GradientTexture1D or tex is GradientTexture2D:
			if tex.gradient and not out.has(tex.gradient):
				out.append(tex.gradient)
	for n in _own():
		if n is GPUParticles2D and n.process_material is ParticleProcessMaterial:
			add.call(n.process_material.color_ramp)
			add.call(n.process_material.color_initial_ramp)
		if n is Line2D and n.gradient and not out.has(n.gradient):
			out.append(n.gradient)
		if n is CanvasItem and n.material is ShaderMaterial:
			for u in n.material.shader.get_shader_uniform_list():
				add.call(n.material.get_shader_parameter(u.name))
		if "texture" in n:
			add.call(n.get("texture"))
	return out


func _make_unique() -> void:
	if _unique:
		return
	_unique = true
	var mats := {}
	for n in _own():
		if n is GPUParticles2D and n.process_material:
			n.process_material = n.process_material.duplicate(true)
		if n is Line2D and n.gradient:
			n.gradient = n.gradient.duplicate(true)
		if n is CanvasItem and n.material:
			if not mats.has(n.material):
				mats[n.material] = n.material.duplicate(true)
			n.material = mats[n.material]
		if "texture" in n and n.get("texture") is GradientTexture1D:
			n.set("texture", n.get("texture").duplicate(true))
	if _anim:
		# colour keys get recoloured too: this instance's own copy of the animation, playing on from where it was
		var at := _anim.current_animation_position if _anim.is_playing() else -1.0
		var cur := _anim.current_animation
		for lib in _anim.get_animation_library_list():
			var copy: AnimationLibrary = _anim.get_animation_library(lib).duplicate(true)
			_anim.remove_animation_library(lib)
			_anim.add_animation_library(lib, copy)
		if at >= 0.0 and cur != "":
			_anim.play(cur)
			_anim.seek(at, true)
