// A soft, lumpy ring of dust on the floor (src/fx/impacts/_lib.js dustRing()): radius, w thick (lumps swell it),
// translucent, lit on its upper side; squash flattens it; brk 0..1 tears it into clumps as it thins; ph varies it;
// side 1 only the far half (above the centre), -1 the near half. Key radius, w, alpha, brk.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform vec2 mid = vec2(0.0);
uniform float radius = 10.0;
uniform float w = 4.0;
uniform float alpha = 1.0;
uniform float squash = 0.2;
uniform float ph = 0.0;
uniform float brk = 0.0;
uniform float side = 0.0;
uniform vec4 color : source_color = vec4(1.0);
uniform vec4 lite : source_color = vec4(1.0);

void fragment() {
	vec4 tint = COLOR;
	vec2 p = floor(center + (UV - 0.5) * size) + 0.5 - mid;
	float dx = p.x;
	float dy = p.y / squash;
	if ((side > 0.5 && dy >= 0.0) || (side < -0.5 && dy < 0.0) || alpha <= 0.01 || radius <= 0.0) {
		discard;
	}
	float d = length(vec2(dx, dy));
	float g = atan(dy, dx);
	float lumpy = 0.6 + 0.3 * sin(5.0 * g + ph) + 0.18 * sin(11.0 * g + ph * 2.1) + 0.12 * sin(17.0 * g + ph * 0.7);
	float wt = w * lumpy;
	float off = abs(d - radius - w * 0.25 * sin(7.0 * g + ph));
	if (off >= wt) {
		discard;
	}
	float tear = brk > 0.0 ? clamp((0.55 + 0.45 * sin(6.0 * g + ph * 1.7) - brk) / 0.25, 0.0, 1.0) : 1.0;
	float a = alpha * (1.0 - pow(off / wt, 2.0)) * tear;
	if (a <= 0.01) {
		discard;
	}
	vec4 c = (dy < 0.0 && d > radius - wt * 0.3) ? lite : color;
	c.a = a;
	c *= tint;
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
