// The force field (src/fx/scifi/force-field.js), from the keyed clock `t`:
//   mode 0: the dome's far side seen through the glass (dim seams, a breath of tint; translucent) over the far
//           emitters round its foot (behind the stand-in)
//   mode 1: the near side: a hard bright rim, glassy plates thicker toward it with a lit top-left edge each, seams
//           humming, the struck plates white, ripples racing out from each hit, plates glinting, the scan band
//   mode 2: the near emitters round the foot, chasing; then for each shot: the fractures racing out from the big hit
//           (the original's own bolt paths over the sphere, `cracks`), the tracer streaking in from the right, the
//           white star of the impact
// Colour layer (translucent where the original blends).
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/scifi/_scifi.gdshaderinc"

uniform vec2 size = vec2(184.0, 104.0);
uniform vec2 center = vec2(0.0);
uniform float t = 0.0;
uniform int mode = 0;
uniform sampler2D near : filter_nearest, repeat_disable;
uniform sampler2D far : filter_nearest, repeat_disable;
uniform sampler2D cracks : filter_nearest, repeat_disable;
uniform int crack_count = 0;
uniform vec4 pal[8] : source_color;
uniform vec4 sparks[4] : source_color;
uniform float right_edge = 105.0;

#include "res://addons/pixelfx_particles/fx/scifi/_force_field.gdshaderinc"

// the emitters round the foot: (C2 either side, the light itself white when it peaks)
bool emitter(ivec2 P, bool nearside, out vec4 c) {
	bool hit = false;
	for (int i = 0; i < 10; i++) {
		float g = float(i) / 10.0 * TAU + 0.31;
		if ((sin(g) >= 0.0) != nearside) {
			continue;
		}
		vec2 p = vec2(cos(g) * (RAD - 0.5), sin(g) * RAD * SA);
		float k = 0.5 + 0.5 * cos(TAU * (2.0 * (t / D) - float(i) / 10.0));
		ivec2 cp = ivec2(floor(p));
		if (P == cp - ivec2(1, 0) || P == cp + ivec2(1, 0)) {
			c = pal[2];
			hit = true;
		}
		if (P == cp) {
			c = k > 0.6 ? vec4(1.0) : pal[5];
			hit = true;
		}
	}
	return hit;
}

bool line_cells(vec2 cell, vec2 a, vec2 b) {
	return cell_on_line(cell, floor(a), floor(b));
}

vec4 shots(ivec2 P, vec2 pc, float thr) {
	vec2 cell = vec2(P);
	vec4 c = vec4(0.0);
	vec4 ec;
	if (emitter(P, true, ec)) {
		c = ec;
	}
	for (int s = 0; s < 2; s++) {
		bool big = s == 0;
		float st = shot_t(s);
		float age = mod(t - st, D);
		float n = big ? 1.0 : 0.6;
		vec2 h = project(s == 0 ? 0.66 : 0.95, s == 0 ? 0.62 : 0.26);
		// the fractures: race out from the hit white-hot, then cool down the ramp and fade
		if (big && age < 0.9 && abs(pc.x - h.x) < 50.0) {
			float fade = 1.0 - e_smooth(0.35, 0.9, age);
			float reach = clamp(age / 0.09, 0.0, 1.0);
			for (int pass = 0; pass < 2; pass++) {
				for (int i = 0; i < 256; i++) {
					if (i >= crack_count) {
						break;
					}
					vec4 a = texelFetch(cracks, ivec2(i, 0), 0);
					vec4 b = texelFetch(cracks, ivec2(i, 1), 0);
					float u = b.z;
					if (u > reach || b.x < 0.05 || b.y < 0.05) {
						continue;
					}
					float k = fade * (1.2 - u * 0.4);
					if (pass == 0) {
						if (age < 0.32) {
							float al = k * (1.0 - age / 0.32);
							for (int o = 0; o < 4; o++) {
								vec2 off = o == 0 ? vec2(1.0, 0.0) : o == 1 ? vec2(-1.0, 0.0) : o == 2 ? vec2(0.0, 1.0) : vec2(0.0, -1.0);
								if (line_cells(cell, a.xy + off, a.zw + off) && al >= thr) {
									c = age < 0.12 ? pal[6] : pal[5];
								}
							}
						}
						continue;
					}
					if (line_cells(cell, a.xy, a.zw) && k >= thr) {
						c = age < 0.12 + u * 0.08 ? vec4(1.0) : age < 0.3 + u * 0.1 ? pal[6] : pal[5];
					}
				}
			}
		}
		// the tracer, in from the right: a streak out of the edge, its tail never past where it entered
		float tk = (t - (st - 0.1)) / 0.1;
		if (tk >= 0.0 && tk < 1.0) {
			vec2 sp0 = vec2(right_edge, h.y - 12.0);
			float L = length(sp0 - h);
			float hd = L * tk;
			vec2 x0 = sp0 + (h - sp0) * max(0.0, hd) / L;
			vec2 x2 = sp0 + (h - sp0) * max(0.0, hd - 2.0) / L;
			vec2 x7 = sp0 + (h - sp0) * max(0.0, hd - 7.0) / L;
			vec2 x16 = sp0 + (h - sp0) * max(0.0, hd - 16.0) / L;
			if (line_cells(cell, x16, x7)) {
				c = sparks[3];
			}
			if (line_cells(cell, x7, x2)) {
				c = sparks[1];
			}
			if (line_cells(cell, x2, x0)) {
				c = sparks[0];
			}
			if (all(equal(cell, floor(x0)))) {
				c = vec4(1.0);
			}
		}
		// the impact: a white star
		if (age < 0.14) {
			int arm = int(floor((7.0 * (1.0 - age / 0.14) + 1.0) * n + 0.5));
			ivec2 d = P - ivec2(floor(h));
			int ax = abs(d.x);
			int ay = abs(d.y);
			if (arm >= 1) {
				if (d == ivec2(0)) {
					c = vec4(1.0);
				} else if ((d.x == 0 && ay <= arm) || (d.y == 0 && ax <= arm)) {
					c = float(max(ax, ay)) > float(arm) * 0.6 ? pal[5] : pal[6];
				} else if (arm >= 3 && ax == 1 && ay == 1) {
					c = pal[6];
				} else if (arm >= 6 && ax == 2 && ay == 2) {
					c = pal[5];
				}
			}
		}
	}
	return c;
}

void fragment() {
	vec2 cell = floor(center + (UV - 0.5) * size + 0.001);
	ivec2 P = ivec2(cell);
	vec2 pc = cell + 0.5;
	float thr = pfx_threshold(FRAGCOORD.xy);
	vec4 c = vec4(0.0);
	bool soft = false;
	if (mode == 0) {
		vec4 ec;
		if (emitter(P, false, ec)) {
			c = ec;
		}
		Shell s = shell_at(P, false);
		if (c.a <= 0.0 && s.a > 0.004) {
			c = vec4(s.col.rgb, s.a);
			soft = true;
		}
	} else if (mode == 1) {
		Shell s = shell_at(P, true);
		if (s.a > 0.004) {
			c = vec4(s.col.rgb, s.a);
			soft = !s.opaque;
		}
	} else {
		c = shots(P, pc, thr);
	}
	if (c.a <= 0.0) {
		discard;
	}
	if (px_out(c, FRAGCOORD.xy, soft)) {
		discard;
	}
	COLOR = c;
}
