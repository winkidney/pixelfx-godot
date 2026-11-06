# ./pfx new <category>/<name> [--loop] [--sim]: a working starting point, then render it once.
#   pure one-shot (default), --loop for a seamless loop, --sim for a simulated effect with particles.
# port-of: tools/new.mjs (upstream)
extends RefCounted

const Lib := preload("fxlib.gd")


func run(pos: PackedStringArray, flags: Dictionary) -> int:
	var id: String = pos[0] if pos.size() else ""
	var re := RegEx.create_from_string("^[a-z0-9-]+/[a-z0-9-]+$")
	if not re.search(id):
		printerr("usage: ./pfx new <category>/<name> [--loop] [--sim]   (kebab-case)")
		return 1
	var path := Lib.pathOf(id)
	if FileAccess.file_exists(path):
		printerr(ProjectSettings.globalize_path(path), " already exists")
		return 1
	var cat := id.get_slice("/", 0)
	var name := id.get_slice("/", 1).replace("-", " ").capitalize()
	var loop: bool = flags.has("loop")
	var src: String
	var meta := """static var meta := {
	"name": "%s",
	"desc": "One line: what it is, how it moves.",
	"tags": ["%s"],
	"size": [48, 48],
	"origin": [24, 32],
	"duration": %s,
	"loop": %s,
	"fps": 30,
	"bg": "dark",
	"options": {"palette": Px.PAL.arcane, "seed": 1},
}""" % [name, cat, "1.2" if loop else "0.7", "true" if loop else "false"]
	if not loop and not flags.has("sim"):
		meta = meta.replace('"size": [48, 48]', '"size": [64, 64]').replace('"origin": [24, 32]', '"origin": [32, 28]')
	if flags.has("sim"):
		meta = meta.replace('"size": [48, 48]', '"size": [112, 96]').replace('"origin": [24, 32]', '"origin": [56, 72]')
		src = """# %s: a simulated effect. The script is its state: members are what persists between frames.
extends "../../core/effect.gd"

const Px := preload("../../core/px.gd")
const P := Px.P

%s

var C: Array
var R: Px.Rng
var ps: Px.Particles
var lights: Px.Lights
var t := 0.0


func create(o: Dictionary) -> void:
	C = Px.fit(o.palette, 7)
	R = Px.Rng.new(o.seed)
	ps = Px.Particles.new({"rng": R, "ground": func(): return 0.0})
	lights = Px.Lights.new()
	lights.add(0, -8, 30, C[4], 0.7, 0.4)
	for i in 30:
		var a := R.range(0.0, TAU)
		var sp := R.range(60.0, 200.0)
		ps.spawn(P.SPARK, 0, -8, cos(a) * sp, sin(a) * sp - 40.0, R.range(0.2, 0.5))


func update(dt: float) -> void:
	t += dt
	ps.update(dt)
	lights.update(dt)


func draw(p: Px.Painter) -> void:
	if t < 0.08:
		Px.sparkle(p, 0, -8, 8.0 * (1.0 - t / 0.08), C[5], C[3])
	ps.draw(p)
	lights.draw(p)
""" % [name, meta]
	elif loop:
		src = """# %s: a loop. Everything is a function of the phase, so t = 0 and t = duration match.
extends RefCounted

const Px := preload("../../core/px.gd")

%s


static func draw(p: Px.Painter, t: float, o: Dictionary) -> void:
	var C := Px.ramp(o.palette)
	var ph: float = t / meta.duration
	Px.cycle(t, meta.duration, 12, o.seed, 0.8, func(age: float, life: float, r: Px.Rng):
		var k: float = age / life
		var a: float = r.range(0.0, TAU) + ph * TAU
		var rad := 6.0 + k * 12.0
		p.px(cos(a) * rad, sin(a) * rad - 8.0, Px.at(C.slice(2), 1.0 - k)))
	p.circle(0, -8, 4.0 + sin(ph * TAU) * 1.5, C[5])
	p.glow(0, -8, 20, C[4], 0.35)
""" % [name, meta]
	else:
		src = """# %s: a one-shot. A hero frame, then everything falls away and is gone by t = duration.
extends RefCounted

const Px := preload("../../core/px.gd")

%s


static func draw(p: Px.Painter, t: float, o: Dictionary) -> void:
	var C := Px.ramp(o.palette)
	if t < 0.06:
		p.circle(0, -8, 6, Px.WHITE)
	Px.burst(14, o.seed, func(r: Px.Rng):
		var a := r.range(0.0, TAU)
		var sp := r.range(40.0, 90.0)
		var life := r.range(0.3, 0.6)
		if t > life:
			return
		var xy := Px.fly(0, -8, cos(a) * sp, sin(a) * sp, t, 120, 2)
		p.px(xy[0], xy[1], Px.at(C.slice(2), 1.0 - t / life))
		p.light(xy[0], xy[1], C[4], 0.5 * (1.0 - t / life)))
	p.glow(0, -8, 24, C[4], 0.5 * (1.0 - Px.seg(t, 0, 0.4)))
""" % [name, meta]
	Lib.save_text(path, src)
	print("wrote %s\nnext: ./pfx render %s   then look at records/%s/contact.png\na character in it? give it an act (see godot/docs/AUTHORING.md, \"Acts\"), then ./pfx act %s" % [ProjectSettings.globalize_path(path), id, id, id])
	return 0
