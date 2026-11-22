// crt-off.js draw(): the picture squeezed to a strip between two inks, the strip to a humming line, the line to a dot.
// Keyed every frame at the reference's clock: t, the strip's height h and the line's half-length w (shape(t)), the
// flicker fl and the frame number fr the static rolls from.
uniform float t = 0.0;
uniform float h = 180.0;
uniform float w = 160.0;
uniform float fl = 1.0;
uniform float fr = 0.0;
uniform int seed = 1;
uniform vec4 C[8] : source_color;
uniform vec4 ink : source_color;

const float YC = 90.0;
const float XC = 160.0;
const float SQ1 = 0.34;
const float ON0 = 1.06;
const float ON1 = 1.16;
const float OPEN1 = 1.42;

float crt_round(float x) {
	return floor(x + 0.5);
}

// the line's row at column x, and u: 0 in its middle .. 1 at its ends
float crt_line_y(float x, out float u) {
	u = abs(x + 0.5 - XC) / w;
	return YC + crt_round(tr_noise(x / 23.0 + t * 9.0, seed) * (0.7 + 0.5 * u));
}
