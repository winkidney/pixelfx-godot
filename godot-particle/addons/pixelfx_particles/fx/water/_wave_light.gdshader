// The light of a wave crashing (see _wave.gdshaderinc), additive: on the crest as it stands, along the thrown lip
// and under its barrel, the tip's glint, the crash, the whitewater after.
shader_type canvas_item;
render_mode blend_add;

#include "res://addons/pixelfx_particles/fx/water/_water.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/water/_wave.gdshaderinc"

uniform float strength = 1.0;

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5 + center;
	float t = now;
	vec3 l = vec3(0.0);
	float k = lip_k(t);
	if (k > 0.0 && t < CRASH) {
		for (int i = 0; i <= 8; i++) {
			vec3 q = lip(float(i) * 0.125, t);
			l += pal[5].rgb * 0.24 * k * wv_glow(p, q.xy, 6.0 + q.z);
		}
		vec3 b = lip(0.6, t);
		l += pal[4].rgb * 0.25 * k * wv_glow(p, b.xy + vec2(-3.0, 8.0), 16.0);
		float g = sin(W_PI * clamp((k - 0.55) / 0.45, 0.0, 1.0));
		if (g > 0.05) {
			l += pal[6].rgb * 0.5 * g * wv_glow(p, lip(1.0, t).xy, 4.0 + floor(6.0 * g + 0.5) * 2.0);
		}
	}
	float xc = crest_x(t);
	float A = crest_h(t);
	if (t < CRASH) {
		float s = smoothstep(0.2, CRASH, t);
		l += pal[4].rgb * 0.22 * s * wv_glow(p, vec2(xc + 4.0, -A + 2.0), 26.0);
		vec2 a = vec2(xc - 26.0, -A * 0.45);
		vec2 d = vec2(xc, -A) - a;
		float u = clamp(dot(p - a, d) / dot(d, d), 0.0, 1.0);
		l += pal[5].rgb * 0.14 * s * wv_glow(p, a + d * u, 10.0);
	} else {
		l += pal[4].rgb * 0.26 * (1.0 - smoothstep(CRASH, dur - 0.3, t)) * wv_glow(p, vec2(xc, -10.0), 34.0);
	}
	// the crash: light bursting where the lip lands, fading
	float x0 = lip(1.0, CRASH - 0.001).x;
	float a = t - CRASH;
	if (a >= 0.0 && a < 0.55) {
		float f = 1.0 - a / 0.55;
		l += pal[5].rgb * 0.8 * f * f * wv_glow(p, vec2(x0, -20.0), 56.0 * (0.55 + 0.45 * f));
	}
	if (a >= 0.0 && a < 0.1) {
		float f = 1.0 - a / 0.1;
		l += pal[7].rgb * 0.6 * f * f * wv_glow(p, vec2(x0, -4.0), 22.0 * (0.55 + 0.45 * f));
	}
	COLOR = vec4(l * strength, 1.0);
}
