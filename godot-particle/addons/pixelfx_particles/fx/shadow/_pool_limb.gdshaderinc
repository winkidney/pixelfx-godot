// A limb rising out of the dark pool (shared by _pool_limb.gdshader, its colour, and _pool_limb_light.gdshader):
// the original's spine, stepped every 0.5 px from below the surface, with its angle and half-width.
//   mode 0: a tentacle (shadow-tendrils spine()): a wave writhes up it (writhe, lam, om, ph), its tip curls into a
//           hook (curl, hook); half-width W (1 - u)^0.75 + 0.45.
//   mode 1: an arm (grasping-hands arm()): bent at the elbow (elbow), curving (curve); half-width W (1 - 0.5 u) + 0.4.
// Keyed per frame: t (seconds), hidden (how much of it is still under the surface), lean, writhe / elbow, hook, grip.
// Coordinates are px from the effect's origin; (x0, surf) is where it breaks the surface.
uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform int mode = 0;
uniform float t = 0.0;
uniform float x0 = 0.0;
uniform float surf = 0.0;
uniform float len = 40.0;
uniform float wid = 4.0;
uniform float hidden = 0.0;
uniform float lean = 0.0;
uniform float bend = 0.0;
uniform float hook = 0.0;
uniform float lam = 40.0;
uniform float om = 5.0;
uniform float ph = 0.0;
uniform float curl = 1.0;
uniform float curve = 0.0;
uniform float grip = 0.0;
uniform float t0 = 0.0;

const vec2 LDIR = vec2(-0.6, -0.8);

float limb_w(float u) {
	return mode == 0 ? wid * pow(max(0.0, 1.0 - u), 0.75) + 0.45 : wid * (1.0 - 0.5 * u) + 0.4;
}

float limb_smooth(float a, float b, float x) {
	float u = clamp((x - a) / (b - a), 0.0, 1.0);
	return u * u * (3.0 - 2.0 * u);
}

float limb_dth(float s, float u) {
	if (mode == 0) {
		return 0.5 * (bend * sin(s / lam * TAU - om * t + ph) + curl * hook * limb_smooth(0.58, 1.0, u));
	}
	float g = (u - 0.52) / 0.07;
	return 0.5 * (bend * exp(-g * g) / (0.07 * sqrt(PI) * len) + curve / len);
}

int limb_n() {
	return int(ceil(len / 0.5));
}

// the spine's start: below the surface by `hidden`, along its first angle
void limb_start(out vec2 q, out float th) {
	th = -PI / 2.0 + lean;
	q = vec2(x0 - cos(th) * hidden, surf - sin(th) * hidden);
}

void limb_step(inout vec2 q, inout float th, float s, float u) {
	th += limb_dth(s, u);
	q += vec2(cos(th), sin(th)) * 0.5;
}
