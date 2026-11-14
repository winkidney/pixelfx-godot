// Light riding a swing (melee/_lib.js glowAlong()), light layer: the original's p.glow(x, y, rad, color, k(u)) at plane
// radius gr every `gstep` radians from u0 to u1, summed. k(u) = k0, times (u - la) / (lb - la) when lin is 1, times
// exp(-age / atau) when age_mode is 1 (spin-slash: the edge passed u at SW (1 - (1 - u / aspan)^(1 / 1.6))) or 2
// (heavy-cleave: at ap0 + ap1 sqrt(u / aspan)), age = at - that. Key u0, u1, k0, la, lb, at.
shader_type canvas_item;
render_mode blend_add;

#include "res://addons/pixelfx_particles/fx/melee/_swing.gdshaderinc"

uniform float gr = 30.0;
uniform float u0 = 0.0;
uniform float u1 = 0.0;
uniform float gstep = 0.3;
uniform float rad = 10.0;
uniform vec4 color : source_color = vec4(1.0);
uniform float k0 = 0.0;
uniform float lin = 0.0;
uniform float la = 0.0;
uniform float lb = 1.0;
uniform float age_mode = 0.0;
uniform float at = 0.0;
uniform float ap0 = 0.0;
uniform float ap1 = 0.0;
uniform float aspan = 6.2831853;
uniform float atau = 1.0;
uniform float strength = 1.0;

void fragment() {
	vec2 p = sw_px(UV);
	float sum = 0.0;
	if (k0 > 0.0 && u1 >= u0) {
		for (int i = 0; i < 96; i++) {
			float u = u0 + float(i) * gstep;
			if (u > u1 + 1e-5) {
				break;
			}
			if (!sw_keep(a0 + dir * u, side)) {
				continue;
			}
			float k = k0;
			if (lin > 0.5) {
				k *= (u - la) / max(1e-4, lb - la);
			}
			if (age_mode > 0.5 && age_mode < 1.5) {
				float f = clamp(u / aspan, 0.0, 1.0);
				k *= exp(-(at - ap0 * (1.0 - pow(1.0 - f, 1.0 / 1.6))) / atau);
			} else if (age_mode > 1.5) {
				float f = clamp(u / aspan, 0.0, 1.0);
				k *= exp(-max(0.0, at - ap0 - ap1 * sqrt(f)) / atau);
			}
			if (k <= 0.004) {
				continue;
			}
			float d = length(p - sw_on(gr, u)) / rad;
			if (d < 1.0) {
				sum += (1.0 - d) * (1.0 - d) * k;
			}
		}
	}
	COLOR = vec4(color.rgb * sum * strength * COLOR.rgb * COLOR.a, 1.0);
}
