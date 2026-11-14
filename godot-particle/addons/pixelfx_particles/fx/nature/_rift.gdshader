// The rift a quake tears along the floor (nature/quake): a jagged split out both ways from the middle, `open` px
// so far, lit along its upper lip, dark inside with a glow deep in it where it's widest (`heat`), a dark lower lip;
// it closes to a thin scar (`gapk` -> 0) and fades. `rift` holds its points (x, depth into the floor); `jx` shakes
// it sideways. Key the uniforms frame by frame. Coordinates are px from the origin (`center` is the rect's middle).
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform sampler2D stone : filter_nearest, repeat_disable;
uniform sampler2D glow_ramp : filter_nearest, repeat_disable;
uniform vec2 rift[80];
uniform float rift_count = 0.0;
uniform float reach = 118.0;
uniform float open = 0.0;
uniform float gapk = 0.0;
uniform float heat = 0.0;
uniform float jx = 0.0;
uniform float flicker = 0.0;
uniform float alpha = 1.0;

vec4 S(int i) {
	return texture(stone, vec2((float(i) + 0.5) / 8.0, 0.5));
}

vec4 GL(int i) {
	return texture(glow_ramp, vec2((float(i) + 0.5) / 5.0, 0.5));
}

float rnd(float a, float b) {
	return fract(sin(a * 12.9898 + b * 78.233) * 43758.5453);
}

void fragment() {
	vec2 q = floor((UV - 0.5) * size + center);
	float x = q.x - floor(jx);
	vec4 c = vec4(0.0);
	for (int i = 1; i < 80; i++) {
		if (float(i) >= rift_count) {
			break;
		}
		vec2 a = rift[i - 1];
		vec2 b = rift[i];
		if (x < ceil(a.x) || x >= b.x) {
			continue;
		}
		if (abs(a.x) > open) {
			break;
		}
		float u = (x - a.x) / (b.x - a.x);
		float d = floor(a.y + (b.y - a.y) * u + 0.5);
		float w = gapk * (1.0 + 2.6 * (1.0 - abs(x) / reach));
		float y = q.y - d;
		if (w < 0.4) {
			if (y == 0.0) {
				c = S(1);
			}
		} else if (y == -1.0) {
			c = S(6);
		} else if (y >= 0.0 && y < w) {
			float deep = rnd(floor(x / 3.0), 41.0) + (w - 1.5) * 0.35;
			float hot = heat * clamp(deep - 0.35, 0.0, 1.0) * 1.6;
			if (y > w / 2.0 - 1.0 && hot > 0.25) {
				c = hot > 0.9 && rnd(x, flicker) < 0.6 ? GL(3) : GL(2);
			} else if (y > w / 2.0 - 1.0 && hot > 0.08) {
				c = GL(1);
			} else {
				c = S(0);
			}
		} else if (y == ceil(w)) {
			c = S(2);
		}
		break;
	}
	if (c.a <= 0.0) {
		discard;
	}
	c.a *= alpha;
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
