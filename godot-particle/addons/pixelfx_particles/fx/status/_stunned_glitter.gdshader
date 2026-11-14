// status/stunned's glitter (a process shader for GPUParticles2D): the dots left along the tilted ring behind each of
// the three stars, placed by the original's formula from the particle's index and the loop's time `t` (keyed 0 ->
// period), flickering on the original's own hash. A star's trail is drawn in the layer the star is in, and only the
// part of it on that side of the ring (`side`: 1 near, -1 far). mode 0: the dots (c6 / c5 / c4 by distance, alpha
// dithered by the colour layer), mode 1: the light under the first five.
shader_type particles;
render_mode disable_velocity, disable_force;

uniform float t = 0.0;
uniform float period = 2.0;
uniform float turns = 2.0;
uniform float items = 5.0;
uniform float rx = 14.88;
uniform float ry = 4.5;
uniform float cy = -36.0;
uniform float side = 1.0;
uniform int mode = 0;
uniform vec4 c4 : source_color = vec4(1.0);
uniform vec4 c5 : source_color = vec4(1.0);
uniform vec4 c6 : source_color = vec4(1.0);
uniform vec4 lightc : source_color = vec4(1.0);

// the originals' rand(a, b, c): their 32-bit hash, bit for bit
float jrand3(int a, int b, int c) {
	uint h = 0x9e3779b9u;
	int ns[3] = int[](a, b, c);
	for (int i = 0; i < 3; i++) {
		h = (h ^ uint(ns[i])) * 0x85ebca6bu;
		h ^= h >> 13u;
		h *= 0xc2b2ae35u;
		h ^= h >> 16u;
	}
	return float(h) / 4294967296.0;
}

vec4 place(uint index, out vec2 p) {
	p = vec2(-10000.0);
	int j = int(index) / 12;
	int k = int(index) % 12 + 1;
	if (j >= 3) {
		return vec4(0.0);
	}
	int i = j * 2;
	bool far = side < 0.0;
	float th0 = TAU * (turns * t / period + float(i) / items);
	if ((sin(th0) >= 0.0) == far) {
		return vec4(0.0);
	}
	float th = th0 - float(k) * 0.085;
	if ((sin(th) >= 0.0) == far) {
		return vec4(0.0);
	}
	if (jrand3(i, k, int(floor((t / period * turns + float(k) * 0.37) * 9.0))) < 0.25) {
		return vec4(0.0);
	}
	vec2 q = vec2(cos(th) * rx, cy - 1.0 + sin(th) * ry);
	p = floor(q) + 0.5;
	if (mode == 1) {
		if (k >= 6) {
			return vec4(0.0);
		}
		return vec4(lightc.rgb, 0.3 * (1.0 - float(k) / 6.0));
	}
	vec4 c = k < 4 ? c6 : (k < 8 ? c5 : c4);
	c.a = clamp(1.1 - float(k) / 13.0, 0.0, 1.0);
	return c;
}

void start() {
	TRANSFORM[3].xy = vec2(-10000.0);
	COLOR = vec4(0.0);
}

void process() {
	vec2 p;
	vec4 c = place(INDEX, p);
	float sc = 1.0;
	if (c.a <= 0.0) {
		sc = 0.0;
		p = vec2(-10000.0);
	}
	TRANSFORM[0] = vec4(sc, 0.0, 0.0, 0.0);
	TRANSFORM[1] = vec4(0.0, sc, 0.0, 0.0);
	TRANSFORM[2] = vec4(0.0, 0.0, 1.0, 0.0);
	TRANSFORM[3] = vec4(p, 0.0, 1.0);
	COLOR = c;
}
