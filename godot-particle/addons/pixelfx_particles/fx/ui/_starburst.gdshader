// crit-number's starburst (src/fx/ui/crit-number.js starburst()): a jagged 13-point polygon stretched SX across, a
// dark rim, a glowing rim inside it, bands cooling from the white-hot middle out, a bright inner contour and spokes
// of light to every tip; white all through while it's hot. Its centre, size, turn, heat and every vertex's radius
// (the boil re-rolls them with the original's own hash) keyed every frame. Colour layer.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform vec4 C[8] : source_color;
uniform bool on = false;
uniform vec2 at = vec2(0.0);
uniform float R = 30.0;
uniform float rot = 0.0;
uniform float heat = 0.0;
uniform float vr[26];

const float SX = 1.3;
const int N = 13;

vec2 vert(int i) {
	float an = rot + float(i) * PI / float(N);
	return vec2(cos(an), sin(an)) * vr[i];
}

// where the ray from the middle along (dx, dy) leaves the polygon
float edge(float dx, float dy) {
	float a = atan(dy, dx) - rot;
	a -= floor(a / TAU) * TAU;
	float step_ = PI / float(N);
	int i = min(2 * N - 1, int(floor(a / step_)));
	vec2 p0 = vert(i);
	vec2 p1 = vert((i + 1) % (2 * N));
	float ex = p1.x - p0.x;
	float ey = p1.y - p0.y;
	float den = dx * ey - dy * ex;
	return abs(den) < 1e-9 ? length(p0) : (p0.x * ey - p0.y * ex) / den;
}

void fragment() {
	vec2 cell = floor(center + (UV - 0.5) * size);
	float M = R * 1.15 + 2.0;
	if (!on || R < 2.0 || cell.x < floor(at.x - M * SX) || cell.x > ceil(at.x + M * SX) || cell.y < floor(at.y - M) || cell.y > ceil(at.y + M)) {
		discard;
	}
	vec2 pc = cell + 0.5;
	float dx = (pc.x - at.x) / SX;
	float dy = pc.y - at.y;
	float d = length(vec2(dx, dy));
	vec3 c;
	if (d < 0.01) {
		c = vec3(1.0);
	} else {
		float L = edge(dx / d, dy / d);
		float gap = (L - d) * (1.0 + 0.3 * abs(dx / d));
		float q = d / L;
		if (gap < 0.0) {
			discard;
		}
		if (heat > 0.85) {
			c = gap < 1.0 ? C[6].rgb : vec3(1.0);
		} else if (gap < 1.0) {
			c = C[1].rgb;
		} else if (gap < 2.2) {
			c = heat > 0.3 ? vec3(1.0) : C[6].rgb;
		} else if (gap < 3.4) {
			c = heat > 0.3 ? C[6].rgb : C[5].rgb;
		} else if (gap >= 6.0 && gap < 7.0) {
			c = heat > 0.5 ? vec3(1.0) : C[4].rgb;
		} else {
			float an = atan(dy, dx) - rot;
			float w = (an / TAU) * float(N) + 0.5;
			float sp = abs((w - trunc(w)) - 0.5) * (TAU / float(N)) * d;
			if (sp < 0.6 && q > 0.25) {
				c = heat > 0.5 ? vec3(1.0) : q > 0.6 ? C[5].rgb : C[4].rgb;
			} else {
				int i = int(floor((q > 0.72 ? 3.0 : q > 0.45 ? 4.0 : 5.0) - heat * 5.0 + 0.5));
				vec3 ramp[6] = vec3[](vec3(1.0), C[6].rgb, C[5].rgb, C[4].rgb, C[3].rgb, C[2].rgb);
				c = i <= 0 ? vec3(1.0) : ramp[i];
			}
		}
	}
	vec4 o = vec4(c, 1.0);
	if (pfx_pixel(o, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = o;
}
