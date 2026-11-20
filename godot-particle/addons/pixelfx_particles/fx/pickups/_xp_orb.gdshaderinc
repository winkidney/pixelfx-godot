// xp-orb's figure-eight (src/fx/pickups/xp-orb.js at()): where the orb is at time t (one lap a loop).
uniform float dur = 1.8;
uniform float t = 0.0;

vec2 orb_at(float tt) {
	float a = (tt / dur) * TAU;
	return vec2(16.0 * sin(a), -20.0 + 9.0 * sin(a) * cos(a) - 1.2 * cos(a * 2.0));
}
