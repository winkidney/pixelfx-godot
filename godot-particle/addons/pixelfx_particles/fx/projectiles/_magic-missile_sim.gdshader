// A particle process shader replaying the magic missile's particles (projectiles/magic-missile.js and core/sim.js
// Particles): each particle's spawn is a row of `data` (from the build script, which replays the original's own
// random draws): (time, x, y, life), (vx, vy, size, seed), (r, g, b, delay). It waits unseen until its time and its
// delay are up, then moves as the original's do, stepped at 120 Hz: motes (kind 0) drift and slow, stars (1) slow
// and lift a little, sparks (2) fall, slow and bounce off the floor. Drawn as the original draws them: motes and
// sparks as streaks along their motion (_magic-missile_streak.gdshader: COLOR carries the colour and the life left),
// stars as twinkling sparkles snapped to the pixel grid (_magic-missile_star: COLOR.a carries the arm); with glow, a
// light quad instead (light layer twin).
shader_type particles;
render_mode disable_velocity, disable_force;

uniform sampler2D data : filter_nearest;
uniform int kind = 0;
uniform float glow = 0.0;
uniform float tex_size = 8.0;
uniform vec4 s0 : source_color = vec4(1.0);
uniform vec4 s1 : source_color = vec4(1.0);
uniform vec4 s2 : source_color = vec4(1.0);

void place(inout mat4 tr, inout vec4 col, inout vec4 cu, inout vec3 vel, float dt, int idx) {
	vec4 A = texelFetch(data, ivec2(0, idx), 0);
	vec4 B = texelFetch(data, ivec2(1, idx), 0);
	vec4 Cc = texelFetch(data, ivec2(2, idx), 0);
	float T = cu.x;
	float act = T - A.x - Cc.w;
	float life = A.w;
	bool shown = false;
	if (T < A.x) {
		cu.yz = A.yz;
		vel.xy = B.xy;
	} else if (act > 0.0 && act < life) {
		// step at 120 Hz, as the original does
		int n = int(round(dt * 120.0));
		float h = dt / float(max(n, 1));
		for (int i = 0; i < 8; i++) {
			if (i >= n) {
				break;
			}
			vec2 v = vel.xy;
			vec2 p = cu.yz;
			if (kind == 0) {
				v -= v * 0.6 * h;
			} else if (kind == 1) {
				v.x -= v.x * 1.6 * h;
				v.y -= v.y * 1.6 * h + 5.0 * h;
			} else {
				v.y += 950.0 * 0.45 * h;
				v -= v * 2.2 * h;
				float ny = p.y + v.y * h;
				p.x += v.x * h;
				if (v.y > 0.0 && p.y <= 0.0 && ny >= 0.0) {
					v.y = -v.y * 0.45;
					v.x *= 0.7;
					p.y = -0.25;
				} else {
					p.y = ny;
				}
				vel.xy = v;
				cu.yz = p;
				continue;
			}
			p += v * h;
			vel.xy = v;
			cu.yz = p;
		}
		shown = true;
	}
	vec2 pos = cu.yz;
	vec2 v = vel.xy;
	float k = clamp(1.0 - act / life, 0.0, 1.0);
	float sp = max(length(v), 1.0);
	vec2 u = v / sp;
	vec3 c = Cc.rgb;
	if (kind == 1) {
		// a twinkling star: arm = size * twinkle * min(1, 3k) (a lone pixel under size 1)
		float sd = B.w;
		float tw = 0.6 + 0.4 * sin(T * (8.0 + mod(sd, 5.0)) + sd);
		float n = -1.0;
		float gk = 0.0;
		float gr = 0.0;
		vec3 gc = c;
		if (B.z < 1.0) {
			if (tw * k > 0.25) {
				n = 0.0;
				c = tw > 0.8 ? vec3(1.0) : c;
			}
			gk = 0.4 * k * tw;
			gr = 3.0;
		} else {
			n = round(B.z * tw * min(1.0, k * 3.0));
			if (n < 1.0) {
				n = -1.0;
			} else {
				gk = 0.5 * k * tw;
				gr = 4.0 + n * 2.0;
			}
		}
		if (glow > 0.0) {
			float sc = shown && gk > 0.004 ? gr * 2.0 / tex_size : 0.0;
			tr = mat4(vec4(sc, 0.0, 0.0, 0.0), vec4(0.0, sc, 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(pos, 0.0, 1.0));
			col = vec4(gc, gk);
			return;
		}
		float sc = shown && n >= 0.0 ? 1.0 : 0.0;
		tr = mat4(vec4(sc, 0.0, 0.0, 0.0), vec4(0.0, sc, 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(floor(pos) + 0.5, 0.0, 1.0));
		col = vec4(c, (n + 0.5) / 16.0);
		return;
	}
	if (glow > 0.0) {
		// motes: glow(2.5 + size, col, 0.4k); sparks: glow(3, head, 0.45k)
		float gr = kind == 0 ? 2.5 + B.z : 3.0;
		vec3 gc = kind == 0 ? c : (k > 0.6 ? s0.rgb : k > 0.3 ? s1.rgb : s2.rgb);
		float gk = kind == 0 ? 0.4 * k : 0.45 * k;
		float sc = shown ? gr * 2.0 / tex_size : 0.0;
		tr = mat4(vec4(sc, 0.0, 0.0, 0.0), vec4(0.0, sc, 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(pos, 0.0, 1.0));
		col = vec4(gc, gk);
		return;
	}
	float len = kind == 0 ? min(16.0, 0.5 + sp * 0.026) * B.z : min(9.0, 1.0 + sp * 0.022);
	float w = max(abs(u.x), abs(u.y));
	vec2 X = vec2(-u.y, u.x) * (shown ? w : 0.0);
	vec2 Y = u * (shown ? len / tex_size : 0.0);
	vec2 o = pos - u * len * 0.5;
	tr = mat4(vec4(X, 0.0, 0.0), vec4(Y, 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(o, 0.0, 1.0));
	col = vec4(c, k);
}

void start() {
	CUSTOM = vec4(0.0);
	VELOCITY = vec3(0.0);
	place(TRANSFORM, COLOR, CUSTOM, VELOCITY, 0.0, int(INDEX));
}

void process() {
	CUSTOM.x += DELTA;
	place(TRANSFORM, COLOR, CUSTOM, VELOCITY, DELTA, int(INDEX));
}
