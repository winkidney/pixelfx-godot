// How the pickups' particles look (colour layer), drawn cell by cell as the original draws each kind: a dot
// (painter.js dot / px), a star glint (_lib.js glint: arms, dimmer tips, a white heart), a 1 px line (painter.js
// line, Bresenham, two colours along it), a mini heart sprite (heart-pickup), a bubble (potion), a splinter
// (crystal-shard). Placed by _ftp.gdshader on its cell's centre; `data` holds what the original drew at each frame:
//   row 0: cell x, cell y, size (glint arms, ...), alpha (dithered; 1 opaque)
//   row 1: colour index, second colour index, light colour index, present
//   row 2: light x, y, radius, k (for _bits_light.gdshader)
//   row 3: kind-specific extras
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/pickups/_pk.gdshaderinc"

uniform sampler2D data : filter_nearest, repeat_disable;
// 0 dot, 1 glint, 2 line, 3 mini heart, 4 (unused), 5 splinter, 6 coin, 7 gemlet, 8 sparkle, 9 soft disc, 10 ring
uniform float kind = 0.0;
uniform float quad = 9.0;
uniform vec4 pal[16] : source_color;

varying flat vec4 cu;

void vertex() {
	cu = INSTANCE_CUSTOM;
}

vec4 row(int r) {
	return texelFetch(data, ivec2(int(cu.x + 0.5), int(cu.y + 0.5) * 4 + r), 0);
}

// painter.js line() from cell (0, 0) to cell e: the step index of cell d along it, or -1 off it
int line_step(vec2 d, vec2 e) {
	int sx = 0;
	int sy = 0;
	int ex = int(e.x);
	int ey = int(e.y);
	int dx = abs(ex);
	int dy = -abs(ey);
	int stx = ex > 0 ? 1 : -1;
	int sty = ey > 0 ? 1 : -1;
	int err = dx + dy;
	ivec2 q = ivec2(d);
	for (int i = 0; i < 96; i++) {
		if (sx == q.x && sy == q.y) {
			return i;
		}
		if (sx == ex && sy == ey) {
			break;
		}
		int e2 = 2 * err;
		if (e2 >= dy) {
			err += dy;
			sx += stx;
		}
		if (e2 <= dx) {
			err += dx;
			sy += sty;
		}
	}
	return -1;
}

// the splinter's colour at cell d from its centre cell (an index into pal, 8 white), -1 off it
int splinter_px(vec2 d, vec4 r3) {
	if (d.x < -7.0 || d.x > 6.0 || d.y < -7.0 || d.y > 6.0) {
		return -1;
	}
	float dx = d.x + 0.5;
	float dy = d.y + 0.5;
	float ca = r3.y;
	float sa = r3.z;
	float u = dx * ca + dy * sa;
	float v = -dx * sa + dy * ca;
	if (abs(u) / r3.x + abs(v) / (u > 0.0 ? 1.7 : 1.1) > 1.0) {
		return -1;
	}
	float lit = -(ca * 0.6 + sa * 0.8) * (v == 0.0 ? 1.0 : sign(v));
	if (r3.w > 0.5) {
		return v < 0.0 ? 4 : 3;
	}
	if (abs(v) < 0.5 && u < 0.0) {
		return 8;
	}
	return (v < 0.0) == (lit > 0.0) ? 6 : 4;
}

// _lib.js coin(): a coin of radius r tumbling (its face turned by the spin about an axis at a screen angle), lit
// from the top left, a rim showing as it goes edge-on; its centre at r3.xy within cell (0, 0). An index into pal (C
// first, 8 white), -1 off it.
int coin_px(vec2 d, float r, vec4 r3, bool wh) {
	float R = ceil(r) + 2.0;
	if (abs(d.x) > R + 0.5 || abs(d.y) > R + 0.5) {
		return -1;
	}
	float cs = cos(r3.z);
	float sn = sin(r3.z);
	float b = max(0.5, r * abs(cs));
	float th = 1.2 * sn * (cs == 0.0 ? 1.0 : sign(cs));
	float ca = cos(r3.w);
	float sa = sin(r3.w);
	float face = abs(cs);
	float dx = d.x + 0.5 - r3.x;
	float dy = d.y + 0.5 - r3.y;
	float u = dx * ca + dy * sa;
	float w = -dx * sa + dy * ca;
	float ef = length(vec2(u / r, w / b));
	float er = length(vec2(u / r, (w - th) / b));
	if (wh && (ef <= 1.0 || er <= 1.0)) {
		return 8;
	}
	if (ef <= 1.0) {
		float lit = -(dx * 0.62 + dy * 0.78) / max(1.0, length(vec2(dx, dy)));
		int dim = face < 0.45 ? 1 : 0;
		if (b < 1.1) {
			return lit > 0.0 ? 6 : 4;
		}
		if (ef > 0.72) {
			return (lit > 0.3 ? 6 : lit > -0.35 ? 5 : 3) - dim;
		}
		if (b > 2.2 && ef > 0.42) {
			return (lit > 0.2 ? 4 : 5) - dim;
		}
		if (face > 0.6 && lit > 0.5) {
			return 7;
		}
		return 5 - dim;
	}
	if (er <= 1.0) {
		return abs(w - th) < abs(w) ? 2 : 3;
	}
	return -1;
}

// _lib.js gemlet(): a small cut gem of radius r turned to ang, its facets lit from the top left; G is pal[9..14]
int gemlet_px(vec2 d, float r, float ang, bool wh) {
	float R = ceil(r * 1.4) + 2.0;
	if (d.x < -R || d.x > R - 1.0 || d.y < -R || d.y > R - 1.0) {
		return -1;
	}
	float ca = cos(ang);
	float sa = sin(ang);
	float ct = r * 0.75;
	float tw = r * 0.5;
	float pv = r * 1.3;
	float dx = d.x + 0.5;
	float dy = d.y + 0.5;
	float u = dx * ca + dy * sa;
	float w = -dx * sa + dy * ca;
	int facet;
	if (w < 0.0) {
		if (w < -ct || abs(u) > r - ((-w) / ct) * (r - tw)) {
			return -1;
		}
		facet = (w < -ct * 0.45 && abs(u) < tw * 0.95) ? 0 : u < 0.0 ? 1 : 2;
	} else {
		if (w > pv || abs(u) > r * (1.0 - w / pv)) {
			return -1;
		}
		facet = abs(u) < 0.5 ? 4 : u < 0.0 ? 3 : 5;
	}
	if (wh) {
		return 8;
	}
	vec2 N = facet == 0 ? vec2(0.0, -1.0) : facet == 1 ? vec2(-0.7, -0.7) : facet == 2 ? vec2(0.7, -0.7) : facet == 3 ? vec2(-0.6, 0.8) : facet == 4 ? vec2(0.0, 1.0) : vec2(0.6, 0.8);
	float nx = N.x * ca - N.y * sa;
	float ny = N.x * sa + N.y * ca;
	float l = -(nx * 0.62 + ny * 0.78);
	if (facet == 0 && l > 0.3 && u < 0.0) {
		return 8;
	}
	return l > 0.6 ? 14 : l > 0.2 ? 13 : l > -0.2 ? 12 : l > -0.6 ? 11 : 10;
}

void fragment() {
	vec2 d = floor((UV - 0.5) * quad + 0.5);
	vec4 r0 = row(0);
	vec4 r1 = row(1);
	int kd = int(kind + 0.5);
	vec3 c1 = pal[int(r1.x + 0.5)].rgb;
	vec3 c2 = pal[int(r1.y + 0.5)].rgb;
	float a = r0.w;
	vec4 c = vec4(0.0);
	vec2 ad = abs(d);
	if (kd == 0) {
		if (ad.x < 0.5 && ad.y < 0.5) {
			c = vec4(c1, a);
		}
	} else if (kd == 1) {
		float n = r0.z;
		if (ad.x < 0.5 && ad.y < 0.5) {
			c = vec4(n > 0.5 ? vec3(1.0) : c1, a);
		} else if ((ad.x < 0.5 || ad.y < 0.5) && max(ad.x, ad.y) <= n + 0.1) {
			float m = max(ad.x, ad.y);
			c = vec4(abs(m - n) < 0.1 && n > 1.5 ? js_scale(c1, 0.8) : c1, a);
		}
	} else if (kd == 2) {
		vec4 r3 = row(3);
		int i = line_step(d, r3.xy);
		if (i >= 0) {
			// r3.w: 1 the second colour from u >= split (else from u > split); 2 alpha fades over its second half
			// (power-star's ray lines: 1 then 1.6 - 1.4 u)
			int mode = int(r3.w + 0.5);
			float n = max(abs(r3.x), abs(r3.y));
			float u = float(i) / max(1.0, n);
			bool second = (mode % 2 == 1) ? u >= r3.z : u > r3.z;
			float au = (mode == 2 || mode == 3) ? (u < 0.5 ? 1.0 : 1.6 - u * 1.4) : 1.0;
			vec3 lc = second ? c2 : c1;
			if (mode == 4) {
				// chest-open's crack of light under the lid: white in its middle, fading to its ends
				lc = abs(u - 0.5) < 0.2 ? c2 : c1;
				au = 1.0 - abs(u - 0.5) * 0.9;
			} else if (mode == 8) {
				// chest-open's rays out of the crack: white, C6, C5 along it, fading
				lc = u < 0.25 ? vec3(1.0) : u < 0.6 ? pal[6].rgb : pal[5].rgb;
				au = 1.15 - u;
			}
			c = vec4(lc, a * au);
		}
	} else if (kd == 3) {
		// _MINI: ".a.a.", "abbba", ".aba.", "..a.." from its top-left cell
		ivec2 q = ivec2(d);
		int ch = 0;
		if (q.y == 0) {
			ch = (q.x == 1 || q.x == 3) ? 1 : 0;
		} else if (q.y == 1) {
			ch = (q.x == 0 || q.x == 4) ? 1 : (q.x >= 1 && q.x <= 3) ? 2 : 0;
		} else if (q.y == 2) {
			ch = (q.x == 1 || q.x == 3) ? 1 : q.x == 2 ? 2 : 0;
		} else if (q.y == 3) {
			ch = q.x == 2 ? 1 : 0;
		}
		if (ch == 1) {
			c = vec4(c1, a);
		} else if (ch == 2) {
			c = vec4(c2, a);
		}
	}
	if (kd == 5) {
		// crystal-shard's splinter (a little two-tone sliver in its own Layer, outlined): row 3 = len, cos, sin of its
		// turn, far (1: the far half, dimmer); the cell is its rounded centre
		vec4 r3 = row(3);
		int k = splinter_px(d, r3);
		if (k >= 0) {
			c = vec4(k == 8 ? vec3(1.0) : pal[k].rgb, 1.0);
		} else if (splinter_px(d + vec2(1.0, 0.0), r3) >= 0 || splinter_px(d - vec2(1.0, 0.0), r3) >= 0 || splinter_px(d + vec2(0.0, 1.0), r3) >= 0 || splinter_px(d - vec2(0.0, 1.0), r3) >= 0) {
			c = vec4(pal[r3.w > 0.5 ? 1 : 0].rgb, 1.0);
		}
	}
	if (kd == 6 || kd == 7) {
		// row 0 .z: radius, .w: 2 when it flashes white; row 3: the centre's offset in its cell, the turn, the axis
		vec4 r3 = row(3);
		bool wh = a > 1.5;
		int k = kd == 6 ? coin_px(d, r0.z, r3, wh) : gemlet_px(d, r0.z, r3.z, wh);
		if (k >= 0) {
			c = vec4(pal[k].rgb, 1.0);
		} else {
			bool edge = kd == 6
				? (coin_px(d + vec2(1.0, 0.0), r0.z, r3, wh) >= 0 || coin_px(d - vec2(1.0, 0.0), r0.z, r3, wh) >= 0 || coin_px(d + vec2(0.0, 1.0), r0.z, r3, wh) >= 0 || coin_px(d - vec2(0.0, 1.0), r0.z, r3, wh) >= 0)
				: (gemlet_px(d + vec2(1.0, 0.0), r0.z, r3.z, wh) >= 0 || gemlet_px(d - vec2(1.0, 0.0), r0.z, r3.z, wh) >= 0 || gemlet_px(d + vec2(0.0, 1.0), r0.z, r3.z, wh) >= 0 || gemlet_px(d - vec2(0.0, 1.0), r0.z, r3.z, wh) >= 0);
			if (edge) {
				c = vec4(pal[kd == 6 ? 1 : 9].rgb, 1.0);
			}
		}
	} else if (kd == 8) {
		// sim.js sparkle(): arms of n px (the outer 40% in the tip colour), diagonals from 3, longer from 6, white heart
		float n = r0.z;
		vec3 tip = js_scale(c1, 0.75);
		if (ad.x < 0.5 && ad.y < 0.5) {
			c = vec4(1.0);
		} else if ((ad.x < 0.5 || ad.y < 0.5) && max(ad.x, ad.y) <= n + 0.1) {
			c = vec4(max(ad.x, ad.y) > n * 0.6 ? tip : c1, 1.0);
		} else if (n >= 3.0 && abs(ad.x - 1.0) < 0.1 && abs(ad.y - 1.0) < 0.1) {
			c = vec4(c1, 1.0);
		} else if (n >= 6.0 && abs(ad.x - 2.0) < 0.1 && abs(ad.y - 2.0) < 0.1) {
			c = vec4(tip, 1.0);
		}
	} else if (kd == 9 || kd == 10) {
		// a disc (painter.js disc, translucent) or a 1 px ring (painter.js ring) round an exact centre
		vec4 r3 = row(3);
		vec2 q = d + 0.5 - r3.xy;
		float d2 = dot(q, q);
		float r = r0.z;
		if (kd == 9) {
			if (r < 0.5 ? (ad.x < 0.5 && ad.y < 0.5) : d2 <= r * r) {
				c = vec4(c1, a);
			}
		} else {
			float r0_ = max(0.0, r - 1.0);
			if (d2 <= r * r && d2 >= r0_ * r0_) {
				c = vec4(c1, a);
			}
		}
	}
	if (c.a <= 0.0) {
		discard;
	}
	c.a *= COLOR.a;
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
