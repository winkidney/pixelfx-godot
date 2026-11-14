// shield-block's half-dome of energy (src/fx/impacts/shield-block.js): a glassy fill (real translucency), a diamond
// lattice mapped on by longitude and latitude, a bright rim where it turns away, a sheen sweeping up it, two ripples
// running out from the blow, then it blinks out cell by cell. back 1 draws the far side seen through it (dim lattice
// only). t is the effect's time (keyed).
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "_dome.gdshaderinc"

uniform float back = 0.0;
uniform vec4 c3 : source_color = vec4(1.0);
uniform vec4 c4 : source_color = vec4(1.0);
uniform vec4 c5 : source_color = vec4(1.0);
uniform vec4 c6 : source_color = vec4(1.0);
uniform vec4 white : source_color = vec4(1.0);

void fragment() {
	vec2 cell = floor(center + (UV - 0.5) * size);
	float fade = 1.0 - smoothstep(gone + 0.35, gone + 0.55, t);
	float q;
	float z;
	float lon;
	float lat;
	bool line;
	float cgone;
	float hit;
	if (fade <= 0.0 || !dome_at(cell, back, q, z, lon, lat, line, cgone, hit)) {
		discard;
	}
	float rim = 1.0 - abs(z);
	bool flash = t < 0.05;
	bool blink = t > cgone - 0.06;
	bool sheen = abs(fract(lat * 0.8 - lon * 0.3 - t * 1.6) - 0.5) < 0.05;
	vec4 c;
	float a;
	bool solid = true;
	if (back > 0.5) {
		if (!line) {
			discard;
		}
		c = c3;
		a = 0.5 * fade;
	} else if (q > 0.9) {
		c = (flash || hit > 0.5) ? white : c6;
		a = fade;
	} else if (line) {
		c = (flash || blink || hit > 0.5) ? white : (hit > 0.2 || sheen) ? c6 : rim > 0.7 ? c5 : rim > 0.35 ? c4 : c3;
		a = fade;
	} else {
		c = (flash || hit > 0.35) ? c6 : c3;
		a = fade * min(0.85, (flash ? 0.35 : 0.1 + 0.25 * rim * rim) + hit * 0.65);
		solid = false;
	}
	a *= COLOR.a;
	if (solid) {
		if (a < pfx_threshold(FRAGCOORD.xy)) {
			discard;
		}
		a = 1.0;
	}
	COLOR = vec4(c.rgb, a);
}
