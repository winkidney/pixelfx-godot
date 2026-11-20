// diamond-wipe.js draw() per pixel: the lattice of diamonds (`lat`: cx, cy, tin, tout, in the original's draw order)
// swelling in and shrinking out at the reference's clock `t`; the colour shader keeps the last diamond that writes the
// pixel, the light shader adds every diamond's rim light and glow.
uniform sampler2D lat : filter_nearest, repeat_disable;
uniform int count = 0;
uniform float t = 0.0;
uniform vec4 C[8] : source_color;
uniform vec4 ink : source_color;

const float S = 32.0;
const float HD = 17.0;
const float GROW = 0.24;

float dw_out_back(float x, float s) {
	return 1.0 + (s + 1.0) * pow(x - 1.0, 3.0) + s * pow(x - 1.0, 2.0);
}

float dw_in_back(float x, float s) {
	return (s + 1.0) * x * x * x - s * x * x;
}

float dw_smooth(float a, float b, float x) {
	float u = clamp((x - a) / (b - a), 0.0, 1.0);
	return u * u * (3.0 - 2.0 * u);
}

// one diamond's size and heat at t (hd < 0.5: not drawn)
void dw_state(vec4 d, out float hd, out float heat) {
	float ki = (t - d.z) / GROW;
	float ko = (t - d.w) / GROW;
	hd = 0.0;
	heat = 0.0;
	if (ki <= 0.0 || ko >= 1.0) {
		return;
	}
	hd = HD * (ko > 0.0 ? 1.0 - dw_in_back(ko, 2.0) : dw_out_back(min(1.0, ki), 2.2));
	heat = ko > 0.0 ? dw_smooth(0.0, 0.35, ko) : 1.0 - dw_smooth(0.45, 1.25, ki);
}

// whether pixel (x, y) is inside diamond d of half-size hd, as the original's row spans fill it
bool dw_in(vec2 px, vec4 d, float hd) {
	float y0 = max(0.0, floor(d.y - hd));
	float y1 = min(TR_H - 1.0, ceil(d.y + hd));
	if (px.y < y0 || px.y > y1) {
		return false;
	}
	float dy = px.y + 0.5 - d.y;
	float w = hd - abs(dy);
	if (w <= 0.0) {
		return false;
	}
	float x0 = max(0.0, ceil(d.x - w - 0.5));
	float x1 = min(TR_W - 1.0, floor(d.x + w - 0.5));
	return px.x >= x0 && px.x <= x1;
}
