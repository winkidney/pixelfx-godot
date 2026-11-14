// The laser bolt's body (projectiles/laser-bolt.js): bands round a white core, thickest just behind the rounded head
// and tapering to a thread `len` px back, pulses running back down it, its edge breaking up a little as the light
// shimmers; two sparks spiral round the core, the near one bright. Coordinates are px from the effect's origin;
// key t (0 -> 1 over the loop) and fr (the frame, for the shimmer).
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform float t = 0.0;
uniform float fr = 0.0;
uniform float len = 40.0;
uniform vec4 cols[8];

float h(float x, float y) {
	return fract(sin(x * 12.9898 + y * 78.233) * 43758.5453);
}

void fragment() {
	vec2 cell = floor(UV * size) - size * 0.5 + center;
	vec2 p = cell + 0.5;
	float ph = t;
	float TAU_ = 6.28318530718;
	int lvl = -1;
	float d = -p.x + 3.0;
	float u = d / (len + 3.0);
	if (u >= 0.0 && u <= 1.0) {
		float head = d < 3.0 ? sqrt(max(0.0, 1.0 - pow((3.0 - d) / 3.0, 2.0))) : 1.0;
		float w = (3.4 * pow(1.0 - u, 0.9) + 0.5) * head * (1.0 + 0.08 * sin(d * 0.9 - ph * TAU_ * 4.0));
		float v = abs(p.y - 0.5) / max(w, 1e-4);
		bool on = v <= 1.2 && !(v > 1.0 && (u > 0.5 || h(cell.x, fr) > 0.6));
		if (on) {
			float pulse = fract(d * 0.05 - ph * 3.0) < 0.12 ? 1.0 : 0.0;
			int l = v < 0.22 ? (u < 0.6 ? 7 : 6) : v < 0.45 ? 6 - (u > 0.5 ? 1 : 0) : v < 0.72 ? 4 : v <= 1.0 ? 3 : 2;
			lvl = min(7, l + (v < 0.72 ? int(pulse) : 0));
		}
	}
	// the sparks spiralling round the core: a dot every px back from 2 to 0.7 of its length
	vec4 col = lvl >= 0 ? cols[lvl] : vec4(0.0);
	float dd = -cell.x;
	if (dd >= 2.0 && dd < len * 0.7) {
		for (int k = 0; k < 2; k++) {
			float a = dd * 0.45 - ph * TAU_ * 3.0 + float(k) * 3.14159265359;
			float yy = floor(0.5 + sin(a) * (2.2 * (1.0 - dd / len) + 0.6));
			if (cell.y == yy && cos(a) > 0.3) {
				col = cos(a) > 0.8 ? vec4(1.0) : cols[6];
			}
		}
	}
	if (col.a <= 0.0) {
		discard;
	}
	if (pfx_pixel(col, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = col;
}
