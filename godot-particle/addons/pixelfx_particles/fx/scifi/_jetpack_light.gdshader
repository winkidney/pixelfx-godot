// The jetpack's light (src/fx/scifi/jetpack.js), from the keyed clock `t` and the frame's jitter: a glow on each
// shock diamond, hot at each nozzle, warm down each plume, the fire lighting the smoke below it. Light layer.
shader_type canvas_item;
render_mode blend_add;

#include "res://addons/pixelfx_particles/fx/scifi/_scifi_light.gdshaderinc"

uniform vec2 size = vec2(96.0, 116.0);
uniform vec2 center = vec2(0.0);
uniform float t = 0.0;
uniform float length_ = 26.0;
uniform sampler2D data : filter_nearest, repeat_disable;
uniform vec4 pal[8] : source_color;
uniform float strength = 1.0;

const float D = 2.0;

void fragment() {
	vec2 pc = floor(center + (UV - 0.5) * size + 0.001) + 0.5;
	int fi = clamp(int(floor(t * 30.0 + 0.5)), 0, 59);
	vec4 f = texelFetch(data, ivec2(fi, 0), 0);
	float dy = texelFetch(data, ivec2(fi, 1), 0).x;
	float ph = t / D;
	vec3 l = vec3(0.0);
	for (int side = 0; side < 2; side++) {
		float cx = side == 0 ? f.x : f.z;
		float L = side == 0 ? f.y : f.w;
		for (int i = 0; i < 3; i++) {
			float fl = float(i);
			float yy = floor(dy + 5.0 + fl * 6.5 + sin(TAU * 4.0 * ph + fl) * 0.5 + 0.5);
			float r = floor(2.2 - fl * 0.45 + 0.4 * sin(TAU * 8.0 * ph + fl * 2.0) + 0.5);
			if (yy > dy + L * 0.75 || r < 1.0) {
				break;
			}
			l += pal[6].rgb * glow_at(pc, vec2(cx, yy), 6.0) * 0.35;
		}
		l += glow_at(pc, vec2(cx, dy + 2.0), 9.0) * 0.45;
		l += pal[4].rgb * glow_at(pc, vec2(cx, dy + L * 0.45), L * 0.8) * 0.35;
	}
	l += pal[4].rgb * glow_at(pc, vec2(0.0, length_ + 14.0), 34.0) * 0.16;
	l += pal[5].rgb * glow_at(pc, vec2(0.0, length_ * 0.4), 30.0) * 0.18;
	COLOR = vec4(l * strength, 1.0);
}
