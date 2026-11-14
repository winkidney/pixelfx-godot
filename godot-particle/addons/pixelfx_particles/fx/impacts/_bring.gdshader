// A ring that breaks into flying arcs (src/fx/impacts/_lib.js brokenRing()): segs[i] = (centre angle, gap, dr, w)
// evenly round it. brk 0 is a whole ring `th` thick; as brk grows each arc shrinks, tapers into a crescent at both
// ends and drifts out at its own speed (dr). color is the outer edge, color2 the inner; squash flattens it onto a
// plane; nothing is drawn at or below max_y (the floor, in the effect's coordinates). Key radius / th / brk /
// colours / alpha on the original's frames.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform vec4 segs[8];
uniform float seg_count = 0.0;
uniform float radius = 10.0;
uniform float th = 2.0;
uniform float brk = 0.0;
uniform float squash = 1.0;
uniform float max_y = 1e6;
uniform vec4 color : source_color = vec4(1.0);
uniform vec4 color2 : source_color = vec4(1.0);
uniform float alpha = 1.0;

void fragment() {
	vec4 tint = COLOR;
	vec2 q = floor((UV - 0.5) * size) + 0.5;
	if (center.y + q.y >= max_y || radius <= 0.0) {
		discard;
	}
	vec2 p = vec2(q.x, q.y / max(squash, 0.001));
	float rho = length(p);
	float g = atan(p.y, p.x);
	int n = int(seg_count + 0.5);
	float full = 6.2831853 / max(1.0, seg_count);
	bool hit = false;
	vec4 c = vec4(0.0);
	for (int i = 0; i < 8; i++) {
		if (i >= n) {
			break;
		}
		vec4 s = segs[i];
		float span = full * (1.0 - s.y * brk) + 0.02;
		float rr = radius * (1.0 + s.z * brk);
		float dg = mod(g - s.x + 3.14159265, 6.2831853) - 3.14159265;
		float slack = 0.5 / max(rr, 1.0);
		if (abs(dg) > span * 0.5 + slack) {
			continue;
		}
		float u = clamp(dg / span + 0.5, 0.0, 1.0);
		float w = max(0.5, th * s.w * (1.0 - brk * pow(abs(2.0 * u - 1.0), 1.6)));
		float o = rho - rr;
		if (o < -w * 0.5 - 0.5 || o > w * 0.5 + 0.5) {
			continue;
		}
		hit = true;
		c = o > -0.26 - 0.25 ? color : color2;
	}
	if (!hit) {
		discard;
	}
	c.a *= alpha;
	c *= tint;
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
