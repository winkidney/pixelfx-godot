// The light the scifi effects' particles give off (the original's p.glow round each spark, mote, streak, star
// glint, ember and young fire puff, and the haze round vapour), on the light layer: the light twin of an emitter
// drawn by _bits.gdshader (same data, same motion, _ghost.gdshader). After fx/impacts/_bits_light.gdshader.
shader_type canvas_item;
render_mode blend_add;

uniform sampler2D data : filter_nearest, repeat_disable;
uniform float kind = 0.0;
uniform vec2 quad = vec2(28.0);
uniform vec4 s0 : source_color = vec4(1.0);
uniform vec4 s1 : source_color = vec4(1.0);
uniform vec4 s2 : source_color = vec4(1.0);
// VAPOUR: the haze colour its puffs glow with
uniform vec4 haze : source_color = vec4(1.0);
uniform vec4 fire[9] : source_color;
uniform float strength = 1.0;

varying flat vec4 cu;
varying flat vec4 pc;

void vertex() {
	cu = INSTANCE_CUSTOM;
	pc = COLOR;
}

float glow(vec2 off, float r) {
	if (r < 1.0) {
		return 0.0;
	}
	float f = 1.0 - length(off) / r;
	return f > 0.0 ? f * f : 0.0;
}

void fragment() {
	vec2 off = (UV - 0.5) * quad;
	int kd = int(kind + 0.5);
	float k = cu.z;
	vec3 l = vec3(0.0);
	if (kd == 0) {
		vec3 head = k > 0.6 ? s0.rgb : k > 0.3 ? s1.rgb : s2.rgb;
		l = head * glow(off, 3.0) * 0.45 * k;
	} else if (kd == 1) {
		float size = texelFetch(data, ivec2(int(cu.w + 0.5), 1), 0).z;
		l = pc.rgb * glow(off, 2.5 + size) * 0.4 * k;
	} else if (kd == 2) {
		l = pc.rgb * glow(off, 4.0) * 0.4;
	} else if (kd == 6) {
		float tw = cu.x;
		float size = cu.y;
		if (size < 1.0) {
			l = pc.rgb * glow(off, 3.0) * 0.4 * k * tw;
		} else {
			float n = floor(size * tw * min(1.0, k * 3.0) + 0.5);
			if (n >= 1.0) {
				l = pc.rgb * glow(off, 4.0 + n * 2.0) * 0.5 * k * tw;
			}
		}
	} else if (kd == 7) {
		if (cu.x > 0.5) {
			vec3 hc = k > 0.6 ? s0.rgb : k > 0.3 ? s1.rgb : s2.rgb;
			l = hc * glow(off, 3.0 + cu.y) * 0.35 * k;
		}
	} else if (kd == 4) {
		float r = cu.x * (0.6 + (1.0 - k) * 0.9);
		l = haze.rgb * haze.a * glow(off, r * 1.8) * 0.16 * k;
	} else if (kd == 9) {
		int idx = int(cu.y + 0.5);
		if (idx < 6) {
			l = fire[idx].rgb * glow(off, cu.x * 2.4 + 2.0) * 0.18 * k;
		}
	}
	COLOR = vec4(l * strength * COLOR.a, 1.0);
}
