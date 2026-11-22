// A particle process shader for what a projectile sheds into the air it flies through (projectiles/_lib.js wake()
// and spark(); used by energy-disc and plasma-shot): particle i is launched off a ring of radius spawn_r round
// spawn_at at an angle in [ang_min, ang_max] (plus a jitter in spawn_box, every other one mirrored up or down with
// `mirror`), at a speed in [v_min, v_max] along the ring's tangent (mode 0, the way a disc spins) or straight out
// (mode 1); it slows toward the still air (drag k), the air streams left at V px/s, gravity g pulls it. Each slot's
// numbers come from its index (or from slot_a / slot_b: the original's own draws), so with lifetime = the loop it
// repeats exactly every loop, as the original's beat() does; its own life is life_min..life_max, hidden after (and
// outside the clip). It's drawn as a streak along its screen velocity, min(max_len, 1 + speed * stretch) px long (or,
// with len_range, a length times len_a + len_b * age / life: speed lines that stretch), its quad one pixel per column
// so it rasterises as a clean line (draw with _energy-disc_spark.gdshader and a 1x8 texture: COLOR.r carries the life
// left); with glow > 0 it's a glow quad `glow` px across instead, coloured like the spark's head (light layer twin).
// Use local coordinates on the emitter.
shader_type particles;
render_mode disable_velocity, disable_force;

uniform float seed = 0.0;
uniform float life_min = 0.1;
uniform float life_max = 0.3;
uniform float spawn_r = 10.0;
uniform vec2 spawn_at = vec2(0.0);
uniform float ang_min = 0.0;
uniform float ang_max = 6.2831853;
uniform float mode = 0.0;
uniform vec2 spawn_box = vec2(0.0);
uniform float mirror = 0.0;
// 1: the streak runs ahead of the point instead of behind it (speed lines: drawn from the point on, forward)
uniform float ahead = 0.0;
uniform vec2 len_range = vec2(0.0);
uniform float len_a = 0.5;
uniform float len_b = 1.0;
// the head's colour steps over its life left (s0 above th0, s1 above th1, then s2), for the glow twin
uniform float th0 = 0.6;
uniform float th1 = 0.3;
uniform float v_min = 100.0;
uniform float v_max = 200.0;
uniform float V = 100.0;
uniform float k = 2.0;
uniform float g = 0.0;
uniform float stretch = 0.022;
uniform float max_len = 9.0;
uniform float tex_len = 8.0;
uniform float glow = 0.0;
uniform float glow_k = 0.45;
uniform vec4 s0 : source_color = vec4(1.0);
uniform vec4 s1 : source_color = vec4(1.0);
uniform vec4 s2 : source_color = vec4(1.0);
// the original's own numbers for each slot (its beat()'s rng(seed, i) draws, from the build script): slot i < slots
// takes slot_a (life, angle, speed, length) and slot_b (offset x, y from spawn_at) instead of its own
uniform float slots = 0.0;
uniform vec4 slot_a[32];
uniform vec4 slot_b[32];
// added to every launch angle (keyed: the original turns them with the disc)
uniform float ang_add = 0.0;
uniform float clip_x = -1e6;
uniform float clip_y = 1e6;

float rnd(float i, float j) {
	return fract(sin(i * 12.9898 + j * 78.233 + seed * 37.719) * 43758.5453);
}

void place(inout mat4 tr, inout vec4 col, float age, float i) {
	float life = mix(life_min, life_max, rnd(i, 1.0));
	float a = mix(ang_min, ang_max, rnd(i, 2.0));
	float v = mix(v_min, v_max, rnd(i, 3.0));
	float lb = mix(len_range.x, len_range.y, rnd(i, 7.0));
	vec2 off = spawn_box * (vec2(rnd(i, 4.0), rnd(i, 5.0)) * 2.0 - 1.0);
	if (i < slots) {
		vec4 sa = slot_a[int(i)];
		life = sa.x;
		a = sa.y;
		v = sa.z;
		lb = sa.w;
		off = slot_b[int(i)].xy;
	}
	a += ang_add;
	vec2 p0 = spawn_at + vec2(cos(a), sin(a)) * spawn_r + off;
	if (mirror > 0.5 && mod(i, 2.0) > 0.5) {
		p0.y = -p0.y;
	}
	vec2 v0 = mode < 0.5 ? vec2(-sin(a), cos(a)) * v : vec2(cos(a), sin(a)) * v;
	float e = exp(-k * age);
	float f = (1.0 - e) / k;
	float vt = g / k;
	vec2 pos = vec2(p0.x + v0.x * f - V * age, p0.y + vt * age + (v0.y - vt) * f);
	vec2 sv = vec2(v0.x * e - V, vt + (v0.y - vt) * e);
	float kk = 1.0 - age / life;
	bool shown = age < life && pos.x > clip_x && abs(pos.y) < clip_y;
	float sp = max(length(sv), 1.0);
	vec2 u = sv / sp;
	if (glow > 0.0) {
		vec4 head = kk > th0 ? s0 : kk > th1 ? s1 : s2;
		float sc = shown ? glow / tex_len : 0.0;
		tr = mat4(vec4(sc, 0.0, 0.0, 0.0), vec4(0.0, sc, 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(pos, 0.0, 1.0));
		col = vec4(head.rgb, glow_k * kk);
		return;
	}
	float len = min(max_len, 1.0 + sp * stretch);
	if (len_range.y > 0.0) {
		len = lb * (len_a + len_b * age / life);
	}
	float w = max(abs(u.x), abs(u.y));
	vec2 X = vec2(-u.y, u.x) * (shown ? w : 0.0);
	vec2 Y = u * (shown ? len / tex_len : 0.0);
	vec2 o = pos + u * len * (ahead > 0.5 ? 0.5 : -0.5);
	tr = mat4(vec4(X, 0.0, 0.0), vec4(Y, 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(o, 0.0, 1.0));
	col = vec4(kk, 0.0, 0.0, 1.0);
}

void start() {
	CUSTOM = vec4(0.0);
	VELOCITY = vec3(0.0);
	place(TRANSFORM, COLOR, 0.0, float(INDEX));
}

void process() {
	CUSTOM.y += DELTA;
	VELOCITY = vec3(0.0);
	place(TRANSFORM, COLOR, CUSTOM.y, float(INDEX));
}
