// The stand-in as current runs through it: on a jolt its pixels flare to an electric silhouette, each one's own
// brightness (luma) stepped up the palette by `lift`, then fade back through its shading. Off a jolt it's itself.
// `flash` paints the whole silhouette `flash_color` (a caster lit white by its own discharge). A light at
// `light_at` (px from the feet) catches the silhouette's edge: C[4] within `light_r`, C[6] within `light_hot`.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform bool jolt = false;
uniform float lift = 0.0;
// the effect's palette from C[1] to C[7]
uniform vec4 ramp[7] : source_color;
uniform float flash = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0);
uniform vec2 light_at = vec2(0.0);
uniform float light_r = 0.0;
uniform float light_hot = 0.0;

varying vec2 local;

void vertex() {
	local = VERTEX;
}


void fragment() {
	// COLOR already holds the texture (Godot 4); sampling TEXTURE again would square the colours
	vec4 c = COLOR;
	if (c.a < 0.5) {
		discard;
	}
	if (flash > 0.5) {
		vec4 o = flash_color;
		if (pfx_pixel(o, FRAGCOORD.xy)) {
			discard;
		}
		COLOR = o;
	} else if (!jolt) {
		COLOR = vec4(c.rgb, 1.0);
		if (light_r > 0.0) {
			vec2 px = TEXTURE_PIXEL_SIZE;
			// an edge pixel: one of its four neighbours is empty (or off the texture; the sampler clamps, so check)
			vec2 r = UV + vec2(px.x, 0.0);
			vec2 l = UV - vec2(px.x, 0.0);
			vec2 d = UV + vec2(0.0, px.y);
			vec2 u = UV - vec2(0.0, px.y);
			bool edge = r.x > 1.0 || l.x < 0.0 || d.y > 1.0 || u.y < 0.0 || texture(TEXTURE, r).a < 0.5 || texture(TEXTURE, l).a < 0.5
				|| texture(TEXTURE, d).a < 0.5 || texture(TEXTURE, u).a < 0.5;
			float dist = distance(floor(local) + 0.5, light_at);
			if (edge && dist < light_r) {
				vec4 o = dist < light_hot ? ramp[5] : ramp[3];
				if (!pfx_pixel(o, FRAGCOORD.xy)) {
					COLOR = o;
				}
			}
		}
	} else {
		float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
		vec4 o = ramp[clamp(int(round(0.4 + l * 6.0 + lift)), 0, 6)];
		if (pfx_pixel(o, FRAGCOORD.xy)) {
			discard;
		}
		COLOR = o;
	}
}
