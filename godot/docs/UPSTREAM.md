# Keeping up with upstream

This repository is a fork of [patch-gg/pixelfx](https://github.com/patch-gg/pixelfx).

- **Upstream's JavaScript stays untouched** at its own paths (`src/`, `tools/`, `docs/`, `gallery/`, `skills/pixelfx/`,
  `package.json`). It is the reference the Godot port is checked against.
- **Everything Godot lives in `godot/`**, which upstream never touches.
- **Two upstream files are ours instead:** `README.md` and `.claude-plugin/marketplace.json`. `.gitattributes` marks them
  `merge=ours`, so a merge keeps our versions.

As a result, merging upstream is an ordinary `git merge`. Afterwards, the Godot side is brought up to date file by file.

## Every port knows what it came from

Every `.gd` that ports a JS file names that file and its git blob on a `port-of` line near the top:

```gdscript
# port-of: src/fx/melee/sword-slash.js@8e9258f474a2461b85a2992d4d58c354f27054da
```

`node godot/port/sync.mjs` compares each of those blobs with the JS as it is now. It reports three kinds of file:

- **stale**: the JS changed since it was ported. It prints the `git diff <old> <new>` to apply, which works on blobs
  directly.
- **missing**: an upstream file nothing ports yet, such as a new effect.
- **orphan**: a port whose JS is gone upstream.

## The loop

```bash
node godot/port/sync.mjs --setup          # once per clone: the upstream remote and the merge=ours driver
git fetch upstream
git merge upstream/main                   # JS updates land at their own paths; README and marketplace stay ours
node godot/port/sync.mjs                  # what the merge left behind on the Godot side
```

Then, for each stale or missing file:

1. **Port it.**
   - For a stale file, apply the diff to the `.gd` with the rules in [PORTING.md](PORTING.md):
     `git diff <old-blob> <new-blob>` shows exactly what changed.
   - For a missing effect, port the whole file.
   - The `pixelfx-godot` skill knows the procedure ("port this upstream change").
2. **Prove it.** Run `cd godot && ./pfx parity <id> --full` (and `--acts` if it has an act). It must say `ok` or `ok~`.
   The reference frames are regenerated from the new JS automatically.
3. **Stamp it.** `node godot/port/sync.mjs --stamp <category>/<name>` writes the new blob into the `port-of` line.

If upstream changed the core (`src/core/*.js`), port that first. Then run `./pfx test` (core fixtures:
`node godot/port/ref.mjs --fixtures` regenerates them) and `./pfx parity --quiet` for every effect, because a core change
can move any of them. Core files carry their `port-of` lines too, so `sync.mjs` lists them.

When the merge changes the effect list, finish with `./pfx index`. It regenerates `addons/pixelfx/fx/registry.gd` and
`godot/docs/CATALOG.md`. Then commit.

## What may differ, and why

- **Numbers:** GDScript gets `sin`, `cos`, `atan2`, `exp` and `pow` from the C library, while V8 uses its own fdlibm.
  The two disagree in the last bit for a few percent of inputs. Almost always that changes nothing. Once in a while it
  moves one pixel (`ok~`). In a simulation it can flip a branch that consumes random numbers, and then the rest of that
  run diverges. `./pfx parity` reports it (the Rng trace differs). Such a case is listed in `godot/port/parity-allow.json`
  with the reason, after a look at its side-by-side sheet.
- **Upstream tools** (`tools/*.mjs`) have Godot counterparts in `godot/tools/` (`./pfx render|act|check|sheets|new|index`).
  Port their changes by hand when they matter to Godot users. They aren't checked by parity.
- **Upstream's skill** (`skills/pixelfx/SKILL.md`) has a Godot counterpart at `godot/skills/pixelfx-godot/SKILL.md`. Fold in
  new advice about making effects (the "you see / fix" table, the quality bar) when upstream adds it.
