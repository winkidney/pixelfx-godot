#!/usr/bin/env node
// Keep the Godot port in step with upstream pixelfx (github.com/patch-gg/pixelfx).
//
//   node godot/port/sync.mjs                 what's out of date: every .gd's `port-of:` line against the JS it came from
//   node godot/port/sync.mjs --setup         add the `upstream` remote and the merge driver .gitattributes relies on
//   node godot/port/sync.mjs --stamp <ids>   after re-porting: write the JS file's current blob into the .gd's port-of line
//   node godot/port/sync.mjs --json          the report as JSON
//
// The loop (godot/docs/UPSTREAM.md): git fetch upstream && git merge upstream/main, then this script, then re-port each
// stale or missing file (the pixelfx-godot skill knows how), ./pfx parity, --stamp, commit.

import { execFileSync } from "node:child_process";
import { readFileSync, writeFileSync, readdirSync, statSync, existsSync } from "node:fs";
import { join, relative, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..", "..");
const GD = join(ROOT, "godot", "addons", "pixelfx");
const git = (...a) => execFileSync("git", a, { cwd: ROOT, encoding: "utf8" }).trim();
const blob = (file) => git("hash-object", file);
const args = process.argv.slice(2);

if (args.includes("--setup")) {
  const remotes = git("remote").split("\n");
  if (!remotes.includes("upstream")) git("remote", "add", "upstream", "https://github.com/patch-gg/pixelfx");
  // README.md and the plugin marketplace are ours: keep them on merges (see .gitattributes)
  git("config", "merge.ours.driver", "true");
  console.log("upstream remote and merge.ours driver set. Next: git fetch upstream && git merge upstream/main");
  process.exit(0);
}

/** Every .gd under the addon with the port-of lines in it: [{ gd, js, blob }]. */
function portLines() {
  const out = [];
  const walk = (d) => {
    for (const f of readdirSync(d)) {
      const p = join(d, f);
      if (statSync(p).isDirectory()) walk(p);
      else if (f.endsWith(".gd"))
        for (const m of readFileSync(p, "utf8").matchAll(/^# port-of: (\S+?)@([0-9a-f]{40})/gm)) out.push({ gd: relative(ROOT, p), js: m[1], blob: m[2] });
    }
  };
  walk(GD);
  return out;
}

/** Every upstream source the port is meant to cover: core modules and every effect and helper. */
function sources() {
  const list = [];
  for (const f of readdirSync(join(ROOT, "src", "core"))) if (f.endsWith(".js") && f !== "index.js") list.push(`src/core/${f}`);
  const fx = join(ROOT, "src", "fx");
  for (const cat of readdirSync(fx)) {
    const d = join(fx, cat);
    if (!statSync(d).isDirectory()) continue;
    for (const f of readdirSync(d)) if (f.endsWith(".js")) list.push(`src/fx/${cat}/${f}`);
  }
  list.push("src/fx/categories.js");
  return list.sort();
}

if (args.includes("--stamp")) {
  const ids = args.filter((a) => !a.startsWith("--"));
  let n = 0;
  for (const id of ids) {
    const gd = join(GD, "fx", `${id}.gd`), js = `src/fx/${id}.js`;
    if (!existsSync(gd) || !existsSync(join(ROOT, js))) {
      console.error(`${id}: no ${relative(ROOT, gd)} or ${js}`);
      continue;
    }
    const src = readFileSync(gd, "utf8"), b = blob(js), line = `# port-of: ${js}@${b}`;
    const next = /^# port-of: \S+@[0-9a-f]{40}.*$/m.test(src) ? src.replace(/^# port-of: \S+@[0-9a-f]{40}.*$/m, line) : `${line}\n${src}`;
    writeFileSync(gd, next);
    n++;
  }
  console.log(`stamped ${n} file${n === 1 ? "" : "s"}`);
  process.exit(0);
}

const lines = portLines();
const ported = new Map();
for (const l of lines) (ported.get(l.js) ?? ported.set(l.js, []).get(l.js)).push(l);
const stale = [], missing = [], orphans = [];
for (const js of sources()) {
  const ls = ported.get(js);
  if (!ls) {
    missing.push(js);
    continue;
  }
  const now = blob(js);
  for (const l of ls) if (l.blob !== now) stale.push({ ...l, now });
}
for (const [js, ls] of ported) if (!existsSync(join(ROOT, js))) orphans.push(...ls);

if (args.includes("--json")) {
  console.log(JSON.stringify({ stale, missing, orphans }, null, 1));
} else {
  for (const s of stale) console.log(`stale    ${s.gd}\n         ${s.js} changed: git diff ${s.blob.slice(0, 10)} ${s.now.slice(0, 10)}`);
  for (const m of missing) console.log(`missing  ${m}  (no .gd says it is a port of it)`);
  for (const o of orphans) console.log(`orphan   ${o.gd}  (${o.js} is gone upstream)`);
  console.log(`\n${sources().length} upstream files: ${stale.length} stale, ${missing.length} missing, ${orphans.length} orphaned`);
}
process.exit(stale.length || missing.length || orphans.length ? 1 : 0);
