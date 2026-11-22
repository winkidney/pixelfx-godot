// The scifi effects' simulated particles (build/fx/scifi/_scifi.gd ghost() / ghosts()): every slot is one of the
// original's particles (src/fx/scifi/_lib.js Ghosts for loops, src/core/sim.js Particles for one-shots), placed from
// the keyed clock `t` (the effect's own seconds) by integrating the original's physics from its birth, at the
// original's own steps (1/240 s for Ghosts, 1/120 s for Particles). So a loop is a function of t alone with no seam,
// and a one-shot replays its spawns exactly when they happened. Drawn by _bits.gdshader / _bits_light.gdshader.
//   data rows: 0 (x, y, vx, vy), 1 (life, born, size, seed), 2 (colour), 3 (hash seed for grit hops, age offset,
//   periods back, a dead pixel's life in frames)
//   CUSTOM out: kind-specific drawing values, (.., .., life left 0..1, index)
shader_type particles;
render_mode disable_velocity, disable_force;

#include "res://addons/pixelfx_particles/fx/scifi/_jsrand.gdshaderinc"

uniform sampler2D data : filter_nearest, repeat_disable;
uniform float t = 0.0;
// > 0: a loop of this period (ages wrap); 0: a one-shot (age = t - born)
uniform float period = 0.0;
// the original's kind: 0 SPARK, 1 MOTE, 2 STREAK, 3 FLAKE, 4 VAPOUR, 5 DUST, 6 STAR, 7 EMBER, 8 SMOKE, 9 FIRE,
// 11 GRIT; 12 PIXEL (a dead pixel: steps a whole frame at a time, blinks out over its second half); 13 DEAD (the
// EMP's dead pixels: falling slowly, never below y = -1, blinking out as they die); 14 BIT (warp-out's body bits: hauled
// up the beam, drawn in to its middle; e.w: the bit's own roll, which decides streak or spark)
uniform float kind = 0.0;
uniform float floor_y = 1e9;
uniform float big = 0.0;
// particles outside it are dropped (Ghosts' box)
uniform vec4 box = vec4(-1e9, -1e9, 1e9, 1e9);
uniform float step_s = 0.0041666667;
// the sin() terms run on the particle's own age (Ghosts) or on the effect's clock (Particles)
uniform bool own_clock = true;

const float G = 950.0;

mat4 at_(vec2 p, float sc) {
	return mat4(vec4(sc, 0.0, 0.0, 0.0), vec4(0.0, sc, 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(p, 0.0, 1.0));
}

void place(int i, inout mat4 tr, inout vec4 col, inout vec4 cu) {
	vec4 a = texelFetch(data, ivec2(i, 0), 0);
	vec4 b = texelFetch(data, ivec2(i, 1), 0);
	vec4 e = texelFetch(data, ivec2(i, 3), 0);
	col = texelFetch(data, ivec2(i, 2), 0);
	float born = b.y;
	// a particle that outlives the loop shows again a period later (e.z: which period back this slot is)
	float age = period > 0.0 ? mod(t - born, period) + e.z * period : t - born;
	int kd = int(kind + 0.5);
	float life = b.x;
	if (age < 0.0 || age >= life + 1e-5 || b.x <= 0.0) {
		tr = at_(vec2(0.0), 0.0);
		cu = vec4(0.0);
		return;
	}
	float seed = b.w;
	vec4 s = a;
	float left = life;
	float hops = 0.0;
	float aa = 0.0;
	// the clock the sin() terms read: the particle's own age (Ghosts) or the effect's (Particles)
	float c0 = own_clock ? e.y : born;
	if (kd == 12) {
		// a dead pixel: x0 + side * q * speed, y0 - q / 2, q the whole frames since it was born
		float q = floor(age * 30.0 + 1e-3);
		s.xy = a.xy + vec2(a.z * q, a.w * q);
		left = life - age;
	} else {
		for (int j = 0; j < 2000; j++) {
			if (aa >= age - 1e-6) {
				break;
			}
			float dt = min(step_s, age - aa);
			float ck = c0 + aa;
			if (kd == 9) {
				s.w -= 95.0 * dt;
				s.z += sin(ck * 17.0 + seed) * 30.0 * dt;
				s.z -= s.z * 5.0 * dt;
				s.w -= s.w * 3.2 * dt;
				s.xy += s.zw * dt;
			} else if (kd == 11) {
				s.w += G * dt;
				s.z -= s.z * 0.8 * dt;
				float ny = s.y + s.w * dt;
				s.x += s.z * dt;
				if (s.w > 0.0 && s.y <= floor_y && ny >= floor_y) {
					s.y = floor_y - 0.25;
					uint hh = js_hash2(int(e.x), int(hops));
					hops += 1.0;
					if (s.w > 130.0 && float(hh) / 4294967296.0 < 0.4) {
						s.w = -s.w * 0.25;
						s.z = s.z * 0.5;
					} else {
						s.z = 0.0;
						s.w = 0.0;
						left = min(left, 0.5);
					}
				} else {
					s.y = ny;
				}
			} else if (kd == 0) {
				s.w += G * 0.45 * dt;
				s.z -= s.z * 2.2 * dt;
				s.w -= s.w * 2.2 * dt;
				float ny = s.y + s.w * dt;
				s.x += s.z * dt;
				if (s.w > 0.0 && s.y <= floor_y && ny >= floor_y) {
					s.w = -s.w * 0.45;
					s.z *= 0.7;
					s.y = floor_y - 0.25;
				} else {
					s.y = ny;
				}
			} else if (kd == 2) {
				s.zw += s.zw * 3.0 * dt;
				s.xy += s.zw * dt;
			} else if (kd == 3) {
				s.z -= s.z * 2.2 * dt;
				s.w -= s.w * 2.2 * dt - 35.0 * dt;
				s.x += sin(ck * 2.5 + seed) * 7.0 * dt;
				s.xy += s.zw * dt;
			} else if (kd == 7) {
				s.w += (-30.0 + sin(ck * 3.0 + seed) * 20.0) * dt;
				s.z += cos(ck * 2.3 + seed) * 45.0 * dt;
				s.z -= s.z * 1.6 * dt;
				s.w -= s.w * 1.6 * dt;
				s.xy += s.zw * dt;
			} else if (kd == 8) {
				s.w -= (big > 0.5 ? 23.0 : 16.0) * dt;
				s.z += sin(ck * 1.3 + seed) * 8.0 * dt;
				s.z -= s.z * 1.6 * dt;
				s.w -= s.w * 1.2 * dt;
				s.xy += s.zw * dt;
			} else if (kd == 14) {
				s.w -= 560.0 * dt;
				s.z += (-(s.x + 0.5) * 14.0 - s.z * 3.0) * dt;
				s.xy += s.zw * dt;
			} else if (kd == 13) {
				s.w += 60.0 * dt;
				s.x += s.z * dt;
				s.y = min(-1.0, s.y + s.w * dt);
			} else if (kd == 1) {
				s.z -= s.z * 0.6 * dt;
				s.w -= s.w * 0.6 * dt;
				s.xy += s.zw * dt;
			} else {
				float dr = (kd == 4 || kd == 5) ? 4.0 : 1.6;
				s.z -= s.z * dr * dt;
				s.w -= s.w * dr * dt + 5.0 * dt;
				s.xy += s.zw * dt;
			}
			aa += dt;
			left -= dt;
			if (left <= 0.0) {
				break;
			}
		}
	}
	if (left <= 0.0 || s.x < box.x || s.x > box.z || s.y < box.y || s.y > box.w) {
		tr = at_(vec2(0.0), 0.0);
		cu = vec4(0.0);
		return;
	}
	// the original reads k = life left / max: GRIT's max stays its first life even when a landing cuts it short
	float k = clamp(left / max(life, 1e-4), 0.0, 1.0);
	tr = at_(s.xy, 1.0);
	float spd = length(s.zw);
	vec2 u = spd > 0.0 ? s.zw / spd : vec2(1.0, 0.0);
	if (kd == 0) {
		cu = vec4(u * min(9.0, 1.0 + spd * 0.022), k, float(i));
	} else if (kd == 1) {
		cu = vec4(u * min(16.0, 0.5 + spd * 0.026) * b.z, k, float(i));
	} else if (kd == 2) {
		cu = vec4(u * clamp(spd / 30.0, 1.0, 7.0), k, float(i));
	} else if (kd == 6) {
		// the twinkle runs on the effect's clock
		float tw = 0.6 + 0.4 * sin(t * (8.0 + mod(seed, 5.0)) + seed);
		cu = vec4(tw, b.z, k, float(i));
	} else if (kd == 7) {
		bool off = k < 0.25 && sin(t * 40.0 + seed) < 0.0;
		cu = vec4(off ? 0.0 : 1.0, b.z, k, float(i));
	} else if (kd == 9) {
		float ag = 1.0 - k;
		float heat = min(0.999, pow(ag, 0.62) + fract(seed) * 0.1);
		float idx = min(7.0, floor(heat * 8.0));
		float r = b.z * (0.55 + 0.45 * min(1.0, ag * 7.0)) * (1.0 - ag * 0.55);
		cu = vec4(r, idx, k, float(i));
	} else if (kd == 14) {
		// the streak's far end (dx, dy) and how far up the beam it is (0 at the top .. 1 where it started)
		float u = clamp((s.y - box.y + 0.0) / max(1e-3, a.y - box.y), 0.0, 1.0);
		cu = vec4(-s.z * 0.01, min(8.0, abs(s.w) * 0.02), u, float(i));
	} else if (kd == 13) {
		// e.w: its blink phase; it blinks out once less than 0.6 s of it is left, and cools after 0.5 s
		bool off = sin(t * 40.0 + e.w) < -0.3 && left < 0.6;
		cu = vec4(b.z, off ? 0.0 : 1.0, left > 0.5 ? 1.0 : 0.0, float(i));
	} else if (kd == 12) {
		float q = floor(age * 30.0 + 1e-3);
		bool off = q > e.w / 2.0 && mod(q, 2.0) > 0.5;
		cu = vec4(b.z, off ? 0.0 : 1.0, k, float(i));
	} else {
		cu = vec4(b.z, 1.0 - k, k, float(i));
	}
}

void start() {
	VELOCITY = vec3(0.0);
	place(int(INDEX), TRANSFORM, COLOR, CUSTOM);
}

void process() {
	VELOCITY = vec3(0.0);
	place(int(INDEX), TRANSFORM, COLOR, CUSTOM);
}
