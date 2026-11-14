// The fire tornado's funnel (after src/fx/fire/fire-tornado.js): narrow at the foot and flaring at the top, its spine
// snaking as it turns; each pixel's place round the funnel picks its heat, so a darker body carries thin bright
// streaks spiralling up it, hottest where it faces us; near the top it comes apart into spiral strands, and licks
// flicker off its edges. Key `t` 0 -> 1 over the loop and `fl` (the fire's flicker). Coordinates: px from the origin.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(80.0, 104.0);
uniform vec2 center = vec2(0.0, -48.0);
uniform float t = 0.0;
uniform float fl = 1.0;
uniform float height = 80.0;
uniform float seed = 4.0;
uniform float spin_turns = 3.0;
// the hot-first ramp, 8 steps: white .. deep red
uniform sampler2D heat_ramp : filter_nearest, repeat_disable;

float h1(float i, float s) {
	return fract(sin(i * 12.9898 + s * 78.233) * 43758.5453);
}

// smooth value noise in [-1, 1] repeating every `period` cells
float pn(float x, float period, float s) {
	float i = floor(x);
	float f = x - i;
	float u = f * f * (3.0 - 2.0 * f);
	float a = h1(mod(i, period), s);
	float b = h1(mod(i + 1.0, period), s);
	return (a + (b - a) * u) * 2.0 - 1.0;
}

float cx(float v) {
	return 3.2 * sin(v * 4.2 - t * 6.28318531 * 2.0) * v + 2.0 * sin(t * 6.28318531) * v;
}

float rad(float v) {
	return 3.5 + 15.0 * pow(v, 1.35);
}

void fragment() {
	vec2 p = floor(UV * size) + 0.5 + center - size * 0.5;
	float x = floor(p.x);
	float y = floor(p.y);
	if (y > 0.0 || y < -height * 1.2) {
		discard;
	}
	float v = -y / height;
	float vv = min(1.0, v);
	float c = cx(vv);
	float r = rad(vv) * (1.0 + 0.08 * pn(t * 6.0 + y * 0.1, 6.0, seed + 2.0));
	float sp = t * 6.28318531 * spin_turns + v * 5.5;
	float cut = clamp((v - 0.72) / 0.42, 0.0, 1.0);
	float lickL = 0.3 * max(0.0, pn(-y * 0.22 + t * 18.0, 18.0, seed + 3.0));
	float lickR = 0.3 * max(0.0, pn(-y * 0.22 + t * 18.0 + 9.0, 18.0, seed + 4.0));
	float dx = (x + 0.5 - c) / r;
	float edge = 1.0 + (dx < 0.0 ? lickL : lickR);
	if (abs(dx) > edge) {
		discard;
	}
	float th = asin(clamp(dx, -1.0, 1.0));
	float depth = cos(th);
	float tear = 0.18 * pn(y * 0.45 + dx * 2.0 - t * 30.0, 30.0, seed + 6.0);
	float band = 0.5 + 0.5 * sin((th + sp + tear) * 3.0);
	float streak = band * band * band;
	if (cut > 0.0 && band < 0.35 + cut * 0.6 + 0.1 * pn(x * 0.7 + t * 20.0, 20.0, seed + 5.0)) {
		discard;
	}
	float heat = 0.22 + 0.36 * depth + 0.5 * streak - 0.22 * vv + 0.1 * (1.0 - vv) - 0.25 * cut;
	if (abs(dx) > 1.0) {
		heat = 0.3 - (abs(dx) - 1.0) * 1.5;
	}
	heat *= fl;
	float idx = heat > 0.95 ? 0.0 : heat > 0.82 ? 1.0 : heat > 0.7 ? 2.0 : heat > 0.58 ? 3.0 : heat > 0.46 ? 4.0 : heat > 0.34 ? 5.0 : heat > 0.2 ? 6.0 : 7.0;
	vec4 col = texture(heat_ramp, vec2((idx + 0.5) / 8.0, 0.5));
	col.a = 1.0;
	if (pfx_pixel(col, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = col;
}
