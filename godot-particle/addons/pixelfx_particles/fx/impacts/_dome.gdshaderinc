// Shared by _dome.gdshader and _dome_light.gdshader (shield-block): the half-dome's surface under a pixel, the
// lattice cell it falls in and how hard the blow's two ripples light it (src/fx/impacts/shield-block.js dome()).
uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform float cx = 3.0;
uniform float rx = 28.0;
uniform float ry = 44.0;
uniform float grid = 3.4;
uniform vec2 hit_at = vec2(1.18, 0.5);   // lon, lat of the blow
uniform float gone = 0.5;
uniform float t = 0.0;

float cell_rand(int a, int b) {
	uint h = 0x9e3779b9u;
	h = (h ^ uint(a)) * 0x85ebca6bu;
	h ^= h >> 13u;
	h *= 0xc2b2ae35u;
	h ^= h >> 16u;
	h = (h ^ uint(b)) * 0x85ebca6bu;
	h ^= h >> 13u;
	h *= 0xc2b2ae35u;
	h ^= h >> 16u;
	h = (h ^ 31u) * 0x85ebca6bu;
	h ^= h >> 13u;
	h *= 0xc2b2ae35u;
	h ^= h >> 16u;
	return float(h) / 4294967296.0;
}

// returns false off the dome or where its cell has blinked out. out: q (0 middle .. 1 rim), z, lon, lat, line,
// cell_gone (when this cell goes), hit
bool dome_at(vec2 cell, float back, out float q, out float z, out float lon, out float lat, out bool line, out float cgone, out float hit) {
	float u = (cell.x + 0.5 - cx) / rx;
	float v = -(cell.y + 0.5) / ry;
	q = u * u + v * v;
	if (q > 1.0 || u < 0.0 || v < 0.0) {
		return false;
	}
	z = sqrt(1.0 - q) * (back > 0.5 ? -1.0 : 1.0);
	lon = atan(u, z);
	lat = asin(clamp(v, 0.0, 1.0));
	float a = (lon + lat) * grid;
	float b = (lon - lat) * grid;
	float fa = fract(a);
	float fb = fract(b);
	line = min(min(fa, 1.0 - fa), min(fb, 1.0 - fb)) < 0.13;
	cgone = gone + cell_rand(int(floor(a)), int(floor(b))) * 0.35;
	if (t > cgone) {
		return false;
	}
	float d = acos(clamp(cos(lat) * cos(hit_at.y) * cos(lon - hit_at.x) + sin(lat) * sin(hit_at.y), -1.0, 1.0));
	hit = 0.0;
	for (int i = 0; i < 2; i++) {
		float t0 = i == 0 ? 0.0 : 0.12;
		float k0 = i == 0 ? 1.0 : 0.55;
		float k = t - t0;
		if (k < 0.0 || k > 0.55) {
			continue;
		}
		float front = k * 3.6;
		if (abs(d - front) < 0.2) {
			hit = max(hit, k0 * (1.0 - k / 0.55));
		} else if (d < front) {
			hit = max(hit, 0.3 * k0 * (1.0 - k / 0.55));
		}
	}
	return true;
}
