// The column of light (after magic-circle-cast.js column()): first a thread of light climbing, then the beam firing up
// (white for two frames), banded across with strands wandering in it and pulses climbing it, flared at its foot,
// holding, then breaking apart as holes open and drift up; halos (rings of dots) climb it. `t` runs 0..1 over the
// effect (`dur` s). Coordinates: px from the effect's origin; the column stands on x = 0. Colour layer.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(80.0, 200.0);
uniform vec2 center = vec2(0.0);
uniform float t = 0.0;
uniform float dur = 3.9;
uniform vec4 c3 : source_color = vec4(1.0);
uniform vec4 c4 : source_color = vec4(1.0);
uniform vec4 c5 : source_color = vec4(1.0);
uniform vec4 c6 : source_color = vec4(1.0);
uniform vec4 white : source_color = vec4(1.0);
// strands: x offset across (-1..1), half width, wander frequency
uniform vec3 strands[9];
uniform float grain = 6.0;

const float TOP = 192.0;
const float W = 11.0;
const float FLASH = 1.52;
const float BREAK = 2.42;

float hash(vec2 q) {
	return fract(sin(dot(q, vec2(127.1, 311.7)) + grain * 13.7) * 43758.5453);
}

float vnoise(vec2 q) {
	vec2 i = floor(q);
	vec2 f = q - i;
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), u.x), u.y) * 2.0 - 1.0;
}

vec4 lv_col(int i) {
	return i <= 0 ? white : i == 1 ? c6 : i == 2 ? c5 : i == 3 ? c4 : c3;
}

float out_expo(float x) {
	return x >= 1.0 ? 1.0 : 1.0 - pow(2.0, -10.0 * x);
}

float out_cubic(float x) {
	return 1.0 - pow(1.0 - x, 3.0);
}

void fragment() {
	float s = t * dur;
	if (s < FLASH - 0.22 || s > BREAK + 0.6) {
		discard;
	}
	vec2 cell = floor((UV - 0.5) * size + center + 0.001);
	float b = pfx_threshold(FRAGCOORD.xy);
	vec4 c = vec4(0.0);
	if (s < FLASH) {
		// the thread climbing
		float a = smoothstep(FLASH - 0.22, FLASH - 0.04, s);
		float top = -(TOP - 10.0) * out_cubic(a);
		if (cell.x == 0.0 && cell.y <= -1.0 && cell.y >= ceil(top)) {
			c = vec4((cell.y > top + 6.0 ? c6 : white).rgb, a * (0.35 + 0.65 * (1.0 + cell.y / TOP)));
		}
	} else {
		float u = s - FLASH;
		float brk = clamp((s - BREAK) / 0.45, 0.0, 1.0);
		float top = -TOP * out_expo(clamp(u / 0.09, 0.0, 1.0));
		float w = s < BREAK ? W * (1.0 + 0.38 * exp(-u * 9.0)) : W * (1.0 - out_cubic(brk) * 0.85);
		float fade = 1.0 - smoothstep(BREAK + 0.25, BREAK + 0.55, s);
		bool wh = u < 0.067;
		float y = cell.y;
		float x = cell.x;
		if (y <= 3.0 && y >= ceil(top) && fade > 0.0) {
			float h = -y;
			float ww = w * (1.0 + 0.5 * exp(-max(0.0, h) / 6.0));
			if (x >= floor(-ww * 1.3) && x <= ceil(ww * 1.3)) {
				float pulse = fract(h * 0.022 - u * 2.6) < 0.07 ? 1.0 : 0.0;
				float q = abs(x + 0.5) / ww;
				bool hole = brk > 0.0 && vnoise(vec2(x * 0.32, h * 0.11 - (s - BREAK) * 6.0)) * 0.5 + 0.5 < brk * 1.25 - 0.1;
				if (!hole) {
					int lv = q < 0.2 ? 0 : q < 0.42 ? 1 : q < 0.66 ? 2 : q < 0.88 ? 3 : 4;
					for (int i = 0; i < 9; i++) {
						vec3 st = strands[i];
						if (abs((x + 0.5) / ww - st.x - 0.05 * sin(s * st.z + st.x * 9.0)) < st.y) {
							lv = max(0, lv - 1);
						}
					}
					lv = wh ? 0 : max(0, lv - int(pulse));
					float a = (q < 0.88 ? 1.0 : (1.3 - q) / 0.42) * fade;
					if (a > b * (q < 0.66 ? 0.2 : 1.0)) {
						c = lv_col(lv);
					}
				}
			}
		}
		// halos climbing it
		for (int i = 0; i < 6; i++) {
			float k = (s - (FLASH + 0.08 + float(i) * 0.16)) / 0.8;
			if (k < 0.0 || k > 1.0) {
				continue;
			}
			float rx = w * 1.4 * (1.0 + k * 0.35);
			float ry = rx * 0.3;
			float yc = -3.0 - (1.0 - (1.0 - k) * (1.0 - k)) * 120.0;
			vec2 p = cell + 0.5 - vec2(0.0, yc);
			vec2 n = vec2(p.x / rx, p.y / ry);
			float d = length(n);
			float gr = length(vec2(n.x / rx, n.y / ry)) / max(d, 1e-6);
			if (abs(d - 1.0) / gr <= 0.5) {
				float g = atan(n.y, n.x);
				float a = (1.0 - k) * fade * (sin(g) < 0.0 ? 0.6 : 1.0);
				if (a > b) {
					c = k < 0.3 ? white : c6;
				}
			}
		}
	}
	if (c.a <= 0.0) {
		discard;
	}
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
