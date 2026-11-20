// loot-beam's column (src/fx/pickups/loot-beam.js column()), shared by its colour and light shaders: whether row y
// (a whole pixel row, -1 up to -H) is drawn at all, and its half-width. ph: the loop's phase, beat: the swell as a
// ring leaves the foot. Include after scifi/_jsrand.gdshaderinc.
uniform float ph = 0.0;
uniform float beat = 0.0;

const float H = 150.0;

float js_rand2(int a, int b) {
	return float(js_hash2(a, b)) / 4294967296.0;
}

float js_rand3(int a, int b, int c) {
	return float(js_hash3(a, b, c)) / 4294967296.0;
}

float beam_smooth(float a, float b, float x) {
	float u = clamp((x - a) / (b - a), 0.0, 1.0);
	return u * u * (3.0 - 2.0 * u);
}

float beam_w(float h) {
	float u = h / H;
	return (4.2 * (1.0 - 0.45 * u) + 3.2 * exp(-h / 7.0)) * (1.0 + 0.2 * beat);
}

int beam_seg(float h) {
	return int(floor(h / 3.0 + js_rand2(int(floor(h / 9.0)), 5) * 2.0));
}

// the dashes the column breaks into near its top: false where the row is skipped
bool beam_row(float y) {
	float h = -y - 0.5;
	float u = h / H;
	int flick = int(floor(ph * 12.0));
	return !(u > 0.66 && js_rand3(beam_seg(h), flick, 7) > 1.75 - u * 1.65);
}
