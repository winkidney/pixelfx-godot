// Under water, seen side on (water/bubbles), shared by _underwater.gdshader and _underwater_light.gdshader: a
// wavy surface at `top`, the water deeper toward the floor (y = 0), light shafts slanting down from the surface and
// drifting, caustics dancing where they reach the floor. `half` px either side, fading out at the ends. Key `t`
// 0 -> 1 over the loop. Coordinates are px from the effect's origin.
uniform vec2 size = vec2(96.0, 96.0);
uniform vec2 center = vec2(0.0);
uniform float t = 0.0;
uniform float top = -92.0;
uniform float half_w = 48.0;

const float U_TAU = 6.28318530718;

float surface_y(float x, float ph) {
	return top + sin(x * 0.13 + ph * U_TAU * 2.0) * 1.1 + sin(x * 0.051 - ph * U_TAU) * 1.3;
}

float shaft(float x, float y, float ph) {
	float u = x + (y - top) * 0.32;
	float s = sin(u * 0.16 + ph * U_TAU) * 0.6 + sin(u * 0.07 - ph * U_TAU + 1.0) * 0.4;
	return max(0.0, s - 0.35) / 0.65;
}

bool surface_glint(float x, float ph) {
	return sin(x * 0.37 - ph * U_TAU * 3.0) * sin(x * 0.13 + ph * U_TAU) > 0.55;
}
