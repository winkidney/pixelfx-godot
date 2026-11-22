// Shared by the scifi effects' colour-layer shaders: _scifi_light.gdshaderinc (easings, lines, glow falloff) and a
// pixel's output on the colour layer either opaque (dithered by its alpha, as the original's dot()) or translucent
// (the original's blend(), in 32 steps). Include after pixel.gdshaderinc.

#include "res://addons/pixelfx_particles/fx/scifi/_scifi_light.gdshaderinc"

// one colour over another at alpha a, keeping the result's own alpha (painter.js blendPx)
vec4 blend_over(vec4 dst, vec3 c, float a) {
	if (a <= 0.004) {
		return dst;
	}
	float oa = a + dst.a * (1.0 - a);
	float k = a / oa;
	return vec4(c * k + dst.rgb * (1.0 - k), oa);
}

// the colour layer's output for a pixel: `soft` keeps its alpha (32 steps, dithered between them), otherwise its
// alpha is on / off through the Bayer matrix. True when the pixel should be dropped.
bool px_out(inout vec4 c, vec2 fragcoord, bool soft) {
	float a = c.a * alpha_scale;
	if (soft) {
		a = floor(a * 32.0 + pfx_threshold(fragcoord)) / 32.0;
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
