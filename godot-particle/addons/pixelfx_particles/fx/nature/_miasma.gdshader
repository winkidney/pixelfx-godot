// nature/poison-cloud: one sheet of gas hugging the floor (the original's sheet()): a height field flat through the
// middle and falling away at its ends, its top torn by noise flowing outward, raised behind tongues that creep out
// from the middle and curl over at their tips. Brightest at the floor (lit from within), darkening to violet toward
// its torn top, streaked in thin layers, a pale rim along its top; the tongues' fronts roll over in curls.
// Key `t` 0 -> 1 over the loop (the tongues and the noise come back where they started). Soft layer (translucent).
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform float t = 0.0;
// the sheet: height, width (x E), opacity, how much dimmer (ramp steps), how fast its edges flow, tongues a side
uniform float h = 16.0;
uniform float e = 1.0;
uniform float a = 0.5;
uniform float dim = 0.0;
uniform float flow = 8.0;
uniform float n = 2.0;
uniform float si = 0.0;
uniform float reach = 96.0;
uniform float seed = 3.0;
// the palette, dark to bright, 8 steps
uniform sampler2D ramp : filter_nearest, repeat_disable;
uniform float alpha = 1.0;

vec3 C(float i) {
	return texture(ramp, vec2((clamp(i, 0.0, 7.0) + 0.5) / 8.0, 0.5)).rgb;
}

float hash(vec2 p, float s) {
	return fract(sin(dot(p, vec2(127.1, 311.7)) + s * 17.31) * 43758.5453);
}

// value noise in -1..1 repeating every px in x (so a field scrolled by whole periods loops)
float tnoise(float x, float y, float px, float s) {
	float ix = floor(x);
	float iy = floor(y);
	float fx = x - ix;
	float fy = y - iy;
	float ux = fx * fx * (3.0 - 2.0 * fx);
	float uy = fy * fy * (3.0 - 2.0 * fy);
	float x0 = mod(ix, px);
	float x1 = mod(ix + 1.0, px);
	float va = hash(vec2(x0, iy), s);
	float vb = hash(vec2(x1, iy), s);
	float vc = hash(vec2(x0, iy + 1.0), s);
	float vd = hash(vec2(x1, iy + 1.0), s);
	return mix(mix(va, vb, ux), mix(vc, vd, ux), uy) * 2.0 - 1.0;
}

// tongue i: side s, phase q along its creep, front x, height
vec4 tongue(int i) {
	float s = float(i) < n ? -1.0 : 1.0;
	float j = mod(float(i), n);
	float q = fract(t + j / n + si * 0.17 + (s > 0.0 ? 0.5 / n : 0.0));
	return vec4(s, q, s * reach * (0.3 + 0.82 * q), h * (0.75 - 0.45 * q));
}

float height(float x) {
	float ax = abs(x);
	float env = 1.0 - smoothstep(0.5, 1.0, ax / (reach * e));
	float r = tnoise(ax * 0.07 - t * flow, si * 3.7, flow, seed + si);
	float H = h * env * (0.55 + 0.45 * r);
	for (int i = 0; i < 8; i++) {
		if (float(i) >= 2.0 * n) {
			break;
		}
		vec4 g = tongue(i);
		float behind = g.x * (g.z - x);
		if (behind < -1.5 || behind > 30.0) {
			continue;
		}
		H = max(H, g.w * sqrt(max(0.0, 1.0 - behind / 30.0)) * smoothstep(-1.5, 1.5, behind) * (1.0 - smoothstep(0.75, 1.0, g.y)));
	}
	return H;
}

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5 + center;
	float x = floor(p.x);
	float y = floor(p.y);
	vec3 col = vec3(0.0);
	float al = 0.0;
	float H = height(x + 0.5);
	if (H >= 0.6) {
		float top = -floor(H + 0.5);
		if (y >= top && y <= 1.0) {
			float v = clamp(-y / H, 0.0, 1.0);
			float sg = x < 0.0 ? -1.0 : 1.0;
			float streak = 0.7 + 0.3 * tnoise(x * 0.05 - t * flow * sg, y * 0.55, flow, seed + 9.0 + si);
			float lv = v - (streak - 0.7) * 0.6;
			float ci = y == top ? max(1.0, 4.0 - dim) : lv < 0.16 ? 6.0 - dim : lv < 0.42 ? 5.0 - dim : lv < 0.68 ? 4.0 - dim : max(1.0, 3.0 - dim);
			col = C(ci);
			al = a * (y == top ? 0.65 : (0.6 + 0.4 * (1.0 - v)) * streak);
		}
	}
	// the tongues' leading edges roll over: a thick soft band winding in on itself, lighter along its outer edge
	for (int i = 0; i < 8; i++) {
		if (float(i) >= 2.0 * n) {
			break;
		}
		vec4 g = tongue(i);
		float k = sin(3.14159265 * g.y);
		if (k < 0.15 || g.w < 4.0) {
			continue;
		}
		float r = 1.8 + g.w * 0.22;
		vec2 c = vec2(g.z - g.x * r * 0.6, -g.w * 0.72);
		vec2 d = vec2(g.x * (p.x - c.x), p.y - c.y);
		float rho = length(d);
		if (rho > r + 2.0) {
			continue;
		}
		float spin = -g.x * g.y * 6.2831853 * 2.2;
		float th = mod(atan(d.y, d.x) - spin, 6.2831853);
		for (int m = 0; m < 2; m++) {
			float an = th + float(m) * 6.2831853;
			if (an > 4.6) {
				break;
			}
			float rr = r * (1.0 - an * 0.12);
			float w = 1.6 * (1.0 - an / 6.0);
			float o = rho - rr;
			if (abs(o) <= w + 0.3) {
				float ca = a * 0.75 * k * (1.0 - an / 5.5);
				vec3 cc = o > w * 0.4 ? C(5.0 - dim) : C(4.0 - dim);
				col = al > 0.0 ? mix(col, cc, ca / max(0.001, al + ca * (1.0 - al))) : cc;
				al = al + ca * (1.0 - al);
				break;
			}
		}
	}
	if (al <= 0.0) {
		discard;
	}
	vec4 o4 = vec4(col, al * alpha);
	if (pfx_pixel(o4, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = o4;
}
