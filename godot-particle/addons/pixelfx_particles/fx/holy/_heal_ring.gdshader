// The healing ring rolling out over the floor (holy/heal-aoe, colour layer): the band (white rim, greens inward,
// thinning as it goes), its 1 px oval, a crest of light blades flickering up along the front and the lights riding
// round it. One half: side 1 the far half (behind), -1 the near half. `time` is the effect's clock in seconds.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(220.0, 64.0);
uniform float time = 0.0;
uniform float reach = 104.0;
uniform float side = 1.0;
uniform vec4 pal[8] : source_color;
// x: the rider's angle, y: its turn rate
uniform vec4 riders[14];

const float SY = 0.2;
const float SEED = 0.3;
const float ROLL = 1.0;

float hash(float a, float b) {
	return fract(sin(a * 127.1 + b * 311.7 + 0.37) * 43758.5453);
}

float ellipse_f(vec2 q, float rx, float ry) {
	return (q.x / rx) * (q.x / rx) + (q.y / ry) * (q.y / ry) - 1.0;
}

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5;
	vec2 cell = floor(p);
	float t = time;
	if (t < SEED) {
		discard;
	}
	float u = clamp((t - SEED) / (ROLL + 0.25), 0.0, 1.0);
	float fr = reach * (1.0 - pow(1.0 - clamp((t - SEED) / ROLL, 0.0, 1.0), 3.0));
	float k = u < 0.7 ? 1.0 : (1.0 - u) / 0.3;
	if (k <= 0.0 || fr <= 0.0) {
		discard;
	}
	bool back = side > 0.0;
	float thr = pfx_threshold(FRAGCOORD.xy);
	vec4 c = vec4(0.0);
	// the band, coloured by depth in from its rim
	if ((p.y < 0.0) == back) {
		float th = max(2.0, 7.0 * (1.0 - u * 0.7));
		float d = length(vec2(p.x, p.y / SY));
		float o = fr - d;
		if (o >= -0.25 && o <= th + 0.25) {
			float uu = clamp(o / th, 0.0, 1.0);
			vec4 cc = uu < 0.15 ? pal[7] : uu < 0.4 ? pal[6] : uu < 0.7 ? pal[5] : pal[4];
			if (k * (uu < 0.4 ? 1.2 : 1.15 - uu) > thr) {
				c = vec4(cc.rgb, 1.0);
			}
		}
	}
	// its 1 px oval, white along the near side
	{
		float rx = fr + 1.0;
		float ry = rx * SY;
		float f0 = ellipse_f(cell, rx, ry);
		float f1 = ellipse_f(cell + vec2(1.0, 0.0), rx, ry);
		float f2 = ellipse_f(cell + vec2(0.0, 1.0), rx, ry);
		float f3 = ellipse_f(cell + vec2(1.0, 1.0), rx, ry);
		float lo = min(min(f0, f1), min(f2, f3));
		float hi = max(max(f0, f1), max(f2, f3));
		if (lo <= 0.0 && hi >= 0.0) {
			float s = (p.y / ry) / max(length(vec2(p.x / rx, p.y / ry)), 1e-4);
			if ((s < 0.0) == back && k * (back ? 0.7 : 1.0) > thr) {
				c = s > 0.3 ? vec4(1.0) : vec4(pal[6].rgb, 1.0);
			}
		}
	}
	// a crest of light blades flickering up along the front
	int n = int(ceil(fr * 0.9));
	float flick = floor(t * 20.0);
	for (int j = 0; j < 100; j++) {
		if (j >= n) {
			break;
		}
		float g = float(j) / float(n) * TAU;
		bool near = sin(g) >= 0.0;
		if (near == back || hash(float(j), flick) > 0.45) {
			continue;
		}
		float x = cos(g) * fr;
		if (floor(x) != cell.x) {
			continue;
		}
		float y = sin(g) * fr * SY;
		float h = (1.0 + hash(float(j), 7.0) * 4.0) * k * (near ? 1.0 : 0.6);
		float i = floor(y) - cell.y;
		if (i >= 1.0 && i <= h && k * (1.2 - i / (h + 1.0)) > thr) {
			c = i > h - 1.0 ? vec4(1.0) : vec4(pal[6].rgb, 1.0);
		}
	}
	// lights riding round the ring: sparkles on the near side, dots on the far
	for (int r = 0; r < 14; r++) {
		float g = riders[r].x + riders[r].y * (t - SEED) * 2.2;
		bool near = sin(g) >= 0.0;
		if (near == back) {
			continue;
		}
		vec2 q = vec2(cos(g) * fr, sin(g) * fr * SY);
		if (near) {
			int arm = 2 + (sin(t * 9.0 + riders[r].x * 5.0) > 0.3 ? 1 : 0);
			ivec2 o = ivec2(cell - floor(q - vec2(0.0, 1.0)));
			int ax = abs(o.x);
			int ay = abs(o.y);
			if (o == ivec2(0)) {
				c = vec4(1.0);
			} else if ((o.x == 0 && ay <= arm) || (o.y == 0 && ax <= arm)) {
				c = float(max(ax, ay)) > float(arm) * 0.6 ? vec4(pal[6].rgb, 1.0) : vec4(1.0);
			} else if (arm >= 3 && ax == 1 && ay == 1) {
				c = vec4(1.0);
			}
		} else if (cell == floor(q) && k > thr) {
			c = vec4(pal[6].rgb, 1.0);
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
