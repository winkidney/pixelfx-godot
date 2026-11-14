// nature/spore-burst: the toadstool (the original's toadstool()), drawn the way the original draws it at its current
// growth g, squash (sx, sy), gill glow and sink: a stem with a frilled ring, glowing gills, a domed cap lit from the
// upper left with pale spots, a curled dark lip. The build keys g, sx, sy, glow and sink every frame. Colour layer.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform float g = 0.0;
uniform float sx = 1.0;
uniform float sy = 1.0;
uniform float glow = 0.0;
uniform float sink = 0.0;
uniform sampler2D ramp : filter_nearest, repeat_disable;
uniform sampler2D cap : filter_nearest, repeat_disable;
uniform sampler2D stem : filter_nearest, repeat_disable;

vec3 K(float i) {
	return texture(ramp, vec2((i + 0.5) / 8.0, 0.5)).rgb;
}

vec3 Cs(float i) {
	return texture(cap, vec2((i + 0.5) / 6.0, 0.5)).rgb;
}

vec3 Sm(float i) {
	return texture(stem, vec2((i + 0.5) / 5.0, 0.5)).rgb;
}

const vec3 SPOTS[6] = vec3[](vec3(-0.45, 0.45, 1.4), vec3(0.1, 0.72, 1.8), vec3(0.55, 0.38, 1.2), vec3(-0.12, 0.25, 1.0),
	vec3(0.3, 0.12, 0.9), vec3(-0.7, 0.16, 0.8));

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5 + center;
	float X = floor(p.x);
	float Y = floor(p.y);
	if (g < 0.05) {
		discard;
	}
	float H = 17.0 * g;
	float cw = 17.0 * sx * g;
	float ch = 13.0 * sy * g;
	float top = sink - H;
	vec3 col = vec3(-1.0);
	// stem
	if (Y >= floor(top) && Y <= min(0.0, sink) && X >= -4.0 && X <= 4.0) {
		float w = 3.0 + (Y - top) / H;
		if (abs(X + 0.5) <= w) {
			float q = (X + 0.5 + w) / (2.0 * w);
			col = abs(X + 0.5) > w - 0.8 ? Sm(1.0) : q < 0.4 ? Sm(4.0) : q < 0.7 ? Sm(3.0) : Sm(2.0);
		}
	}
	// its frilled ring
	float ring = top + H * 0.3;
	if (ring <= 0.0 && X >= -5.0 && X <= 5.0 && Y == floor(ring) + (abs(X) > 3.0 ? 1.0 : 0.0)) {
		col = abs(X) > 4.0 ? Sm(1.0) : Sm(3.0);
	}
	// gills: a glowing underside
	float gy = top + 1.0;
	if (gy <= 0.0 && Y == floor(gy) && X >= floor(-cw) && X <= ceil(cw)) {
		float d = abs(X + 0.5) / cw;
		if (d <= 0.95) {
			bool odd = mod(X, 2.0) == 1.0;
			col = d < 0.3 ? Cs(0.0) : odd ? Sm(2.0) : Sm(3.0);
			if (glow > 0.05) {
				col = glow > 0.6 && odd ? K(7.0) : K(5.0);
			}
		}
	}
	// the cap: a dome with a curled lip
	if (p.x >= -cw - 1.0 && p.x <= cw + 1.0 && p.y >= top - ch - 1.0 && p.y <= top + 1.0) {
		float dx = p.x / cw;
		float dy = (top - p.y) / ch;
		float d = dx * dx + dy * dy;
		if (!(dy < -0.12 || d > 1.12 || p.y > 0.0)) {
			if (d > 1.0) {
				col = Cs(0.0);
			} else {
				float i = dx < -0.35 && dy > 0.45 ? 5.0 : dx < 0.05 && dy > 0.3 ? 4.0 : dy < 0.18 ? 2.0 : dx > 0.55 ? 2.0 : 3.0;
				for (int s = 0; s < 6; s++) {
					float ex = (dx - SPOTS[s].x) * cw;
					float ey = (dy - SPOTS[s].y) * ch;
					if (ex * ex + ey * ey * 1.6 < SPOTS[s].z * SPOTS[s].z * g * g) {
						i = ex < 0.0 && ey > 0.0 ? 9.0 : 8.0;
					}
				}
				col = i == 9.0 ? Sm(4.0) : i == 8.0 ? Sm(3.0) : Cs(i);
			}
		}
	}
	if (X == floor(-cw * 0.45) && Y == floor(top - ch * 0.8)) {
		col = Cs(5.0);
	}
	if (col.r < 0.0) {
		discard;
	}
	vec4 c = vec4(col, 1.0);
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
