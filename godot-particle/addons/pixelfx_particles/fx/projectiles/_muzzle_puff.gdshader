// Gunsmoke puffs as GPU particles (projectiles/muzzle-*, cannonball): each particle replays one puff the original
// spawns, its numbers read from a data texture by index (build/fx/projectiles/_muzzle.gd smoke_puffs()), so the
// chains, curls and clouds come out where the original's do. Drawn by _lobe.gdshader (the particle colour is the
// puff's state: red its brightness, green the fire's light on it, alpha its density); its size is its radius.
//   mode 0: _lib.js Smoke, stepped at 120 Hz as the original: a push out, drag, a curl turning its heading, a rise,
//           a sway, swelling from r0 to r1, thinning as (1 - k)^1.3. One-shot emitters, every puff emitted at 0
//           and waiting out its delay. Rows: (x, y, vx, vy) (r0, r1, life, a) (b, drag, rise, grow)
//           (curl, warm, delay, seed).
//   mode 1: muzzle-smg's wisps in closed form. Rows: (x0, y0, vx, vy) (life, drift, lift, phase)
//           (r0, grow, a, delay). Particle i replays wisp i % count; looping emitters.
shader_type particles;
render_mode disable_velocity, disable_force;

uniform sampler2D data : filter_nearest;
uniform float count = 1.0;
uniform float mode = 0.0;
// the fire's light on the young smoke is scaled by this (keyed: the shot's pop)
uniform float wmul = 1.0;
// the texture's radius in px (glow16: 8)
uniform float tex_r = 8.0;
// mode 1: the canvas's top (puffs thin out under it) and the muzzle (the pop lights what's near it)
uniform float top = -1000.0;
uniform vec2 muzzle = vec2(0.0);

vec4 row(uint index, int r) {
	return texelFetch(data, ivec2(int(mod(float(index), count)), r), 0);
}

void hide(inout mat4 tr, inout vec4 col) {
	tr = mat4(vec4(0.0), vec4(0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(tr[3].xy, 0.0, 1.0));
	col = vec4(0.0);
}

void place(inout mat4 tr, vec2 pos, float r) {
	float s = r / tex_r;
	tr = mat4(vec4(s, 0.0, 0.0, 0.0), vec4(0.0, s, 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(pos, 0.0, 1.0));
}

void start() {
	vec4 d0 = row(INDEX, 0);
	// x: delay left, y: age, zw: velocity
	CUSTOM = vec4(row(INDEX, 3).z, 0.0, d0.zw);
	if (mode > 0.5) {
		CUSTOM = vec4(0.0);
	}
	TRANSFORM[3].xy = d0.xy;
	hide(TRANSFORM, COLOR);
}

void run(uint index, float delta, inout mat4 tr, inout vec4 cu, inout vec4 co) {
	vec4 d0 = row(index, 0);
	vec4 d1 = row(index, 1);
	vec4 d2 = row(index, 2);
	vec4 d3 = row(index, 3);
	if (mode < 0.5) {
		float life = d1.z;
		vec2 pos = tr[3].xy;
		vec2 v = cu.zw;
		float dt = delta * 0.5;
		for (int i = 0; i < 2; i++) {
			if (cu.x > 0.0) {
				cu.x -= dt;
				continue;
			}
			cu.y += dt;
			if (cu.y >= life) {
				break;
			}
			if (d3.x != 0.0) {
				float c = cos(d3.x * dt);
				float s = sin(d3.x * dt);
				v = vec2(v.x * c - v.y * s, v.x * s + v.y * c);
			}
			v.y -= d2.z * dt;
			// the sway runs off the smoke's clock: since the start, the delay included
			float T = d3.z + cu.y;
			v.x += sin(T * 1.3 + d3.w) * 8.0 * dt;
			v -= v * d2.y * dt;
			pos += v * dt;
		}
		cu.zw = v;
		tr[3].xy = pos;
		float age = cu.y;
		if (cu.x > 0.0 || age >= life || age <= 0.0) {
			hide(tr, co);
			return;
		}
		float k = age / life;
		float r = d1.x + (d1.y - d1.x) * (1.0 - exp(-d2.w * age));
		float a = d1.w * min(1.0, age * 30.0) * pow(1.0 - k, 1.3);
		if (r < 0.5 || a <= 0.01) {
			hide(tr, co);
			return;
		}
		place(tr, pos, r);
		co = vec4(d2.x * (1.0 - k * 0.5), clamp(d3.y * exp(-age * 5.0) * wmul, 0.0, 1.0), 0.0, a);
	} else {
		cu.y += delta;
		float a = cu.y - d2.w;
		float life = d1.x;
		if (a < 0.0 || a >= life) {
			hide(tr, co);
			return;
		}
		float k = a / life;
		vec2 pos = vec2(d0.x + d0.z * (1.0 - exp(-3.2 * a)) / 3.2 - d1.y * a * a + sin(a * 2.1 + d1.w) * a * 2.5,
			d0.y + d0.w * (1.0 - exp(-2.4 * a)) / 2.4 - 0.5 * d1.z * a * a);
		float r = d2.x + d2.y * (1.0 - exp(-1.4 * a));
		if (pos.y - r < top + 1.0) {
			hide(tr, co);
			return;
		}
		float edge = min(1.0, (pos.y - r - top) / 12.0);
		float al = min(1.0, a * 10.0) * pow(1.0 - k, 1.6) * d2.z * edge;
		place(tr, pos, r);
		co = vec4(clamp(0.92 - k * 0.6, 0.0, 1.0), clamp(wmul * exp(-length(pos - muzzle) / 9.0), 0.0, 1.0), 0.0, al);
	}
}

void process() {
	run(INDEX, DELTA, TRANSFORM, CUSTOM, COLOR);
}
