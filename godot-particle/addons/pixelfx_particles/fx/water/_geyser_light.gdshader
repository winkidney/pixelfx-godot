// The light of a geyser (see _geyser.gdshaderinc), additive: the mound's pulse, the spurts, the blast, the column and
// its head, the foot and the pool.
shader_type canvas_item;
render_mode blend_add;

#include "res://addons/pixelfx_particles/fx/water/_water.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/water/_geyser.gdshaderinc"

uniform float strength = 1.0;

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5 + center;
	float t = now;
	vec3 l = vec3(0.0);
	float H = top_h(t);
	float hk = head_k(t);
	float k = clamp(t / ERUPT, 0.0, 1.0);
	float th = thin_k(t);
	if (t < ERUPT + 0.05) {
		float beat = pow(max(0.0, sin(t * (8.0 + 18.0 * k * k))), 3.0);
		l += pal[5].rgb * (0.06 + 0.12 * k + 0.12 * beat) * g_glow(p, vec2(0.0, -5.0), 16.0 + 16.0 * k + 8.0 * beat);
	}
	float sp = spurt_h(t);
	if (sp > 1.0 && H < 1.0) {
		l += pal[5].rgb * 0.3 * g_glow_line(p, vec2(0.0), vec2(0.0, -sp), 8.0);
	}
	if (H >= 1.0) {
		l += pal[5].rgb * 0.12 * th * g_glow_line(p, vec2(0.0), vec2(0.0, -H), 16.0 + 8.0 * th);
		l += pal[4].rgb * 0.2 * th * g_glow_line(p, vec2(0.0), vec2(0.0, -H), 26.0);
	}
	if (hk > 0.01 && H >= 4.0) {
		l += pal[5].rgb * 0.34 * hk * g_glow(p, vec2(0.0, -H - 2.0), 38.0);
	}
	l += pal[4].rgb * 0.24 * max(hk, 0.3 * k * (t < ERUPT ? 1.0 : 0.0)) * g_glow(p, vec2(0.0, -2.0), 46.0);
	l += pal[3].rgb * 0.12 * pool_k(t) * g_glow(p, vec2(0.0, 2.0), 60.0);
	// the blast: a burst of light up the column and a white flash at the vent, fading
	float a = t - ERUPT;
	if (a >= 0.0 && a < 0.6) {
		float f = 1.0 - a / 0.6;
		l += pal[5].rgb * 0.85 * f * f * g_glow(p, vec2(0.0, -26.0), 64.0 * (0.55 + 0.45 * f));
	}
	if (a >= 0.0 && a < 0.1) {
		float f = 1.0 - a / 0.1;
		l += pal[7].rgb * 0.75 * f * f * g_glow(p, vec2(0.0, -4.0), 28.0 * (0.55 + 0.45 * f));
	}
	COLOR = vec4(l * strength, 1.0);
}
