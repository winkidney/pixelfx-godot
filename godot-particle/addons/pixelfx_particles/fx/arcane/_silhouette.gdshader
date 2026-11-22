// The stand-in's silhouette as the blinks draw it (arcane/_lib.js squeezed() and the crackling outline), read from its
// own pixels (`tex`, feet at the origin, centred): mode 0, squeezed to `sx` of its width about its middle, `body` on
// its pixels and `edge` on its dark outline pixels; mode 1, an outline of light crackling just outside it (each pixel
// on with chance `chance`, re-rolled when `grain` changes; white or c6 when `hot`); mode 2, a translucent ghost (`body`
// on its pixels, `edge` on its outline, at `alpha`). Coordinates: px from the effect's origin. Colour layer.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(28.0, 40.0);
uniform vec2 center = vec2(0.0);
uniform sampler2D tex : filter_nearest;
uniform float mode = 0.0;
uniform float sx = 1.0;
uniform vec4 body : source_color = vec4(1.0);
uniform vec4 edge : source_color = vec4(1.0);
uniform vec4 white : source_color = vec4(1.0);
uniform float chance = 1.0;
uniform float hot = 0.0;
uniform float grain = 0.0;
uniform float alpha = 1.0;

float rnd(vec2 q, float g) {
	return fract(sin(dot(q, vec2(12.9898, 78.233)) + g * 7.13) * 43758.5453);
}

// 0 empty, 1 dark outline, 2 body
int shade_at(ivec2 q) {
	ivec2 ts = textureSize(tex, 0);
	if (q.x < 0 || q.y < 0 || q.x >= ts.x || q.y >= ts.y) {
		return 0;
	}
	vec4 c = texelFetch(tex, q, 0);
	if (c.a < 0.5) {
		return 0;
	}
	return dot(c.rgb, vec3(0.299, 0.587, 0.114)) < 0.24 ? 1 : 2;
}

void fragment() {
	vec2 cell = floor((UV - 0.5) * size + center + 0.001);
	ivec2 ts = textureSize(tex, 0);
	float ax = -floor(float(ts.x) / 2.0);
	float ay = -float(ts.y);
	ivec2 q = ivec2(int(cell.x - ax), int(cell.y - ay));
	vec4 c = vec4(0.0);
	if (mode < 0.5) {
		if (sx <= 0.02) {
			discard;
		}
		float cx = ax + float(ts.x) / 2.0;
		float half = float(ts.x) / 2.0 + 1.0;
		if (cell.x < floor(cx - half * sx) || cell.x > ceil(cx + half * sx)) {
			discard;
		}
		int i = int(round(cx + (cell.x + 0.5 - cx) / sx - 0.5) - ax);
		int v = shade_at(ivec2(i, q.y));
		if (v == 0) {
			discard;
		}
		c = v == 1 ? edge : body;
		c.a *= alpha;
	} else if (mode < 1.5) {
		if (shade_at(q) != 0) {
			discard;
		}
		bool near = shade_at(q + ivec2(1, 0)) != 0 || shade_at(q - ivec2(1, 0)) != 0 || shade_at(q + ivec2(0, 1)) != 0 || shade_at(q - ivec2(0, 1)) != 0;
		if (!near || rnd(vec2(q), grain) >= chance) {
			discard;
		}
		c = hot > 0.5 && rnd(vec2(q), 7.0) < 0.5 ? white : body;
		c.a *= alpha;
	} else {
		int v = shade_at(q);
		if (v == 0) {
			discard;
		}
		c = v == 1 ? edge : body;
		COLOR = vec4(pfx_snap(c.rgb), floor(alpha * 8.0 + 0.5) / 8.0);
		if (COLOR.a <= 0.0) {
			discard;
		}
	}
	if (mode < 1.5) {
		if (pfx_pixel(c, FRAGCOORD.xy)) {
			discard;
		}
		COLOR = c;
	}
}
