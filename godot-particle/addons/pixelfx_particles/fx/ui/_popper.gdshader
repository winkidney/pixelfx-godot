// confetti's party poppers (src/fx/ui/confetti.js popper()): striped cones standing on the floor, pointing along their
// angle, kicked back as each fires, fading at the end. kick (each popper's) and alpha keyed every frame. Colour layer.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform vec4 ink : source_color;
uniform vec4 stripe_lit : source_color;
uniform vec4 stripe_dark : source_color;
uniform vec4 paper_dark : source_color;
uniform vec4 pos[2];
uniform vec2 kick = vec2(0.0);
uniform float alpha = 1.0;

void fragment() {
	vec2 cell = floor(center + (UV - 0.5) * size);
	vec2 pc = cell + 0.5;
	float th = pfx_threshold(FRAGCOORD.xy);
	vec3 c = vec3(0.0);
	bool hit = false;
	for (int k = 1; k >= 0 && !hit; k--) {
		// pos: x, y, angle
		vec4 pp = pos[k];
		float ca = cos(pp.z);
		float sa = sin(pp.z);
		float kk = k == 0 ? kick.x : kick.y;
		vec2 b = pp.xy - vec2(ca, sa) * kk;
		if (cell.x < floor(b.x - 12.0) || cell.x > ceil(b.x + 12.0) || cell.y < floor(b.y - 12.0) || cell.y > ceil(b.y + 12.0)) {
			continue;
		}
		float dx = pc.x - b.x;
		float dy = pc.y - b.y;
		float u = dx * ca + dy * sa;
		float v = -dx * sa + dy * ca;
		if (u < 0.0 || u > 11.0) {
			continue;
		}
		float hw = 0.8 + u * 0.32;
		if (abs(v) > hw + 0.6) {
			continue;
		}
		if (!(alpha >= 1.0 || alpha > th)) {
			continue;
		}
		hit = true;
		if (abs(v) > hw - 0.4 || u > 10.2 || u < 0.8) {
			c = ink.rgb;
		} else {
			bool stripe = mod(floor((u + v * 0.6) / 2.2), 2.0) == 0.0;
			c = stripe ? (v < 0.0 ? stripe_lit.rgb : stripe_dark.rgb) : (v < 0.0 ? vec3(1.0) : paper_dark.rgb);
		}
	}
	if (!hit) {
		discard;
	}
	vec4 o = vec4(c, 1.0);
	if (pfx_pixel(o, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = o;
}
