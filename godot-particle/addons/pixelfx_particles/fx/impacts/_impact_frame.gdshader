// An anime impact frame (src/fx/impacts/impact-frame.js): burst lines (wedges aimed at the hit from past the edges,
// lines[set * 64 + i] = (angle, inner radius, width)) on paper round a jagged star whose points shift every frame;
// frames 0-1 ink on paper, 2-3 inverted, 4-7 only the lines, in paper, pulling out past the edges and thinning.
// `frame` is the original's frame (keyed in steps, 30 a second).
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(320.0, 180.0);
uniform vec4 lines[128];
uniform float per_set = 64.0;
uniform vec2 jit[2];
uniform float ph[4];
uniform float frame = 0.0;
uniform vec4 ink : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 paper : source_color = vec4(1.0);

float spikes(float a, float p) {
	return 10.0 + 6.0 * abs(sin(a * 5.0 + p)) + 4.0 * abs(sin(a * 11.0 + p * 2.7)) + 2.0 * sin(a * 23.0 + p);
}

void fragment() {
	vec4 tint = COLOR;
	int f = int(frame + 0.5);
	if (f >= 8) {
		discard;
	}
	int set = f % 2;
	int n = int(per_set + 0.5);
	vec2 j = f < 4 ? jit[set] : vec2(0.0);
	vec2 p = floor((UV - 0.5) * size) + 0.5 - j;
	float rho = length(vec2(p.x, p.y * 1.35));
	float ang = atan(p.y * 1.35, p.x);
	float wrapped = mod(ang, TAU);
	int slot = int(floor(wrapped / (TAU / per_set)));
	float reach = f < 4 ? 0.0 : pow(float(f - 3) / 4.5, 1.5);
	float thin = f < 4 ? 1.0 : 1.0 - float(f - 3) / 5.5;
	bool line = false;
	for (int k = -1; k <= 1; k++) {
		vec4 l = lines[set * n + (slot + k + n) % n];
		float d = mod(ang - l.x, TAU);
		if (d > PI) {
			d = TAU - d;
		}
		float inner = l.y + reach * 150.0;
		float hw = l.z * clamp((rho - inner) / 40.0, 0.0, 1.0) * thin;
		if (rho > inner && d * rho < max(0.5, hw)) {
			line = true;
		}
	}
	vec4 c;
	if (f < 4) {
		bool inv = f >= 2;
		vec4 a = inv ? paper : ink;
		vec4 b = inv ? ink : paper;
		float r2 = length(vec2(p.x, p.y * 1.1));
		float core = spikes(atan(p.y * 1.1, p.x), ph[f]) * (f == 0 ? 0.85 : 1.0 + float(f) * 0.08);
		c = r2 < core ? (r2 < 4.0 + float(f) ? b : a) : (line ? a : b);
	} else {
		if (!line) {
			discard;
		}
		c = paper;
	}
	c *= tint;
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
