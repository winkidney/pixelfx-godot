// The dark explosion's black star (the lib's blackStar()): four long arms `len` px and four short ones between them,
// turned `rot`, black, with a burning rim on the cells just outside it except inside radius `cut` (the flash, the
// sphere). For a node above the light layer. Centred on the rect.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(128.0);
uniform float len = 0.0;
uniform float rot = 0.0;
uniform float cut = 0.0;
uniform float shorter = 0.5;
uniform float q = 0.4;
uniform vec4 body : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 rim : source_color = vec4(1.0);

bool in_star(vec2 p, float L, float ro) {
	if (L <= 0.0) {
		return false;
	}
	float c = cos(ro);
	float s = sin(ro);
	float u = abs(p.x * c + p.y * s) / L;
	float v = abs(-p.x * s + p.y * c) / L;
	return u < 1.0 && v < 1.0 && pow(u, q) + pow(v, q) <= 1.0;
}

bool at(vec2 p) {
	if (in_star(p, len, rot) || in_star(p, len * shorter, rot + PI / 4.0)) {
		return true;
	}
	// the arms keep a 1 px spine to their tips
	for (int a = 0; a < 4; a++) {
		vec2 dir = vec2(cos(rot + float(a) * PI / 2.0), sin(rot + float(a) * PI / 2.0));
		float along = dot(p, dir);
		if (along >= 0.0 && along < len - 1.0 && abs(dot(p, vec2(-dir.y, dir.x))) < 0.5) {
			return true;
		}
	}
	return false;
}

void fragment() {
	if (len <= 0.0) {
		discard;
	}
	vec2 p = floor((UV - 0.5) * size) + 0.5;
	vec4 c;
	if (at(p)) {
		c = body;
	} else if (dot(p, p) >= cut * cut && (at(p + vec2(1.0, 0.0)) || at(p - vec2(1.0, 0.0)) || at(p + vec2(0.0, 1.0)) || at(p - vec2(0.0, 1.0)))) {
		c = rim;
	} else {
		discard;
	}
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
