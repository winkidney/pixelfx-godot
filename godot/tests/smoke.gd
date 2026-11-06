extends SceneTree

const Px := preload("res://addons/pixelfx/core/px.gd")


func _initialize() -> void:
	var code: Variant = run()
	quit(code if code is int else 1)


func run() -> int:
	print("hash(1,2)=", Px.hash(1, 2), " rand(3,4,5)=", Px.rand(3, 4, 5))
	var r := Px.Rng.new(7)
	print("rng7: ", r.next(), " ", r.next(), " ", r.range(2, 5), " ", r.int_(0, 10))
	print("noise2=", Px.noise2(1.3, 2.7, 4), " fbm=", Px.fbm(0.5, 0.25, 3), " hypot=", Px.hypot(3, 4), " round(-2.5)=", Px.round(-2.5))
	print("hex=", Px.hex("#ff8800"), " mix=", Px.mix(Px.hex("#000000"), Px.WHITE, 0.5), " fit=", Px.fit(Px.PAL.fire, 4))
	var f := Px.createFrame(32, 32)
	var p := Px.painterFor(f)
	p.place(16, 16)
	p.circle(0, 0, 5, Px.hex("#ff0000"))
	p.glow(0, 0, 8, Px.hex("#00ff00"), 0.5)
	p.disc(3, 3, 4, Px.hex("#0000ff"), 0.5)
	p.line(-10, -10, 10, 5, func(u): return Px.mix(Px.WHITE, Px.BLACK, u))
	p.text("HI 12", -10, -14, Px.WHITE)
	Px.sparkle(p, -8, 8, 4, Px.hex("#ffff00"))
	var lit := 0
	for c in f.color:
		if c: lit += 1
	print("pixels drawn: ", lit)
	var ps := Px.Particles.new({"seed": 3, "ground": func(): return 0.0})
	for i in 10:
		ps.spawn(Px.P.SPARK, 0, -4, r.range(-100, 100), r.range(-200, -50), 0.5)
	ps.spawn(Px.P.SMOKE, 0, -4, 0, -10, 1.0, 0, 4.0)
	for i in 20:
		ps.update(1.0 / 120.0)
	ps.draw(p)
	print("particles: ", ps.count)
	print("actor: ", Px.stockActor(2).w, "x", Px.stockActor(2).h)
	print("backdrop: ", Px.Scene.backdrop("ground", 8, 8, 4).size())
	return 0
