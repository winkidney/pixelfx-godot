// spawn/soul-rise, as the original draws it. mode 0, over the stand-in: its outline flaring (re-rolled each frame on
// the original's hash) and the body left dimmed under a shadow. mode 1: the soul, the body's own picture in pale
// light (`tone`: each pixel's step of the ramp, its rim the brightest), lifted, stretched taller and thinner,
// swaying, its legs melting into a rippling wisp, thinning from the bottom up with a ragged edge; drawn backward from
// the screen so stretching leaves no holes, see-through with its rim solid. Soft layer.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/spawn/_jsrand.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform int mode = 0;
uniform sampler2D tone : filter_nearest;
uniform vec2 origin = vec2(-12.0, -38.0);
uniform float waist = 23.0;
uniform float t = 0.0;
uniform float leave_t = 0.35;
// mode 0
uniform float flare = -1.0;
uniform float dim = 0.0;
uniform vec4 shadow : source_color = vec4(0.0, 0.0, 0.0, 1.0);
// mode 1
uniform float s = 1.0;
uniform float lift = 0.0;
uniform float melt = 0.0;
uniform float thin = 0.0;
uniform float fade_in = 0.0;
uniform float sway_k = 0.0;
uniform vec4 pal[7] : source_color;
uniform vec4 white : source_color = vec4(1.0);

int tone_at(int mx, int my) {
	ivec2 sz = textureSize(tone, 0);
	if (mx < 0 || my < 0 || mx >= sz.x || my >= sz.y) {
		return -1;
	}
	vec4 v = texelFetch(tone, ivec2(mx, my), 0);
	return v.a > 0.5 ? int(v.r + 0.5) : -1;
}

float sway(float row) {
	return sin(t * 3.0 - row * 0.12) * 2.2 * sway_k;
}

vec4 over(vec4 dst, vec3 c, float a) {
	if (a <= 0.004) {
		return dst;
	}
	float oa = a + dst.a * (1.0 - a);
	float k = a / oa;
	return vec4(c * k + dst.rgb * (1.0 - k), oa);
}

void fragment() {
	vec2 cell = floor(center + (UV - 0.5) * size);
	float th = pfx_threshold(FRAGCOORD.xy);
	ivec2 sz = textureSize(tone, 0);
	vec4 o = vec4(0.0);
	if (mode == 0) {
		ivec2 m = ivec2(cell - origin);
		bool body = tone_at(m.x, m.y) >= 0;
		if (flare >= 0.0 && !body && (tone_at(m.x + 1, m.y) >= 0 || tone_at(m.x - 1, m.y) >= 0 || tone_at(m.x, m.y + 1) >= 0 || tone_at(m.x, m.y - 1) >= 0)) {
			if (js_rand3(m.x, m.y, int(floor(t * 30.0))) < 0.25 + 0.7 * flare) {
				o = flare > 0.7 ? white : pal[5];
			}
		}
		if (body && dim > 0.0) {
			o = over(o, shadow.rgb, 0.45 * dim);
		}
	} else {
		float W = float(sz.x);
		float Hh = float(sz.y);
		float top = origin.y * s - lift;
		float sx = 1.0 - 0.12 * (s - 1.0) * 4.0;
		float tail = floor(10.0 * melt + 0.5);
		float y1 = top + (Hh + tail) * s;
		float y = cell.y;
		float x = cell.x;
		if (y >= floor(top) && y <= ceil(y1)) {
			float my = floor((y + 0.5 - top) / s);
			float k = my >= waist ? (my - waist + 1.0) / (Hh - waist + tail) : 0.0;
			float narrow = 1.0 - k * melt * 0.95;
			if (my >= 0.0 && narrow > 0.05) {
				float cx = sway(my) + sin(my * 0.7 - t * 8.0) * 2.0 * k * melt;
				float a = (my >= waist ? 1.0 - k * 0.45 : 1.0) * fade_in;
				if (x >= floor(cx - W / 2.0 - 4.0) && x <= ceil(cx + W / 2.0 + 4.0)) {
					float mx = floor((x + 0.5 - cx) / (sx * narrow) - origin.x);
					bool gone = thin > 0.0 && my / (Hh + tail) > 1.0 - thin * 1.25 + 0.25 * js_rand3(int(mx), int(my), 5) - 0.1;
					int ti = -1;
					if (!gone) {
						if (my < Hh) {
							ti = tone_at(int(mx), int(my));
						} else {
							float w = (1.0 - (my - Hh) / max(1.0, tail)) * 3.2 * melt;
							float d = abs(x + 0.5 - cx);
							if (d <= w) {
								ti = d > w - 1.0 ? 5 : 4;
							}
						}
					}
					if (ti >= 0) {
						if (t < leave_t + 0.07) {
							o = ti >= 6 ? pal[5] : white;
						} else if (ti >= 5) {
							float aa = min(1.0, a * 1.3);
							if (aa >= 1.0 || aa > th) {
								o = ti >= 6 ? white : pal[5];
							}
						} else {
							o = over(o, pal[ti].rgb, a * 0.7);
						}
					}
				}
			}
		}
	}
	if (o.a <= 0.0) {
		discard;
	}
	float a = floor(o.a * 32.0 + th) / 32.0;
	if (a <= 0.0) {
		discard;
	}
	COLOR = vec4(o.rgb, a);
}
