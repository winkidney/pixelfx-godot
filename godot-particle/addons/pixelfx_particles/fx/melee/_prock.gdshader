// A particle drawn as the original's rock() (melee/_lib.js; melee/_kinds.gdshader CHUNK), colour layer: a tumbling
// stone with a lit side, a shaded side and an outline. The particle's colour carries (angle / TAU, size / 4, fade);
// the quad is 2 (ceil(size) + 1) + 1 px across.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec4 light : source_color = vec4(1.0);
uniform vec4 body : source_color = vec4(1.0);
uniform vec4 shade : source_color = vec4(1.0);
uniform vec4 dark : source_color = vec4(1.0);
uniform vec4 outline : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
	float a = COLOR.r * 6.2831853;
	float s = COLOR.g * 4.0;
	float fade = COLOR.b;
	float w = 2.0 * (ceil(s - 0.01) + 1.0) + 1.0;
	vec2 d = floor(UV * w) - floor(w * 0.5);
	float r = 0.6 + s * 0.75;
	float dist = length(vec2(d.x * 1.15, d.y));
	if (dist > r + 0.9) {
		discard;
	}
	float lit = d.x * cos(a) * r * 0.4 + d.y * sin(a) * r * 0.4;
	vec4 c = dist > r ? outline : lit < -0.4 ? light : lit > 0.6 ? shade : body;
	c.a = fade;
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
