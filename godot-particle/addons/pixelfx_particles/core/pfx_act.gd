@tool
class_name PfxAct
extends Node2D
## An effect acted out: the knight winds up, lets go and recovers, a straw target takes the hit, everything freezes
## for a moment on contact and the screen shakes. The knight and the target are the pixel port's own frames
## (actor/acts/<cat>-<name>/: body.png, target.png, act.json, exported by `./pfx export actors`); the effect is the
## particle scene, started when the act reaches the effect's t = 0 and frozen with the act; dust, straw and after-
## images are made here. Its origin is the knight's feet at rest (the effect's origin).

signal hit(index: int)
signal finished

const ACTS := "res://addons/pixelfx_particles/actor/acts/"
const FX := "res://addons/pixelfx_particles/fx/"
const GHOST_LIFE := 0.24

@export var effect_id := "":
	set(v):
		effect_id = v
		if is_inside_tree():
			_load()
@export var autoplay := true
@export var show_target := true
## Shake the act (off when your camera shakes instead).
@export var shake := true
## Time scale (0 freezes it).
@export var speed := 1.0

var data := {}
var t := 0.0
var _frame := -1
var _stage: Node2D
var _body: Sprite2D
var _target: Sprite2D
var _fx: Node2D
var _fx_on := false
var _hits_done := 0
var _ghost_acc := 0.0
var _ghosts: Array[Sprite2D] = []
var _done := false
var _pelvis0 := Vector2.ZERO


func _ready() -> void:
	if effect_id:
		_load()


func _load() -> void:
	for c in get_children():
		c.queue_free()
	var dir := ACTS + effect_id.replace("/", "-") + "/"
	if not FileAccess.file_exists(dir + "act.json"):
		push_error("PfxAct: no act for %s" % effect_id)
		return
	data = JSON.parse_string(FileAccess.get_file_as_string(dir + "act.json"))
	var pivot := Vector2(data.pivot[0], data.pivot[1])
	_stage = Node2D.new()
	_stage.name = "Stage"
	add_child(_stage)
	_body = _sheet(dir + "body.png", data.body, pivot, "Body")
	_target = _sheet(dir + "target.png", data.target, pivot, "Target")
	_target.visible = show_target
	_target.z_index = -1
	var path := FX + effect_id + ".tscn"
	if ResourceLoader.exists(path):
		_fx = load(path).instantiate()
		_fx.autoplay = false
		_fx.show_actor = false
		_fx.speed = 0.0
		_fx.visible = false
		_stage.add_child(_fx)
	var f0: Dictionary = data.frames[0]
	_pelvis0 = Vector2(f0.j.pelvis[0], f0.j.pelvis[1])
	_spawn_bursts(pivot)
	if autoplay and not Engine.is_editor_hint():
		play()


func _sheet(png: String, info: Dictionary, pivot: Vector2, name_: String) -> Sprite2D:
	var s := Sprite2D.new()
	s.name = name_
	s.texture = load(png)
	s.centered = false
	s.hframes = int(info.cols)
	s.vframes = maxi(1, int(ceil(float(info.count) / info.cols)))
	s.position = Vector2(info.at[0], info.at[1]) - pivot
	_stage.add_child(s)
	return s


## Dust where the feet push off and straw where the target is hit: one-shot bursts, fired on their beats.
func _spawn_bursts(pivot: Vector2) -> void:
	var i := 0
	for d in data.get("dust", []):
		var p := _burst("Dust%d" % i, Vector2(d.get("x", 0.0), -1.0), int(d.get("n", 6)), d.get("dir", 1.0), Color("#6e6382"), 0.5, [20.0, 55.0])
		p.set_meta("at", float(d.t))
		i += 1
	i = 0
	var tx: float = data.targets[0] if data.targets.size() else 66.0
	for h in data.get("hits", []):
		if h.get("target") == false or int(h.get("straw", 8)) <= 0:
			continue
		var p := _burst("Straw%d" % i, Vector2(tx, -26.0), int(h.get("straw", 8)), -1.0 if data.flip else 1.0, Color("#d9a441"), 0.9, [30.0, 90.0])
		p.set_meta("at", float(h.t))
		i += 1


func _burst(name_: String, at: Vector2, n: int, dir: float, c: Color, life: float, sp: Array) -> GPUParticles2D:
	var p := GPUParticles2D.new()
	p.name = name_
	p.position = at
	p.amount = maxi(1, n)
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 1.0
	p.emitting = false
	p.use_fixed_seed = true
	p.seed = absi(hash(effect_id + name_)) % 100000
	p.texture = load("res://addons/pixelfx_particles/textures/dot1.png")
	var m := ParticleProcessMaterial.new()
	m.particle_flag_disable_z = true
	m.direction = Vector3(dir, -0.6, 0)
	m.spread = 35.0
	m.initial_velocity_min = sp[0]
	m.initial_velocity_max = sp[1]
	m.gravity = Vector3(0, 220, 0)
	m.color = c
	m.alpha_curve = null
	p.process_material = m
	p.material = load("res://addons/pixelfx_particles/shaders/dither_material.tres") if ResourceLoader.exists("res://addons/pixelfx_particles/shaders/dither_material.tres") else null
	_stage.add_child(p)
	return p


func play() -> void:
	t = 0.0
	_frame = -1
	_fx_on = false
	_hits_done = 0
	_done = false
	if _fx:
		_fx.visible = false
		_fx.speed = 0.0
	_apply(0)


func is_done() -> bool:
	return _done


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or data.is_empty() or _done:
		return
	t += delta * speed
	var n: int = data.frames.size()
	var i := mini(n - 1, int(floor(t * float(data.fps) + 1e-6)))
	if i != _frame:
		_apply(i)
	_age_ghosts(delta * speed)
	if i >= n - 1:
		_done = true
		finished.emit()


func _apply(i: int) -> void:
	_frame = i
	var f: Dictionary = data.frames[i]
	_body.frame = int(f.b)
	_target.frame = int(f.g)
	_stage.position = Vector2(f.shake[0], f.shake[1]) if shake else Vector2.ZERO
	var act_t: float = f.t
	if _fx:
		if not _fx_on and act_t >= 0.0:
			_fx_on = true
			_fx.visible = true
			_fx.play()
		_fx.speed = 0.0 if (f.frozen or not _fx_on) else speed
		if data.onBody:
			# an effect on the body follows it as it moves (its pelvis against where it stands at rest)
			_fx.position = Vector2(f.j.pelvis[0], f.j.pelvis[1]) - _pelvis0
	for c in _stage.get_children():
		if c is GPUParticles2D and c.has_meta("at") and not c.get_meta("fired", false) and act_t >= float(c.get_meta("at")):
			c.set_meta("fired", true)
			c.restart(true)
	while _hits_done < data.hits.size() and act_t >= float(data.hits[_hits_done].t):
		hit.emit(_hits_done)
		_hits_done += 1
	if f.ghost:
		_ghost_acc += 1.0 / float(data.fps)
		if _ghost_acc >= 1.0 / 30.0:
			_ghost_acc = 0.0
			_add_ghost()


func _add_ghost() -> void:
	var g := Sprite2D.new()
	g.texture = _body.texture
	g.hframes = _body.hframes
	g.vframes = _body.vframes
	g.frame = _body.frame
	g.centered = false
	g.position = _body.position
	g.modulate = Color(data.ghostColor)
	g.z_index = -1
	g.set_meta("age", 0.0)
	_stage.add_child(g)
	_ghosts.append(g)
	if _ghosts.size() > 7:
		_ghosts.pop_front().queue_free()


func _age_ghosts(dt: float) -> void:
	for g in _ghosts.duplicate():
		var a: float = g.get_meta("age") + dt
		g.set_meta("age", a)
		g.modulate.a = clampf(1.0 - a / GHOST_LIFE, 0.0, 1.0) * 0.6
		if a > GHOST_LIFE:
			_ghosts.erase(g)
			g.queue_free()
