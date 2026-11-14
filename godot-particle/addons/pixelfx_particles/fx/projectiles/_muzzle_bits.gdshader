// Sparks, grains, embers and pellets as GPU particles (projectiles/muzzle-*, cannonball): each particle replays one
// the original spawns (its numbers from a data texture by index: build/fx/projectiles/_muzzle.gd bits()), stepped at
// 120 Hz with the original's physics (core/sim.js Particles: a spark's gravity, drag and bounce off the floor, an
// ember's wandering lift; muzzle-smg's fly() with its own gravity and drag; a pellet flying straight). Drawn by
// _muzzle_bit.gdshader: the particle colour carries (life left, kind, shown). With `glow` on, the same particles
// are their points of light instead (light layer, a glow16 texture), coloured as their heads.
//   rows: (x, y, vx, vy) (life, delay, seed, kind) (gravity, drag, stretch, max length) (size, floor, glow k, -)
//   kinds: 0 spark (a two-tone streak along its motion), 1 grain (a pixel), 2 pellet (a hot streak behind its head;
//   x, y the muzzle, vx its angle, vy its speed, gravity its head start), 3 ember (a pixel, flickering out; drawn as kind 4 when it's big)
shader_type particles;
render_mode disable_velocity, disable_force;

uniform sampler2D data : filter_nearest;
uniform float count = 1.0;
uniform float glow = 0.0;
// the sparks' colours, hot to cool [head hot, head warm, head cool, tail]; a grain's two; a pellet's light colour
uniform vec4 s0 : source_color = vec4(1.0);
uniform vec4 s1 : source_color = vec4(1.0);
uniform vec4 s2 : source_color = vec4(1.0);
uniform vec4 s3 : source_color = vec4(1.0);
uniform vec4 g0 : source_color = vec4(1.0);
uniform vec4 pellet : source_color = vec4(1.0);

vec4 row(uint index, int r) {
	return texelFetch(data, ivec2(int(mod(float(index), count)), r), 0);
}

void hide(inout mat4 tr, inout vec4 col) {
	tr = mat4(vec4(0.0), vec4(0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(tr[3].xy, 0.0, 1.0));
	col = vec4(0.0);
}

void start() {
	vec4 d0 = row(INDEX, 0);
	vec4 d1 = row(INDEX, 1);
	// x: delay left, y: life left, zw: velocity
	CUSTOM = vec4(d1.y, d1.x, d0.zw);
	TRANSFORM[3].xy = d0.xy;
	hide(TRANSFORM, COLOR);
}

void run(uint index, float delta, inout mat4 tr, inout vec4 cu, inout vec4 co) {
	vec4 d0 = row(index, 0);
	vec4 d1 = row(index, 1);
	vec4 d2 = row(index, 2);
	vec4 d3 = row(index, 3);
	int kind = int(d1.w + 0.5);
	vec2 pos = tr[3].xy;
	vec2 v = cu.zw;
	float dt = delta * 0.5;
	for (int i = 0; i < 2; i++) {
		if (cu.x > 0.0) {
			cu.x -= dt;
			continue;
		}
		cu.y -= dt;
		if (cu.y <= 0.0) {
			break;
		}
		if (kind == 3) {
			float T = d1.y + d1.x - cu.y;
			v.y += (-30.0 + sin(T * 3.0 + d1.z) * 20.0) * dt;
			v.x += cos(T * 2.3 + d1.z) * 45.0 * dt;
			v -= v * 1.6 * dt;
			pos += v * dt;
		} else if (kind != 2) {
			v.y += d2.x * dt;
			v -= v * d2.y * dt;
			float ny = pos.y + v.y * dt;
			pos.x += v.x * dt;
			if (d3.y > 0.5 && v.y > 0.0 && pos.y <= 0.0 && ny >= 0.0) {
				v.y = -v.y * 0.45;
				v.x *= 0.7;
				pos.y = -0.25;
			} else {
				pos.y = ny;
			}
		}
	}
	cu.zw = v;
	tr[3].xy = pos;
	if (cu.x > 0.0 || cu.y <= 0.0) {
		hide(tr, co);
		return;
	}
	float k = cu.y / d1.x;
	float age = d1.x - cu.y;
	vec4 head = k > 0.6 ? s0 : k > 0.3 ? s1 : s2;
	vec2 at = pos;
	vec2 ax = vec2(1.0, 0.0);
	vec2 ay = vec2(0.0, 1.0);
	float lightr = 3.0;
	float lightk = d3.z * k;
	bool shown = true;
	if (kind == 0) {
		float sp = max(length(v), 1e-4);
		vec2 u = v / sp;
		float len = min(d2.w, 1.0 + sp * d2.z);
		// the quad stays centred on the head (its origin is where the particle is): twice the streak, its front half
		// discarded by the draw shader
		ay = u * (len + 1.0) * 2.0;
		ax = vec2(u.y, -u.x) * 1.15;
	} else if (kind == 2) {
		vec2 u = vec2(cos(d0.z), sin(d0.z));
		float hd = 6.0 + d2.x + d0.w * age;
		float tl = max(4.0, hd - 26.0);
		pos = d0.xy + u * hd;
		at = pos;
		ay = u * (hd - tl + 0.5) * 2.0;
		ax = vec2(u.y, -u.x) * 1.15;
		head = pellet;
		lightr = 4.0;
		lightk = d3.z;
	} else {
		at = floor(pos) + 0.5;
		if (kind == 3) {
			lightr = 3.0 + d3.x;
			shown = !(k < 0.25 && sin((d1.y + age) * 40.0 + d1.z) < 0.0);
			if (d3.x > 1.5) {
				at.y += 0.5;
				ay = vec2(0.0, 2.0);
			}
		} else {
			head = k > 0.5 ? g0 : s2;
		}
	}
	if (glow > 0.5) {
		float s = lightr / 8.0;
		tr = mat4(vec4(s, 0.0, 0.0, 0.0), vec4(0.0, s, 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(pos, 0.0, 1.0));
		co = vec4(head.rgb, shown ? lightk : 0.0);
		return;
	}
	tr = mat4(vec4(ax, 0.0, 0.0), vec4(ay, 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(at, 0.0, 1.0));
	// a big ember draws as kind 4 (a cooler pixel under it)
	float kk = kind == 3 && d3.x > 1.5 ? 4.0 : float(kind);
	co = vec4(k, kk / 4.0, shown ? 1.0 : 0.0, 1.0);
}

void process() {
	run(INDEX, DELTA, TRANSFORM, CUSTOM, COLOR);
}
