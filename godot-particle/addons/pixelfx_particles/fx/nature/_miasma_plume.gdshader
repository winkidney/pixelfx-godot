// nature/poison-cloud: plumes (the original's plumes()): columns that lift off the sheets and twist into ribbons,
// bright where the ribbon faces you and dark where it turns away, thinning as they climb. Each plume repeats every
// `period` seconds: born (s), life (s), x0, rise (px/s) in pa; length, phase, sway amplitude in pb. Key `t` 0 -> 1
// over the loop. Soft layer (translucent).
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform float t = 0.0;
uniform float period = 4.0;
uniform float count = 5.0;
uniform vec4 pa[8];
uniform vec4 pb[8];
uniform sampler2D ramp : filter_nearest, repeat_disable;
uniform float alpha = 1.0;

vec3 C(float i) {
	return texture(ramp, vec2((clamp(i, 0.0, 7.0) + 0.5) / 8.0, 0.5)).rgb;
}

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5 + center;
	float T = t * period;
	vec3 col = vec3(0.0);
	float al = 0.0;
	float hh = -p.y;
	for (int i = 0; i < 8; i++) {
		if (float(i) >= count) {
			break;
		}
		float age = mod(T - pa[i].x, period);
		float L = pa[i].y;
		if (age >= L) {
			continue;
		}
		float u = age / L;
		float head = 14.0 + pa[i].w * age;
		float tail = max(10.0, head - pb[i].x);
		if (hh < tail || hh > head) {
			continue;
		}
		float fade = smoothstep(0.0, 0.15, u) * (1.0 - smoothstep(0.5, 1.0, u));
		float s = (hh - tail) / max(1.0, head - tail);
		float tw = cos(hh * 0.22 + age * 2.4 + pb[i].y);
		float w = 0.6 + 2.2 * abs(tw) * (1.0 - s * 0.5);
		float x = pa[i].z + pb[i].z * sin(hh * 0.12 + age + pb[i].y) * (0.4 + s);
		float o = abs(p.x - x);
		if (o > w + 0.5) {
			continue;
		}
		float a = fade * sin(3.14159265 * min(1.0, s * 1.2)) * 0.32 * 1.15;
		vec3 c = tw > 0.0 ? (o < w * 0.5 ? C(6.0) : C(5.0)) : (o < w * 0.5 ? C(3.0) : C(2.0));
		col = al > 0.0 ? mix(col, c, a / max(0.001, al + a * (1.0 - al))) : c;
		al = al + a * (1.0 - al);
	}
	if (al <= 0.0) {
		discard;
	}
	vec4 o4 = vec4(col, al * alpha);
	if (pfx_pixel(o4, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = o4;
}
