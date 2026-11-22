// The eclipse, colour layer (see _eclipse.gdshaderinc). mode 0: the streamers (1 px dotted rays curling out, white at
// the root through pearl to violet), the streaked inner corona hugging the moon and the diamond bead with its rays.
// mode 1: the black moon with earthshine on its left limb and the part of the bead over it; this node sits above the
// light layer (the original unlights the moon).
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/shadow/_eclipse.gdshaderinc"

uniform float mode = 0.0;
uniform vec4 c0 : source_color = vec4(1.0);
uniform vec4 c1 : source_color = vec4(1.0);
uniform vec4 c4 : source_color = vec4(1.0);
uniform vec4 c5 : source_color = vec4(1.0);
uniform vec4 q1 : source_color = vec4(1.0);
uniform vec4 q2 : source_color = vec4(1.0);
uniform vec4 q3 : source_color = vec4(1.0);
uniform vec4 white : source_color = vec4(1.0);

// the bead: three circles and its 8 rays (a dotted 1 px line each, breaking where it would enter the moon)
bool bead(vec2 cell, vec2 p, float th, inout vec4 c) {
	vec2 bp = e_bead();
	float k = e_bead_k();
	bool hit = false;
	for (int i = 0; i < 8; i++) {
		float a = float(i) * PI / 4.0 + 0.12;
		float len = (i % 2 == 1 ? 7.0 : 22.0) * k * ((i == 1 || i == 5) ? 1.6 : 1.0);
		vec2 dir = vec2(cos(a), sin(a));
		float pr = dot(p - bp, dir);
		float d0 = max(1.0, floor((pr - 1.5) * 2.0) / 2.0);
		for (int j = 0; j < 7; j++) {
			float d = d0 + float(j) * 0.5;
			if (d > len) {
				break;
			}
			vec2 q = bp + dir * d;
			if (dot(q, q) < (E_R - 0.5) * (E_R - 0.5)) {
				break;
			}
			if (floor(q) == cell) {
				float u = d / len;
				float al = u < 0.5 ? 1.0 : (1.0 - u) * 2.2;
				if (al >= th) {
					c = u < 0.35 ? white : u < 0.7 ? q2 : q1;
					hit = true;
				}
			}
		}
	}
	float dd = length(p - bp);
	if (dd <= 3.0 * k) { c = q2; hit = true; }
	if (dd <= 2.2 * k) { c = q3; hit = true; }
	if (dd <= 1.4) { c = white; hit = true; }
	return hit;
}

void fragment() {
	vec2 p = floor((UV - 0.5) * size + center + 0.001) + 0.5;
	vec2 cell = floor(p);
	float th = pfx_threshold(FRAGCOORD.xy);
	float r = length(p);
	vec4 c = vec4(0.0);
	bool hit = false;
	if (mode > 0.5) {
		if (r >= E_R - 0.5) {
			discard;
		}
		c = (r > E_R - 2.2 && p.x < -E_R * 0.45) ? c1 : c0;
		bead(cell, p, th, c);
	} else {
		// streamers: the original's dots every 0.5 px from 4 px out, each landing on the cell it falls in
		float b = e_b();
		if (r > E_R + 4.0 && r < E_R + 60.0) {
			for (int i = 0; i < 30; i++) {
				vec4 s = streams[i];
				float L = e_len(i);
				float dc = r - E_R - 1.0;
				if (dc < 3.0 || dc > L + 1.5) {
					continue;
				}
				float d0 = max(4.0, floor((dc - 1.0) * 2.0) / 2.0);
				for (int j = 0; j < 5; j++) {
					float d = d0 + float(j) * 0.5;
					if (d > L) {
						break;
					}
					float a = s.x + s.z * d * d;
					vec2 q = vec2(cos(a), sin(a)) * (E_R + 1.0 + d);
					if (floor(q) == cell) {
						float u = d / L;
						float al = u < 0.75 ? 1.0 : (1.0 - u) * 4.0;
						if (al >= th) {
							c = u < 0.3 ? q2 : u < 0.65 ? q1 : c5;
							hit = true;
						}
					}
				}
			}
		}
		float I = e_corona(p);
		if (I >= 9.0) {
			c = q3;
			hit = true;
		} else if (I >= 0.1) {
			c = I > 0.72 ? q2 : I > 0.42 ? q1 : I > 0.22 ? c5 : c4;
			hit = true;
		}
		if (bead(cell, p, th, c)) {
			hit = true;
		}
		if (!hit) {
			discard;
		}
	}
	c.a = 1.0;
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
