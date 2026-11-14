// The void orb (after src/fx/shadow/void-orb.js), shared by its colour pass (_void-orb.gdshader) and light pass
// (_void-orb_light.gdshader): the vortex winding into the orb (three arms of dark dust, a veil, bright filaments
// streaming in), the lensing round it (the Einstein ring and specks behind it smeared into arcs) and the orb. `t` runs
// 0..1 over the 3.2 s loop; coordinates are px from the effect's origin. Needs _jsrand.gdshaderinc (the original's
// fbm, exactly).
uniform vec2 size = vec2(96.0);
uniform vec2 center = vec2(0.0, -62.0);
uniform float t = 0.0;

const float VO_Y = -62.0;
const float VO_R = 12.0;
const float VO_VR = 48.0;
const float VO_GAP = 21.0;
const float VO_E = 16.5;
const float VO_D = 3.2;

float vo_gulp() {
	float s = 0.0;
	float gs[2] = float[](0.2, 0.68);
	for (int i = 0; i < 2; i++) {
		float w = (fract(t - gs[i] + 0.5) - 0.5) * VO_D / 0.07;
		s += exp(-w * w);
	}
	return s;
}

float vo_rand3(int a, int b, int c) {
	return float(js_hash3(a, b, c)) / 4294967296.0;
}

float vo_noise2(float x, float y, int seed) {
	float ix = floor(x);
	float iy = floor(y);
	float fx = x - ix;
	float fy = y - iy;
	float ux = fx * fx * (3.0 - 2.0 * fx);
	float uy = fy * fy * (3.0 - 2.0 * fy);
	int i = int(ix);
	int j = int(iy);
	float a = vo_rand3(i, j, seed);
	float b = vo_rand3(i + 1, j, seed);
	float c = vo_rand3(i, j + 1, seed);
	float d = vo_rand3(i + 1, j + 1, seed);
	return mix(mix(a, b, ux), mix(c, d, ux), uy) * 2.0 - 1.0;
}

float vo_fbm(float x, float y, int seed) {
	float s = 0.0;
	float a = 0.5;
	float n = 0.0;
	for (int o = 0; o < 3; o++) {
		s += vo_noise2(x, y, seed + o * 101) * a;
		n += a;
		x *= 2.03;
		y *= 2.03;
		a *= 0.5;
	}
	return s / n;
}

float vo_smooth(float e0, float e1, float x) {
	float u = clamp((x - e0) / (e1 - e0), 0.0, 1.0);
	return u * u * (3.0 - 2.0 * u);
}

// the vortex at cell centre p: 0 nothing, 1 a filament (col 7, 6 or 5; light k), 2 the arm's lit edge (col),
// 3 the veil (col, alpha a)
int vo_vortex(vec2 p, float g, out int col, out float a, out float k) {
	vec2 q = p - vec2(0.0, VO_Y);
	float r = length(q);
	col = 0;
	a = 0.0;
	k = 0.0;
	if (abs(q.x) > VO_VR || abs(q.y) > VO_VR || r < VO_GAP || r > VO_VR) {
		return 0;
	}
	float th = atan(q.y, q.x);
	float ln = log(max(1.0, r));
	float nz = vo_fbm(cos(th) * 2.5 + ln * 2.4, sin(th) * 2.5 + ln * 2.4, 17);
	float env = vo_smooth(VO_VR, VO_VR * 0.42, r) * vo_smooth(VO_GAP, VO_GAP + 4.0, r);
	float ph = 3.0 * th + 7.0 * ln + TAU * 2.0 * t + nz * 2.6;
	float A = (0.5 + 0.5 * cos(ph)) * env * (1.0 + 0.4 * g);
	if (A < 0.16) {
		return 0;
	}
	float hot = 1.0 - vo_smooth(VO_GAP, VO_GAP + 16.0, r);
	float fil = cos(12.0 * th + 28.0 * ln + TAU * 12.0 * t + nz * 1.6);
	float dash = cos(9.0 * ln * 2.2 + 2.2 * th + TAU * 12.0 * 0.75 * t);
	if (fil > 0.86 && A > 0.3 && dash > -0.55) {
		col = hot > 0.6 ? 7 : ((hot > 0.25 || fil > 0.97) && dash > 0.0) ? 6 : 5;
		k = 0.1 + 0.2 * hot;
		return 1;
	}
	if (A > 0.36 && A < 0.46 && sin(ph) > 0.0) {
		col = hot > 0.4 ? 6 : 4;
		return 2;
	}
	col = A > 0.6 ? 3 : 2;
	a = min(0.75, (A - 0.16) * 1.4);
	return 3;
}

// one lensed image of source s (0..6), which 0 (the bright one) or 1 (the faint one beyond the orb): radius r,
// angle a0, half width hw, magnification mag; false when it falls inside the orb
bool vo_image(int s, int which, out float r, out float a0, out float hw, out float mag) {
	vec4 geo[7] = vec4[](vec4(0.0, 0.0, 6.0, 1.0), vec4(1.0, -1.0, 8.0, -1.0), vec4(18.0, -6.0, 24.0, 1.0), vec4(-26.0, 10.0, 30.0, 1.0),
		vec4(8.0, 22.0, 20.0, 2.0), vec4(-12.0, -26.0, 34.0, 1.0), vec4(34.0, 18.0, 16.0, 2.0));
	vec3 more[7] = vec3[](vec3(0.0, 2.6, 0.75), vec3(2.2, 2.0, 0.6), vec3(0.4, 2.4, 0.7), vec3(2.6, 2.0, 0.55), vec3(4.1, 1.6, 0.8),
		vec3(5.3, 1.8, 0.6), vec3(1.2, 1.4, 0.9));
	vec4 G = geo[s];
	vec3 M = more[s];
	float q = TAU * G.w * t + M.x;
	float sx = G.x + G.z * cos(q);
	float sy = G.y + G.z * sin(q) * M.z;
	float b = max(0.3, length(vec2(sx, sy)));
	float al = atan(sy, sx);
	float root = sqrt(b * b + 4.0 * VO_E * VO_E);
	float w;
	if (which == 0) {
		r = (b + root) / 2.0;
		a0 = al;
		w = 1.0;
	} else {
		r = (root - b) / 2.0;
		a0 = al + PI;
		w = 0.55;
	}
	mag = r / b * w;
	hw = min(PI, M.y * 1.6 / (2.0 * b));
	return r >= VO_R + 1.5;
}
