// The laser grid's light (src/fx/scifi/laser-grid.js), from the keyed clock `t`: a low red pool on the floor, the
// posts' lenses and carriages, light along each beam scattered unevenly by the drifting haze (its tileFbm, as the
// original's, every 5 px), the motes a beam catches, glints where beams cross, the sweepers' hot spots. Light layer.
shader_type canvas_item;
render_mode blend_add;

#include "res://addons/pixelfx_particles/fx/scifi/_scifi_light.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/scifi/_jsrand.gdshaderinc"

uniform vec2 size = vec2(128.0, 84.0);
uniform vec2 center = vec2(0.0);
uniform float t = 0.0;
uniform int seed = 31;
uniform sampler2D motes : filter_nearest, repeat_disable;
uniform vec4 pal[8] : source_color;
uniform float strength = 1.0;

#include "res://addons/pixelfx_particles/fx/scifi/_laser_grid.gdshaderinc"

void fragment() {
	vec2 pc = floor(center + (UV - 0.5) * size + 0.001) + 0.5;
	vec3 l = vec3(0.0);
	for (int i = -2; i <= 2; i++) {
		l += pal[3].rgb * glow_at(pc, vec2(float(i) * 20.0, -2.0), 20.0) * 0.12;
	}
	for (int si = 0; si < 2; si++) {
		float s = si == 0 ? -1.0 : 1.0;
		for (int b = 0; b < 3; b++) {
			l += pal[4].rgb * glow_at(pc, vec2(s * IN, floor(slide_y(t, b) + 0.5)), 7.0) * 0.55;
		}
		l += pal[4].rgb * glow_at(pc, vec2(s * IN, TOP + 6.0), 8.0) * 0.55;
	}
	for (int i = 0; i < 5; i++) {
		vec4 b = beam(t, i);
		float L = length(b.zw - b.xy);
		if (near_beam(b, pc) > 12.0) {
			continue;
		}
		for (int j = 0; j < 40; j++) {
			float d = float(j) * 5.0;
			if (d > L) {
				break;
			}
			vec2 p = mix(b.xy, b.zw, d / L);
			float h = 0.5 + 0.5 * tile_fbm(p.x / 14.0 + (t / D) * 4.0, p.y / 10.0, 4, 0, seed, 3);
			l += pal[3].rgb * glow_at(pc, p, 6.0 + 4.0 * h) * (0.14 + 0.3 * h * h);
		}
	}
	for (int i = 0; i < 90; i++) {
		vec4 r = texelFetch(motes, ivec2(i, 0), 0);
		vec2 p = vec2((r.x * 2.0 - 1.0) * (IN - 3.0) + 4.0 * sin(TAU * (t / D) + float(i)), -2.0 - r.y * 62.0 + 3.0 * sin(TAU * 2.0 * (t / D) + float(i) * 1.7));
		if (length(p - pc) > 3.0) {
			continue;
		}
		float d = 9.0;
		for (int b = 0; b < 5; b++) {
			d = min(d, near_beam(beam(t, b), p));
		}
		if (d < 1.6) {
			l += pal[5].rgb * glow_at(pc, p, 3.0) * 0.45;
		}
	}
	for (int i = 0; i < 5; i++) {
		for (int j = i + 1; j < 5; j++) {
			vec2 x;
			if (cross_at(beam(t, i), beam(t, j), x)) {
				l += pal[5].rgb * glow_at(pc, x, 9.0) * 0.4;
				l += pal[6].rgb * glow_at(pc, x, 8.0) * 0.3;
			}
		}
	}
	for (int si = 0; si < 2; si++) {
		float x = sweep_x(t, si == 0 ? -1.0 : 1.0);
		l += pal[4].rgb * glow_at(pc, vec2(x, -1.0), 10.0) * 0.55;
		l += glow_at(pc, vec2(x, -1.0), 4.0) * 0.35;
	}
	COLOR = vec4(l * strength, 1.0);
}
