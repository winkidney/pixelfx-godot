// A cherry petal as the original shades it (cherry-blossoms.js petal()): a little notched teardrop squashed across
// as it flips, its pale face or deeper back, palest at the tip; a white glint above it as it flashes. A blossom:
// five petals round a gold heart. Placed by _cherry.gdshader (see there for the data).
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/weather/_wx_draw.gdshaderinc"

uniform vec4 C[6] : source_color;
uniform vec4 white : source_color = vec4(1.0);
uniform vec4 heart : source_color = vec4(1.0, 0.88, 0.54, 1.0);

// the petal at (x, y) (from the particle's cell corner) over pixel centre q: its colour, alpha 0 where it isn't
vec4 petal(vec2 q, vec2 xy, float len, float ang, float flip) {
	float fs = 0.3 + 0.7 * abs(flip);
	bool back = flip < -0.2;
	float c = cos(ang);
	float s = sin(ang);
	vec2 dd = q - xy;
	float u = (dd.x * c + dd.y * s) / len;
	float v = (-dd.x * s + dd.y * c) / (len * fs);
	if (u < -1.0 || u > 1.0) {
		return vec4(0.0);
	}
	float hw = 0.55 * sqrt(1.0 - u * u) * (1.0 + 0.35 * u);
	if (abs(v) > hw || (u > 0.7 && abs(v) < 0.12)) {
		return vec4(0.0);
	}
	if (u > 0.45 && v < 0.1) {
		return back ? C[3] : C[5];
	}
	if (u < -0.45) {
		return back ? C[1] : C[2];
	}
	return v < 0.0 ? (back ? C[3] : C[4]) : (back ? C[2] : C[3]);
}

void fragment() {
	vec2 d = wx_cell(UV);
	vec2 q = d + 0.5;
	vec4 c = vec4(0.0);
	if (pc.z > 0.5) {
		float r = cu.z;
		if (d == vec2(0.0)) {
			c = heart;
		} else {
			for (int k = 4; k >= 0; k--) {
				float an = cu.w + float(k) * TAU / 5.0;
				c = petal(q, cu.xy + vec2(cos(an), sin(an)) * r * 0.75, r * 0.7, an, 1.0);
				if (c.a > 0.0) {
					break;
				}
			}
		}
	} else {
		if (pc.y > 0.5 && d == floor(cu.xy - vec2(0.0, 1.0))) {
			c = white;
		} else {
			c = petal(q, cu.xy, cu.z, cu.w, pc.x);
		}
	}
	if (c.a <= 0.0 || pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
