# Sound for the 244 effects

8-bit sound for every pixelfx particle effect, synthesized in code the way the effects are drawn and timed to each
effect's own beats. It plays with the effect: put a `PixelFxParticles2D` in your scene and you hear it.

## What's in the pack

- **179 effects have sound.** Hits sound like what they hit: water, stone, wood, flesh, metal, ice, energy. Only
  explosions boom. There is no music, and one-shots end clean, with no vague tail after the main sound.
- **65 are silent on purpose.** They are all steady loops that make no noise of their own: a torch or candle burning,
  an idle pickup spinning, a status glow on a character, fog, fireflies, drifting snow. Decoration you'd hear for as
  long as it is on screen gets tiring fast. Each silent entry in `index.json` says why. When such a thing has a strong
  moment of its own (a torch catching fire), play your own one-shot for that moment.
- **Environment loops** (rain, storm, blizzard, wind, a waterfall) are quiet beds with no accents. A recurring strike,
  such as a storm's lightning, is a phase of its own.

Each effect with sound is a folder, `<category>/<name>/`:

- `full.ogg`: the whole play on the effect's clock. It starts at the effect's t = 0, so play it with the effect. A
  one-shot may ring up to 1.5 s past the effect's end. A loop's is exactly one loop long, wraps seamlessly, and is
  imported with looping on.
- `<phase>.ogg`: the parts on their own, for a game that times them itself.

| phase | when to play it |
|---|---|
| `start` | `play()`, or an attack's windup: anticipation, quiet |
| `loop` | a charge held, a beam or engine running, rain falling: seamless, imported looping |
| `hit` | the climax, or your game's real moment of contact: loudest and shortest |
| `body`, `tail` | after the hit: short |
| `release`, `stop` | a charge let go, a loop stopped |

Some effects have phases named for what they are instead: `swish`, `crack`, `launch`, `land`, `shatter`, and so on.
`index.json` lists each effect's phases.

The files are OGG Vorbis, mono unless the sound moves across the stereo field. The pack is about 11 MB.

### index.json

One entry for every effect id, 244 in all:

```json
{
 "melee/sword-slash": {
  "sound": true,
  "loop": false,
  "duration": 0.75,
  "length": 0.75,
  "phases": ["hit", "start", "swish"],
  "notes": "swish over the sweep (0-0.16), steel edge ring + flesh smack on the hit (0.06); start = the act's windup"
 },
 "fire/torch": {
  "sound": false,
  "why": "a steady torch flame: silent thing stays silent (ignite one-shot only when the game lights it)",
  "loop": true,
  "duration": 2.0
 }
}
```

- `duration` is the effect's length in seconds (one loop for a loop).
- `length` is `full.ogg`'s length.
- `phases` lists the files besides `full`.
- `notes` says what you hear and which beats it follows.

## In Godot

`PixelFxParticles2D` plays the effect's sound by default:

```gdscript
var fx := PixelFxParticles2D.new()
fx.effect = "explosions/small-explosion"
fx.sound_bus = &"SFX"            # your own bus (default "Master")
fx.sound_volume_db = -3.0
fx.position = hit_point          # the sound is panned from here
add_child(fx)
```

- **What it does.** `play()` starts `full.ogg` on an `AudioStreamPlayer2D` that it makes at run time (it is never
  saved in a scene), so the sound is panned and attenuated from the node's position.
  - A loop's sound loops, and `stop()` fades it out with the picture over the same 0.3 s.
  - `free_when_done` waits for a one-shot's sound to ring out before freeing the node.
  - Playing a one-shot again lets the earlier play ring out under the new one. The full track keeps at most 3
    voices per node.
- **Hit-stop.** Setting `speed` to 0 (a freeze) does not pause the sound. The hit's crack rings on through the
  freeze, and each sound was made with its body starting when the freeze ends. Any other speed scales the pitch,
  so slow motion sounds slow.
- **One phase on its own.** `fx.play_sound("hit")` plays one phase now, for example on your game's real moment of
  contact. It returns the `AudioStreamPlayer2D`, follows `speed` and `stop()` like the full track, and a `"loop"`
  phase loops until `stop()`. `PfxEffect.sound_info(id)` returns the effect's `index.json` entry, phases included.
- **Moves.** A move (`moves/*`) cues other effects inside it. The move plays its own full track, and the effects
  cued inside it stay quiet, so nothing sounds twice.
- **Acts.** `PixelFxParticlesAct2D` starts the effect's sound when the act reaches the effect's t = 0 (after the
  windup). Through each hit-stop the crack rings on and the body comes in as the freeze ends.
- **Turning it off.** Set `sound = false` on `PixelFxParticles2D`, `PixelFxParticlesAct2D` or a `PfxEffect` scene
  root. This is useful when your game plays its own sounds, or when you want only `play_sound()` at your own moments.
- **Without the nodes.** The files are plain imported `AudioStreamOggVorbis` resources:
  `res://addons/pixelfx_particles/sfx/<category>/<name>/<phase>.ogg`. Use them with your own players or in an
  AnimationPlayer's audio track.

In the SubViewport of a pixel view, 2D audio has no listener. The nodes therefore host the effect's players
themselves, in your game's world, at the effect's origin.

## Re-exporting

From `godot-particle/`, one command regenerates and exports the whole pack:

```bash
./pfxp sfx                                   # render and check all 244, export OGG here + index.json, import in Godot
./pfxp sfx explosions/small-explosion water  # some ids or whole categories
./pfxp sfx --out ~/mygame/sfx --format wav   # the same tree and index.json into any folder, for another engine
./pfxp sfx --out ~/mygame/sfx --format ogg
```

- The sound is generated from code in `port/sfx/` (see its README). Running it again gives the same files, so an
  unchanged sound rewrites nothing.
- Files of phases or effects that no longer exist are deleted.
- WAV export is 16-bit stereo, 44.1 kHz.
- The pack's size is checked on every export (20 MB at most). The OGG quality is `OGG_Q` in `port/sfx/make.py`.

## License

The same as the project: MIT. See `LICENSE` and `NOTICE.md` at the repository's root. The sounds are synthesized by
this repository's code, with no recorded samples. You may use them in your games, commercial or not.
