// The teleporter pad's light (src/fx/scifi/teleporter-pad.js), from the keyed clock `t`: the emitters' glows as they
// chase, glows up the column, a glow under each lifting ring's near half, the pool on the floor and the well's hot
// heart, pulsing. Light layer.
shader_type canvas_item;
render_mode blend_add;

#include "res://addons/pixelfx_particles/fx/scifi/_scifi_light.gdshaderinc"

uniform vec2 size = vec2(96.0, 104.0);
uniform vec2 center = vec2(0.0);
uniform float t = 0.0;
uniform vec4 pal[8] : source_color;
uniform float strength = 1.0;

const float D = 2.4;
const float RX = 31.0;
const float RY = 7.0;
const float PY = -3.0;
const float IN = 0.78;
const float HIGH = -84.0;

void fragment() {
	vec2 pc = floor(center + (UV - 0.5) * size + 0.001) + 0.5;
	float ph = t / D;
	vec3 l = vec3(0.0);
	for (int i = 0; i < 10; i++) {
		float a = float(i) / 10.0 * TAU + 0.15;
		float k = 0.5 + 0.5 * cos(TAU * (2.0 * ph - float(i) / 10.0));
		if (k > 0.5) {
			l += pal[4].rgb * glow_at(pc, vec2(cos(a) * RX * 0.885, PY + sin(a) * RY * 0.885), 4.0) * 0.35 * k;
		}
	}
	float W = RX * IN;
	for (float y = PY - 6.0; y > HIGH + 20.0; y -= 12.0) {
		l += pal[4].rgb * glow_at(pc, vec2(0.0, y), W + 8.0) * 0.16 * (1.0 - (y - PY) / (HIGH - PY));
	}
	for (int i = 0; i < 4; i++) {
		float k = mod(t - float(i) / 4.0 * D, D) / 1.25;
		if (k >= 1.0) {
			continue;
		}
		float y = mix(PY, HIGH + 12.0, pow(k, 0.85));
		float rx = RX * IN * (1.0 + 0.08 * k);
		float ry = rx * (RY / RX);
		l += pal[4].rgb * glow_at(pc, vec2(0.0, y + ry * 0.5), rx + 8.0) * 0.22 * (1.0 - k);
	}
	float k = 0.85 + 0.15 * sin(TAU * 2.0 * ph);
	for (int i = -1; i <= 1; i++) {
		l += pal[4].rgb * glow_at(pc, vec2(float(i) * RX * 0.6, PY), 20.0) * 0.25 * k;
	}
	l += glow_at(pc, vec2(0.0, PY), 10.0) * 0.3 * k;
	COLOR = vec4(l * strength, 1.0);
}
