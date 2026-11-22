// The ice effects' snowflake(): six crisp 1 px arms of radius `r` turned by `rot` (in 10 degree ticks, like sprite
// frames), side branches at 60 degrees ([where, length] pairs in `branches`, `nb` of them), a hexagonal plate round the
// heart or forked tips by design, white tips and heart. Small ones lose detail: a flipping six-point star under
// 2.6 px, a dot under 1.2. `hot` (0..1) makes it twinkle white. `smear` >= 0: lying on the floor, a smear `flat` px
// either side. Centred on the rect's middle pixel (odd size). Colour layer; c6 / c5 are the ramp's two palest steps
// below white.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(31.0);
uniform vec2 center = vec2(0.0);
uniform float r = 6.0;
uniform float rot = 0.0;
uniform float hot = 0.0;
uniform vec4 branches = vec4(0.58, 0.36, 0.0, 0.0);
uniform float nb = 1.0;
uniform float plate = 0.0;
uniform float fork = 0.0;
uniform float smear = -1.0;
uniform vec4 c6 : source_color = vec4(0.86, 0.98, 1.0, 1.0);
uniform vec4 c5 : source_color = vec4(0.65, 0.93, 1.0, 1.0);
uniform float alpha = 1.0;

ivec2 cellof(vec2 q) {
	return ivec2(floor(q + 0.5));
}

// the original's 1 px Bresenham line between two cells
bool on_line(ivec2 P, ivec2 A, ivec2 B) {
	ivec2 d = B - A;
	if (abs(d.x) >= abs(d.y)) {
		if (d.x == 0) {
			return P == A;
		}
		float u = float(P.x - A.x) / float(d.x);
		if (u < 0.0 || u > 1.0) {
			return false;
		}
		return P.y == A.y + int(round(u * float(d.y)));
	}
	float u = float(P.y - A.y) / float(d.y);
	if (u < 0.0 || u > 1.0) {
		return false;
	}
	return P.x == A.x + int(round(u * float(d.x)));
}

void fragment() {
	vec4 tint = COLOR;   // the node's modulate: fade a group, tint a copy
	ivec2 P = ivec2(floor(UV * size) - floor(size / 2.0));
	vec4 W = vec4(1.0);
	vec4 c = vec4(0.0);
	bool hit = false;
	float tick = PI / 18.0;
	float rr = round(rot / tick) * tick;
	if (smear >= 0.0) {
		int L = int(smear);
		if (P.y == 0 && abs(P.x) <= L) {
			c = abs(P.x) == L ? c5 : (P.x == 0 ? W : c6);
			hit = true;
		}
	} else if (r < 1.2) {
		if (P == ivec2(0)) {
			c = W;
			hit = true;
		}
	} else if (r < 2.6) {
		float sixth = PI / 3.0;
		float m = rr - sixth * trunc(rr / sixth);
		int pose = int(floor((m + sixth) / (PI / 6.0))) % 2;
		ivec2 a = abs(P);
		bool star = pose == 1 ? ((a.x == 1 && a.y == 0) || (a.x == 0 && a.y == 1)) : (a.x == 1 && a.y == 1);
		if (star) {
			c = hot > 0.5 ? W : c5;
			hit = true;
		}
		if (P == ivec2(0)) {
			c = W;
			hit = true;
		}
	} else {
		vec4 arm = hot > 0.5 ? W : c6;
		vec4 br = hot > 0.5 ? c6 : c5;
		bool big = r >= 7.0;
		int n = r < 4.0 ? 0 : (big ? int(min(nb, 2.0)) : 1);
		ivec2 O = ivec2(0);
		for (int k = 0; k < 6; k++) {
			float g = rr + float(k) * TAU / 6.0;
			vec2 dir = vec2(cos(g), sin(g));
			ivec2 T = cellof(dir * r);
			if (on_line(P, O, T)) {
				c = arm;
				hit = true;
			}
			for (int b = 0; b < 2; b++) {
				if (b >= n) {
					break;
				}
				float u = big ? (b == 0 ? branches.x : branches.z) : 0.58;
				float l = big ? (b == 0 ? branches.y : branches.w) : 0.36;
				vec2 bp = dir * r * u;
				float bl = max(1.0, r * l);
				for (int s = -1; s <= 1; s += 2) {
					float ga = g + float(s) * PI / 3.0;
					if (on_line(P, cellof(bp), cellof(bp + vec2(cos(ga), sin(ga)) * bl))) {
						c = br;
						hit = true;
					}
				}
			}
			if (fork > 0.5 && big && plate < 0.5) {
				for (int s = -1; s <= 1; s += 2) {
					float ga = g + float(s) * 0.9;
					if (P == cellof(dir * r + vec2(cos(ga), sin(ga)) * 1.2)) {
						c = br;
						hit = true;
					}
				}
			}
			if (P == T) {
				c = W;
				hit = true;
			}
		}
		if (plate > 0.5 && big) {
			float q = r * 0.34;
			for (int k = 0; k < 6; k++) {
				float g0 = rr + PI / 6.0 + float(k) * TAU / 6.0;
				float g1 = g0 + TAU / 6.0;
				if (on_line(P, cellof(vec2(cos(g0), sin(g0)) * q), cellof(vec2(cos(g1), sin(g1)) * q))) {
					c = c5;
					hit = true;
				}
			}
		}
		if (P == ivec2(0)) {
			c = W;
			hit = true;
		}
	}
	if (!hit) {
		discard;
	}
	c.a = alpha;
	c *= tint;
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
