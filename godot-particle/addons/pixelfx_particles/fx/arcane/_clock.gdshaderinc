// Shared by the time-stop clock's passes (_clock.gdshader, _clock_light.gdshader): fourteen motes circling the clock
// on tilted orbits, on the clock's own slowing time `tc`. Coordinates: px from the clock's centre.
uniform float tc = 0.0;
// a, orbit radius, turns (rad per clock-second, signed), tilt
uniform vec4 motes[14];
uniform vec4 mote_cols[14];

vec2 mote_pos(vec4 m, float a) {
	return vec2(cos(a) * m.y, cos(a) * m.y * m.w + sin(a) * m.y * 0.3);
}
