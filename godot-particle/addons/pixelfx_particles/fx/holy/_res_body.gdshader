// holy/resurrection: the fallen body as the light climbs it, drawn over the stand-in from its own pixels (`tex`, feet
// at the origin, centred). mode 1: above the line `ly` it's ash (each pixel's brightness on the ash ramp), the line
// itself white then cream, below it warmed toward gold and fading back to itself; its outline catches the light
// just under the line. mode 2: the hero frame, the body flashed white then cooling through gold (u: seconds since).
// mode 0: nothing (the stand-in shows as itself). Colour layer; the warmed colours are mixes, kept as they are.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(28.0, 42.0);
uniform vec2 center = vec2(0.0);
uniform sampler2D tex : filter_nearest;
uniform float mode = 0.0;
uniform float ly = 1.0;
uniform float u = 0.0;
uniform vec4 ash[6] : source_color;
uniform vec4 pal[8] : source_color;

vec4 at(ivec2 q) {
	ivec2 ts = textureSize(tex, 0);
	if (q.x < 0 || q.y < 0 || q.x >= ts.x || q.y >= ts.y) {
		return vec4(0.0);
	}
	return texelFetch(tex, q, 0);
}

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5 + center;
	vec2 cell = floor(p);
	ivec2 ts = textureSize(tex, 0);
	ivec2 q = ivec2(cell) + ivec2(ts.x / 2, ts.y);
	vec4 c = at(q);
	bool inside = c.a >= 0.5;
	float th = pfx_threshold(FRAGCOORD.xy);
	vec4 o = vec4(0.0);
	if (mode < 0.5) {
		discard;
	}
	if (inside) {
		if (mode < 1.5) {
			float d = cell.y - ly;
			if (d < -0.5) {
				float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
				o = ash[clamp(int(floor(l * 1.1 * 6.0)), 0, 5)];
			} else if (d < 0.5) {
				o = vec4(1.0);
			} else if (d < 1.5) {
				o = pal[6];
			} else {
				float k = exp(-(d - 1.5) / 4.0) * 0.7;
				if (k > 0.08) {
					o = vec4(mix(c.rgb, pal[5].rgb, k), 1.0);
				}
			}
		} else {
			if (u < 0.06) {
				o = vec4(1.0);
			} else if (u < 0.45) {
				o = vec4(mix(c.rgb, pal[5].rgb, 0.55 * pow(1.0 - u / 0.45, 2.0)), 1.0);
			}
		}
	} else {
		bool rim = at(q + ivec2(1, 0)).a >= 0.5 || at(q - ivec2(1, 0)).a >= 0.5 || at(q + ivec2(0, 1)).a >= 0.5 || at(q - ivec2(0, 1)).a >= 0.5;
		if (rim) {
			if (mode < 1.5) {
				float d = cell.y - ly;
				if (d >= -0.5 && d <= 12.0) {
					float a = d < 1.0 ? 1.0 : 1.1 - d / 12.0;
					if (a >= 1.0 || a > th) {
						o = d < 1.0 ? vec4(1.0) : d < 5.0 ? pal[5] : pal[4];
					}
				}
			} else if (u < 0.25 && 1.0 - u / 0.25 > th) {
				o = u < 0.08 ? vec4(1.0) : pal[5];
			}
		}
	}
	if (o.a < 0.5) {
		discard;
	}
	COLOR = vec4(o.rgb, 1.0);
}
