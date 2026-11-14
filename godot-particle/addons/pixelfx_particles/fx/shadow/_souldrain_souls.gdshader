// Soul drain's souls (after the original's draw()): four a loop (souls[j] = born, line), each dragged down its
// streamline (a cubic bezier, la/lb) ever faster: a wavering tail of translucent discs, pale near the head, thinning
// to violet; a pale round head with a lit rim, hollow eyes and an open mouth, shrinking as it nears the vessel; a ring
// where it's torn loose; and a ring off the vessel as each lands. `t` is the clock in seconds. Canvas-sized, soft
// layer (opaque where the original draws solid pixels, translucent where it blends).
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(208.0, 120.0);
uniform vec2 center = vec2(0.0);
uniform float t = 0.0;
uniform float period = 3.2;
uniform float travel = 1.45;
uniform float vy = -50.0;
uniform vec4 la[11];
uniform vec4 lb[11];
uniform vec4 souls[4];
uniform vec4 s0 : source_color = vec4(1.0);
uniform vec4 s1 : source_color = vec4(1.0);
uniform vec4 s2 : source_color = vec4(1.0);
uniform vec4 s3 : source_color = vec4(1.0);
uniform vec4 c3 : source_color = vec4(1.0);
uniform vec4 c5 : source_color = vec4(1.0);
uniform vec4 c7 : source_color = vec4(1.0);

vec2 along(int i, float u) {
	float v = 1.0 - u;
	float a = v * v * v;
	float b = 3.0 * v * v * u;
	float c = 3.0 * v * u * u;
	float d = u * u * u;
	vec4 A = la[i];
	vec4 B = lb[i];
	return vec2(a * A.x + b * A.z + c * B.x, a * A.y + b * A.w + c * B.y + d * vy);
}

float wrapd(float x) {
	return mod(mod(x, period) + period, period);
}

bool on(vec2 cell, vec2 at) {
	return all(equal(cell, floor(at)));
}

void fragment() {
	vec2 p = floor((UV - 0.5) * size + center + 0.001) + 0.5;
	vec2 cell = floor(p);
	vec3 col = vec3(0.0);
	float A = 0.0;
	float y0 = vy + sin(TAU * t / period) * 1.5;
	for (int j = 0; j < 4; j++) {
		float age = wrapd(t - souls[j].x);
		if (age > travel) {
			continue;
		}
		int li = int(souls[j].y);
		float u = pow(age / travel, 1.8);
		vec2 h = along(li, u);
		if (age < 0.18) {
			float k = 1.0 - age / 0.18;
			float r = 3.0 + 9.0 * (1.0 - k);
			float d = length(p - la[li].xy);
			if (d < r && d >= r - 1.0) {
				col = (k > 0.5 ? s2 : s1).rgb;
				A = 1.0;
			}
		}
		for (int k = 14; k >= 1; k--) {
			float fk = float(k);
			float uu = pow(max(0.0, age - fk * 0.03) / travel, 1.8);
			vec2 tp = along(li, uu);
			tp.y += sin(t * 12.0 + fk * 0.8 + float(j)) * fk * 0.16;
			float r = max(0.5, 2.6 - fk * 0.17);
			vec2 dd = p - tp;
			if (dot(dd, dd) <= r * r) {
				vec3 c = (k < 4 ? s2 : k < 9 ? s1 : c5).rgb;
				float a = 0.75 * (1.0 - fk / 15.0);
				float oa = a + A * (1.0 - a);
				float kk = a / oa;
				col = c * kk + col * (1.0 - kk);
				A = oa;
			}
		}
		float near = smoothstep(0.82, 1.0, u);
		float hr = 3.4 - near * 1.6;
		vec2 dh = p - h;
		float d2 = dot(dh, dh);
		if (d2 <= (hr + 0.8) * (hr + 0.8)) {
			col = s1.rgb;
			A = 1.0;
		}
		if (d2 <= hr * hr) {
			col = s2.rgb;
			A = 1.0;
		}
		if (on(cell, h + vec2(-1.0, -2.0)) || on(cell, h + vec2(-2.0, -1.0))) {
			col = s3.rgb;
			A = 1.0;
		}
		if (near < 0.5 && (on(cell, h + vec2(-1.5, 0.0)) || on(cell, h + vec2(1.5, 0.0)) || on(cell, h + vec2(0.0, 1.6)) || on(cell, h + vec2(0.0, 2.4)))) {
			col = s0.rgb;
			A = 1.0;
		}
	}
	for (int j = 0; j < 4; j++) {
		float since = wrapd(t - souls[j].x - travel);
		if (since < 0.3) {
			float k = since / 0.3;
			float r = 6.0 + 18.0 * (1.0 - pow(1.0 - k, 3.0));
			float w = max(1.0, 2.0 * (1.0 - k));
			float d = length(p - vec2(0.0, y0));
			if (d < r && d >= max(0.0, r - w)) {
				col = (k < 0.4 ? c7 : k < 0.7 ? c5 : c3).rgb;
				A = 1.0;
			}
		}
	}
	if (A <= 0.0) {
		discard;
	}
	vec4 c = vec4(col, A);
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
