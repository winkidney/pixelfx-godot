// The EMP blast's light (src/fx/scifi/emp-blast.js), from the frame's state: the charge's glow, ticking; light along
// the arcs every third joint; glows round the bubble's rim and across its torn rows; the pop's star. (The flashes
// of the pop and the break are keyed glows of their own.) Light layer.
shader_type canvas_item;
render_mode blend_add;

#include "res://addons/pixelfx_particles/fx/scifi/_scifi_light.gdshaderinc"

uniform vec2 size = vec2(152.0, 116.0);
uniform vec2 center = vec2(0.0);
uniform float frame = 0.0;
uniform sampler2D data : filter_nearest, repeat_disable;
uniform sampler2D arcs : filter_nearest, repeat_disable;
uniform int arc_width = 320;
uniform vec4 pal[8] : source_color;
uniform float strength = 1.0;

const float POP = 0.42;

vec4 F(int row) {
	return texelFetch(data, ivec2(clamp(int(frame + 0.5), 0, textureSize(data, 0).x - 1), row), 0);
}

void fragment() {
	vec2 pc = floor(center + (UV - 0.5) * size + 0.001) + 0.5;
	vec4 m = F(0);
	float t = m.x;
	float r = m.y;
	vec3 l = vec3(0.0);
	if (t < POP) {
		float k = t / POP;
		bool tick = sin(TAU * (2.0 * t + 10.0 * t * t)) > 0.0;
		l += pal[4].rgb * glow_at(pc, vec2(0.0, -7.0), 8.0 + 16.0 * k) * (0.4 + 0.5 * k * (tick ? 1.0 : 0.6));
	}
	// the arcs: light every third joint
	int f = clamp(int(frame + 0.5), 0, textureSize(arcs, 0).y - 1);
	int cur = -1;
	int idx = 0;
	vec2 prev = vec2(0.0);
	for (int j = 0; j < 512; j++) {
		if (j >= arc_width) {
			break;
		}
		vec4 q = texelFetch(arcs, ivec2(j, f), 0);
		if (q.z < -0.5) {
			break;
		}
		int sid = int(q.z + 0.5);
		if (sid != cur) {
			idx = 0;
		} else {
			idx += 1;
			if (idx % 3 == 0) {
				int set = sid / 1000;
				float w = set == 0 ? 0.5 : set == 1 ? 1.3 : 0.8;
				vec3 gc = set == 1 ? pal[5].rgb : pal[4].rgb;
				l += gc * glow_at(pc, prev, 9.0 * w) * 0.45 * q.w;
			}
		}
		cur = sid;
		prev = q.xy;
	}
	if (r > 1.0 && m.z < 0.5 && m.w > 0.5) {
		for (float a = 0.15; a < PI - 0.1; a += 0.35) {
			l += pal[4].rgb * glow_at(pc, vec2(cos(a) * r, -sin(a) * r), 8.0) * 0.12;
		}
		for (int i = 0; i < 3; i++) {
			vec4 q = F(1 + i);
			if (q.y != 0.0) {
				l += pal[5].rgb * glow_seg(pc, vec2(-r, q.x), vec2(r, q.x), 4.0) * 0.3;
			}
			if (q.w != 0.0) {
				l += pal[5].rgb * glow_seg(pc, vec2(-r, q.z), vec2(r, q.z), 4.0) * 0.3;
			}
		}
	}
	float a = t - POP;
	if (a >= 0.0 && a < 0.16) {
		float n = floor(10.0 * (1.0 - a / 0.16) + 0.5);
		if (n >= 1.0) {
			l += pal[6].rgb * glow_at(pc, vec2(0.0, -7.0), 4.0 + n * 2.0) * 0.6;
		}
	}
	COLOR = vec4(l * strength, 1.0);
}
