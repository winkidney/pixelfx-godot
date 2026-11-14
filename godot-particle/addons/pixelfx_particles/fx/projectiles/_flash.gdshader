// A muzzle flash (projectiles/_lib.js flash()): lobes [off, angle, length, width] fanned along `ang` from the
// muzzle (the rect's centre), each a tapering tongue; a pixel takes the deepest lobe it sits in: the core colour
// where it's in a lobe's hot core (or the muzzle's own hot ball), the inner flame where it's well inside, the body,
// and a ragged rim of c3 just outside. Colour layer; show it for its frame (projectiles/_projectiles.gd flash()).
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(64.0);
// the muzzle, px from the effect's origin (shape() sets it): the rim's grain is the original's rand() of the pixel
uniform vec2 center = vec2(0.0);
uniform vec4 lobes[24];
uniform float cores[24];
uniform int count = 0;
uniform float ang = 0.0;
// the flash's reach (scales the rim's raggedness) and the rim's grain
uniform float ext = 14.0;
uniform float grain = 1.0;
uniform vec4 c0 : source_color = vec4(1.0);
uniform vec4 c1 : source_color = vec4(1.0);
uniform vec4 c2 : source_color = vec4(1.0);
uniform vec4 c3 : source_color = vec4(1.0);
uniform float alpha = 1.0;

// core/math.js hash(a, b) / 2^32: the original's rand(), bit for bit
uint jmix(uint h, int n) {
	h = (h ^ uint(n)) * 0x85ebca6bu;
	h ^= h >> 13u;
	h *= 0xc2b2ae35u;
	h ^= h >> 16u;
	return h;
}

float jrand(int a, int b) {
	return float(jmix(jmix(0x9e3779b9u, a), b)) / 4294967296.0;
}

void fragment() {
	vec2 cell = floor(UV * size) - size * 0.5;
	vec2 d = cell + 0.5;
	float c = cos(ang);
	float s = sin(ang);
	float along = d.x * c + d.y * s;
	float across = -d.x * s + d.y * c;
	float m = -9.0;
	bool hot = false;
	bool warm = false;
	for (int i = 0; i < 24; i++) {
		if (i >= count) {
			break;
		}
		vec4 l = lobes[i];
		float ca = cos(l.y);
		float sa = sin(l.y);
		float lu = (along - l.x) * ca + across * sa;
		float lv = -(along - l.x) * sa + across * ca;
		if (lu < -1.5 || lu > l.z + 1.0) {
			continue;
		}
		float k = max(0.0, lu) / l.z;
		float r = l.w * pow(max(0.0, 1.0 - k), 0.8) * min(1.0, 0.45 + k * 3.0);
		float mm = r - abs(lv);
		m = max(m, mm);
		if (lu < l.z * cores[i] && abs(lv) <= r * 0.5) {
			hot = true;
		}
		if (mm > r * 0.4) {
			warm = true;
		}
	}
	float dm = 1.6 - length(vec2(along - 0.5, across));
	if (dm > m) {
		m = dm;
	}
	if (dm > 0.6) {
		hot = true;
	}
	vec2 px = cell + center;
	m += (jrand(int(px.x) * 73 + int(px.y) * 151, int(grain)) - 0.5) * 0.5 * min(1.0, ext / 14.0);
	if (m < -0.85) {
		discard;
	}
	vec4 col = m < 0.0 ? c3 : hot ? c0 : warm ? c1 : c2;
	col.a *= alpha * COLOR.a;
	if (pfx_pixel(col, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = col;
}
