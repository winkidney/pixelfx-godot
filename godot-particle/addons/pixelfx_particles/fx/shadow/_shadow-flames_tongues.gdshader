// Shadow flames' tongues (after the original's grid): five tongues, each four nested layers running inside out (a
// pale skin, violet, deep violet, a black heart), their widths and sway on noise that loops with `t` (0..1 over the
// loop); the skin breaks up near the top and whitens at its tips. heart_only 1 draws only the black heart (lifted
// above the light layer so the glow stays off it, the original's unlight). Coordinates: px from the origin.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(44.0, 60.0);
uniform vec2 center = vec2(0.0, -30.0);
uniform float t = 0.0;
uniform float heart_only = 0.0;
uniform vec4 c0 : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 c2 : source_color = vec4(1.0);
uniform vec4 c4 : source_color = vec4(1.0);
uniform vec4 c6 : source_color = vec4(1.0);
uniform vec4 c7 : source_color = vec4(1.0);
uniform vec4 white : source_color = vec4(1.0);

// offset, base height, width, seed; the middle tallest (outermost drawn first)
const vec4 TONGUES[5] = vec4[](vec4(-11.0, 20.0, 4.2, 1.0), vec4(11.0, 22.0, 4.4, 2.0), vec4(-6.0, 31.0, 5.4, 3.0),
	vec4(6.0, 29.0, 5.2, 4.0), vec4(0.0, 40.0, 6.6, 5.0));
// width share, height share, tone (3: the black heart)
const vec3 LAYERS[4] = vec3[](vec3(1.0, 1.0, 0.0), vec3(0.8, 0.88, 1.0), vec3(0.54, 0.68, 2.0), vec3(0.32, 0.48, 3.0));

float rnd(vec2 q, float s) {
	return fract(sin(dot(q, vec2(127.1, 311.7)) + s * 74.7) * 43758.5453);
}

float noise2(vec2 q, float s) {
	vec2 i = floor(q);
	vec2 f = q - i;
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = rnd(i, s);
	float b = rnd(i + vec2(1.0, 0.0), s);
	float c = rnd(i + vec2(0.0, 1.0), s);
	float d = rnd(i + vec2(1.0, 1.0), s);
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y) * 2.0 - 1.0;
}

// noise that comes back to where it started each loop: a circle through 2D noise, offset by v
float ln(float v, float seed, float speed) {
	float ph = TAU * t;
	return noise2(vec2(cos(ph) * speed + v, sin(ph) * speed), seed);
}

int tone_at(float X, float Y) {
	if (X < -22.0 || X > 21.0 || Y < -60.0 || Y > -1.0) {
		return -1;
	}
	float r = -Y;
	int tone = -1;
	for (int i = 0; i < 5; i++) {
		vec4 T = TONGUES[i];
		float n = T.w;
		float h = T.y * (0.78 + 0.22 * ln(n * 3.0, n, 4.0));
		float sway = ln(n * 7.0, n + 9.0, 3.0) * 3.0;
		for (int l = 0; l < 4; l++) {
			vec3 L = LAYERS[l];
			float Hl = h * L.y;
			if (r > Hl) {
				continue;
			}
			float u = r / max(1.0, Hl);
			float hw = T.z * L.x * pow(1.0 - u, 0.85) * min(1.0, (r + 1.5) / 3.5) + ln(r * 0.45 + n, n + 20.0, 6.0) * 1.1
				+ ln(r * 1.3 + n * 5.0, n + 50.0, 9.0) * 0.6;
			if (hw < 0.3) {
				continue;
			}
			float cx = T.x + sway * u * u * L.y + ln(r * 0.2 + n * 2.0, n + 30.0, 5.0) * u * 1.4;
			if (X < floor(cx - hw + 0.5) || X > floor(cx + hw + 0.5)) {
				continue;
			}
			// the skin breaks up near the top: pixels flicker out of it
			if (l == 0 && u > 0.45 && ln(X * 0.9 + r * 0.7 + n, n + 60.0, 8.0) > 0.35) {
				continue;
			}
			tone = int(L.z);
		}
	}
	return tone;
}

void fragment() {
	vec2 p = floor((UV - 0.5) * size + center + 0.001);
	int v = tone_at(p.x, p.y);
	if (v < 0 || (heart_only > 0.5 && v != 3)) {
		discard;
	}
	vec4 c = v == 0 ? c6 : v == 1 ? c4 : v == 2 ? c2 : c0;
	// the pale skin whitens to its tips
	if (v == 0 && p.y < -24.0 && tone_at(p.x, p.y - 1.0) < 0) {
		c = p.y < -32.0 ? white : c7;
	}
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
