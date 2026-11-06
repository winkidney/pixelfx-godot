#!/usr/bin/env node
// Reference data from the upstream JS (../../src), for checking the Godot port against it.
//
//   node godot/port/ref.mjs [ids|categories ...] [--variants default,flip,...]
//       per effect: godot/.parity/js/<cat>/<name>.json, a SHA-1 of the raw color and light buffers of every frame of
//       every variant, the number and xor of every Rng.next() drawn per frame, and the act timing.
//   node godot/port/ref.mjs <id> --dump --variant <v>
//       also the raw frames: godot/.parity/js/<cat>/<name>.<v>.bin.gz (u32 w, u32 h, u32 n, then color+light per frame)
//   node godot/port/ref.mjs --fixtures
//       core fixtures for the Godot unit tests: godot/tests/fixtures/core.json
//
// The frames are what tools/lib/fxlib.mjs renderFrames() draws into its `bare` frame before edgeFade: the effect
// alone, placed at its origin, stepped by 1 / fps from t = 0.

import { createHash } from "node:crypto";
import { mkdirSync, writeFileSync } from "node:fs";
import { gzipSync } from "node:zlib";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { allIds, resolveIds, loadEffect } from "../../tools/lib/fxlib.mjs";
import * as core from "../../src/core/index.js";

const { createFrame, clearFrame, createFx, painterFor, Rng, PAL, actTiming } = core;
const HERE = dirname(fileURLToPath(import.meta.url));
const OUT = join(HERE, "..", ".parity", "js");

// ---- every Rng.next(), counted and xored, so a simulation that draws a different stream shows up at once
const trace = { n: 0, x: 0 };
Rng.prototype.next = function () {
  let t = (this.s = (this.s + 0x6d2b79f5) >>> 0);
  t = Math.imul(t ^ (t >>> 15), t | 1);
  t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
  const u = (t ^ (t >>> 14)) >>> 0;
  trace.n++;
  trace.x = (trace.x ^ u) >>> 0;
  return u / 4294967296;
};

/** The variants every effect is checked in: options laid over the defaults, and whether it applies. */
export const VARIANTS = {
  default: { opts: {} },
  flip: { opts: { flip: true } },
  angle: { opts: { angle: 0.5 }, when: (m) => !isScreen(m) },
  pal4: { opts: { palette: ["#141024", "#5a3c8c", "#c8a0f0", "#ffffff"] } },
  recolor: { opts: { palette: PAL.poison } },
  seed7: { opts: { seed: 7 } },
  light: { opts: { light: 0.5 } },
  stop: { opts: {}, when: (m) => m.loop, stop: true },
};
const isScreen = (m) => m.size[0] >= 320 && Math.abs(m.size[0] / m.size[1] - 16 / 9) < 0.05;
const sha1 = (u32) => createHash("sha1").update(Buffer.from(u32.buffer, u32.byteOffset, u32.byteLength)).digest("hex");

/** Render one variant: [{ c, l, rn, rx }] per frame, plus the raw frames when asked. */
export function renderVariant(fx, name, raw = false) {
  const { meta, mod } = fx, v = VARIANTS[name], [W, H] = meta.size, [OX, OY] = meta.origin;
  const fps = meta.fps, n = Math.max(1, Math.round(meta.duration * fps) + (meta.loop ? 0 : 1));
  const frame = createFrame(W, H);
  trace.n = 0;
  trace.x = 0;
  const inst = createFx(mod, { x: OX, y: OY, ...v.opts });
  const frames = [], dump = [];
  const total = v.stop ? Math.round((meta.duration * 0.5 + 0.3) * fps) + 1 : n;
  for (let i = 0; i < total; i++) {
    if (i > 0) inst.update(1 / fps);
    if (v.stop && i === Math.round(meta.duration * 0.5 * fps)) inst.stop();
    clearFrame(frame);
    inst.draw(frame);
    frames.push({ c: sha1(frame.color), l: sha1(frame.light), rn: trace.n, rx: trace.x });
    trace.n = 0;
    trace.x = 0;
    if (raw) dump.push(Buffer.from(frame.color.slice().buffer), Buffer.from(frame.light.slice().buffer));
  }
  return { frames, w: W, h: H, dump };
}

function writeRef(fx, names, opts) {
  const { meta, mod } = fx;
  const out = { id: fx.id, src: fx.file, meta: exact({ size: meta.size, origin: meta.origin, fps: meta.fps, duration: meta.duration, loop: meta.loop }), act: mod.act ? exact(actTiming(mod)) : null, variants: {} };
  for (const name of names) {
    const v = VARIANTS[name];
    if (v.when && !v.when(meta)) continue;
    const r = renderVariant(fx, name, opts.dump && (!opts.variant || opts.variant === name));
    out.variants[name] = { w: r.w, h: r.h, opts: exact(v.opts), stopAt: v.stop ? Math.round(meta.duration * 0.5 * meta.fps) : -1, frames: r.frames };
    if (r.dump.length) {
      const head = Buffer.alloc(12);
      head.writeUInt32LE(r.w, 0); head.writeUInt32LE(r.h, 4); head.writeUInt32LE(r.frames.length, 8);
      const file = join(OUT, `${fx.id}.${name}.bin.gz`);
      mkdirSync(dirname(file), { recursive: true });
      writeFileSync(file, gzipSync(Buffer.concat([head, ...r.dump])));
    }
  }
  if (opts.dump) return out; // a dump leaves the reference as it is
  const file = join(OUT, `${fx.id}.json`);
  mkdirSync(dirname(file), { recursive: true });
  writeFileSync(file, JSON.stringify(out));
  return out;
}

// ---- core fixtures for tests/core_test.gd
function fixtures() {
  const { hash, rand, noise, noise2, fbm, tileNoise, tileFbm, loopNoise, fit, blend, mix, scale, luma, at, hex, ease, ramp } = core;
  const nums = [0, 1, 2, 3, -1, -7, 0.5, -0.5, 2.75, -3.25, 1e6, 123456.789, 4294967295, 4294967296, -2147483649, 911];
  const out = { hash: [], rand: [], rng: [], noise: [], noise2: [], fbm: [], tile: [], loop: [], color: [], ease: [], hypot: [], round: [], painter: [] };
  for (let i = 0; i < nums.length; i++)
    for (let j = 0; j < nums.length; j += 3) {
      out.hash.push({ a: [nums[i], nums[j]], v: hash(nums[i], nums[j]) });
      out.rand.push({ a: [nums[i], nums[j], i], v: rand(nums[i], nums[j], i) });
    }
  out.hash.push({ a: [1], v: hash(1) }, { a: [1, 2, 3, 4, 5, 6], v: hash(1, 2, 3, 4, 5, 6) }, { a: [5, -2.5, 911, 3, 1], v: hash(5, -2.5, 911, 3, 1) });
  for (const seed of [1, 2, 7, 0, 3.7, -5, 4294967296, 12345]) {
    const r = new Rng(seed), seq = [];
    for (let i = 0; i < 12; i++) seq.push(r.next());
    out.rng.push({ seed, seq, range: r.range(-3, 9), int: r.int(2, 11), chance: r.chance(0.4), sign: r.sign(), gauss: r.gauss(), pick: r.pick([10, 20, 30, 40, 50]) });
  }
  for (let i = 0; i < 40; i++) {
    const x = i * 0.37 - 5.3, y = i * 0.61 - 9.1;
    out.noise.push({ a: [x, i], v: noise(x, i) });
    out.noise2.push({ a: [x, y, i % 5], v: noise2(x, y, i % 5) });
    out.fbm.push({ a: [x, y, i % 3, 1 + (i % 4)], v: fbm(x, y, i % 3, 1 + (i % 4)) });
    out.tile.push({ a: [x, y, i % 7, 6, i % 4], v: tileNoise(x, y, i % 7, 6, i % 4), f: tileFbm(x, y, i % 7, 6, i % 4, 3) });
    out.loop.push({ a: [i / 40, 1.5, i % 3], v: loopNoise(i / 40, 1.5, i % 3) });
    out.hypot.push({ a: [x * 13.1, y * 0.7], v: Math.hypot(x * 13.1, y * 0.7), a3: [x, y, i * 0.3], v3: Math.hypot(x, y, i * 0.3) });
    out.round.push({ a: x * 2.5, v: Math.round(x * 2.5) });
  }
  for (const v of [0.5, -0.5, 1.5, -1.5, 2.5, -2.5, 0.49999999999999994, -0.49999999999999994]) out.round.push({ a: v, v: Math.round(v) });
  const R = ramp(PAL.fire);
  for (let i = 0; i <= 20; i++) {
    const t = i / 20 - 0.1;
    out.color.push({ t, fit5: fit(PAL.ice, 5), fit11: fit(PAL.ice, 11), at: at(R, t), blend: blend(R, t), mix: mix(R[1], R[6], t), scale: scale(R[4], 0.3 + t * 2), luma: luma(R[i % R.length]), hex: hex(PAL.candy[i % 7]) });
  }
  for (const [name, f] of Object.entries(ease)) for (let i = 0; i <= 10; i++) out.ease.push({ name, t: i / 10, v: f(i / 10) });
  // the painter: each case draws into a 48 x 40 frame from a placement; both sides hash the buffers
  for (const c of PAINTER_CASES) {
    const f = createFrame(48, 40), p = painterFor(f);
    p.place(24, 22, c.flip ?? false, c.angle ?? 0);
    if (c.fade) p.fade = c.fade;
    drawCase(core, p, c.draw);
    out.painter.push({ name: c.name, pi: c.pi, si: c.si, c: sha1(f.color), l: sha1(f.light) });
  }
  const file = join(HERE, "..", "tests", "fixtures", "core.json");
  mkdirSync(dirname(file), { recursive: true });
  writeFileSync(file, JSON.stringify(exact(out)));
  console.log(`wrote ${file}`);
}

/** Godot's JSON reader rounds some doubles: every non-integer number goes as its exact bytes, { "$d": hex }. */
function exact(v) {
  if (typeof v === "number" && !Number.isSafeInteger(v)) {
    const b = Buffer.alloc(8);
    b.writeDoubleLE(v);
    return { $d: b.toString("hex") };
  }
  if (Array.isArray(v)) return v.map(exact);
  if (v && typeof v === "object") return Object.fromEntries(Object.entries(v).map(([k, x]) => [k, exact(x)]));
  return v;
}

// Painter cases are plain data so tests/core_test.gd can replay the same calls. Colors are hex strings;
// "fn:<name>" stands for one of the callbacks defined in drawCase (and its GDScript twin).
const PAINTER_CASES = [];
const placements = [{}, { flip: true }, { angle: 0.6 }, { flip: true, angle: -2.2 }, { fade: 0.55 }];
const shapes = [
  ["circle", [0, 0, 9, "#ff4020"]], ["circle", [3, -2, 7, "fn:dcol", "fn:dalpha"]], ["circle", [1, 1, 0.4, "#ffffff"]],
  ["ellipse", [0, 2, 14, 5, "fn:dcol"]], ["ring", [0, 0, 12, 3, "fn:vcol"]], ["arc", [0, 0, 15, 5, -2.5, 0.9, "fn:uvcol", "fn:ualpha"]],
  ["arc", [0, 0, 15, "fn:taper", -1, 2, "#a0e0ff"]], ["line", [-18, -12, 16, 9, "fn:ucol"]], ["line", [10, -15, -12, 14, "#ffee88", 0.5]],
  ["beam", [-14, 6, 15, -8, 5, "fn:uvcol"]], ["rect", [-10, -6, 17, 9, "#40c060", 0.7]], ["poly", [[[-12, 8], [0, -14], [13, 6], [2, 1]], "fn:xycol"]],
  ["tri", [-5, -5, 9, -2, 1, 11, "#8040ff"]], ["glow", [0, 0, 16, "#ff8a2a", 0.8]], ["glowLine", [-15, 10, 14, -11, 6, "#3f8cff", 0.6]],
  ["glowRing", [0, 0, 11, 4, "#ffd84a", 0.7]], ["disc", [-3, 2, 9, "#7b6f72", 0.5]], ["disc", [4, -3, 6, "fn:dcol", "fn:dalpha"]],
  ["dot", [5, 5, "#ffffff", 0.4]], ["blend", [-6, 4, "#20a0ff", 0.6]], ["text", ["LV 12!", -18, -10, "#ffe066", { font: "mini", scale: 2, outline: "#140c18", align: "left" }]],
  ["text", ["GO", 0, -6, "fn:xycol", { font: "big", align: "center", shadow: "#000000" }]], ["sprite", [["..##..", ".#oo#.", "#oOOo#", ".#oo#."], { "#": "#222034", o: "#f0b424", O: "#fff6c4" }, -6, -4, { scale: 2 }]],
  ["sparkle", [2, -3, 7, "#9bdcff", "#2f7fcc", 0.6]], ["flare", [0, 0, 14, 0.5, PAL.holy]], ["band", [0, 4, 16, 0.3, 4, 0.9, PAL.ice, "fn:far", true]],
  ["crystal", [0, 12, 26, 9, 4, PAL.ice, { glint: 0.4 }]], ["crystal", [6, 10, 14, 6, -3, PAL.arcane, { a: 0.7 }]],
];
placements.forEach((pl, pi) => shapes.forEach(([m, args], si) => PAINTER_CASES.push({ name: `${m} ${JSON.stringify(pl)} #${si}`, pi, si, ...pl, draw: [m, args] })));

function drawCase(core, p, [m, args]) {
  const { hex, at, ramp, mix, WHITE, sparkle, flare, band, crystal } = core;
  const R = ramp(PAL.fire);
  const fns = {
    dcol: (d) => at(R, 1 - d), dalpha: (d, a) => 1 - d * 0.6 + Math.sin(a) * 0.1, vcol: (v, a) => (Math.cos(a * 3) > 0 ? R[2 + Math.floor(v * 4)] : R[7]),
    uvcol: (u, v) => at(R, 1 - u * 0.5 - v * 0.4), ualpha: (u) => Math.min(1, u * 2), taper: (u) => 6 * Math.sin(Math.PI * u), ucol: (u) => mix(R[2], WHITE, u),
    xycol: (x, y) => ((Math.floor(x) + Math.floor(y)) & 1 ? R[5] : R[3]), far: (g) => Math.sin(g) < 0,
  };
  const a = args.map((v) => (typeof v === "string" && v.startsWith("fn:") ? fns[v.slice(3)] : typeof v === "string" && v.startsWith("#") ? hex(v) : v));
  if (m === "text") a[4] = { ...a[4], outline: a[4].outline && hex(a[4].outline), shadow: a[4].shadow && hex(a[4].shadow) };
  if (m === "sparkle") return sparkle(p, ...a);
  if (m === "flare") return flare(p, ...a);
  if (m === "band") return band(p, ...a);
  if (m === "crystal") return crystal(p, ...a);
  return p[m](...a);
}

// ---- command line
const args = process.argv.slice(2), flags = {}, pos = [];
for (let i = 0; i < args.length; i++) {
  if (["--dump", "--fixtures"].includes(args[i])) flags[args[i].slice(2)] = true;
  else if (args[i].startsWith("--")) flags[args[i].slice(2)] = args[++i];
  else pos.push(args[i]);
}
if (flags.fixtures) {
  fixtures();
  process.exit(0);
}
const names = flags.variants ? flags.variants.split(",") : flags.variant ? [flags.variant] : Object.keys(VARIANTS);
const ids = pos.length ? resolveIds(pos) : allIds();
let failed = 0;
const t0 = Date.now();
for (const id of ids) {
  try {
    const fx = await loadEffect(id);
    const r = writeRef(fx, names, flags);
    if (ids.length <= 12) console.log(`${id}  ${Object.entries(r.variants).map(([k, v]) => `${k}:${v.frames.length}`).join(" ")}`);
  } catch (e) {
    failed++;
    console.error(`${id}  FAILED: ${e.stack ?? e}`);
  }
}
console.log(`${ids.length} effects, variants ${names.join(",")}, ${((Date.now() - t0) / 1000).toFixed(1)} s -> ${OUT}`);
process.exit(failed ? 1 : 0);
