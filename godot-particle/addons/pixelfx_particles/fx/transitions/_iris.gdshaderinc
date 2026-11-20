// iris.js draw(): the ink outside a round hole of radius r round `focus`, its bevelled rim (rw wide, lit from the top
// left, `hot` how white-hot) and the light just inside it. mode: 0 nothing, 1 the hole and rim, 2 all ink.
uniform float mode = 0.0;
uniform float r = 0.0;
uniform float hot = 0.0;
uniform float rw = 5.0;
uniform vec2 focus = vec2(160.0, 100.0);
uniform vec4 C[8] : source_color;
uniform vec4 ink : source_color;

const float GLO = 16.0;

// the row's span inside the rim's outer edge, and the inner glow's half-width (pixels |dx| < g are left alone)
bool ir_span(vec2 px, out float a0, out float b1, out float g) {
	float dy = px.y + 0.5 - focus.y;
	float xo = sqrt(max(0.0, (r + rw) * (r + rw) - dy * dy));
	g = r > GLO ? sqrt(max(0.0, (r - GLO) * (r - GLO) - dy * dy)) : 0.0;
	if (xo <= 0.0) {
		a0 = 0.0;
		b1 = 0.0;
		return false;
	}
	a0 = clamp(floor(focus.x - xo), 0.0, TR_W);
	b1 = clamp(ceil(focus.x + xo), 0.0, TR_W);
	return true;
}
