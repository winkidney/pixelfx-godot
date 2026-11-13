// Shared by every colour-layer shader: on/off alpha through a 4x4 Bayer matrix on the screen's pixel grid, and a
// snap to the effect's palette (PfxEffect sets `palette` and `palette_size` from its colour ramps).
uniform sampler2D palette : filter_nearest, repeat_disable;
uniform int palette_size = 0;
uniform float alpha_scale = 1.0;
// true: keep real translucency (smoke, dust, mist: the original blends those) in 8 steps instead of dithering it
uniform bool translucent = false;

const float PFX_BAYER[16] = float[](0., 8., 2., 10., 12., 4., 14., 6., 3., 11., 1., 9., 15., 7., 13., 5.);

float pfx_threshold(vec2 fragcoord) {
	ivec2 p = ivec2(fragcoord) % 4;
	return (PFX_BAYER[p.y * 4 + p.x] + 0.5) / 16.0;
}

vec3 pfx_snap(vec3 c) {
	if (palette_size <= 0) {
		return c;
	}
	float best = 1e9;
	vec3 pick = c;
	for (int i = 0; i < palette_size; i++) {
		vec3 q = texelFetch(palette, ivec2(i, 0), 0).rgb;
		vec3 d = q - c;
		float e = dot(d, d);
		if (e < best) {
			best = e;
			pick = q;
		}
	}
	return pick;
}

// true when the pixel should be dropped; otherwise c becomes opaque and snapped
bool pfx_pixel(inout vec4 c, vec2 fragcoord) {
	float a = c.a * alpha_scale;
	if (translucent) {
		a = floor(a * 8.0 + 0.5) / 8.0;
		if (a <= 0.0) {
			return true;
		}
		c = vec4(pfx_snap(c.rgb), a);
		return false;
	}
	if (a < pfx_threshold(fragcoord)) {
		return true;
	}
	c = vec4(pfx_snap(c.rgb), 1.0);
	return false;
}
