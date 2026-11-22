// A particle that steps through a strip of frames over its life (the colour layer): frames side by side in its
// texture, frame = floor(INSTANCE_CUSTOM.z * frames) (the process material's anim_speed 1 runs it once over a life).
// Only the texture's own alpha counts (the particle's colour alpha is left to a light twin).
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform int frames = 1;
// 1: use the particle's colour alpha too (dithered)
uniform float use_alpha = 0.0;

void vertex() {
	float f = float(frames);
	VERTEX.x /= f;
	float fr = clamp(floor(INSTANCE_CUSTOM.z * f), 0.0, f - 1.0);
	UV.x = (UV.x + fr) / f;
}

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	vec4 c = vec4(t.rgb, t.a * mix(1.0, COLOR.a, use_alpha));
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
