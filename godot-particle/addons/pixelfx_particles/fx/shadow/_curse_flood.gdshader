// Curse's flood over the stand-in (`tex`, feet at the origin, centred): mode 0 washes its pixels down to `flood`
// (0..1 of its height) in violet by their brightness at alpha 0.6 k pulse, a bright front just ahead (while it runs)
// and a band sweeping down once it's full (band: its height share, < -1 none); mode 1 is the crawling violet edge
// just outside it (c6 / c4 by sin(my 0.7 - t 14 + mx 0.3), at k). Translucent for mode 0. Colour layer.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(28.0, 42.0);
uniform vec2 center = vec2(0.0);
uniform sampler2D tex : filter_nearest;
uniform float mode = 0.0;
uniform float flood = 0.0;
uniform float k = 1.0;
uniform float pulse = 1.0;
uniform float band = -9.0;
uniform float crawl = 0.0;
uniform vec4 c2 : source_color = vec4(1.0);
uniform vec4 c3 : source_color = vec4(1.0);
uniform vec4 c4 : source_color = vec4(1.0);
uniform vec4 c5 : source_color = vec4(1.0);
uniform vec4 c6 : source_color = vec4(1.0);
uniform vec4 c7 : source_color = vec4(1.0);

bool at(ivec2 q, ivec2 ts) {
	if (q.x < 0 || q.y < 0 || q.x >= ts.x || q.y >= ts.y) {
		return false;
	}
	return texelFetch(tex, q, 0).a >= 0.5;
}

void fragment() {
	vec2 cell = floor((UV - 0.5) * size + center + 0.001);
	ivec2 ts = textureSize(tex, 0);
	float ax = -floor(float(ts.x) / 2.0);
	float ay = -float(ts.y);
	ivec2 q = ivec2(int(cell.x - ax), int(cell.y - ay));
	float u = float(q.y) / float(ts.y);
	vec4 c;
	if (mode < 0.5) {
		if (!at(q, ts) || u > flood + 0.06) {
			discard;
		}
		vec4 c0 = texelFetch(tex, q, 0);
		float l = dot(c0.rgb, vec3(0.299, 0.587, 0.114));
		bool edge = flood < 1.0 && abs(u - flood) < 0.05;
		bool bnd = flood >= 1.0 && abs(u - band) < 0.06;
		vec4 cc = l > 0.72 ? c6 : l > 0.5 ? c5 : l > 0.33 ? c4 : l > 0.18 ? c3 : c2;
		c = edge ? c7 : bnd ? c6 : cc;
		c.a = edge ? 0.85 : bnd ? 0.7 * k : 0.6 * k * pulse;
	} else {
		if (at(q, ts) || !(at(q + ivec2(1, 0), ts) || at(q - ivec2(1, 0), ts) || at(q + ivec2(0, 1), ts) || at(q - ivec2(0, 1), ts))) {
			discard;
		}
		if (u > flood) {
			discard;
		}
		c = sin(float(q.y) * 0.7 - crawl * 14.0 + float(q.x) * 0.3) > 0.2 ? c6 : c4;
		c.a = k;
	}
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
