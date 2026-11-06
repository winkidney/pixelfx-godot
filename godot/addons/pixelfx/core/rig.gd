# The character who acts: a real skeleton in 3D, drawn down to pixels (src/core/rig.js).
# Phase 1 holds the rest pose; the solver and renderer are ported with the acts.
# port-of: src/core/rig.js@525b7145624f53722fde335503cdf271d3958ca5 (STAND only)
extends RefCounted

## Standing easy, in screen terms: hands and feet are where they should end up, y negative is up.
const STAND := {"lean": 0, "crouch": 0, "yaw": 0, "fx": -3, "fy": -15, "bx": 5, "by": -15, "ffx": -2, "ffy": -4, "fbx": 3, "fby": -4}
