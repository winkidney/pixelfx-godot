// The whirlpool seen from above (water/whirlpool), shared by _whirlpool.gdshader (the water and its foam) and
// _whirlpool_light.gdshader (the light on the foam): thin streaks of foam laid along a log spiral that turns once a
// loop, dashed and brightest where two sets cross, drawn down into a deep eye with a lit far wall and a racing foam
// lip. Key `t` 0 -> 1 over the loop.
uniform vec2 size = vec2(120.0, 72.0);
uniform float t = 0.0;
uniform float R = 60.0;
uniform float sy = 0.6;
uniform float K = 2.4;
uniform float eye = 0.16;

const float W_TAU = 6.28318530718;

float foam(float rho, float th, float ph) {
	float s = log(max(rho, 0.02));
	float a = th + K * s + ph * W_TAU;
	float b = th + K * 1.35 * s + ph * W_TAU * 2.0;
	float one = pow(0.5 + 0.5 * cos(7.0 * a + 0.9 * sin(3.0 * a + s * 4.0)), 26.0);
	float two = pow(0.5 + 0.5 * cos(11.0 * b + 1.3), 34.0) * 0.7;
	float three = pow(0.5 + 0.5 * cos(17.0 * (th + K * 0.8 * s + ph * W_TAU * 3.0)), 30.0) * 0.8 * max(0.0, 1.0 - (rho - eye) * 2.2);
	float dash = 0.55 + 0.45 * sin(s * 22.0 - ph * W_TAU * 4.0 + a * 2.0);
	return (one + two + three) * dash;
}

// what the field draws at p (px from the middle): mode 0 the see-through water (colour, alpha), 1 the foam and the
// eye (opaque colour or nothing), 2 the light (colour * amount)
vec4 whirl(vec2 p, int mode) {
	float ry = R * sy;
	float dx = p.x / R;
	float dy = p.y / ry;
	float rho = length(vec2(dx, dy));
	if (rho > 1.0) {
		return vec4(0.0);
	}
	float th = atan(dy, dx);
	if (rho < eye) {
		if (mode != 1) {
			return vec4(0.0);
		}
		float far = -dy / max(rho, 1e-4);
		float wall = (rho / eye - 0.35) / 0.65;
		if (far > 0.0) {
			return wall > 0.8 ? (far > 0.6 ? pal[5] : pal[4]) : wall > 0.45 ? pal[3] : wall > 0.15 ? pal[2] : pal[0];
		}
		return (wall > 0.85 && far > -0.5) ? pal[2] : pal[0];
	}
	float k = (rho - eye) / (1.0 - eye);
	float fade = 1.0 - smoothstep(0.62, 1.0, k);
	if (mode == 0) {
		// dark see-through water, darker toward the eye, a faint sheen mid-way
		vec3 c1 = (k < 0.25 ? pal[0] : pal[1]).rgb;
		float a1 = (0.75 - 0.25 * k) * (1.0 - smoothstep(0.8, 1.0, k));
		float a2 = (k > 0.3 && k < 0.8) ? 0.18 * sin(3.14159265 * (k - 0.3) / 0.5) : 0.0;
		float A = a1 + a2 * (1.0 - a1);
		if (A <= 0.0) {
			return vec4(0.0);
		}
		return vec4((c1 * a1 * (1.0 - a2) + pal[2].rgb * a2) / A, A);
	}
	float ph = t;
	if (k < 0.035) {
		if (mode != 1) {
			return vec4(0.0);
		}
		float g = 0.5 + 0.5 * cos(th * 9.0 - ph * W_TAU * 6.0);
		return g > 0.7 ? pal[7] : g > 0.3 ? pal[6] : pal[4];
	}
	float I = foam(rho, th, ph) * fade * min(1.0, (k - 0.08) * 4.0) * (0.45 + 0.55 * sin(3.14159265 * min(1.0, k * 1.25)));
	if (mode == 2) {
		return I > 0.25 ? vec4(pal[5].rgb * (0.08 + 0.14 * min(1.0, I)), 1.0) : vec4(0.0);
	}
	if (I > 0.12) {
		return I > 0.75 ? pal[7] : I > 0.45 ? pal[6] : I > 0.25 ? pal[5] : pal[4];
	}
	return vec4(0.0);
}
