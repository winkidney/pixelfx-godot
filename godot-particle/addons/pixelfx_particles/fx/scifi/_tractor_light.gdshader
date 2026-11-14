// The tractor beam's light (src/fx/scifi/tractor-beam.js), from the keyed clock `t`: light along the cone's edges and
// down its body, under each climbing ring, round the motes hauled up it and the twinkles, over the rising rocks, a
// flash at the lens as each is swallowed, the pod's running lights and its lens, the pool on the floor. Light layer.
shader_type canvas_item;
render_mode blend_add;

#include "res://addons/pixelfx_particles/fx/scifi/_scifi_light.gdshaderinc"

uniform vec2 size = vec2(120.0, 132.0);
uniform vec2 center = vec2(0.0);
uniform float t = 0.0;
uniform vec4 pal[8] : source_color;
uniform sampler2D grit : filter_nearest, repeat_disable;
uniform sampler2D twinkles : filter_nearest, repeat_disable;
uniform vec4 rock_a[7];
uniform vec4 rock_b[7];
uniform float strength = 1.0;

#include "res://addons/pixelfx_particles/fx/scifi/_tractor.gdshaderinc"

const float LIFE = POP + HOVER + RISE;

void fragment() {
	vec2 pc = floor(center + (UV - 0.5) * size + 0.001) + 0.5;
	float ph = t / D;
	vec3 l = vec3(0.0);
	for (float y = ceil(LENS + 3.0); y < 0.0; y += 1.0) {
		if ((int(y) & 3) == 0) {
			float w = half_w(y);
			l += pal[4].rgb * (glow_at(pc, vec2(-w, y), 8.0) + glow_at(pc, vec2(w, y), 8.0)) * 0.18;
		}
	}
	for (int i = 0; i < 5; i++) {
		float k = mod(t - float(i) / 5.0 * D, D) / 1.1;
		if (k >= 1.0) {
			continue;
		}
		float y = mix(0.0, LENS + 5.0, k * k);
		float w = half_w(y) + 1.0;
		l += pal[5].rgb * glow_at(pc, vec2(0.0, y + w * 0.17), w + 4.0) * 0.12;
	}
	for (int i = 0; i < 46; i++) {
		vec4 a = texelFetch(grit, ivec2(i, 0), 0);
		vec4 b = texelFetch(grit, ivec2(i, 1), 0);
		float age = mod(t - a.x, D);
		if (age >= a.y || b.z < 0.5) {
			continue;
		}
		vec3 h = haul(a.z, a.w, b.x, b.y, age / a.y);
		l += pal[5].rgb * glow_at(pc, h.xy, 4.0) * 0.45;
	}
	for (int i = 0; i < 8; i++) {
		vec4 a = texelFetch(twinkles, ivec2(i, 0), 0);
		vec4 b = texelFetch(twinkles, ivec2(i, 1), 0);
		float age = mod(t - a.x, D);
		if (age >= a.y) {
			continue;
		}
		float k = age / a.y;
		vec3 h = haul(a.z, a.w, b.x, 0.6, b.y + k * 0.15);
		float arm = floor(2.0 * sin(PI * k) + 0.5);
		if (arm > 0.0) {
			l += pal[6].rgb * glow_at(pc, h.xy, 4.0 + arm * 2.0) * 0.4;
		}
	}
	for (int i = 0; i < 7; i++) {
		float age = mod(t - rock_a[i].x, D);
		if (age < LIFE) {
			Rock q = rock_at(rock_a[i], rock_b[i], age);
			if ((q.z >= 0.0 || q.lift <= 0.0) && q.lift > 0.0) {
				float R = max(0.9, q.size);
				l += pal[5].rgb * glow_at(pc, q.p - vec2(0.0, R), 5.0 + R) * 0.25 * q.lift;
			}
		}
		float fa = t - (rock_a[i].x + LIFE - 0.08);
		if (fa >= 0.0 && fa < 0.28) {
			float qq = 1.0 - fa / 0.28;
			l += pal[5].rgb * glow_at(pc, vec2(0.0, LENS + 3.0), 30.0 * (0.55 + 0.45 * qq)) * 0.7 * qq * qq;
		}
	}
	float py = floor(LENS - 5.0 + 1.5 * sin(TAU * 2.0 * ph) + 0.5);
	for (int i = 0; i < 6; i++) {
		float k = 0.5 + 0.5 * cos(TAU * (4.0 * ph - float(i) / 6.0));
		if (k > 0.5) {
			l += pal[5].rgb * glow_at(pc, vec2(-15.0 + float(i) * 6.0, py + 1.0), 5.0) * 0.35 * k;
		}
	}
	float fl = 0.85 + 0.15 * sin(TAU * 6.0 * ph);
	l += pal[5].rgb * glow_at(pc, vec2(0.0, LENS + 6.0), 36.0) * 0.7 * fl;
	l += glow_at(pc, vec2(0.0, LENS + 6.0), 12.0) * 0.7 * fl;
	for (float y = LENS + 16.0; y < -8.0; y += 14.0) {
		l += pal[4].rgb * glow_at(pc, vec2(0.0, y), half_w(y) + 10.0) * 0.16;
	}
	for (int i = -1; i <= 1; i++) {
		l += pal[4].rgb * glow_at(pc, vec2(float(i) * 20.0, -2.0), 22.0) * 0.26;
	}
	COLOR = vec4(l * strength, 1.0);
}
