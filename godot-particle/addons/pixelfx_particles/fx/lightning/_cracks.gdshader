// The cracks a lightning strike splits in the floor (lightning-strike): `data` holds, per pixel, its distance out
// along the cracks (r * 64 px), its kind (g: 0 a main crack, 0.5 a side crack, 1 soot under it) and a grain (b).
// They open as `front` races out, white at the fresh tip, flash white with every flicker (`elec`), glow with
// `heat` cooling down the fire ramp to soot, and `fade` away.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform sampler2D data : filter_nearest;
uniform float front = 0.0;
uniform float reach = 52.0;
uniform float heat = 0.0;
uniform float elec = 0.0;
uniform float fade = 1.0;
uniform vec4 fire[9];
uniform vec4 soot : source_color;
uniform vec4 soot2 : source_color;
uniform vec4 c6 : source_color;

void fragment() {
	vec4 d = texelFetch(data, ivec2(floor(UV * size)), 0);
	if (d.a < 0.5 || fade <= 0.0) {
		discard;
	}
	float dist = d.r * 64.0;
	if (dist > front) {
		discard;
	}
	vec4 c;
	if (d.g > 0.75) {
		c = soot;
	} else {
		float q = dist / reach;
		float n = d.b;
		bool fresh = dist > front - 6.0 && front < reach;
		float T = heat * (1.15 - q) * (d.g > 0.25 ? 0.8 : 1.0) - n * 0.25;
		if (fresh || (elec > 0.3 && n < 0.85)) {
			c = q < 0.5 ? vec4(1.0) : c6;
		} else if (T > 0.06) {
			c = fire[clamp(int(floor((1.0 - min(1.0, T)) * 8.0)), 0, 8)];
		} else {
			c = soot2;
		}
	}
	c.a = fade;
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
