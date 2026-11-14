// spawn/disintegrate's body, drawn over the stand-in from its own pixels (`tex`, feet at the origin): a crackling
// outline that thickens as the charge gathers (re-rolled each frame with the original's hash), then the body shudders,
// flashes white, and peels from the head down, each pixel heating white-hot as the front reaches it and gone once it
// has passed (`keys`: when each pixel lets go, from the original's formula). Colour layer; the body's warmed colours
// are mixes of its own, kept as they are.
//   phase 0: no body (the stand-in shows as itself), 1 shudder (shift: -1 or 0 px), 2 white, 3 peel (front)
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/spawn/_jsrand.gdshaderinc"

uniform vec2 size = vec2(28.0, 40.0);
uniform vec2 center = vec2(0.0);
uniform sampler2D tex : filter_nearest;
uniform sampler2D keys : filter_nearest;
// the mask's top-left in the effect's coordinates
uniform vec2 origin = vec2(-12.0, -38.0);
uniform float phase = 0.0;
uniform float shift = 0.0;
uniform float front = -1.0;
// the charge's crackle: ck (0..1, < 0 off) and the frame it's rolled on
uniform float ck = -1.0;
uniform float frame = 0.0;
uniform vec4 c4 : source_color = vec4(1.0);
uniform vec4 c5 : source_color = vec4(1.0);
uniform vec4 c6 : source_color = vec4(1.0);
uniform vec4 white : source_color = vec4(1.0);

bool on(ivec2 m, ivec2 sz) {
	return m.x >= 0 && m.y >= 0 && m.x < sz.x && m.y < sz.y && texelFetch(tex, m, 0).a > 0.5;
}

vec3 mix8(vec3 a, vec3 b, float t) {
	vec3 a8 = floor(a * 255.0 + 0.5);
	vec3 b8 = floor(b * 255.0 + 0.5);
	return floor(a8 + (b8 - a8) * t) / 255.0;
}

void fragment() {
	vec2 cell = floor(center + (UV - 0.5) * size);
	ivec2 sz = textureSize(tex, 0);
	vec4 o = vec4(0.0);
	if (phase > 0.5) {
		ivec2 m = ivec2(cell - origin - vec2(phase < 1.5 ? shift : 0.0, 0.0));
		if (on(m, sz)) {
			vec4 kk = texelFetch(keys, m, 0);
			float key = kk.r;
			bool edge = kk.g > 0.5;
			vec3 c = texelFetch(tex, m, 0).rgb;
			if (phase < 1.5) {
				o = vec4(edge ? mix8(c, c6.rgb, 0.7) : mix8(c, c5.rgb, 0.25), 1.0);
			} else if (phase < 2.5) {
				o = edge ? c6 : white;
			} else if (key >= front) {
				float d = key - front;
				ivec2 up = m - ivec2(0, 1);
				bool above = !on(up, sz) || texelFetch(keys, up, 0).r < front;
				vec3 r = above && d < 0.06 ? white.rgb : d < 0.03 ? mix8(c, c6.rgb, 0.7) : d < 0.1 ? mix8(c, c5.rgb, 0.4)
					: edge ? mix8(c, c5.rgb, 0.5) : mix8(c, c4.rgb, 0.16);
				o = vec4(r, 1.0);
			}
		}
	}
	if (o.a < 0.5 && ck >= 0.0) {
		// the crackle round the rim: the cells just outside the body
		ivec2 m = ivec2(cell - origin);
		if (!on(m, sz) && (on(m + ivec2(1, 0), sz) || on(m - ivec2(1, 0), sz) || on(m + ivec2(0, 1), sz) || on(m - ivec2(0, 1), sz))) {
			int fr = int(frame + 0.5);
			float h = js_rand3(m.x * 61 + m.y, fr, 7);
			if (h < 0.12 + 0.62 * ck * ck) {
				o = ck > 0.72 && js_rand3(m.x, m.y, fr) < 0.5 ? white : h < 0.2 ? c6 : c5;
			}
		}
	}
	if (o.a < 0.5) {
		discard;
	}
	COLOR = vec4(o.rgb, 1.0);
}
