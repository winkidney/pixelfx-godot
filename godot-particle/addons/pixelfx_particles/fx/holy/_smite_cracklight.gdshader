// The cracks' light (holy/smite, light layer): a glow (10 px, gold) on every other point of every crack, as hot as
// that crack is there, and the crater's glow. pts: (x, y, d, cool). Key t (seconds since the hit).
shader_type canvas_item;
render_mode blend_add;

#include "res://addons/pixelfx_particles/fx/holy/_smite_lib.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform vec4 pts[96];
uniform int count = 0;
uniform float t = -1.0;
uniform vec4 c4 : source_color;
uniform float strength = 1.0;

void fragment() {
	if (t < 0.0) {
		discard;
	}
	vec2 p = floor((UV - 0.5) * size) + 0.5 + center;
	float l = 0.0;
	for (int i = 0; i < 96; i++) {
		if (i >= count) {
			break;
		}
		vec4 q = pts[i];
		float h = clamp(1.0 - t / q.w - q.z * 0.5, 0.0, 1.0);
		if (h > 0.0) {
			l += smite_glow(p, q.xy, 10.0) * 0.45 * h;
		}
	}
	float hh = clamp(1.0 - t / 1.6, 0.0, 1.0);
	l += smite_glow(p, vec2(0.0), 18.0) * 0.45 * hh;
	COLOR = vec4(min(c4.rgb * l, vec3(1.0)) * strength, 1.0);
}
