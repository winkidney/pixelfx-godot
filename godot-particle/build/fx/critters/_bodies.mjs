#!/usr/bin/env node
// The critters' bodies lifted from the originals, and nothing else: port/frames.py lifts a whole effect's sheet
// (trails, motes, glows and all), so this runs the original (src/fx/<id>.js) at the reference's clock with every
// painter write switched off except the cells its body Grids put down (_lib.js Grid.draw), and no light. The
// critter's effects (glows, trails, bubbles, drips...) are left to the build script, made natively.
// Writes fx/<id>/frames.png + frames.json in port/frames.py's layout, for build.gd frames().
//   node build/fx/critters/_bodies.mjs critters/bird [--calls 0,1] [--grid 52x46]
//     --calls: which of a frame's Grid.draw calls to keep, by order (default: all; -1 is its last)
//     --grid:  keep only grids of this size (w x h)
//     --name:  write <name>.png / <name>.json instead of frames (a body split in two, a part behind and one in front)
import { mkdirSync, writeFileSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const HERE = dirname(fileURLToPath(import.meta.url));
const GP = join(HERE, "..", "..", "..");
const REPO = join(GP, "..");
const lib = await import(pathToFileURL(join(REPO, "tools", "lib", "fxlib.mjs")).href);
const { Painter } = await import(pathToFileURL(join(REPO, "src", "core", "painter.js")).href);
const { Grid } = await import(pathToFileURL(join(REPO, "src", "fx", "critters", "_lib.js")).href);
const { encodePNG } = await import(pathToFileURL(join(REPO, "tools", "lib", "png.mjs")).href);

const args = process.argv.slice(2), ids = [], flags = {};
for (let i = 0; i < args.length; i++) {
  if (args[i].startsWith("--")) flags[args[i].slice(2)] = args[++i];
  else ids.push(args[i]);
}
const calls = flags.calls ? new Set(flags.calls.split(",").map(Number)) : null;
const size = flags.grid ?? null;

let totals = null, inGrid = 0, callNo = 0, pass = -1, counts = [];
const draw0 = Grid.prototype.draw;
Grid.prototype.draw = function (p, ...rest) {
  const n = callNo++, fr = pass >> 1;
  if (!(pass & 1)) counts[fr] = callNo;
  if (pass & 1) return;   // the shown passes: thrown away
  const m = totals ? n - totals[fr] : n;
  if ((calls && !calls.has(n) && !calls.has(m)) || (size && `${this.w}x${this.h}` !== size)) return;
  inGrid++;
  try { return draw0.call(this, p, ...rest); } finally { inGrid--; }
};
const put0 = Painter.prototype.put, blend0 = Painter.prototype.blendPx;
Painter.prototype.put = function (...a) { if (inGrid) put0.apply(this, a); };
Painter.prototype.blendPx = function (...a) { if (inGrid) blend0.apply(this, a); };
Painter.prototype.add = function () {};

for (const id of ids) {
  const fx = await lib.loadEffect(id);
  // count a frame's Grid.draw calls from its first pass (drawBack if it has one); only the bare render is kept
  const mod = fx.mod, first = mod.drawBack ? "drawBack" : "draw", f0 = mod[first];
  // a frame draws its bare pass (kept) then its shown pass(es); the first pass starts each
  mod[first] = (...a) => { callNo = 0; pass++; return f0(...a); };
  // a first run counts each frame's calls, so -1 can mean the last
  totals = null; pass = -1; counts = [];
  lib.renderFrames(fx, { bg: "none", actor: false });
  totals = counts; pass = -1; counts = [];
  const r = lib.renderFrames(fx, { bg: "none", actor: false });
  const [W, H] = fx.meta.size, cols = 8, rows = Math.ceil(r.n / cols);
  const img = new Uint8ClampedArray(W * cols * H * rows * 4);
  r.frames.forEach((f, i) => {
    const ox = (i % cols) * W, oy = Math.floor(i / cols) * H;
    for (let y = 0; y < H; y++) img.set(f.clear.subarray(y * W * 4, (y + 1) * W * 4), ((oy + y) * W * cols + ox) * 4);
  });
  const out = join(GP, "addons", "pixelfx_particles", "fx", id);
  mkdirSync(out, { recursive: true });
  const base = flags.name ?? "frames";
  writeFileSync(join(out, base + ".png"), encodePNG(W * cols, H * rows, img));
  writeFileSync(join(out, base + ".json"), JSON.stringify({ cols, rows, count: r.n, fps: r.fps, pivot: fx.meta.origin, size: [W, H] }));
  console.log(id, r.n, "frames");
}
