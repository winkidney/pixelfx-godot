// What an upstream merge left for the particle port to redo. Every build script (build/fx/<cat>/<name>.gd) starts with
// `# reimagined-from: src/fx/<cat>/<name>.js@<git blob>`: the original it was made from. This compares those blobs with
// the originals as they are now and lists
//   stale     the original changed since the scene was made: `git diff <old> <new>` shows how
//   missing   an original with no scene yet
//   orphaned  a scene whose original is gone
//   node godot-particle/port/sync.mjs [--json]
//   node godot-particle/port/sync.mjs --stamp <ids...>   after redoing them: record the current blobs
// Re-export port/meta.json first (cd godot && ./pfx export meta --out ../godot-particle/port) so sizes and timings
// are the new ones; `./pfxp check` holds every scene to them.
import { execFileSync } from "node:child_process";
import { readFileSync, writeFileSync, readdirSync, existsSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = join(HERE, "..");
const REPO = join(ROOT, "..");
const blob = (p) => execFileSync("git", ["hash-object", p], { cwd: REPO, encoding: "utf8" }).trim();
const HEAD = /^# reimagined-from: (src\/fx\/[^@\s]+)@([0-9a-f]*)/m;

function originals() {
  const out = [];
  for (const cat of readdirSync(join(REPO, "src/fx"), { withFileTypes: true })) {
    if (!cat.isDirectory()) continue;
    for (const f of readdirSync(join(REPO, "src/fx", cat.name)))
      if (f.endsWith(".js") && !f.startsWith("_")) out.push(`${cat.name}/${f.slice(0, -3)}`);
  }
  return out.sort();
}

function scripts() {
  const out = {};
  const base = join(ROOT, "build/fx");
  if (!existsSync(base)) return out;
  for (const cat of readdirSync(base, { withFileTypes: true })) {
    if (!cat.isDirectory()) continue;
    for (const f of readdirSync(join(base, cat.name)))
      if (f.endsWith(".gd")) out[`${cat.name}/${f.slice(0, -3)}`] = join(base, cat.name, f);
  }
  return out;
}

const args = process.argv.slice(2);
if (args[0] === "--stamp") {
  const all = scripts();
  for (const id of args.slice(1)) {
    const path = all[id];
    if (!path) { console.error(`${id}: no build script`); continue; }
    const src = `src/fx/${id}.js`;
    const text = readFileSync(path, "utf8");
    const line = `# reimagined-from: ${src}@${blob(src)}`;
    writeFileSync(path, HEAD.test(text) ? text.replace(/^# reimagined-from: .*$/m, line) : `${line}\n${text}`);
    console.log(`stamped ${id}`);
  }
  process.exit(0);
}

const all = scripts();
const report = { stale: [], missing: [], orphaned: [], unstamped: [], ok: 0 };
for (const id of originals()) {
  const path = all[id];
  if (!path) { report.missing.push(id); continue; }
  const m = HEAD.exec(readFileSync(path, "utf8"));
  const now = blob(`src/fx/${id}.js`);
  if (!m || !m[2]) report.unstamped.push(id);
  else if (m[2] !== now) report.stale.push({ id, from: m[2], to: now });
  else report.ok++;
}
for (const id of Object.keys(all)) if (!existsSync(join(REPO, `src/fx/${id}.js`))) report.orphaned.push(id);

if (args.includes("--json")) {
  console.log(JSON.stringify(report, null, 1));
} else {
  for (const s of report.stale) console.log(`stale     ${s.id}   git diff ${s.from.slice(0, 10)} ${s.to.slice(0, 10)}`);
  for (const id of report.unstamped) console.log(`unstamped ${id}`);
  for (const id of report.orphaned) console.log(`orphaned  ${id}`);
  if (report.missing.length) console.log(`missing   ${report.missing.length}: ${report.missing.slice(0, 12).join(" ")}${report.missing.length > 12 ? " ..." : ""}`);
  console.log(`\n${report.ok + report.stale.length + report.unstamped.length} scenes of ${originals().length} originals: ` +
    `${report.ok} current, ${report.stale.length} stale, ${report.unstamped.length} unstamped, ${report.missing.length} missing, ${report.orphaned.length} orphaned`);
}
process.exit(report.stale.length || report.orphaned.length || report.unstamped.length ? 1 : 0);
