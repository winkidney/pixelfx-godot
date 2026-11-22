// src/core/sim.js sparkle(): a cross of rays round a white heart (diagonals from arm 3, longer ones from 6), the
// outer 40% in `tip`. sparkle_px: the colour it puts on cell q (alpha 0: none).
vec4 sparkle_px(vec2 q, vec2 xy, float arm, vec4 c, vec4 tip, vec4 white) {
	float n = floor(arm + 0.5);
	if (n < 1.0) {
		return vec4(0.0);
	}
	vec2 e = q - floor(xy);
	vec2 ae = abs(e);
	if (e == vec2(0.0)) {
		return white;
	}
	if (n >= 6.0 && ae == vec2(2.0)) {
		return tip;
	}
	if (n >= 3.0 && ae == vec2(1.0)) {
		return c;
	}
	if ((ae.x == 0.0 || ae.y == 0.0) && max(ae.x, ae.y) <= n) {
		return max(ae.x, ae.y) > n * 0.6 ? tip : c;
	}
	return vec4(0.0);
}
