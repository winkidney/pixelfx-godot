// The impacts' particles (build/fx/impacts/_impacts.gd sim()): GPU particles that move by the original's own
// physics (src/core/sim.js Particles and Bits), which a ParticleProcessMaterial can't: drag proportional to speed,
// a spark's half gravity and bouncy floor, grit that ticks once off the floor and stops, buoyant smoke, tumbling
// rocks that bounce and come to rest. Each particle's start (where, how fast, how long, after what delay) is a
// column of `data`, rolled at build time from the original's seeded draws; the motion is all here, at 120 Hz
// substeps as the original's. Drawn by _bits.gdshader (colour / soft layer) and _bits_light.gdshader (light).
//   data rows: 0 (x, y, vx, vy), 1 (life, delay, size, seed), 2 (colour), 3 (angle, spin, 0, 0), 4.. (rock corners)
//   CUSTOM out: kind-specific drawing values, (.., .., life left 0..1, index)
shader_type particles;
render_mode disable_velocity, disable_force;

uniform sampler2D data : filter_nearest, repeat_disable;
// the original's kind: 0 SPARK, 1 MOTE, 3 FLAKE, 5 DUST, 6 STAR, 8 SMOKE, 11 GRIT, 20 CHUNK, 21 SHARD; 30 PUFF (an
// effect's own soft puff: drag and lift of its own in row 3, a warm tint in row 4 that cools off by warm_t)
uniform float kind = 0.0;
uniform float floor_y = 0.0;
// Bits: gravity scale, drag, bounce
uniform float grav = 1.0;
uniform float drag = 0.0;
uniform float bounce = 0.0;
// SMOKE: PF.BIG
uniform float big = 0.0;
uniform float substeps = 2.0;
// PUFF: the tint toward row 4's colour, k * clamp(1 - (t - warm_t0) / warm_len)
uniform float warm_k = 0.0;
uniform float warm_t0 = 0.03;
uniform float warm_len = 0.25;

const float G = 950.0;

float h1(float n) {
	return fract(sin(n * 12.9898 + 4.1414) * 43758.5453);
}

void start() {
	int i = int(INDEX);
	vec4 a = texelFetch(data, ivec2(i, 0), 0);
	vec4 b = texelFetch(data, ivec2(i, 1), 0);
	vec4 e = texelFetch(data, ivec2(i, 3), 0);
	USERDATA1 = a;
	// clock since start, life left, delay left, resting (bits) / bounces (grit)
	USERDATA2 = vec4(0.0, b.x, b.y, 0.0);
	USERDATA3 = vec4(e.x, e.y, 0.0, 0.0);
	TRANSFORM = mat4(vec4(0.0), vec4(0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(a.xy, 0.0, 1.0));
	VELOCITY = vec3(0.0);
	COLOR = texelFetch(data, ivec2(i, 2), 0);
	CUSTOM = vec4(0.0, 0.0, 1.0, float(i));
}

void process() {
	int i = int(INDEX);
	vec4 b = texelFetch(data, ivec2(i, 1), 0);
	vec4 s = USERDATA1;
	vec4 st = USERDATA2;
	vec4 r = USERDATA3;
	float n = max(1.0, substeps);
	float dt = DELTA / n;
	int kd = int(kind + 0.5);
	for (int j = 0; j < int(n); j++) {
		st.x += dt;
		if ((kd == 20 || kd == 21)) {
			// Bits: no delay; life counts down, a resting bit stays put
			st.y -= dt;
			if (st.y <= 0.0 || st.w > 0.5) {
				continue;
			}
			s.w += G * grav * dt;
			s.z -= s.z * drag * dt;
			s.w -= s.w * drag * dt;
			s.x += s.z * dt;
			s.y += s.w * dt;
			r.x += r.y * dt;
			float sp = s.w;
			if (grav <= 0.0 || s.y < floor_y || sp <= 0.0) {
				continue;
			}
			s.y = floor_y - 0.01;
			if (bounce > 0.0 && sp > 70.0) {
				s.w = -sp * bounce;
				s.z *= 0.7;
				r.y *= 0.6;
			} else {
				st.w = 1.0;
				s.z = 0.0;
				s.w = 0.0;
			}
			continue;
		}
		if (st.z > 0.0) {
			st.z -= dt;
			continue;
		}
		st.y -= dt;
		if (st.y <= 0.0) {
			break;
		}
		if (kd == 0) {
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
			continue;
		} else if (kd == 11) {
			s.w += G * dt;
			s.z -= s.z * 0.8 * dt;
			float ny = s.y + s.w * dt;
			s.x += s.z * dt;
			if (s.w > 0.0 && s.y <= floor_y && ny >= floor_y) {
				s.y = floor_y - 0.25;
				st.w += 1.0;
				if (s.w > 130.0 && h1(float(i) * 3.7 + st.w * 1.3 + b.w) < 0.4) {
					s.w = -s.w * 0.25;
					s.z = s.z * 0.5 + (h1(float(i) * 1.9 + st.w * 5.1 + b.w) * 20.0 - 10.0);
				} else {
					s.z = 0.0;
					s.w = 0.0;
					st.y = min(st.y, 0.5);
				}
			} else {
				s.y = ny;
			}
			continue;
		} else if (kd == 3) {
			s.z -= s.z * 2.2 * dt;
			s.w -= s.w * 2.2 * dt - 35.0 * dt;
			s.x += sin(st.x * 2.5 + b.w) * 7.0 * dt;
		} else if (kd == 8) {
			s.w -= (big > 0.5 ? 23.0 : 16.0) * dt;
			s.z += sin(st.x * 1.3 + b.w) * 8.0 * dt;
			s.z -= s.z * 1.6 * dt;
			s.w -= s.w * 1.2 * dt;
		} else if (kd == 1) {
			s.z -= s.z * 0.6 * dt;
			s.w -= s.w * 0.6 * dt;
		} else if (kd == 30) {
			s.z -= s.z * r.x * dt;
			s.w -= s.w * r.x * dt + r.y * dt;
		} else {
			float dr = kd == 5 ? 4.0 : 1.6;
			s.z -= s.z * dr * dt;
			s.w -= s.w * dr * dt + 5.0 * dt;
		}
		s.x += s.z * dt;
		s.y += s.w * dt;
	}
	USERDATA1 = s;
	USERDATA2 = st;
	USERDATA3 = r;
	if (st.y <= 0.0) {
		ACTIVE = false;
	}
	bool live = st.y > 0.0 && ((kd == 20 || kd == 21) || st.z <= 0.0);
	float k = clamp(st.y / max(b.x, 1e-4), 0.0, 1.0);
	float sc = live ? 1.0 : 0.0;
	TRANSFORM = mat4(vec4(sc, 0.0, 0.0, 0.0), vec4(0.0, sc, 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(s.xy, 0.0, 1.0));
	float spd = length(s.zw);
	vec2 u = spd > 0.0 ? s.zw / spd : vec2(1.0, 0.0);
	if (kd == 0) {
		CUSTOM = vec4(u * min(9.0, 1.0 + spd * 0.022), k, float(i));
	} else if (kd == 1) {
		CUSTOM = vec4(u * min(16.0, 0.5 + spd * 0.026) * b.z, k, float(i));
	} else if (kd == 6) {
		// twinkle off the system's clock (st.x: every spawn here starts with the system)
		float tw = 0.6 + 0.4 * sin(st.x * (8.0 + mod(b.w, 5.0)) + b.w);
		CUSTOM = vec4(tw, b.z, k, float(i));
	} else if (kd == 30) {
		vec4 base = texelFetch(data, ivec2(i, 2), 0);
		vec4 warm = texelFetch(data, ivec2(i, 4), 0);
		COLOR = vec4(mix(base.rgb, warm.rgb, warm_k * clamp(1.0 - (st.x - warm_t0) / warm_len, 0.0, 1.0)), 1.0);
		CUSTOM = vec4(b.z * (0.7 + (1.0 - k) * 0.85), pow(k, 1.25) * min(1.0, (b.x - st.y) / 0.03), k, float(i));
	} else if ((kd == 20 || kd == 21)) {
		CUSTOM = vec4(r.x, min(1.0, st.y / (kd == 20 ? 0.5 : 0.4)), k, float(i));
	} else {
		CUSTOM = vec4(b.z, 1.0 - k, k, float(i));
	}
}
