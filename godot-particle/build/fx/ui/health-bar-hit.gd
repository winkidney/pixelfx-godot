# reimagined-from: src/fx/ui/health-bar-hit.js@14c43a3c6f6b7f46b0827798ccb27c8aed5e23ce
# Health bar hit: A segmented health bar takes a hit: it jolts and dips, the lost chunk flashes white and sheds chips, holds, then drains away behind a sparking edge.
# one-shot, 2.00 s, 160x64 canvas, origin [80.0, 30.0], backdrop dark
# ramp palette: #1a0508 #4a0b12 #8c1420 #d42a2e #ff5a4a #ff9a86 #ffd8cc #ffffff
# The HUD (plate, segmented bar, white chunk, edges, heart) is one canvas shader (fx/ui/_hbar.gdshader, the original's
# own pixel rules) keyed every frame from the original's jolt, dip, unfold and drain. Chips, sparks and the drain's
# sparks are frame-table particles from the original's simulation replayed at its 120 Hz steps (_ui.gd); every
# light is a light table.
extends "res://build/fx/ui/_ui.gd"

const HIT := 0.2
const DRAIN := 0.62
const DRAINED := 1.05
const FOLD := 1.62
const BX := -48.0
const BW := 104.0
const BY := -4.0
const BH := 8.0
const HEART := [
	"..kkk...kkk..",
	".khhok.khook.",
	"khwhookoooomk",
	"khwoooooooomk",
	"khoooooooommk",
	"kooooooooomdk",
	".kooooooomdk.",
	"..kooooomdk..",
	"...kooomdk...",
	"....komdk....",
	".....kdk.....",
	"......k......",
]


func make() -> void:
	var W := Color.WHITE
	var seed_: int = int(meta.options.seed)
	var R := JsRng.new(seed_)
	var from := clampf(float(meta.options.from), 0.0, 1.0)
	var to := clampf(minf(float(meta.options.to), from), 0.0, 1.0)
	var ps := sim_new(R, [C[7], C[6], C[5], C[3]])
	var bits := bits_new()
	var lights := lights_new()
	var pale := mixc(C[6], Color("#ffe9a8"), 0.5)
	var st := {"hit": false}
	var ghost_at := func(t: float) -> float: return from if t < DRAIN else from - (from - to) * in_out_quad(seg(t, DRAIN, DRAINED))
	var img := Image.create(13, 12, false, Image.FORMAT_R8)
	for j in 12:
		for i in 13:
			var code: int = {".": 0, "k": 1, "w": 2, "h": 3, "o": 4, "m": 5, "d": 6}[HEART[j][i]]
			img.set_pixel(i, j, Color8(code, 0, 0))
	var ink := [Color("#0d0a14"), Color("#4a4060"), Color("#2a2338"), Color("#1e1929"), Color("#141019")]
	var hud := shape("Hud", ush("hbar"), canvas_rect().size, {"C": C, "ink": ink, "track": [Color("#0d0a14"), Color("#2a2338"), Color("#191424")],
		"pale": pale, "heart": asset("_heart", img)}, {"at": canvas_rect().get_center()})
	var front := group("Front")
	var gbits := group("Chips")
	var gps := group("Sparks")

	var upd := func(dt: float) -> void:
		var t := T
		if not st.hit and t >= HIT:
			st.hit = true
			lights_add(lights, BX + BW * (to + from) / 2.0, BY + 4, 50, C[5], 0.7, 0.3)
			lights_add(lights, BX + BW * (to + from) / 2.0, BY + 4, 24, W, 0.6, 0.08)
			for i in 12:
				var x := BX + BW * R.range(to, from)
				var an := -PI / 2.0 + R.range(-1.2, 1.2)
				var sp := R.range(50, 130)
				var o := {"kind": 0, "x": x}
				o.y = BY + R.range(1, 7)
				o.vx = cos(an) * sp
				o.vy = sin(an) * sp
				o.g = 0.45
				o.drag = 1.2
				o.life = R.range(0.35, 0.6)
				o.a = R.range(0, TAU)
				o.va = R.range(-20, 20)
				o.s = R.range(1.5, 3)
				o.c = R.pick([C[7], C[6], C[5], C[4]])
				bits_add(bits, o)
			for i in 10:
				var an := R.range(0, TAU)
				var sp := R.range(60, 160)
				spawn(ps, SPARK, BX + BW * R.range(to, from), BY + 4, cos(an) * sp, sin(an) * sp * 0.6 - 30, R.range(0.12, 0.26))
		if t > DRAIN and t < DRAINED and R.chance(0.5):
			var x: float = BX + BW * ghost_at.call(t)
			spawn(ps, SPARK, x, BY + R.range(1, 7), R.range(-20, 60), -R.range(20, 70), R.range(0.1, 0.22))
		bits_update(bits, dt)
		sim_update(ps, dt)
		lights_update(lights, dt)

	var drw := func(_f: int) -> void:
		var t := T
		var jj := shake(t, 3, HIT, 0.28, seed_)
		var dip := jround(3.0 * exp(-(t - HIT) * 10.0) * cos((t - HIT) * 24.0)) if t > HIT else 0.0
		var open := out_back(seg(t, 0, 0.14), 2) * (1.0 - in_back(seg(t, FOLD, FOLD + 0.18), 2))
		var bar := false
		lay = "front"
		fk(hud, "material:shader_parameter/open_on", open > 0.04)
		if open > 0.04:
			var ox: float = jj[0]
			var oy: float = jj[1] + dip
			var h := 18.0 * open
			var y0 := -9.0 + (18.0 - h) / 2.0
			fk(hud, "material:shader_parameter/red", t >= HIT and t < HIT + 0.07)
			fk(hud, "material:shader_parameter/prc", Vector4(BX - 22.0 + ox, y0 + oy, BW + 26.0, h))
			fk(hud, "material:shader_parameter/pr", minf(5.0, h / 2.0))
			if open > 0.75:
				bar = true
				var val := from if t < HIT else to
				var ghost: float = from if t < HIT else ghost_at.call(t)
				fk(hud, "material:shader_parameter/off", Vector2(ox, oy))
				fk(hud, "material:shader_parameter/val", val)
				fk(hud, "material:shader_parameter/ghost", ghost)
				fk(hud, "material:shader_parameter/white", t >= HIT and t < HIT + 0.07)
				fk(hud, "material:shader_parameter/edge_on", t > HIT)
				fk(hud, "material:shader_parameter/val_x", jround(BX + ox + jround(BW * val) - 1.0))
				var drain := t > DRAIN and t < DRAINED
				fk(hud, "material:shader_parameter/drain_on", drain)
				if drain:
					var gx := BX + ox + BW * ghost
					fk(hud, "material:shader_parameter/drain_x", Vector2(jround(gx - 1.0), jround(gx + 1.0)))
					pglow(gx, BY + oy + 4.0, 10, C[5], 0.6)
				pglow(BX + ox + BW * val * 0.5, BY + oy + 4.0, BW * 0.4, C[3], 0.12)
				var hk := t - HIT
				var hop := jround(-3.0 * exp(-hk * 12.0) * absf(cos(hk * 22.0))) if hk > 0.0 else 0.0
				fk(hud, "material:shader_parameter/heart_at", Vector2(BX - 17.0 + ox, oy - 6.0 + hop))
				fk(hud, "material:shader_parameter/heart_white", hk > 0.0 and hk < 0.07)
				pglow(BX - 11.0 + ox, oy, 10, C[4], 0.25 + (0.4 if (hk > 0.0 and hk < 0.2) else 0.0))
				if t < HIT and fmod(t * 2.5, 1.0) < 0.3:
					psparkle(BX - 14.0 + ox, oy - 3.0, 2, C[7], C[6], 0.3)
		fk(hud, "material:shader_parameter/bar_on", bar)
		lay = "bits"
		bits_draw(bits)
		lay = "ps"
		sim_draw(ps)
		lights_draw(lights)

	run(upd, drw)
	utable("Front", "front", {"parent": front})
	utable("Chips", "bits", {"parent": gbits})
	utable("Sparks", "ps", {"parent": gps})
	light_table()
	flush_keys()
