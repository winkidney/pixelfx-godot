// The force field's light (src/fx/scifi/force-field.js), from the keyed clock `t`: a faint pool along the floor, the
// foot's emitters, the near shell's own light (its rim, humming seams, struck and rippling plates), light along the
// fractures, the tracer's head, the impact's star and its flashes, the dome's glow. mode 0: the part behind the
// stand-in (the pool, the far emitters); mode 1: the rest. Light layer.
shader_type canvas_item;
render_mode blend_add;

#include "res://addons/pixelfx_particles/fx/scifi/_scifi_light.gdshaderinc"

uniform vec2 size = vec2(184.0, 104.0);
uniform vec2 center = vec2(0.0);
uniform float t = 0.0;
uniform int mode = 0;
uniform sampler2D near : filter_nearest, repeat_disable;
uniform sampler2D far : filter_nearest, repeat_disable;
uniform sampler2D cracks : filter_nearest, repeat_disable;
uniform int crack_count = 0;
uniform vec4 pal[8] : source_color;
uniform vec4 sparks[4] : source_color;
uniform float pool_x[7];
uniform float right_edge = 105.0;
uniform float strength = 1.0;

#include "res://addons/pixelfx_particles/fx/scifi/_force_field.gdshaderinc"

float flash(vec2 pc, float t0, vec2 at, float r, float k, float life) {
	float a = t - t0;
	if (a < 0.0 || a >= life) {
		return 0.0;
	}
	float q = 1.0 - a / life;
	return glow_at(pc, at, r * (0.55 + 0.45 * q)) * k * q * q;
}

vec3 front_light(vec2 cell, vec2 pc) {
	vec3 l = vec3(0.0);
	Shell s = shell_at(ivec2(cell), true);
	if (s.a > 0.004) {
		l += pal[4].rgb * s.lk;
	}
	for (int si = 0; si < 2; si++) {
		bool big = si == 0;
		float st = shot_t(si);
		float age = mod(t - st, D);
		float n = big ? 1.0 : 0.6;
		vec2 h = project(si == 0 ? 0.66 : 0.95, si == 0 ? 0.62 : 0.26);
		if (big && age < 0.9) {
			float fade = 1.0 - e_smooth(0.35, 0.9, age);
			float reach = clamp(age / 0.09, 0.0, 1.0);
			for (int i = 0; i < 256; i++) {
				if (i >= crack_count) {
					break;
				}
				vec4 a = texelFetch(cracks, ivec2(i, 0), 0);
				vec4 b = texelFetch(cracks, ivec2(i, 1), 0);
				if (b.z > reach || b.x < 0.05 || b.y < 0.05 || b.w < 0.5) {
					continue;
				}
				l += pal[4].rgb * glow_at(pc, a.zw, 6.0) * 0.35 * fade * (1.0 - b.z * 0.5);
			}
		}
		float tk = (t - (st - 0.1)) / 0.1;
		if (tk >= 0.0 && tk < 1.0) {
			vec2 sp0 = vec2(right_edge, h.y - 12.0);
			float L = length(sp0 - h);
			vec2 x0 = sp0 + (h - sp0) * max(0.0, L * tk) / L;
			l += sparks[1].rgb * glow_at(pc, x0, 9.0) * 0.55;
		}
		if (age < 0.14) {
			float arm = floor((7.0 * (1.0 - age / 0.14) + 1.0) * n + 0.5);
			if (arm >= 1.0) {
				l += pal[6].rgb * glow_at(pc, h, 4.0 + arm * 2.0) * 0.4;
			}
		}
		l += pal[4].rgb * flash(pc, st, h, 56.0 * n, 0.45, 0.45);
		l += flash(pc, st, h, 12.0, 0.5 * n, 0.08);
		l += sparks[1].rgb * flash(pc, st, h + vec2(3.0, 0.0), 22.0, 0.4 * n, 0.15);
	}
	float a0 = mod(t - shot_t(0), D);
	l += pal[3].rgb * glow_at(pc, vec2(0.0, -RAD * 0.45), RAD * 1.3) * (0.11 + 0.1 * max(0.0, 1.0 - a0 * 2.0));
	return l;
}

void fragment() {
	vec2 cell = floor(center + (UV - 0.5) * size + 0.001);
	vec2 pc = cell + 0.5;
	vec3 l = vec3(0.0);
	for (int i = 0; i < 10; i++) {
		float g = float(i) / 10.0 * TAU + 0.31;
		bool nr = sin(g) >= 0.0;
		if (nr != (mode == 1)) {
			continue;
		}
		vec2 p = vec2(cos(g) * (RAD - 0.5), sin(g) * RAD * SA);
		float k = 0.5 + 0.5 * cos(TAU * (2.0 * (t / D) - float(i) / 10.0));
		l += pal[4].rgb * glow_at(pc, p, 6.0 + 4.0 * k) * (nr ? 0.25 : 0.15) * (0.4 + k);
	}
	if (mode == 0) {
		for (int i = 0; i < 7; i++) {
			l += pal[3].rgb * glow_at(pc, vec2(pool_x[i], -1.0), 22.0) * 0.1;
		}
	} else {
		l += front_light(cell, pc);
	}
	COLOR = vec4(l * strength, 1.0);
}
