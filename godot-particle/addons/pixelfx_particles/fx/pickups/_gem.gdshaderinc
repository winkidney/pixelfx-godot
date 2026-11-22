// _lib.js drawGem(): a cut gem as a convex solid (facet planes: unit normal and distance in `planes`, kind in
// `kinds`), turned by the spin (cs, sn), its girdle's centre on cell corner (gx, gy), seen from a little above (tilt).
// Every pixel's ray finds the facet it looks at; crown facets catch the light from the top left, pavilion facets
// glow with light bouncing up through the stone, a crystal's prism faces take the light's level direction; where two
// facets meet a pavilion edge sinks a shade and a crown ridge gains one; a dark outline round it all.
// Include after pixel.gdshaderinc, _pk.gdshaderinc and scifi/_jsrand.gdshaderinc. Declares its uniforms.

uniform vec4 planes[52];
uniform float kinds[52];
uniform int count = 0;
// the Layer's fill box round (gx, gy): R across, top above, bot below
uniform vec3 box = vec3(10.0, 6.0, 12.0);
uniform float gx = 0.0;
uniform float gy = 0.0;
uniform float cs = 1.0;
uniform float sn = 0.0;
uniform float tilt_c = 0.95;
uniform float tilt_s = 0.31;
uniform float gain = 1.0;
uniform bool edges = true;

vec3 gem_rot(vec3 n) {
	return vec3(n.x * cs - n.z * sn, n.y, n.x * sn + n.z * cs);
}

// the facet the ray through pixel centre pc looks at, or -1
int gem_hit(vec2 pc) {
	vec2 rel = floor(pc) - vec2(gx, gy);
	if (rel.x < -box.x || rel.x > box.x || rel.y < -box.y || rel.y > box.z) {
		return -1;
	}
	float sx = pc.x - gx;
	float sy = -(pc.y - gy);
	vec3 o = vec3(sx, sy * tilt_c, -sy * tilt_s);
	vec3 dv = vec3(0.0, -tilt_s, -tilt_c);
	float t0 = -1e9;
	float t1 = 1e9;
	int hit = -1;
	for (int i = 0; i < 52; i++) {
		if (i >= count) {
			break;
		}
		vec3 n = gem_rot(planes[i].xyz);
		float nd = dot(n, dv);
		float no = dot(n, o);
		if (abs(nd) < 1e-6) {
			if (no > planes[i].w) {
				return -1;
			}
			continue;
		}
		float tt = (planes[i].w - no) / nd;
		if (nd < 0.0) {
			if (tt > t0) {
				t0 = tt;
				hit = i;
			}
		} else if (tt < t1) {
			t1 = tt;
		}
	}
	if (hit < 0 || t0 > t1) {
		return -1;
	}
	return hit;
}

bool gem_pav(int i) {
	int k = int(kinds[i] + 0.5);
	return k == 4 || k == 5 || k == 8;
}

// the shade facet i shows at pixel centre pc: an index into C, 8 for white
int gem_shade(int i, vec2 pc) {
	vec3 n = gem_rot(planes[i].xyz);
	int kind = int(kinds[i] + 0.5);
	bool pav = gem_pav(i);
	vec3 Lv = vec3(-0.55, 0.72, 0.42);
	vec3 V = vec3(0.0, tilt_s, tilt_c);
	vec3 H = (Lv + V) / length(Lv + V);
	vec3 m = pav ? vec3(n.x, -n.y * 0.6, n.z) : n;
	float ml = length(m);
	float lam = max(0.0, dot(m, Lv) / ml);
	float spec = pow(max(0.0, dot(m, H) / ml), 18.0);
	float b = pav ? 0.02 + 0.72 * pow(lam, 2.4) : kind == 3 ? 0.12 + 0.4 * lam : 0.04 + 0.66 * pow(lam, 1.8);
	if (kind == 6) {
		b = 0.16 + 0.66 * pow(max(0.0, (n.x * Lv.x + n.z * Lv.z) / length(vec2(Lv.x, Lv.z))), 1.3);
	} else if (kind == 7) {
		b = 0.22 + 0.62 * pow(lam, 1.2);
	} else if (kind == 9) {
		b = 0.62 + 0.25 * lam;
	} else if (kind == 10) {
		uint h = js_hash3(int(floor(pc.x - gx)), int(floor(pc.y - gy)), 43);
		b = 0.3 + 0.5 * lam + (float(h) / 4294967296.0 - 0.5) * 0.08;
	}
	if (kind != 9) {
		b *= gain;
	}
	if (kind == 0) {
		b -= 0.04;
	}
	float s = b + spec * 0.6;
	if (spec > 0.8) {
		return pav ? 6 : 8;
	}
	return clamp(int(js_round(1.0 + s * 5.6)), 1, 6);
}

// the gem's colour at pc (alpha 0: not the gem), outline included; C (a uniform declared before the include): the ramp
vec4 gem_px(vec2 pc) {
	int id = gem_hit(pc);
	if (id < 0) {
		if (gem_hit(pc + vec2(1.0, 0.0)) >= 0 || gem_hit(pc - vec2(1.0, 0.0)) >= 0 || gem_hit(pc + vec2(0.0, 1.0)) >= 0 || gem_hit(pc - vec2(0.0, 1.0)) >= 0) {
			return vec4(C[0].rgb, 1.0);
		}
		return vec4(0.0);
	}
	int k = gem_shade(id, pc);
	if (edges) {
		int r = gem_hit(pc + vec2(1.0, 0.0));
		int d = gem_hit(pc + vec2(0.0, 1.0));
		if ((r >= 0 && r != id) || (d >= 0 && d != id)) {
			// the original looks the pixel's colour up in the ramp: white is C[7] when the ramp ends in white
			int i = k == 8 ? (all(greaterThan(C[7].rgb, vec3(0.999))) ? 7 : -1) : k;
			if (i > 0) {
				k = gem_pav(id) ? max(1, i - 1) : min(7, i + 1);
			}
		}
	}
	return vec4(k == 8 ? vec3(1.0) : C[k].rgb, 1.0);
}
