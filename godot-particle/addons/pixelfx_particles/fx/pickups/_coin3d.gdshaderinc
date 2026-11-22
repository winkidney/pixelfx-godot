// _lib.js coin3d(): a thick coin turning on its upright axis (radius R, thickness TH, turned by theta: 0 faces you),
// its centre on cell corner (cx, cy). Each row shows the squashed face (a raised rim, a recessed field, an embossed
// diamond, a flash as it squares to the light) and, beside it, the reeded edge band. The colour of the pixel whose
// centre is pc as an index into C (8: white), -1 where there's no coin. Include after _pk.gdshaderinc.

// ct, st: cos and sin of the turn, worked out in doubles at build time (edge-on, the GPU's cos(pi / 2) can come out on
// the other side of 0 from the original's, which flips the rim)
int coin3d_px(vec2 pc, float cx, float cy, float R, float TH, float ct, float st) {
	float sg = ct < 0.0 ? -1.0 : 1.0;
	float act = abs(ct);
	float ast = abs(st);
	float xc = (TH / 2.0) * st * sg;
	float nfx = st * sg;
	vec3 Lv = vec3(-0.55, 0.45, 0.7);
	float Ln = length(Lv);
	float lam = (nfx * Lv.x + act * Lv.z) / Ln;
	float Hx = Lv.x / Ln;
	float Hz = Lv.z / Ln + 1.0;
	float Hn = sqrt(Hx * Hx + Hz * Hz);
	int base = int(max(2.0, min(5.0, js_round(2.0 + lam * 3.2))));
	float sx = pc.x - cx;
	float sy = -(pc.y - cy);
	if (abs(sy) > R) {
		return -1;
	}
	float s = sqrt(max(0.0, 1.0 - (sy / R) * (sy / R)));
	float hw = R * s * act;
	float xr = -(st < 0.0 ? -1.0 : 1.0) * s * R * ct;
	float rw = (TH / 2.0) * ast;
	if (abs(sx - xc) <= hw && act > 0.08) {
		float fx = (sx - xc) / act;
		float fy = sy;
		float d = length(vec2(fx, fy)) / R;
		float tx = nfx + (fx / R) * 0.3 * act;
		float sp = pow(max(0.0, (tx * Hx + act * Hz) / Hn / length(vec2(tx, act))), 130.0);
		float lit = (-fx * 0.6 + fy * 0.8) / max(0.5, length(vec2(fx, fy)));
		int k;
		if (d > 0.76) {
			k = base + (lit > 0.75 ? 2 : lit > 0.3 ? 1 : lit < -0.35 ? -1 : 0);
		} else {
			float q = (abs(fx) + abs(fy)) / (R * 0.52);
			k = q >= 1.0 ? base - 1 : q < 0.45 ? base + 1 : (fx <= 0.0 && fy >= 0.0) ? base + 1 : (fx > 0.0 && fy < 0.0) ? base - 2 : base;
		}
		if (sp > 0.5) {
			return sp > 0.8 ? 8 : min(7, k + 2);
		}
		return clamp(k, 2, 6);
	}
	if (abs(sx - xr) <= rw + 0.05) {
		float cphi = xr < 0.0 ? -s : s;
		vec3 n = vec3(cphi * ct, sy / R, -cphi * st);
		float l = dot(n, Lv) / Ln;
		int groove = pk_imod(int(floor((asin(clamp(sy / R, -1.0, 1.0)) + PI) * 9.0)), 2);
		bool edge = abs(sx - xr) > rw - 0.6 && sign(sx - xr) == sign(xc - xr);
		return clamp(int(js_round(2.6 + l * 2.6)) - groove + (edge ? 1 : 0), 1, 6);
	}
	return -1;
}
