// A storm cloud (storm-cloud) as one field: billows (x, y, visible radius, squash) summed so they fuse, each drifting,
// breathing and boiling up on its own seamless clock, clipped flat at the base with a ragged edge; shaded as one mass
// (a lit top, a cool middle, a dark belly, the field's slope rounding each billow), and the billow `flash.x` lit
// from inside by `flash.y`, breaking up through the cloud's own lumps. Key `t` 0 -> 1 over the loop.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(168.0, 70.0);
uniform vec2 center = vec2(0.0, -127.0);
uniform float t = 0.0;
uniform vec4 billows[17];
uniform vec2 flash = vec2(-1.0, 0.0);
// the cloud's seven colours, dark to light, then the palette's C[3] to C[6] for the light inside it
uniform vec4 ramp[11];
uniform float base_y = -100.0;
uniform float top_y = -156.0;
uniform float seed = 8.0;

const float TH = 0.35;
const float VIS = 0.6391;

float h1(float n) {
	return fract(sin(n * 12.9898 + seed * 78.233) * 43758.5453);
}

// smooth, -1..1, the same at phase 0 and 1
float ln(float ph, float s) {
	return 0.65 * sin(TAU * ph + h1(s) * TAU) + 0.35 * sin(2.0 * TAU * ph + h1(s + 0.5) * TAU);
}

float hash2(vec2 p, float s) {
	return fract(sin(dot(p, vec2(127.1, 311.7)) + s * 17.31) * 43758.5453);
}

// value noise in -1..1 repeating every px cells across (so a scroll of px cells a loop is seamless)
float tnoise(vec2 p, float px, float s) {
	vec2 i = floor(p);
	vec2 f = p - i;
	vec2 u = f * f * (3.0 - 2.0 * f);
	float x0 = mod(i.x, px);
	float x1 = mod(i.x + 1.0, px);
	float a = hash2(vec2(x0, i.y), s);
	float b = hash2(vec2(x1, i.y), s);
	float c = hash2(vec2(x0, i.y + 1.0), s);
	float d = hash2(vec2(x1, i.y + 1.0), s);
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y) * 2.0 - 1.0;
}

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5 + center;
	float ph = t;
	float F = 0.0;
	vec2 G = vec2(0.0);
	float LIT = 0.0;
	for (int i = 0; i < 17; i++) {
		vec4 b = billows[i];
		float fi = float(i);
		bool top = b.y < -112.0 && b.w > 0.99;
		float sn = sin(PI * fract(ph + fi * 0.37));
		float boil = 0.82 + 0.3 * sn * sn;
		float bx = b.x + 3.5 * ln(ph, seed + fi) + (b.w < 0.99 ? 4.0 * ln(ph, seed + fi + 90.0) : 0.0);
		float by = b.y + 2.0 * ln(ph, seed + fi + 30.0) - (top ? 4.0 * (boil - 0.97) : 0.0);
		float r = b.z * (top ? boil : 1.0 + 0.08 * ln(ph, seed + fi + 60.0)) / VIS;
		float dx = p.x - bx;
		float dy = (p.y - by) / b.w;
		float r2 = r * r;
		float d2 = (dx * dx + dy * dy) / r2;
		if (d2 >= 1.0) {
			continue;
		}
		float u = 1.0 - d2;
		float c = u * u;
		F += c;
		G += vec2(-4.0 * u * dx / r2, -4.0 * u * dy / (r2 * b.w));
		if (abs(fi - flash.x) < 0.5) {
			LIT += flash.y * (0.25 + 0.75 * c);
		}
	}
	if (F < TH - 0.06) {
		discard;
	}
	float base = base_y + 1.5 * tnoise(vec2(p.x * 0.12 + 9.0 * ph, 3.0), 9.0, seed + 5.0);
	float FF = F * (1.0 - smoothstep(base - 3.0, base, p.y)) + 0.05 * tnoise(vec2(p.x * 0.21 + 18.0 * ph, p.y * 0.21), 18.0, seed);
	if (FF < TH) {
		discard;
	}
	float gl = max(length(G), 1e-4);
	float lam = -(G.x * 0.42 + G.y * 0.9) / gl;
	float edge = min(1.0, gl * 5.0) * (FF < TH + 0.08 ? 1.0 : 0.55);
	float h = 1.0 - 2.0 * clamp((p.y - top_y) / (base_y - top_y), 0.0, 1.0);
	float i = 2.7 + 2.2 * h + 1.3 * lam * edge + 0.4 * tnoise(vec2(p.x * 0.16 + 12.0 * ph, p.y * 0.16), 12.0, seed + 9.0);
	if (FF < TH + 0.05 && lam > 0.3 && h > -0.5) {
		i += 1.0;
	}
	if (p.y > base - 6.0) {
		i -= 1.0;
	}
	i = clamp(round(i), 0.0, 6.0);
	float L = LIT * (0.7 + 0.6 * tnoise(vec2(p.x * 0.2 - 14.0 * ph, p.y * 0.2), 14.0, seed + 3.0));
	if (L > 0.12) {
		i = min(10.0, i + round(L * 5.5));
	}
	vec4 col = ramp[int(i)];
	if (pfx_pixel(col, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = col;
}
