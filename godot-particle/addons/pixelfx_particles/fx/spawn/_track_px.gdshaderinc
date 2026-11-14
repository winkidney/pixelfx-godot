// Colour-layer helpers for the spawn effects' tracked particles (include after pixel.gdshaderinc and
// _track.gdshaderinc).

// on/off alpha through the Bayer matrix without the palette snap: for colours the original mixes from the stand-in's
// own (they aren't in any ramp, and snapping them would repaint the body)
bool tk_dither(inout vec4 c, vec2 fragcoord) {
	if (c.a * alpha_scale < pfx_threshold(fragcoord)) {
		return true;
	}
	c.a = 1.0;
	return false;
}

// color.js scale() and mix(): truncated to whole 0..255 steps, as the original's rgb()
vec3 tk_scale(vec3 c, float k) {
	return floor(min(vec3(255.0), floor(c * 255.0 + 0.5) * k)) / 255.0;
}

vec3 tk_mix(vec3 a, vec3 b, float t) {
	vec3 a8 = floor(a * 255.0 + 0.5);
	vec3 b8 = floor(b * 255.0 + 0.5);
	return floor(a8 + (b8 - a8) * clamp(t, 0.0, 1.0)) / 255.0;
}
