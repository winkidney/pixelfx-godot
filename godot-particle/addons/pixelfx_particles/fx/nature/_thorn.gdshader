// A hooked thorn (nature/thorns, after the original's thorn()): a hardwood horn tapering from its foot on the floor,
// its point hooked forward; lit down its left edge with a bright ridge, shaded on the right, grain running up it, a
// pale point, a barb raking back off it, a dark rim. `h` is how tall it stands (key it to grow it), `base` how far it
// has sunk into the floor (nothing shows below the floor), `white` flashes it. Colours: `ramp` (8 steps, dark to
// bright). Coordinates are px from the effect's origin (`center` is the rect's middle).
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform sampler2D ramp : filter_nearest, repeat_disable;
uniform float x = 0.0;
uniform float w = 6.0;
uniform float hook = 2.0;
uniform float lean = 0.0;
uniform float h = 0.0;
uniform float base = 0.0;
uniform float white = 0.0;
uniform float grain_seed = 1.0;

vec4 C(int i) {
	return texture(ramp, vec2((float(clamp(i, 0, 7)) + 0.5) / 8.0, 0.5));
}

float rnd(float a, float b) {
	return fract(sin(a * 12.9898 + b * 78.233 + grain_seed * 0.731) * 43758.5453);
}

float cx(float u) {
	return x + lean * u + hook * pow(u, 2.4);
}

float hw(float u) {
	return (w / 2.0) * pow(max(0.0, 1.0 - u), 0.9) + 0.25;
}

bool inside(vec2 q) {
	float u = (base - (q.y + 0.5)) / h;
	if (u < 0.0 || u > 1.0 || q.y + 0.5 > 0.0) {
		return false;
	}
	return abs(q.x + 0.5 - cx(u)) <= hw(u);
}

bool on_line(vec2 q, vec2 a, vec2 b) {
	vec2 A = floor(a);
	vec2 B = floor(b);
	vec2 d = B - A;
	if (abs(d.x) >= abs(d.y)) {
		if (q.x < min(A.x, B.x) || q.x > max(A.x, B.x)) {
			return false;
		}
		float y = d.x == 0.0 ? A.y : A.y + (q.x - A.x) * d.y / d.x;
		return q.y == floor(y + 0.5);
	}
	if (q.y < min(A.y, B.y) || q.y > max(A.y, B.y)) {
		return false;
	}
	return q.x == floor(A.x + (q.y - A.y) * d.x / d.y + 0.5);
}

float edge(vec2 p, vec2 a, vec2 b) {
	return (b.x - a.x) * (p.y - a.y) - (b.y - a.y) * (p.x - a.x);
}

void fragment() {
	vec2 q = floor((UV - 0.5) * size + center);
	if (h < 1.5) {
		discard;
	}
	vec4 c = vec4(0.0);
	if (!inside(q)) {
		if (q.y <= 0.0 && (inside(q - vec2(1.0, 0.0)) || inside(q + vec2(1.0, 0.0)) || inside(q + vec2(0.0, 1.0)) || inside(q - vec2(0.0, 1.0)))) {
			c = C(0);
		}
	} else if (white > 0.5) {
		c = vec4(1.0);
	} else {
		float u = (base - (q.y + 0.5)) / h;
		float cc = cx(u);
		float r = hw(u);
		float qq = (q.x + 0.5 - (cc - r)) / (2.0 * r);
		int i = qq < 0.0 ? 4 : qq < 0.16 ? 6 : qq < 0.36 ? 5 : qq < 0.46 ? 7 : qq < 0.7 ? 4 : qq < 0.86 ? 3 : 2;
		if (u > 0.86) {
			i = qq < 0.6 ? 7 : 5;
		}
		if (i < 7 && i > 2 && rnd(q.x, floor((q.y + 0.5 - base) / 3.0)) < 0.12) {
			i -= 1;
		}
		c = C(i);
	}
	// a barb off its back, raking up and away
	if (white < 0.5 && h > 14.0) {
		float y0 = base - 0.34 * h;
		float y1 = base - 0.46 * h;
		float e0 = cx(0.34) - hw(0.34);
		float e1 = cx(0.46) - hw(0.46);
		float L = w * 0.45;
		if (y0 <= 0.0) {
			vec2 a = vec2(e0 + 0.5, y0);
			vec2 b = vec2(e1 + 0.5, y1);
			vec2 d = vec2(e1 - L, y1 - L * 0.7);
			vec2 pc = q + 0.5;
			float s1 = edge(pc, a, b);
			float s2 = edge(pc, b, d);
			float s3 = edge(pc, d, a);
			if ((s1 >= 0.0 && s2 >= 0.0 && s3 >= 0.0) || (s1 <= 0.0 && s2 <= 0.0 && s3 <= 0.0)) {
				c = C(3);
			}
			if (on_line(q, vec2(e1, y1), d)) {
				c = C(6);
			}
			if (q == floor(d)) {
				c = C(7);
			}
			if (on_line(q, vec2(e0, y0 + 1.0), d + vec2(1.0, 1.0))) {
				c = C(0);
			}
		}
	}
	if (c.a <= 0.0) {
		discard;
	}
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
