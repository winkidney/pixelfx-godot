// pixel-dissolve.js draw(): blocks on a 20 px grid (whole, quarters or sixteenths) winking in and out at their own
// times. `blocks`: per block row 0 (x, y, size, index), row 1 (in time, out time); `cells`: per grid cell the first
// block's index and how many. A pixel only ever meets the blocks of its own and the neighbouring cells, visited in
// the original's order. `fr` is the frame number its pixel dust rolls from (floor(t * 15)).
uniform sampler2D blocks : filter_nearest, repeat_disable;
uniform sampler2D cells : filter_nearest, repeat_disable;
uniform float t = 0.0;
uniform float fr = 0.0;
uniform vec4 C[8] : source_color;
uniform vec4 ink : source_color;

const float P = 0.17;
const float CELL = 20.0;

float pd_round(float x) {
	return floor(x + 0.5);
}

float pd_out_back(float x) {
	float s = 1.70158;
	if (x <= 0.0) {
		return 0.0;
	}
	if (x >= 1.0) {
		return 1.0;
	}
	return 1.0 + (s + 1.0) * pow(x - 1.0, 3.0) + s * pow(x - 1.0, 2.0);
}
