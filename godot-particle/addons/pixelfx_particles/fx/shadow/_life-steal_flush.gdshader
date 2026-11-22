// Life steal's flush over the stand-in (`tex`, feet at the origin, centred): mode 0 pushes its own pixels toward
// blood-red by their brightness (c6 / c5 / c4 / c3) at alpha 0.45 fk (translucent); mode 1 is a hot outline just
// outside it in `edge`. Coordinates: px from the effect's origin. Colour layer.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(28.0, 42.0);
uniform vec2 center = vec2(0.0);
uniform sampler2D tex : filter_nearest;
uniform float mode = 0.0;
uniform float fk = 0.0;
uniform vec4 c3 : source_color = vec4(1.0);
uniform vec4 c4 : source_color = vec4(1.0);
uniform vec4 c5 : source_color = vec4(1.0);
uniform vec4 c6 : source_color = vec4(1.0);
uniform vec4 edge : source_color = vec4(1.0);

bool at(ivec2 q, ivec2 ts) {
	if (q.x < 0 || q.y < 0 || q.x >= ts.x || q.y >= ts.y) {
		return false;
	}
	return texelFetch(tex, q, 0).a >= 0.5;
}

void fragment() {
	vec2 cell = floor((UV - 0.5) * size + center + 0.001);
	ivec2 ts = textureSize(tex, 0);
	ivec2 q = ivec2(int(cell.x + floor(float(ts.x) / 2.0)), int(cell.y + float(ts.y)));
	vec4 c;
	if (mode < 0.5) {
		if (!at(q, ts)) {
			discard;
		}
		float l = dot(texelFetch(tex, q, 0).rgb, vec3(0.299, 0.587, 0.114));
		c = l > 0.6 ? c6 : l > 0.4 ? c5 : l > 0.2 ? c4 : c3;
		c.a = 0.45 * fk;
	} else {
		if (at(q, ts) || !(at(q + ivec2(1, 0), ts) || at(q - ivec2(1, 0), ts) || at(q + ivec2(0, 1), ts) || at(q - ivec2(0, 1), ts))) {
			discard;
		}
		c = edge;
	}
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
