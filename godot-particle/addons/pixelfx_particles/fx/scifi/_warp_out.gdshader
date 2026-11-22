// Warp out (src/fx/scifi/warp-out.js), from the effect's clock `t` (the original's own, keyed a frame at a time):
//   mode 0, behind the stand-in: the floor target's far half closing in, then the beam (thin bright walls, a glassy
//           inside) standing from the floor to the sky, lifting off and pinching shut
//   mode 1, in front: the target's near half; the outline flickering on round the hero as it charges; the body held
//           together in light (white in the flash, cooling to the beam's colour, its own shading under it, a bright
//           rim, a rolling scanline, white again the moment each pixel lets go: `bits` holds when, `tex` its colours);
//   mode 2: the star of the flash (over the bits flying up)
// Colour layer (the beam's inside translucent).
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/scifi/_scifi.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/scifi/_jsrand.gdshaderinc"

uniform vec2 size = vec2(128.0, 168.0);
uniform vec2 center = vec2(0.0);
uniform float t = 0.0;
uniform int mode = 0;
uniform sampler2D tex : filter_nearest;
uniform sampler2D bits : filter_nearest, repeat_disable;
uniform vec4 pal[8] : source_color;

#include "res://addons/pixelfx_particles/fx/scifi/_warp.gdshaderinc"

const float FLASH = 0.42;
const float BREAK0 = 0.5;
const float LIFT = 1.3;
const float GONE = 1.62;
const float TOP = -128.0;

float width_at(float tt) {
	if (tt < BREAK0) {
		return 0.0;
	}
	if (tt < LIFT) {
		return 2.0 + 7.0 * e_out_cubic((tt - BREAK0) / 0.35);
	}
	return mix(9.0, 0.6, e_in_cubic((tt - LIFT) / (GONE - LIFT)));
}

float foot_at(float tt) {
	return tt < LIFT ? 0.0 : mix(0.0, TOP, e_in_quad((tt - LIFT) / (GONE - LIFT)));
}

vec4 back_layer(ivec2 P, float thr) {
	vec4 c = vec4(0.0);
	float k = clamp(t / FLASH, 0.0, 1.0);
	float fade = 1.0 - e_smooth(LIFT, LIFT + 0.6, t);
	if (fade > 0.0) {
		band_at(c, P, vec2(0.0), mix(30.0, 14.0, e_out_cubic(k)), 0.16, 1.5, (0.4 + 0.6 * k) * fade, pal[3], pal[4], pal[5], pal[6], -1, false, thr);
	}
	float w = width_at(t);
	float f = foot_at(t);
	float y = float(P.y);
	if (w > 0.3 && t < GONE && y >= TOP && y < f) {
		float x = float(P.x);
		if (x >= floor(-w) - 1.0 && x <= ceil(w)) {
			float q = abs(x + 0.5) / w;
			if (q <= 1.0 + 1.0 / w) {
				if (w < 2.2) {
					c = q < 0.7 ? vec4(1.0) : pal[6];
				} else if (q > 1.0) {
					if (0.5 >= thr) {
						c = pal[4];
					}
				} else if (q > 1.0 - 1.2 / w) {
					c = pal[6];
				} else {
					c = blend_over(c, pal[5].rgb, 0.12 + 0.25 * q * q);
				}
			}
		}
	}
	return c;
}

vec4 front_layer(ivec2 P, float thr) {
	vec4 c = vec4(0.0);
	float k = clamp(t / FLASH, 0.0, 1.0);
	float fade = 1.0 - e_smooth(LIFT, LIFT + 0.6, t);
	if (fade > 0.0) {
		band_at(c, P, vec2(0.0), mix(30.0, 14.0, e_out_cubic(k)), 0.16, 1.5, (0.4 + 0.6 * k) * fade, pal[3], pal[5], pal[6], vec4(1.0), 1, false, thr);
	}
	// charging: the outline flickers on round the hero, denser as it builds
	if (t < FLASH && !on_body(P) && (on_body(P + ivec2(1, 0)) || on_body(P - ivec2(1, 0)) || on_body(P + ivec2(0, 1)) || on_body(P - ivec2(0, 1)))) {
		int fr = int(floor(t * 24.0));
		if (float(js_hash3(P.x, P.y, fr)) / 4294967296.0 < 0.25 + 0.7 * k) {
			uint h = js_mix(js_hash3(P.x, P.y, fr), 1u);
			c = k > 0.7 && float(h) / 4294967296.0 < 0.5 ? vec4(1.0) : pal[5];
		}
	}
	// the body, still held together
	if (t >= FLASH && on_body(P)) {
		vec4 b = texelFetch(bits, P - ivec2(AX, AY), 0);
		float tr = b.x;
		if (t < tr) {
			vec4 bc = body_px(P);
			float a = t - FLASH;
			bool scan = int(mod(float(P.y) + floor(t * 40.0), 4.0)) == 0;
			vec4 col = a < 0.07 ? vec4(1.0) : a < 0.16 ? pal[6] : b.y > 0.5 ? pal[6] : vec4(mix(bc.rgb, scan ? pal[6].rgb : pal[5].rgb, scan ? 0.6 : 0.45), 1.0);
			c = tr - t < 0.06 ? vec4(1.0) : col;
		}
	}
	return c;
}

void fragment() {
	vec2 cell = floor(center + (UV - 0.5) * size + 0.001);
	ivec2 P = ivec2(cell);
	float thr = pfx_threshold(FRAGCOORD.xy);
	vec4 c = vec4(0.0);
	if (mode == 0) {
		c = back_layer(P, thr);
	} else if (mode == 1) {
		c = front_layer(P, thr);
	} else if (t >= FLASH && t < FLASH + 0.12) {
		sparkle_at(c, P, vec2(0.0, -20.0), 10.0 * (1.0 - (t - FLASH) / 0.12), pal[6], pal[5]);
	}
	if (c.a <= 0.0) {
		discard;
	}
	if (px_out(c, FRAGCOORD.xy, c.a < 0.999)) {
		discard;
	}
	COLOR = c;
}
