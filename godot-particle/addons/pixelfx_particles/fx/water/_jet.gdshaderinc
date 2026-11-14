// A pressurised stream blasting right (water/water-jet), shared by _jet.gdshader and _jet_light.gdshader: a glassy rod
// L px long that drops under its weight, white down its core and banded out to blue edges, shadowed underneath;
// streaks race along it and surges bulge through; past halfway it roughens and its end tears into chunks. The rect's
// left edge is the nozzle (`offset` puts the nozzle inside the rect). Key `t` 0 -> 1 over the loop.
uniform vec2 size = vec2(128.0, 40.0);
uniform vec2 offset = vec2(0.0);
uniform float t = 0.0;
uniform float L = 118.0;
uniform float speed = 260.0;
uniform float seed = 3.0;

float tile_n(float x, float y, float px, float s) {
	return w_noise2p(vec2(x, y), s, px);
}

// -1: nothing; else the level: 0 white core, 1..3 out to the edge
int jet_level(vec2 p) {
	float x = p.x;
	float y = p.y;
	float u = x / L;
	if (x < 0.0 || u > 1.0) {
		return -1;
	}
	float ph = t;
	float yc = u * u * 9.0;
	float rough = smoothstep(0.25, 1.0, u);
	float sd = mod(x - ph * speed * 2.0, 130.0) - 65.0;
	float w0 = 2.6 + 5.4 * pow(u, 1.1) + exp(-(sd * sd) / 90.0) * 1.4 * (1.0 - u * 0.5);
	float up = w0 + tile_n(x * 0.18 - ph * 30.0, 9.0, 30.0, seed + 1.0) * 2.2 * rough;
	float dn = w0 + tile_n(x * 0.18 - ph * 30.0, 3.0, 30.0, seed + 1.0) * 2.2 * rough;
	float q = (y - yc) / max(0.8, y < yc ? up : dn);
	float aq = abs(q);
	if (aq > 1.0) {
		return -1;
	}
	if (u > 0.55 && tile_n(x * 0.12 - ph * 25.0, (y - yc) * 0.25, 25.0, seed + 2.0) < -0.9 + 1.6 * smoothstep(0.55, 1.0, u)) {
		return -1;
	}
	float streak = tile_n(x * 0.06 - ph * 40.0, floor(y - yc + 20.0) * 1.7, 40.0, seed);
	int lvl = aq < 0.2 ? 0 : aq < 0.48 ? 1 : aq < 0.78 ? 2 : 3;
	if (streak > 0.35) {
		lvl = max(0, lvl - 1);
	}
	if (q > 0.4) {
		lvl = min(3, lvl + 1);
	}
	return lvl;
}
