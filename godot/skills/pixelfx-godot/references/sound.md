# Sound for pixelfx effects

How to give an effect 8-bit sound that sits right in a game. Read this before you write or change an effect's sound.
Each rule here comes from the owner's listening feedback on real samples, and each one fixed something that sounded
wrong. The tooling lives in `godot-particle/port/sfx/` (see its README).

## First: does it make a sound at all?

Most effects are better silent than decorated. Decide this first.

| the effect is… | sound |
|---|---|
| a steady thing that makes no noise of its own: a torch, brazier, campfire or candle burning; an idle pickup spinning or bobbing; a hovering orb, halo, portal or rune circle; a status glow on a character; fog, clouds, aurora, fireflies, drifting leaves | **none** |
| a strong dynamic moment of such a thing: a torch catching fire, a brazier flaring up, a status setting in (ice cracking over the body) or breaking | a one-shot for that moment only |
| global environment heard everywhere: rain, storm, blizzard, wind, a waterfall | a quiet loop of its material's sound, no accents (−30..−36 dB); a recurring strike is its own one-shot phase |
| something that happens: a hit, a cast, a burst, a throw, a landing, a pickup collected, a wipe | yes; see the rules below |

## The rules for what you make

1. **Sound effects, never music.** Don't use melodies, arpeggios, chords, fanfares, jingles, steady rhythms or musical
   intervals.
   - Energy builds with continuous change: a noise rate that climbs, a thin tone gliding up, crackle getting denser,
     volume swelling toward the release.
   - Light and magic shimmer as bright noise and glides, not chords.
   - Repeated beats that the effect itself has (a flurry, a countdown) keep their timing, but each one varies in pitch,
     level and pan, so it never reads as a beat.
   - The only exception is a pickup or UI confirmation: one or two short notes at the moment of collecting. It never
     goes in an idle loop.
2. **Hits carry the sound, and every hit sounds like what is hit.** A hit is a bright crack, then the weight, then
   only clear debris events. The weight comes from the struck material, never from one shared "thump"; use
   `material_hit(material, weight, seed)` in `port/sfx/synth.py`:
   | material | weight sounds like |
   |---|---|
   | blast (explosions, shockwaves only) | the pitch-dropping pulse thump, about 300 to 46 Hz, then a low rumble |
   | water | a low noise whomp opening into a wash, spray on top, a bubble bloop for a plunge. No tone |
   | stone, earth | a dry short knock and gritty crunch, with no long glide |
   | wood | a hollow tok |
   | flesh | a mid noise smack and a very short low push |
   | metal | inharmonic ringing partials and a scrape |
   | ice, glass | a crisp crack and high tinks, with no low weight |
   | energy, magic | a zap gliding down and a noise whoomp |
   | pop (cartoon, UI) | a quick upward blip and a puff |
   - **Size** sets pitch and length: a pebble ticks, a boulder thuds, a wave crashes.
   - **Seed** varies every hit, so two effects never share one identical hit. When several things land in one
     effect, they may use different materials.
3. **Material over magic.** Steel clanks, glass tinkles, stone thuds, wood creaks, water splashes, fire roars only
   while it moves or bursts. Use synthetic tones only where the effect itself is energy (lasers, bolts), and then
   as glides or buzzes.
4. **Keep it simple; end clean.** Use few layers, each one audible. Once the main sound is over, stop.
   - A tail is allowed only as a clear event you can name and see, such as a chunk landing or a blade ringing out.
   - No vague low bed afterwards: no faint fizz, no ember crackle, no long low rumble decay, no sparse hiss. A
     listener hears it as noise with no meaning.
   - `port/sfx/make.py` enforces this. After a one-shot's loudest moment, it cuts anything that stays 22 dB under it,
     with a short fade. Design so the gate has nothing to cut.

## Phases and timing

| phase | when the game plays it | role |
|---|---|---|
| start | `play()`, or an act's windup | anticipation: quiet, can be cut |
| loop | a charge held, an engine or beam running, global environment | the sustain; seamless (render 30 ms over, crossfade into the start) |
| hit | the climax frame, or the game's real moment of contact | loudest and shortest; plays first |
| body / tail | after the hit, on its own | short; a new instance may cut it |
| release / stop | a charge thrown, a loop stopped (`stop()`'s 0.3 s fade) | the close |

- **Follow the effect's own clock.** Put each event on a beat the effect already has: a constant, `fit`/`band`
  window or spawn time in its JS, an act's `hits`, a move's cues. Replay its random draws (mulberry32, `rand`) so
  landings fall where its pieces land. Don't add beats of your own.
- **Hit-stop:** during the freeze the hit's crack plays on, and the body waits for the freeze to end.
- **Moves** chain their parts' sounds on the cue sheet; a projectile's flight is panned along its path.
- **Loudness order:** hit > release > body/tail > start and charge > environment loop. For dB targets, see
  `port/sfx/README.md`.

## How it is made

- **Code, not recordings.** Each effect's sound is a function, seeded like the effect. Running it again gives the
  same sound; another `take` gives a variation.
- **8-bit voices:**
  - two pulse waves (duty 12.5, 25 or 50 %);
  - a 16-step triangle;
  - an LFSR noise channel, long or short (metallic), at 16 rates.

  Pitches snap to the NES period table, and volume steps in 16 levels per 60 Hz frame.
- **Options carry over.** A palette preset changes the timbre too (fire warmer and lower, ice higher and glassier).
  `flip` and the on-screen x set the pan.

## Playing them in a game

- **Variation:** each play draws a new take (timing, pan and starting pitch vary).
- **Crowds:** at most 3 voices of one effect at once; the 4th cuts the oldest, and each extra voice is 3 dB quieter.
  When voices run short, cut tails first, then loops. Never cut a hit.
- **Delivery:**
  - `.wav` files generated at build time (AudioStreamWAV), or synthesis at run time (AudioStreamGenerator);
  - in a scene, audio tracks on the effect's AnimationPlayer at the phase times, so they can be seen and tuned in
    the editor.

## Give an effect sound: the workflow

1. **Decide whether it makes a sound at all** (the table at the top). If it doesn't, return `Silent("why")` with the
   rule as the reason.
2. **Find its beats** in the JS: constants, `fit`/`band` windows, spawn times, `act.timing.hits` and freezes in
   `godot-particle/port/meta.json`. Replay its random draws when its pieces land.
3. **Pick the material of every hit** (rule 2), and the size of each.
4. **Write the function** in `godot-particle/port/sfx/cats/<category>.py` from the blocks in `synth.py`. Reuse other
   categories' helpers instead of copying them.
5. **Check it:** `./pfxp sfx <id>`. Lengths, peaks, loop seams and the end-clean gate are checked for you.
6. **Listen against the picture:** `./pfxp sfx <id> --preview` writes `records/sfx/fx/<id>/preview.mp4`.
7. **Export:** `./pfxp sfx` writes the OGGs and `index.json` into `addons/pixelfx_particles/sfx/`. The nodes play them.

## Pitfalls that cost a round

- `steps()` holds 16 levels, so a quiet layer under 1/15 vanishes. Step it at full scale and scale it afterwards.
- `pulse(f)` and `tri(f)` take a frequency per sample. A single number gives one sample, which plays as a click.
- An environment loop with an accent stops being ambience. Move the strike into a one-shot phase of its own.
- Parts that land together add up. Round off the peaks (moves do this) rather than turning the whole thing down.
- One shared "thump" under every hit makes waves, fists and spells sound alike. Weight comes from the material.
- A tail made of faint fizz and ember crackle reads as noise. Cut it, or turn it into a clear event.

## How these rules came about

Each line is a listening note from the owner and the rule it became.

| feedback | rule |
|---|---|
| "The charge sounds like music" | 1: sound effects, never music; energy builds with noise and glides |
| "The torch needs nothing, at most the fire burning" | then: steady things with no noise of their own are silent |
| "Torches, braziers: no sound unless something dynamic happens, or it's global environment" | the decision table |
| "After many sounds there is a meaningless low noise floor" | 4: keep it simple, end clean (the gate) |
| "The wave's crash is the same 'thump' as everything else" | 2: every hit sounds like what is hit |
