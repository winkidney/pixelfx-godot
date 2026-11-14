// ice/blizzard-vortex's particles (a process shader for GPUParticles2D): snow and wind carried round a leaning
// funnel. Every particle is placed by the original's formulas from its index and the loop's time `t` (keyed 0 ->
// period), so a loop repeats exactly and the funnel's far half and near half can be drawn apart (`side`). A streak
// or an orbiter is `segs` particles: its head and a dotted arc / tail behind it. Emitters that share mode, count,
// segs and seed draw the same particles (a light copy, a plus on the big ones). Needs explosiveness 1 and a long
// lifetime: Godot only has to emit them once.
//   mode 0  wind streaks: arcs swirling round and climbing the funnel
//   mode 1  orbiters: snow and ice rising on a spiral with a short tail (only_big: just every fifth, the big ones)
//   mode 2  snow boiling at the foot (soft puffs: the texture is scaled to their radius, `disc` px across at 1)
//   mode 3  snow thrown off the mouth, spreading into a thin cloud
shader_type particles;
render_mode disable_velocity, disable_force;

uniform float t = 0.0;
uniform float period = 2.0;
uniform float H = 80.0;
uniform float tilt = 0.24;
uniform int mode = 0;
uniform int count = 10;
uniform int segs = 1;
uniform float seed = 0.0;
// 1: the near half only, -1: the far half only, 0: both
uniform float side = 1.0;
uniform bool only_big = false;
uniform float disc = 16.0;
uniform float radius_k = 1.0;
uniform float alpha = 1.0;
uniform vec4 c0 : source_color = vec4(1.0);
uniform vec4 c1 : source_color = vec4(1.0);
uniform vec4 c2 : source_color = vec4(1.0);
uniform vec2 cut = vec2(0.15, 0.5);


float hash(uint n) {
	n = (n << 13u) ^ n;
	n = n * (n * n * 15731u + 789221u) + 1376312589u;
	return float(n & 0x7fffffffu) / 2147483647.0;
}

float rnd(uint id, uint k) {
	return hash(id * 97u + k * 7919u + uint(seed) * 1013u + 17u);
}

float range(uint id, uint k, float a, float b) {
	return a + (b - a) * rnd(id, k);
}

float funnel(float h) {
	return 4.0 + 28.0 * pow(clamp(h / H, 0.0, 1.0), 1.35);
}

float axis(float h, float ph) {
	return (5.0 * sin(TAU * ph + h * 0.05) + 1.5 * sin(TAU * ph * 2.0 - h * 0.11)) * (h / H) - 2.0 * (h / H);
}

bool wrong_side(float s) {
	return (side > 0.5 && s < 0.0) || (side < -0.5 && s >= 0.0);
}

// where particle INDEX is at the loop's time t: its position, size and colour (alpha 0: not alive or not shown)
vec4 place(uint index, out vec2 p, out float sc) {
	p = vec2(0.0);
	sc = 1.0;
	uint id = index / uint(segs);
	uint j = index % uint(segs);
	if (int(id) >= count) {
		return vec4(0.0);
	}
	float ph = t / period;
	float born = rnd(id, 0u) * period;
	float life;
	if (mode == 0) {
		life = range(id, 1u, 0.5, 0.9);
	} else if (mode == 1) {
		life = range(id, 1u, 0.9, 1.6);
	} else if (mode == 2) {
		life = range(id, 1u, 0.8, 1.2);
	} else {
		life = range(id, 1u, 0.9, 1.3);
	}
	float age = mod(t - born, period);
	if (age >= life) {
		return vec4(0.0);
	}
	float k = age / life;
	if (mode == 0) {
		float h0 = range(id, 2u, 2.0, H);
		float w = range(id, 3u, 8.0, 12.0) * (1.45 - h0 / H);
		float th = range(id, 4u, 0.0, TAU) + age * w;
		float fade = min(1.0, age / 0.08) * (k > 0.7 ? (1.0 - k) / 0.3 : 1.0);
		float m = ceil(range(id, 5u, 0.7, 1.5) / 0.07);
		float fj = float(j);
		if (fj > m) {
			return vec4(0.0);
		}
		float a = th - fj * 0.07;
		float s = sin(a);
		if (wrong_side(s)) {
			return vec4(0.0);
		}
		float h = min(H + 4.0, h0 + age * 16.0 - fj * 0.25);
		float R = funnel(min(h, H)) * (1.0 + min(0.3, max(0.0, h - H * 0.84) * 0.03));
		float u = fj / m;
		p = vec2(axis(min(h, H), ph) + cos(a) * R, -h + s * R * tilt);
		vec4 c = u < cut.x ? c0 : (u < cut.y ? c1 : c2);
		c.a *= clamp(fade * (u < 0.6 ? 1.0 : 1.5 - u * 1.2) * (side > 0.5 ? 1.0 : 0.85), 0.0, 1.0);
		return c;
	} else if (mode == 1) {
		bool big = id % 5u == 0u;
		if (only_big && !big) {
			return vec4(0.0);
		}
		float h0 = range(id, 2u, 0.0, H * 0.6);
		float h = h0 + age * range(id, 3u, 14.0, 30.0);
		if (h > H + 8.0) {
			return vec4(0.0);
		}
		float w = range(id, 4u, 7.0, 11.0) * (1.5 - h / H);
		float th = range(id, 5u, 0.0, TAU) + age * w;
		float o = 1.0 + range(id, 6u, 0.05, 0.3) + min(0.35, max(0.0, h - H * 0.82) * 0.04);
		float R = funnel(min(h, H)) * o;
		float s = sin(th);
		if (wrong_side(s)) {
			return vec4(0.0);
		}
		float ax = axis(min(h, H), ph);
		vec2 head = vec2(ax + cos(th) * R, -h + s * R * tilt);
		float fade = min(1.0, age / 0.1) * (k > 0.8 ? (1.0 - k) / 0.2 : 1.0);
		if (j == 0u) {
			// the head: c0 for the big ones (and half the rest), c1 otherwise
			vec4 c = (big || rnd(id, 7u) < 0.5) ? c0 : c1;
			c.a *= fade;
			p = head;
			return c;
		}
		// the tail: a line back along its path, brighter toward the head
		float th2 = th - 0.25;
		vec2 q = vec2(ax + cos(th2) * R, -h + 2.0 + sin(th2) * R * tilt);
		float u = 1.0 - float(j) / float(max(segs - 1, 1));
		vec4 c = u > 0.6 ? c1 : c2;
		c.a *= u * fade * (side > 0.5 ? 1.0 : 0.8);
		p = mix(q, head, u);
		return c;
	} else if (mode == 2) {
		float th = range(id, 2u, 0.0, TAU) + age * range(id, 3u, 4.0, 6.0);
		float R = 9.0 + age * range(id, 4u, 8.0, 16.0);
		float s = sin(th);
		if (wrong_side(s)) {
			return vec4(0.0);
		}
		p = vec2(axis(0.0, ph) + cos(th) * R, -2.0 - age * range(id, 5u, 4.0, 10.0) + s * R * 0.2);
		sc = (2.0 + 4.0 * k) * radius_k * 2.0 / disc;
		vec4 c = c0;
		c.a *= 0.5 * pow(1.0 - k, 1.2) * min(1.0, age / 0.1);
		return c;
	}
	float th = range(id, 2u, 0.0, TAU);
	float R = funnel(H) * (0.6 + age * 0.9);
	float Rc = min(R, 36.0);
	p = vec2(axis(H, ph) + cos(th) * Rc, -H - 2.0 - age * 4.0 + sin(th) * Rc * tilt);
	sc = (3.0 + 6.0 * k) * radius_k * 2.0 / disc;
	vec4 c = c0;
	c.a *= 0.24 * (1.0 - k) * min(1.0, age / 0.15);
	return c;
}

void start() {
	TRANSFORM[3].xy = vec2(-10000.0);
	COLOR = vec4(0.0);
}

void process() {
	vec2 p;
	float sc;
	vec4 c = place(INDEX, p, sc);
	if (c.a <= 0.0) {
		sc = 0.0;
		p = vec2(-10000.0);
	}
	TRANSFORM[0] = vec4(sc, 0.0, 0.0, 0.0);
	TRANSFORM[1] = vec4(0.0, sc, 0.0, 0.0);
	TRANSFORM[2] = vec4(0.0, 0.0, 1.0, 0.0);
	TRANSFORM[3] = vec4(p, 0.0, 1.0);
	COLOR = vec4(c.rgb, c.a * alpha);
}
