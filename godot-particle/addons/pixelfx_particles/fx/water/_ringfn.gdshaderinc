// The ripple ring (the original's water ring()) as a function, for shaders that draw several: true when pixel p (px
// from the ring's middle) is on a crest; its colour, how lit it is, which crest. See _ring.gdshader for the arguments.
bool ring_hit(vec2 p, float r, float sy, float k, float n, float gap, float side, bool hot, float glint, float seed, float wob,
		out vec4 c, out float lit, out int crest) {
	c = vec4(0.0);
	lit = 0.0;
	crest = -1;
	if (k <= 0.02 || r < 0.5) {
		return false;
	}
	float a = atan(p.y / sy, p.x);
	bool near = p.y > 0.0;
	if ((side > 0.5 && !near) || (side < -0.5 && near)) {
		return false;
	}
	float e = max(length(vec2(p.x, p.y / sy)), 1e-3);
	// how far the pixel's square is from the crest, in px (L1 norm of the gradient: the crest passes through it)
	float g = (abs(p.x) + abs(p.y) / (sy * sy)) / e;
	vec2 gp = floor(vec2(cos(2.05) * r, sin(2.05) * r * sy)) + 0.5;
	if (glint > 0.0 && side > -0.5 && distance(p, gp) < 0.1) {
		c = pal[7];
		lit = glint;
		return true;
	}
	for (int j = 0; j < 4; j++) {
		float fj = float(j);
		if (fj >= n) {
			break;
		}
		float rr = r - fj * gap;
		if (rr < 0.6) {
			break;
		}
		float kj = k * (1.0 - fj * 0.42);
		float need = 1.15 - 2.3 * min(1.0, kj * 1.25);
		float ra = wob > 0.0 ? rr + wob * w_noise(a * 2.6 + seed * 1.9 + fj, seed + 11.0) : rr;
		if (abs(e - ra) / g > 0.5) {
			continue;
		}
		if (w_noise(a * 4.7 + seed * 13.1 + fj * 5.3, seed) * 0.65 + w_noise(a * 11.3 + seed * 7.7, seed + 3.0) * 0.35 < need) {
			continue;
		}
		lit = kj * (near ? 1.0 : 0.7) * (0.88 - 0.12 * cos(a));
		c = (hot && near && j == 0) ? pal[7] : pal[lit > 0.7 ? 6 : lit > 0.38 ? 5 : 4];
		crest = j;
		return true;
	}
	return false;
}
