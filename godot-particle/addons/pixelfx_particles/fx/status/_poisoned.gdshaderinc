// status/poisoned's clock and sway, shared by its body and sweat shaders: `tw` runs 0..1 over the 1.6 s loop (keyed);
// the tick comes every 0.8 s; the body leans from the feet (the head moving most) and on the tick every row wobbles.
uniform float tw = 0.0;

const float PD = 1.6;
const float PTICK = 0.8;
const float PH = 38.0;

float p_ph() {
	return mod(tw * PD, PTICK);
}

// how far row my (mask space) is pushed sideways: the original's offsets(t, H)(my)
float p_off(float my) {
	float lean = 1.3 * sin(tw * TAU);
	float ph = p_ph();
	float w = ph < 0.12 ? sin(ph / 0.12 * PI) : 0.0;
	return floor(lean * (1.0 - my / PH) + w * sin(my * 0.42 + ph * 40.0) + 0.5);
}
