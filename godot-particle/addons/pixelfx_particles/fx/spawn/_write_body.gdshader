// spawn/respawn-beam's character written in from the feet, from the stand-in's own pixels (`tex`): each row lands
// white as the scan bar passes (the original's row times), cools through the beam's colour to its own, its outline
// lit a moment longer; some rows jump sideways for a frame as they land (the original's hash). Over it the scan bar
// (a bright line across the beam, a dimmer one under it), and once it's done a flash round its outline. Colour layer;
// the body's own colours and mixes kept as they are.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/spawn/_jsrand.gdshaderinc"

uniform vec2 size = vec2(53.0, 43.0);
uniform vec2 center = vec2(0.0);
uniform sampler2D tex : filter_nearest;
uniform vec2 origin = vec2(-12.0, -38.0);
uniform float t = 0.0;
uniform float write0 = 0.4;
uniform float write_len = 0.95;
uniform float body_on = 0.0;
uniform float bar_on = 0.0;
uniform float bar_y = 0.0;
uniform float bar_w = 0.0;
uniform float flash = -1.0;
uniform vec4 c4 : source_color = vec4(1.0);
uniform vec4 c5 : source_color = vec4(1.0);
uniform vec4 c6 : source_color = vec4(1.0);
uniform vec4 white : source_color = vec4(1.0);

bool on(ivec2 m, ivec2 sz) {
	return m.x >= 0 && m.y >= 0 && m.x < sz.x && m.y < sz.y && texelFetch(tex, m, 0).a > 0.5;
}

vec3 mix8(vec3 a, vec3 b, float k) {
	vec3 a8 = floor(a * 255.0 + 0.5);
	vec3 b8 = floor(b * 255.0 + 0.5);
	return floor(a8 + (b8 - a8) * k) / 255.0;
}

// a 1 px horizontal line from x0 to x1 at row y (cells): -1 off it, else u along it
float hline(vec2 cell, float x0, float x1, float y) {
	float a = floor(x0);
	float b = floor(x1);
	if (cell.y != floor(y) || cell.x < a || cell.x > b) {
		return -1.0;
	}
	return b > a ? (cell.x - a) / (b - a) : 0.0;
}

void fragment() {
	vec2 cell = floor(center + (UV - 0.5) * size);
	ivec2 sz = textureSize(tex, 0);
	float H = float(sz.y);
	float th = pfx_threshold(FRAGCOORD.xy);
	vec4 o = vec4(0.0);
	if (body_on > 0.5) {
		int my = int(cell.y - origin.y);
		if (my >= 0 && my < sz.y) {
			float t0 = write0 + write_len * acos(1.0 - 2.0 * clamp((H - float(my)) / (H + 2.0), 0.0, 1.0)) / PI;
			float age = t - t0;
			if (age >= 0.0) {
				int fr = int(floor(t * 30.0));
				float glitch = age < 0.12 && js_rand3(my, fr, 9) < 0.3 ? (js_rand3(my, fr, 4) < 0.5 ? -2.0 : 2.0) : 0.0;
				ivec2 m = ivec2(int(cell.x - origin.x - glitch), my);
				if (on(m, sz)) {
					vec3 bc = texelFetch(tex, m, 0).rgb;
					bool edge = !on(m + ivec2(1, 0), sz) || !on(m - ivec2(1, 0), sz) || !on(m + ivec2(0, 1), sz) || !on(m - ivec2(0, 1), sz);
					vec3 c = age < 0.05 ? white.rgb : age < 0.14 ? c5.rgb : age < 0.3 ? mix8(bc, c5.rgb, 0.5 * (1.0 - (age - 0.14) / 0.16)) : bc;
					o = vec4(edge && age < 0.3 ? c6.rgb : c, 1.0);
				}
			}
		}
		if (bar_on > 0.5) {
			float u = hline(cell, -bar_w - 2.0, bar_w + 2.0, bar_y);
			if (u >= 0.0) {
				o = abs(u - 0.5) < 0.35 ? white : c5;
			} else if (hline(cell, -bar_w, bar_w, bar_y + 1.0) >= 0.0 && 0.6 > th) {
				o = c4;
			}
		}
	}
	if (flash >= 0.0) {
		ivec2 m = ivec2(cell - origin);
		if (!on(m, sz) && (on(m + ivec2(1, 0), sz) || on(m - ivec2(1, 0), sz) || on(m + ivec2(0, 1), sz) || on(m - ivec2(0, 1), sz))) {
			float a = 1.2 - flash;
			if (a >= 1.0 || a > th) {
				o = flash < 0.4 ? white : c5;
			}
		}
	}
	if (o.a < 0.5) {
		discard;
	}
	COLOR = vec4(o.rgb, 1.0);
}
