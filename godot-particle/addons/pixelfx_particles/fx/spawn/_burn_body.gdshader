// spawn/dissolve-burn's body, drawn in place of the stand-in from its own pixels (`tex`, feet at the origin): a seam of
// fire climbs it from the feet (`keys`: when each pixel catches, from the original's formula), white-hot at the very
// edge and flickering through yellow and orange (re-rolled each frame with the original's hash), charred just above
// with live sparks in the char, browned by the heat above that; pixels below the seam are gone. Tongues of flame lick
// up from the seam while there's body left to burn (layered, flickering and swaying on the original's noise, keyed
// clock `t`). Colour layer; the body's own colours and its mixes are kept as they are.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/spawn/_jsrand.gdshaderinc"

uniform vec2 size = vec2(28.0, 58.0);
uniform vec2 center = vec2(0.0);
uniform sampler2D tex : filter_nearest;
uniform sampler2D keys : filter_nearest;
uniform vec2 origin = vec2(-12.0, -38.0);
uniform float t = 0.0;
uniform float front = -1.0;
uniform float frame = 0.0;
uniform vec4 pal[8] : source_color;
uniform vec4 char_c[3] : source_color;
uniform vec4 white : source_color = vec4(1.0);
// the tongues: x, height, seed
uniform vec3 tongues[6];

bool on(ivec2 m, ivec2 sz) {
	return m.x >= 0 && m.y >= 0 && m.x < sz.x && m.y < sz.y && texelFetch(tex, m, 0).a > 0.5;
}

vec3 mix8(vec3 a, vec3 b, float k) {
	vec3 a8 = floor(a * 255.0 + 0.5);
	vec3 b8 = floor(b * 255.0 + 0.5);
	return floor(a8 + (b8 - a8) * k) / 255.0;
}

float smooth01(float a, float b, float x) {
	float u = clamp((x - a) / (b - a), 0.0, 1.0);
	return u * u * (3.0 - 2.0 * u);
}

void fragment() {
	vec2 cell = floor(center + (UV - 0.5) * size);
	ivec2 sz = textureSize(tex, 0);
	float H = float(sz.y);
	float f = front;
	vec4 o = vec4(0.0);
	ivec2 m = ivec2(cell - origin);
	if (on(m, sz)) {
		float key = texelFetch(keys, m, 0).r;
		if (key >= f) {
			float d = key - f;
			int fr = int(frame + 0.5);
			vec3 c = texelFetch(tex, m, 0).rgb;
			if (d < 0.025) {
				o = js_rand3(m.x, m.y, fr) < 0.35 ? white : pal[6];
			} else if (d < 0.05) {
				o = js_rand3(m.x, m.y, fr + 7) < 0.5 ? pal[5] : pal[4];
			} else if (d < 0.11) {
				o = js_rand3(m.x, m.y, 13) < 0.15 && js_rand3(m.x, fr, 2) < 0.6 ? pal[3] : char_c[d < 0.075 ? 0 : 1];
			} else if (d < 0.16) {
				o = vec4(mix8(c, char_c[2].rgb, 0.6), 1.0);
			} else if (d < 0.26) {
				o = vec4(mix8(c, pal[2].rgb, 0.18), 1.0);
			} else {
				o = vec4(c, 1.0);
			}
		}
	}
	if (f > -0.02 && f < 1.05) {
		// tongues of flame along the seam: four layers each, later ones on top
		float fy = origin.y + (1.0 - clamp(f, 0.0, 1.0)) * H;
		float k = 1.0 - smooth01(0.95, 1.05, f);
		for (int i = 0; i < 6; i++) {
			vec3 g = tongues[i];
			int row = int(floor(fy - origin.y + 0.5));
			ivec2 gm = ivec2(int(floor(g.x - origin.x + 0.5)), clamp(row, 0, sz.y - 1));
			if (!on(gm, sz)) {
				continue;
			}
			int sd = int(g.z + 0.5);
			float h = g.y * k * (0.6 + 0.6 * (js_noise(t * 2.6 + g.z, sd) * 0.5 + 0.5)) * smooth01(-0.02, 0.06, f);
			if (h < 1.0) {
				continue;
			}
			float y = fy + 1.0;
			for (int l = 0; l < 4; l++) {
				float lw = l == 0 ? 1.0 : l == 1 ? 0.7 : l == 2 ? 0.45 : 0.25;
				float lh = l == 0 ? 1.0 : l == 1 ? 0.8 : l == 2 ? 0.6 : 0.35;
				float hh = h * lh;
				for (int r = 0; r <= 20; r++) {
					if (float(r) > hh) {
						break;
					}
					if (floor(y - float(r) + 0.5) != cell.y) {
						continue;
					}
					float u = float(r) / max(1.0, hh);
					float half_w = 1.8 * lw * pow(1.0 - u, 0.9) + js_noise(t * 9.0 + float(r) * 0.5, sd) * 0.4;
					float cx = g.x + js_noise(t * 4.0 + float(r) * 0.25, sd + 7) * u * 1.6;
					if (half_w < 0.3) {
						continue;
					}
					if (cell.x >= floor(cx - half_w + 0.5) && cell.x <= floor(cx + half_w + 0.5)) {
						o = pal[3 + l];
					}
				}
			}
		}
	}
	if (o.a < 0.5) {
		discard;
	}
	COLOR = vec4(o.rgb, 1.0);
}
