// A blade of grass (fireflies.js grass()): a column of pixels bending with its sway, its tip catching a nearby
// fly's light; a few with a seed head. Placed by _fireflies.gdshader (layers 2, 3).
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/weather/_wx_draw.gdshaderinc"

uniform vec4 C[6] : source_color;
uniform vec4 G[6] : source_color;

void fragment() {
	vec2 d = wx_cell(UV);
	float x = cu.x;
	float base = cu.y;
	float h = cu.z;
	float sway = cu.w;
	int tone = int(pc.x + 0.5);
	float tip = pc.y;
	vec4 c = vec4(0.0);
	if (pc.z > 0.5) {
		vec2 s = vec2(x + sway, base - h);
		if (d == floor(s - vec2(0.0, 1.0))) c = tip > 0.2 ? C[3] : G[5];
		else if (d == floor(s - vec2(1.0, 0.0)) || d == floor(s + vec2(1.0, 0.0))) c = G[4];
	}
	if (c.a <= 0.0) {
		float r = -d.y;
		if (r >= 0.0 && r < h) {
			float u = r / h;
			if (d.x == floor(x + sway * u * u)) {
				c = u > 0.8 && tip > 0.2 ? (tip > 0.55 && u > 0.9 ? C[3] : C[2]) : u > 0.7 ? G[min(5, tone + 1)] : G[tone];
			}
		}
	}
	if (c.a <= 0.0 || pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
