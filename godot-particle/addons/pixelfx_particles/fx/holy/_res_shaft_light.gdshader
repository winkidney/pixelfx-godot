// holy/resurrection: the shaft's light (light layer): gold added down the shaft as bright as its veil, the glow of
// the pour's head as it falls and the glow pooling round the feet once it lands. `t` seconds (keyed).
shader_type canvas_item;
render_mode blend_add;

#include "res://addons/pixelfx_particles/fx/holy/_res_shaft.gdshaderinc"

uniform vec4 pal[8] : source_color;
uniform float strength = 1.0;

vec3 glow(vec2 p, vec2 at, float r, vec3 c, float k) {
	float f = 1.0 - length(p - at) / r;
	return f > 0.0 ? c * f * f * k : vec3(0.0);
}

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5 + center;
	vec3 l = pal[4].rgb * shaft_at(p) * 0.3;
	float k = shaft_k();
	float front = front_y();
	if (t < POUR + 0.05 && front > TOP + 14.0) {
		l += glow(p, vec2(0.0, min(front, 0.0)), 14.0, pal[5].rgb, 0.7 * k);
	}
	float kp = k * r_smooth(POUR - 0.05, POUR + 0.1, t);
	if (kp > 0.0) {
		l += glow(p, vec2(0.0, -2.0), half_w(0.0) * 1.25 * 1.6, pal[4].rgb, 0.3 * kp);
	}
	COLOR = vec4(min(l, vec3(1.0)) * strength, 1.0);
}
