// The divine shield's bubble (holy/divine-shield, soft layer: real translucency): a thin gold film thickening to
// the rim with a sheen sweeping across, a lattice of meridians turning like a slow globe plus the equator (found by
// casting each pixel back onto the sphere), and, on the front half, the bright rim, the bubble's shine, the lit
// crossings on the equator and the seal where it meets the floor. `back` draws the far half (behind the character).
// `t` runs 0..1 over the loop. The rect is centred on the bubble's centre.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(72.0);
uniform float t = 0.0;
uniform float r = 30.0;
uniform float cy = -22.0;
uniform bool back = false;
uniform vec4 pal[8] : source_color;

const float TILT = 0.34;
const float N = 4.0;
const float FLOOR_SY = 0.26;

void over(inout vec4 c, vec4 s) {
	float oa = s.a + c.a * (1.0 - s.a);
	if (oa > 0.0) {
		c = vec4((s.rgb * s.a + c.rgb * c.a * (1.0 - s.a)) / oa, oa);
	}
}

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5;   // from the bubble's centre
	float d = length(p) / r;
	float sw = -1.7 + 3.4 * clamp(fract(t) / 0.55, 0.0, 1.0);
	float q = (p.x - p.y) / (r * 1.414);
	float phi = t * PI / N;
	vec4 c = vec4(0.0);
	if (d < 1.0) {
		// the film
		float hot = max(0.0, 1.0 - abs(q - sw) / 0.22);
		float a = (back ? 0.07 : 0.03) + 0.26 * pow(d, 6.0) + 0.2 * hot * (back ? 0.3 : 1.0);
		c = vec4((hot > 0.5 && !back ? pal[6] : pal[5]).rgb, a);
		// the lattice: this pixel's point on the near (or far) half of the sphere
		float z = sqrt(max(0.0, r * r - dot(p, p))) * (back ? -1.0 : 1.0);
		float yy = -p.y;
		float Y = yy * cos(TILT) + z * sin(TILT);
		float Z = -yy * sin(TILT) + z * cos(TILT);
		float lat = asin(clamp(Y / r, -1.0, 1.0));
		float lon = atan(p.x, Z);
		float m = mod(lon - phi, PI / N);
		m = min(m, PI / N - m) * r * cos(lat);
		bool on = m < 0.55 || abs(lat) * r < 0.55;
		if (on) {
			float f = abs(z) / r;
			if (back) {
				over(c, vec4(pal[4].rgb, 0.32));
			} else if (abs(q - sw) < 0.12) {
				c = vec4(1.0);
			} else if (f < 0.4) {
				c = pal[6];
			} else {
				over(c, vec4((f < 0.7 ? pal[6] : pal[5]).rgb, f < 0.7 ? 0.8 : 0.55));
			}
		}
		if (!back) {
			// the crossings on the equator catch the light
			for (int k = 0; k < 8; k++) {
				float lo = phi + float(k) * PI / N;
				vec3 s = vec3(r * sin(lo), -(-r * cos(lo) * sin(TILT)), r * cos(lo) * cos(TILT));
				if (s.z < r * 0.15) {
					continue;
				}
				vec2 e = floor(p) - floor(s.xy);
				if (e == vec2(0.0)) {
					c = vec4(1.0);
				} else if (s.z > r * 0.45 && abs(e.x) + abs(e.y) == 1.0) {
					over(c, vec4(pal[6].rgb, 0.7));
				}
			}
			// the bubble's shine: a bright curl up on the left, a dot under it, a faint one low on the right
			float g = atan(p.y, p.x);
			g = g < 0.0 ? g + TAU : g;
			float dd = length(p);
			if (abs(dd - r * 0.74) < 0.5 && g > 3.55 && g < 4.2) {
				c = (g > 3.7 && g < 4.05) ? vec4(1.0) : pal[6];
			}
			if (floor(p) == floor(vec2(cos(3.4), sin(3.4)) * r * 0.62)) {
				c = vec4(1.0);
			}
			if (abs(dd - r * 0.8) < 0.5 && g > 0.45 && g < 0.8) {
				over(c, vec4(pal[5].rgb, 0.6));
			}
		}
	}
	if (!back) {
		// the rim: bright where the light sits (top left) and where the sheen crosses it
		float dd = length(p);
		float lit = cos(atan(p.y, p.x) + 2.36);
		if (abs(dd - (r - 1.0)) < 0.5) {
			over(c, vec4(pal[4].rgb, 0.35 + 0.3 * lit));
		}
		if (abs(dd - r) < 0.5) {
			c = (abs(q - sw) < 0.15 || lit > 0.75) ? vec4(1.0) : lit > -0.2 ? pal[6] : pal[5];
		}
	}
	// the seal where it meets the floor: the far half behind, the near half in front
	float rf = sqrt(r * r - cy * cy);
	vec2 fp = vec2(p.x, p.y + cy);
	float e = length(vec2(fp.x, fp.y / FLOOR_SY));
	if (e > 0.0 && abs(e - rf) / (length(vec2(fp.x, fp.y / (FLOOR_SY * FLOOR_SY))) / e) < 0.5) {
		float sg = fp.y / (rf * FLOOR_SY);
		if (back && fp.y < 0.0) {
			over(c, vec4(pal[5].rgb, 0.8));
		} else if (!back && fp.y >= 0.0) {
			c = sg > 0.6 ? vec4(1.0) : pal[6];
		}
	}
	if (c.a <= 0.0 || pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
