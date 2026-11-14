// The drum's lid flying off (explosions/barrel-explosion): a disc seen edge-on as it turns, an ellipse rx x ry at
// `pos` (px from the origin) with an outline, a lit upper rim and a darker lower rim; `alpha` fades it. Colour layer.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(32.0);
uniform vec2 center = vec2(0.0);
uniform vec2 pos = vec2(0.0);
uniform vec2 radii = vec2(7.5, 1.6);
uniform vec4 face : source_color;
uniform vec4 rim_lit : source_color;
uniform vec4 rim_dark : source_color;
uniform vec4 outline : source_color;
uniform float alpha = 1.0;

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5 + center;
	vec2 d = p - pos;
	vec2 qo = d / (radii + 0.8);
	vec2 q = d / radii;
	vec4 c;
	if (abs(d.x) <= radii.x && abs(d.y) <= radii.y && dot(q, q) <= 1.0) {
		c = length(q) > 0.65 ? (q.y < 0.0 ? rim_lit : rim_dark) : face;
	} else if (abs(d.x) <= radii.x + 0.8 && abs(d.y) <= radii.y + 0.8 && dot(qo, qo) <= 1.0) {
		c = outline;
	} else {
		discard;
	}
	c.a = alpha;
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
