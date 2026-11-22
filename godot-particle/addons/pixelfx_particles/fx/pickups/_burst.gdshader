// collect-burst's pop (src/fx/pickups/collect-burst.js draw), colour layer, centred on (0, cy): the white flash disc
// (flash_r), the cross of light (four 1 px lines cross_l long, the vertical ones 0.6 of it, white to C6 to C5 along
// them, dithered by cross_a), the thin ring snapping out (r1, white then C6, a1) and the softer ring after it (r2,
// width w2, a2). Later draws win; each keyed every frame (0: not drawn).
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform vec4 C[8] : source_color;
uniform float cy = -30.0;
uniform float flash_r = 0.0;
uniform float cross_l = 0.0;
uniform float cross_a = 0.0;
uniform float r1 = 0.0;
uniform float a1 = 0.0;
uniform bool r1_white = true;
uniform float r2 = 0.0;
uniform float w2 = 1.0;
uniform float a2 = 0.0;

bool on_ring(vec2 pc, float r, float w) {
	vec2 q = pc - vec2(0.0, cy);
	float d2 = dot(q, q);
	float r0 = max(0.0, r - w);
	return d2 <= r * r && d2 >= r0 * r0;
}

bool passes(float a, float thr) {
	return a > 0.0 && (a >= 1.0 || a > thr);
}

// one of the cross's arms from the centre cell to cell e: true and u along it when cell q is on it
bool on_arm(vec2 q, vec2 e, out float u) {
	float n = max(abs(e.x), abs(e.y));
	u = 0.0;
	if (e.x != 0.0) {
		if (q.y != 0.0 || sign(q.x) * sign(e.x) < 0.0 || abs(q.x) > abs(e.x)) {
			return false;
		}
		u = abs(q.x) / max(1.0, n);
		return true;
	}
	if (q.x != 0.0 || sign(q.y) * sign(e.y) < 0.0 || abs(q.y) > abs(e.y)) {
		return false;
	}
	u = abs(q.y) / max(1.0, n);
	return true;
}

void fragment() {
	vec2 pc = floor(center + (UV - 0.5) * size) + 0.5;
	vec2 cell = floor(pc);
	float thr = pfx_threshold(FRAGCOORD.xy);
	vec4 c = vec4(0.0);
	if (r2 > 0.0 && on_ring(pc, r2, w2) && passes(a2, thr)) {
		c = vec4(C[5].rgb, 1.0);
	} else if (r1 > 0.0 && on_ring(pc, r1, 1.0) && passes(a1, thr)) {
		c = vec4(r1_white ? vec3(1.0) : C[6].rgb, 1.0);
	} else {
		if (cross_a > 0.0) {
			// right, left, down, up: from the centre's cell to the end's cell
			vec2 o = vec2(0.0, floor(cy));
			vec2 ends[4] = vec2[](vec2(floor(cross_l), floor(cy)), vec2(floor(-cross_l), floor(cy)),
				vec2(0.0, floor(cy + cross_l * 0.6)), vec2(0.0, floor(cy - cross_l * 0.6)));
			for (int i = 3; i >= 0; i--) {
				float u;
				if (on_arm(cell - o, ends[i] - o, u) && passes((u < 0.5 ? 1.0 : (1.0 - u) * 2.0) * cross_a, thr)) {
					c = vec4(u < 0.3 ? vec3(1.0) : u < 0.65 ? C[6].rgb : C[5].rgb, 1.0);
					break;
				}
			}
		}
		if (c.a <= 0.0 && flash_r > 0.0 && length(pc - vec2(0.0, cy)) <= flash_r) {
			c = vec4(1.0);
		}
	}
	if (c.a <= 0.0 || pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
