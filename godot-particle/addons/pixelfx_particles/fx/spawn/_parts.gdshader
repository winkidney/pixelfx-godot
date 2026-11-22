// The original's Particles (src/core/sim.js Particles.draw), every kind drawn as it draws it, on whole cells round each
// tracked particle (_track.gdshader moves them by the original's own physics, run at build time): a two-tone spark,
// a mote's trail, a streak's run of dots, a flake, translucent vapour and dust discs, a twinkling star glint, a
// flickering ember, three soft smoke discs, a ball of fire cooling down its ramp, a grit pixel. The soft layer:
// discs blend as the original's do, the rest dithers on and off. Colours are the original's own (its ramps, the fire
// and smoke ramps, and its mixes of them), kept as they are.
//   head 1 (kind, colour index or -1, size, flag), 2 (seed, ..); rows 0 (x, y, on, life left 0..1), 1 (vx, vy, aux,
//   aux2): a star's twinkle; an ember hidden (1) in its flicker; a fire's ramp step and radius
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/spawn/_track.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/spawn/_track_px.gdshaderinc"

uniform vec4 cols[48] : source_color;
uniform vec4 sparks[4] : source_color;
uniform vec4 fire[9] : source_color;
uniform vec4 smoke[5] : source_color;
uniform vec4 white : source_color = vec4(1.0);

void vertex() {
	tk_cu = INSTANCE_CUSTOM;
}

// paint (c, a) on this cell as the original's put(): dithered on/off, the later on top
void put(inout vec4 o, vec3 c, float a, float th) {
	if (a >= 1.0 || a > th) {
		o = vec4(c, 1.0);
	}
}

// blend (c, a) over this cell as the original's blendPx()
void blend(inout vec4 o, vec3 c, float a) {
	o = tk_over(o, c, a);
}

bool at(vec2 cell, vec2 d) {
	return all(equal(cell, floor(tk_fr() + d)));
}

bool circle(vec2 q, vec2 cell, vec2 c, float r) {
	if (r < 0.6) {
		return at(cell, c);
	}
	vec2 e = q - c;
	return dot(e, e) <= r * r;
}

void fragment() {
	vec4 h1 = tk_head(1);
	vec4 r0 = tk_row(0);
	vec4 r1 = tk_row(1);
	int kind = int(h1.x + 0.5);
	int ci = int(h1.y + 0.5);
	vec3 col = h1.y < -0.5 ? vec3(0.0) : cols[ci].rgb;
	float size = h1.z;
	float flag = h1.w;
	float k = r0.w;
	vec2 v = r1.xy;
	float sp = length(v);
	if (sp == 0.0) {
		sp = 1.0;
	}
	vec2 u = v / sp;
	vec2 cell = tk_cell(UV);
	vec2 q = tk_q(UV);
	float th = pfx_threshold(FRAGCOORD.xy);
	vec4 o = vec4(0.0);
	bool soft = false;
	if (kind == 0) {
		// SPARK
		vec3 hd = k > 0.6 ? sparks[0].rgb : k > 0.3 ? sparks[1].rgb : sparks[2].rgb;
		float len = min(9.0, 1.0 + sp * 0.022);
		vec2 fr = tk_fr();
		if (tk_line(cell, floor(fr - u * len), floor(fr - u * len * 0.4)) >= 0.0) {
			o = vec4(k > 0.5 ? hd : sparks[3].rgb, 1.0);
		}
		if (tk_line(cell, floor(fr - u * len * 0.45), vec2(0.0)) >= 0.0) {
			o = vec4(hd, 1.0);
		}
	} else if (kind == 1) {
		// MOTE
		float len = min(16.0, 0.5 + sp * 0.026) * size;
		float a = k < 0.35 ? k / 0.35 : 1.0;
		vec2 fr = tk_fr();
		if (tk_line(cell, floor(fr - u * len), floor(fr - u * len * 0.35)) >= 0.0) {
			put(o, tk_scale(col, 0.55), a, th);
		}
		if (tk_line(cell, floor(fr - u * len * 0.4), vec2(0.0)) >= 0.0) {
			put(o, col, a, th);
		}
	} else if (kind == 2) {
		// STREAK
		float L = clamp(sp / 30.0, 1.0, 7.0);
		int n = int(floor(L / 0.5 + 1e-4));
		for (int j = 0; j <= n; j++) {
			float d = L - 0.5 * float(j);
			if (at(cell, -u * d)) {
				put(o, d < 1.0 ? white.rgb : d < L * 0.5 ? col : tk_scale(col, 0.6), d < L * 0.5 ? 1.0 : 1.2 - d / L, th);
			}
		}
	} else if (kind == 3) {
		// FLAKE
		float a = min(1.0, k * 3.0);
		if (at(cell, vec2(0.0))) {
			put(o, col, a, th);
		} else if (size > 1.3 && (at(cell, vec2(1.0, 0.0)) || at(cell, vec2(-1.0, 0.0)) || at(cell, vec2(0.0, 1.0)) || at(cell, vec2(0.0, -1.0)))) {
			put(o, tk_scale(col, 0.8), a * 0.8, th);
		}
	} else if (kind == 4 || kind == 5) {
		// VAPOUR, DUST
		soft = true;
		if (tk_disc(UV, vec2(0.0), size * (0.6 + (1.0 - k) * 0.9))) {
			blend(o, col, pow(k, 1.3) * (kind == 4 ? 0.45 : 0.7));
		}
	} else if (kind == 6) {
		// STAR
		float tw = r1.z;
		if (size < 1.0) {
			if (tw * k > 0.25 && at(cell, vec2(0.0))) {
				o = vec4(tw > 0.8 ? white.rgb : col, 1.0);
			}
		} else {
			float n = floor(size * tw * min(1.0, k * 3.0) + 0.5);
			if (n >= 1.0) {
				vec3 tip = tk_scale(col, 0.75);
				vec2 ad = abs(cell);
				if (ad.x < 0.5 && ad.y < 0.5) {
					o = white;
				} else if ((ad.x < 0.5 || ad.y < 0.5) && max(ad.x, ad.y) <= n + 0.1) {
					o = vec4(max(ad.x, ad.y) > n * 0.6 ? tip : col, 1.0);
				} else if (n >= 3.0 && ad.x > 0.5 && ad.x < 1.5 && ad.y > 0.5 && ad.y < 1.5) {
					o = vec4(col, 1.0);
				} else if (n >= 6.0 && ad.x > 1.5 && ad.x < 2.5 && ad.y > 1.5 && ad.y < 2.5) {
					o = vec4(tip, 1.0);
				}
			}
		}
	} else if (kind == 7) {
		// EMBER
		if (r1.z < 0.5) {
			vec3 c = k > 0.6 ? sparks[0].rgb : k > 0.3 ? sparks[1].rgb : sparks[2].rgb;
			if (at(cell, vec2(0.0))) {
				o = vec4(c, 1.0);
			} else if (size > 1.5 && at(cell, vec2(0.0, 1.0))) {
				o = vec4(sparks[3].rgb, 1.0);
			}
		}
	} else if (kind == 8) {
		// SMOKE: a body, a denser core sitting low, a lit cap while it's young
		soft = true;
		float age = 1.0 - k;
		bool big = mod(floor(flag / 2.0), 2.0) > 0.5;
		float r = size * (0.65 + min(1.0, age * 2.5) * 0.45 + age * (big ? 0.5 : 0.4));
		float a = min(1.0, age * 12.0) * min(1.0, k * 2.4) * (big ? 0.7 : 0.58);
		vec3 c = h1.y < -0.5 ? smoke[clamp(int(floor(age * 1.05 * 5.0)), 0, 4)].rgb : tk_mix(col, smoke[clamp(int(floor(age * 5.0)), 0, 4)].rgb, age);
		if (tk_disc(UV, vec2(0.0), r)) {
			blend(o, c, a * 0.45);
		}
		if (tk_disc(UV, vec2(r * 0.05, r * 0.06), r * 0.74)) {
			blend(o, c, a * 0.62);
		}
		if (age < 0.5 && tk_disc(UV, vec2(-r * 0.22, -r * 0.3), r * 0.5)) {
			blend(o, tk_mix(c, vec3(1.0), 0.12), a * 0.4 * (1.0 - age * 2.0));
		}
	} else if (kind == 9) {
		// FIRE: a darker rim, a lit core, a tongue on top; at the end of its ramp a fading disc
		int idx = int(r1.z + 0.5);
		float r = r1.w;
		vec3 c = fire[idx].rgb;
		if (idx >= 7) {
			soft = true;
			if (tk_disc(UV, vec2(0.0), r)) {
				blend(o, c, min(1.0, k * 3.0) * 0.85);
			}
		} else {
			if (circle(q, cell, vec2(0.0), r)) {
				o = vec4(fire[min(8, idx + 2)].rgb, 1.0);
			}
			if (circle(q, cell, vec2(-r * 0.16, -r * 0.22), r * 0.78)) {
				o = vec4(c, 1.0);
			}
			if (r > 1.6 && circle(q, cell, vec2(0.0, -r * 0.9), r * 0.42)) {
				o = vec4(c, 1.0);
			}
			if (idx <= 3 && r > 1.8 && circle(q, cell, vec2(-r * 0.28, -r * 0.34), r * 0.36)) {
				o = vec4(fire[max(0, idx - 1)].rgb, 1.0);
			}
		}
	} else if (kind == 11) {
		// GRIT
		if (k > 0.125) {
			if (at(cell, vec2(0.0))) {
				o = vec4(col, 1.0);
			} else if (size >= 2.0) {
				if (at(cell, vec2(1.0, 0.0))) {
					o = vec4(col, 1.0);
				} else if (at(cell, vec2(0.0, 1.0))) {
					o = vec4(tk_scale(col, 0.8), 1.0);
				} else if (at(cell, vec2(1.0, 1.0))) {
					o = vec4(tk_scale(col, 0.7), 1.0);
				}
			}
		}
	}
	if (o.a <= 0.0) {
		discard;
	}
	// the soft layer keeps a blended disc's alpha in 32 steps; the rest is on or off
	float a = soft ? floor(o.a * 32.0 + th) / 32.0 : 1.0;
	if (a <= 0.0) {
		discard;
	}
	COLOR = vec4(o.rgb, a);
}
