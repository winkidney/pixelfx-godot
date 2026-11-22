// spawn/shatter-death's frost on the floor: under the feet, spreading as the ice locks (`k`, `reach`), and rime left
// where each piece hits (`rime`: x, half width, when), all dotted by the original's hash and dithered. Colour layer.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/spawn/_jsrand.gdshaderinc"

uniform vec2 size = vec2(160.0, 3.0);
uniform vec2 center = vec2(0.0);
uniform float k = 0.0;
uniform float reach = 6.0;
uniform vec3 rime[48];
uniform float rime_count = 0.0;
uniform float t = 0.0;
uniform float fade = 1.0;
uniform vec4 c5 : source_color = vec4(1.0);
uniform vec4 c6 : source_color = vec4(1.0);
uniform vec4 white : source_color = vec4(1.0);

void fragment() {
	vec2 cell = floor(center + (UV - 0.5) * size);
	float th = pfx_threshold(FRAGCOORD.xy);
	int x = int(cell.x);
	vec4 o = vec4(0.0);
	if (k > 0.0 && cell.x >= floor(-reach) && cell.x <= ceil(reach)) {
		float h = js_rand2(x, 17);
		float e = 1.0 - abs(cell.x) / (reach + 1.0);
		float a = -1.0;
		vec4 c = white;
		if (cell.y == 0.0) {
			a = k * min(1.0, e * 2.0);
			c = h < 0.3 ? white : c6;
		} else if (cell.y == 1.0 && h < 0.5) {
			a = k * e;
			c = c5;
		} else if (cell.y == -1.0 && h < 0.35 && e > 0.3) {
			a = k * e;
			c = c6;
		}
		if (a > 0.0 && (a >= 1.0 || a > th)) {
			o = c;
		}
	}
	for (int i = 0; i < 48; i++) {
		if (float(i) >= rime_count) {
			break;
		}
		vec3 r = rime[i];
		if (t < r.z || cell.x < floor(r.x - r.y) || cell.x > r.x + r.y) {
			continue;
		}
		float a = clamp((t - r.z) / 0.08, 0.0, 1.0) * fade;
		float h = js_rand2(x, 23);
		if (cell.y == 0.0 && h < 0.7 && (a >= 1.0 || a > th)) {
			o = h < 0.25 ? white : c6;
		} else if (cell.y == 1.0 && h < 0.3 && (a * 0.7 >= 1.0 || a * 0.7 > th)) {
			o = c5;
		}
	}
	if (o.a < 0.5) {
		discard;
	}
	COLOR = vec4(o.rgb, 1.0);
}
