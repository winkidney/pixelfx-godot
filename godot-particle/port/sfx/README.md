# Sound for the 244 effects

Every effect gets a sound function, made the way the effects are made: code, seeded, timed to the effect's own beats.
Some effects stay silent on purpose. **Rules:
[`godot/skills/pixelfx-godot/references/sound.md`](../../../godot/skills/pixelfx-godot/references/sound.md). Read it
first; it is the spec.** What a game gets, and how to use it in Godot, is in
[`addons/pixelfx_particles/sfx/README.md`](../../addons/pixelfx_particles/sfx/README.md).

```bash
cd godot-particle
./pfxp sfx                                  # all 244: render and check, export the pack, import it in Godot
./pfxp sfx melee/sword-slash --preview      # one effect (or a category), with a video of it to listen to
./pfxp sfx --out DIR --format wav           # the same pack into any folder (wav or ogg), for another engine
```

- `synth.py`: the voices and building blocks.
  - Voices: `pulse`, `tri`, `noise` (NES LFSR, rate 0 hiss .. 15 rumble, `short=True` metallic), with `steps` for the
    60 Hz 16-level volume.
  - Blocks: `whoosh`, `boom`, `blip`, `chime`, `tick`, `charge`; helpers `place`, `blank`, `stereo`, `wrap`, `T`,
    `decay`, `NOTE`.
  - The return types: `Sound(full, phases, notes)` and `Silent(why)`.
- `cats/<category>.py`: `SOUNDS = {"<name>": fn}`. Each `fn(m)` gets the effect's meta from `port/meta.json`: `duration`,
  `loop`, `size`, `origin`, `options`, and `act.timing` with `hits` (`t`, `freeze`) and `windup`. It returns a
  `Sound` or a `Silent`.
- `make.py [ids|categories] [--preview] [--out DIR] [--format ogg|wav]` (what `./pfxp sfx` runs) renders
  `records/sfx/fx/<id>/full.wav` and one wav per phase, and updates `records/sfx/manifest.json`. It checks three things:
  - **Length.** A loop is exactly `duration` long and wraps seamlessly: render `X` longer and call `wrap()`. A
    one-shot may ring up to 1.5 s past its end.
  - **Peaks.**
  - **Environment loop level.**

  `--preview` muxes the sound under the particle port's frames (`records/render/<id>/`) into
  `records/sfx/fx/<id>/preview.mp4`.

  Then it exports the pack:
  - Every effect with sound goes to `addons/pixelfx_particles/sfx/<category>/<name>/{full,<phase>}.ogg`, along with
    `index.json` (sound or silent and why, loop, duration, phases, notes). With `--out`, the pack goes to DIR instead.
  - OGG is libvorbis at `OGG_Q`, mono where both channels match. The pack must stay under `MAX_MB`.
  - A loop's `full` and every `loop` phase get `loop=true` in their `.import`.
  - Files of phases or effects that are gone are deleted.

  `./pfxp sfx` then runs Godot's import, and `./pfxp check` fails an effect without an `index.json` entry or its oggs.

Examples to copy: `cats/explosions.py` (small-explosion, the hit recipe), `cats/melee.py` (sword-slash),
`cats/arcane.py` (spell-charge, energy with no notes), `cats/fire.py` (torch, silent), and `cats/moves.py`
(fireball-throw, chaining other effects' parts on a cue sheet).

## Give a new effect sound

1. **Sound or silent?** Decide with the table at the top of `sound.md`. A steady thing with no noise of its own (a
   flame burning, an idle pickup, a glow, fog) stays silent. Return `Silent("why, by which rule")` and you're done.
2. **Find its beats.** Read `src/fx/<cat>/<name>.js` and `port/meta.json` (see [Finding the beats](#finding-the-beats)).
   Write down when things happen: the hit, the spawns, the landings, the windup. Every sound event goes on one of
   them, and you add no beats of your own.
3. **Pick the material.** Decide what is hit, or what moves: water, stone, wood, flesh, metal, ice, energy, or a
   blast for explosions only. A hit's weight is `material_hit(material, weight, seed)` in `synth.py`, with size
   setting the weight.
4. **Write the function.** Add `"<name>": fn` to `SOUNDS` in `cats/<category>.py`. `fn(m)` returns
   `Sound(full, phases, notes)`.
   - `full` is the whole play from t = 0. A loop is exactly `m["duration"]` long; render it longer and `wrap()` it.
   - Phases are the parts a game triggers (`start`, `loop`, `hit`, `body`, `tail`, `release`).
   - `notes` is one line on what you hear and which beats it follows.
   - Copy from the examples above.
5. **Render it.** Run `./pfxp sfx <id> --preview`. Fix anything it prints as a problem, and check that the level is
   in [the table below](#levels).
6. **Listen.** Play `records/sfx/fx/<id>/preview.mp4`, the sound under the effect's frames; render the frames first
   with `./pfxp render <id>`. Then try it in the gallery (`godot --path .`).
   - Does every sound land on something you see?
   - Does the hit sound like its material?
   - Does it stop when the effect does?

   Change it and run step 5 again. When it's done, `./pfxp check <id>` passes and the oggs are in the addon.

## Levels

`full.wav` RMS as `make.py` prints it, after its master gain:

| kind | dB RMS |
|---|---|
| big hits, explosions | −18 .. −22 |
| small hits, impacts, slashes | −20 .. −26 |
| one-shot magic, projectiles, UI | −22 .. −28 |
| charges and held energy loops | −26 .. −32 |
| environment loops (rain, wind) | −30 .. −36 |

## Finding the beats

- The effect's JS (`src/fx/<cat>/<name>.js`) holds the times. Look for constants (`HIT`, `RT`, `D`, `T0`), `fit(t, a, b)` and
  `band(t, a, b)` windows, `ease` ranges, and spawn moments. Act hits are in `act.timing.hits` in `port/meta.json`.
- To see the frames, `records/render/<id>/NNNN.png` is the particle port's render at the effect's fps.
- Put each sound event on one of those beats. A one-shot's `full` starts at the effect's t = 0.

## Pitfalls

- `steps()` holds the volume in 16 levels, so an envelope under about 1/15 becomes silence and small swells flatten.
  For a quiet layer, step it at full scale and multiply by its mix gain afterwards. See `glitter` and `sweep` in
  `cats/arcane.py`, and `leveled` in `cats/projectiles.py`.
- An environment loop has no accents. Keep a recurring strike (a storm's lightning) as a one-shot phase of its own,
  and keep the bed as the `loop` phase (see `cats/lightning.py` storm-cloud).
- Helpers worth reusing:
  - `cats/arcane.py`: `JsRng` (the original's mulberry32, so the JS's own spawn times come out the same).
  - `cats/explosions.py`: `landings`.
  - `cats/impacts.py`: `fly` and `grit_lands` (debris physics).
  - `cats/projectiles.py`: `lput` (a loop event whose tail wraps round), `st_path` (pan per sample) and `per_frame`.
  - `cats/lightning.py`: `zap`, `buzz` and `thunder`.
- `pulse(f)` and `tri(f)` take a frequency per sample. A single number gives a one-sample array, which is a flat click
  rather than a tone. Pass `np.full(n, f)` or a curve over `T(secs)`.
- **One-shots end clean (rule 4).** After a one-shot's loudest moment, `make.py` cuts anything that stays
  `GATE_DB` (−22 dB) under it, with a 120 ms fade, in both `full.wav` and the non-anticipation phases. A clear
  event above that stays, with 100 ms of its decay. Don't rely on the gate: design tails as clear events.
