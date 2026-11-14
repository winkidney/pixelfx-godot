// The light under water (see _underwater.gdshaderinc), additive: shafts slanting down from the surface, the glow
// along the lit surface line, caustics dancing on the floor where the shafts reach it.
shader_type canvas_item;
render_mode blend_add;

#include "res://addons/pixelfx_particles/fx/water/_water.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/water/_underwater.gdshaderinc"

uniform float strength = 1.0;

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5 + center;
	float ph = t;
	vec3 l = vec3(0.0);
	float e = 1.0 - smoothstep(half_w - 14.0, half_w, abs(p.x));
	if (abs(p.x) <= half_w && p.y <= 0.0 && p.y >= top - 2.0 && p.y >= surface_y(p.x, ph)) {
		float depth = (p.y - top) / -top;
		float s = shaft(p.x, p.y, ph) * (1.0 - depth * 0.7) * e;
		if (s > 0.05) {
			l += pal[4].rgb * 0.2 * s;
		}
	}
	// caustics on the floor
	if (abs(p.x) <= half_w && p.y > -3.0 && p.y < 1.0) {
		float s = shaft(p.x, -2.0, ph);
		float cc = max(0.0, 1.0 - abs(sin(p.x * 0.42 + sin(p.x * 0.11 + ph * U_TAU * 2.0) * 2.2)) * 2.4);
		float k = s * cc * e;
		if (k > 0.05) {
			l += floor(p.y) == -1.0 ? pal[5].rgb * 0.5 * k : floor(p.y) == -2.0 ? pal[4].rgb * 0.25 * k : pal[4].rgb * 0.3 * k;
		}
	}
	// the glow along the surface line, every 4 px
	for (int i = 0; i < 24; i++) {
		float X = -half_w + float(i) * 4.0;
		float x = X + 0.5;
		vec2 g = vec2(x, surface_y(x, ph) + 1.0);
		float d = distance(p, g) / 7.0;
		if (d < 1.0) {
			float ee = 1.0 - smoothstep(half_w - 12.0, half_w, abs(x));
			l += pal[5].rgb * (1.0 - d) * (1.0 - d) * (surface_glint(x, ph) ? 0.22 : 0.1) * ee;
		}
	}
	COLOR = vec4(l * strength, 1.0);
}
