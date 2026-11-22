// A cut gem or crystal (_lib.js drawGem in a Layer: fx/pickups/_gem.gdshaderinc): its facets uploaded once, its place
// and turn keyed every frame. Colour layer, over the whole canvas.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/pickups/_pk.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/scifi/_jsrand.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform vec4 C[8] : source_color;

#include "res://addons/pixelfx_particles/fx/pickups/_gem.gdshaderinc"

void fragment() {
	vec2 pc = floor(center + (UV - 0.5) * size) + 0.5;
	vec2 rel = floor(pc) - vec2(gx, gy);
	if (rel.x < -box.x - 1.0 || rel.x > box.x + 1.0 || rel.y < -box.y - 1.0 || rel.y > box.z + 1.0) {
		discard;
	}
	vec4 c = gem_px(pc);
	if (c.a <= 0.0 || pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
