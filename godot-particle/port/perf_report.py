# The performance comparison: the pixel port (godot/, CPU rasterized, LIVE every frame or BAKED once and replayed)
# against the particle port (godot-particle/, GPU particles and shaders), effect by effect, on the same machine.
# Reads what `./pfx perf --mode live|baked` and `./pfxp perf` wrote (records/perf/*.json in each project; several
# runs of a port as <port>.json, <port>.2.json, ... are merged by their median) and writes records/perf/summary.json
# and records/perf/index.html here.
#   python3 port/perf_report.py
import glob, html, json, math, os, statistics

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
PIXEL = os.path.join(ROOT, "..", "godot", "records", "perf")
OUT = os.path.join(ROOT, "records", "perf")
META = json.load(open(os.path.join(HERE, "meta.json")))
PORTS = {"particle": OUT, "pixel-live": PIXEL, "pixel-baked": PIXEL}


def runs(port):
    files = sorted(glob.glob(os.path.join(PORTS[port], port + ".json")) + glob.glob(os.path.join(PORTS[port], port + ".[0-9]*.json")))
    return [json.load(open(f)) for f in files]


def med(xs):
    xs = [x for x in xs if x is not None]
    return statistics.median(xs) if xs else None


def merged(port):
    """id -> {single, crowd, bake?: frame / gpu ms means (medians over runs), minus the empty scene's frame}, machine."""
    rs = runs(port)
    if not rs:
        return {}, {}, 0, []
    base = med(r["baseline"]["frame_ms"]["mean"] for r in rs)
    out = {}
    spread = []
    for fid in rs[0]["effects"]:
        row = {}
        for part in ("single", "crowd", "bake"):
            got = [r["effects"][fid][part] for r in rs if fid in r["effects"] and part in r["effects"][fid]]
            if not got:
                continue
            frames = [g["frame_ms"]["mean"] for g in got]
            row[part] = {
                "frame": med(frames), "net": max(0.0, med(frames) - base), "p95": med(g["frame_ms"]["p95"] for g in got),
                "max": med(g["frame_ms"]["max"] for g in got), "gpu": med(g["gpu_ms"]["mean"] for g in got),
                "calls": med(g["draw_calls"]["mean"] for g in got), "frames": med(g["frames"] for g in got),
                "mem": med(g.get("video_mem_mb") for g in got),
            }
            if len(frames) > 1 and min(frames) > 0:
                spread.append((max(frames) / min(frames) - 1.0, fid, part))
        out[fid] = row
    return out, rs[0]["machine"], base, spread


def gmean(xs):
    xs = [x for x in xs if x and x > 0]
    return math.exp(sum(math.log(x) for x in xs) / len(xs)) if xs else None


def main():
    os.makedirs(OUT, exist_ok=True)
    P, machine, pbase, pspread = merged("particle")
    L, _, lbase, lspread = merged("pixel-live")
    B, _, bbase, bspread = merged("pixel-baked")
    rows = []
    for fid in sorted(META):
        if fid not in P:
            continue
        p, l, b = P[fid], L.get(fid, {}), B.get(fid, {})
        r = {"id": fid, "name": META[fid].get("name", ""), "loop": META[fid].get("loop"),
             "particle": p, "live": l, "baked": b}
        # speed-ups use the frame beyond the empty scene's (the engine's own floor), and a crowd's whole frame
        if l.get("single") and p.get("single"):
            r["x_single"] = (l["single"]["net"] + 0.01) / (p["single"]["net"] + 0.01)
        if l.get("crowd") and p.get("crowd"):
            r["x_crowd"] = l["crowd"]["frame"] / p["crowd"]["frame"]
            r["fps_particle"] = 1000.0 / p["crowd"]["frame"]
            r["fps_live"] = 1000.0 / l["crowd"]["frame"]
        if b.get("crowd"):
            r["fps_baked"] = 1000.0 / b["crowd"]["frame"]
        if b.get("bake") and b.get("single"):
            # what baking costs on top of replaying: the first play's extra time, summed over its frames
            r["bake_ms"] = max(0.0, (b["bake"]["frame"] - b["single"]["frame"]) * b["bake"]["frames"])
        rows.append(r)
    cats = {}
    for r in rows:
        cats.setdefault(r["id"].split("/")[0], []).append(r)

    def agg(rs):
        return {
            "n": len(rs),
            "particle_ms": statistics.mean(r["particle"]["single"]["frame"] for r in rs),
            "live_ms": statistics.mean(r["live"]["single"]["frame"] for r in rs if r["live"].get("single")) if any(r["live"].get("single") for r in rs) else None,
            "baked_ms": statistics.mean(r["baked"]["single"]["frame"] for r in rs if r["baked"].get("single")) if any(r["baked"].get("single") for r in rs) else None,
            "particle_crowd_ms": statistics.mean(r["particle"]["crowd"]["frame"] for r in rs),
            "live_crowd_ms": statistics.mean(r["live"]["crowd"]["frame"] for r in rs if r["live"].get("crowd")) if any(r["live"].get("crowd") for r in rs) else None,
            "baked_crowd_ms": statistics.mean(r["baked"]["crowd"]["frame"] for r in rs if r["baked"].get("crowd")) if any(r["baked"].get("crowd") for r in rs) else None,
            "x_single": gmean([r.get("x_single") for r in rs]),
            "x_crowd": gmean([r.get("x_crowd") for r in rs]),
            "bake_ms": statistics.mean(r["bake_ms"] for r in rs if "bake_ms" in r) if any("bake_ms" in r for r in rs) else None,
            "slower": [r["id"] for r in rs if r.get("x_crowd") and r["x_crowd"] < 1.0],
        }

    spread = sorted(pspread + lspread + bspread, reverse=True)
    summary = {"machine": machine, "baseline_ms": {"particle": pbase, "pixel-live": lbase, "pixel-baked": bbase},
               "crowd": runs("particle")[0]["stress"] if P else None, "all": agg(rows),
               "categories": {c: agg(rs) for c, rs in sorted(cats.items())},
               "effects": {r["id"]: {k: v for k, v in r.items() if k != "id"} for r in rows},
               "unstable": [{"id": f, "part": part, "spread": round(s, 3)} for s, f, part in spread if s > 0.15]}
    json.dump(summary, open(os.path.join(OUT, "summary.json"), "w"), indent=1, ensure_ascii=False)
    write_html(summary, cats)
    a = summary["all"]
    print(f"{a['n']} effects: particle {a['particle_ms']:.3f} ms, live {a['live_ms'] or 0:.3f} ms, baked {a['baked_ms'] or 0:.3f} ms "
          f"(1 each); crowd x{summary['crowd']}: particle {a['particle_crowd_ms']:.2f} ms, live {a['live_crowd_ms'] or 0:.2f} ms; "
          f"speed-up vs live: x{a['x_single'] or 0:.1f} single, x{a['x_crowd'] or 0:.1f} crowd; "
          f"{len(summary['unstable'])} measurements spread > 15% between runs -> {os.path.join(OUT, 'index.html')}")


def fmt(v, d=2):
    return "–" if v is None else f"{v:.{d}f}"


def write_html(s, cats):
    m = s["machine"]
    rows = []
    for c, rs in sorted(cats.items()):
        a = s["categories"][c]
        rows.append(f'<tr class="cat"><th colspan="10">{html.escape(c)} — {a["n"]} effects · ×{fmt(a["x_single"], 1)} single, ×{fmt(a["x_crowd"], 1)} crowd vs LIVE</th></tr>')
        for r in rs:
            p, l, b = r["particle"], r["live"], r["baked"]
            slow = ' class="slow"' if r.get("x_crowd") and r["x_crowd"] < 1 else ""
            rows.append(
                f'<tr{slow}><td>{html.escape(r["id"])}</td>'
                f'<td>{fmt(l.get("single", {}).get("frame"))}</td><td>{fmt(b.get("single", {}).get("frame"))}</td><td>{fmt(p["single"]["frame"])}</td>'
                f'<td>{fmt(l.get("crowd", {}).get("frame"), 1)}</td><td>{fmt(b.get("crowd", {}).get("frame"), 1)}</td><td>{fmt(p["crowd"]["frame"], 1)}</td>'
                f'<td>×{fmt(r.get("x_single"), 1)}</td><td>×{fmt(r.get("x_crowd"), 1)}</td><td>{fmt(r.get("bake_ms"), 0)}</td></tr>')
    a = s["all"]
    page = f"""<!doctype html><meta charset="utf-8"><title>pixelfx: performance</title>
<style>body{{background:#15131a;color:#ddd;font:13px system-ui,sans-serif;margin:24px}} table{{border-collapse:collapse}}
td,th{{padding:3px 9px;border-bottom:1px solid #2c2834;text-align:right}} td:first-child{{text-align:left}}
tr.cat th{{text-align:left;background:#221f2a;padding-top:12px}} tr.slow td{{color:#e8806e}} small{{color:#999}}</style>
<h1>pixelfx — pixel port vs native particles: runtime cost</h1>
<p>{html.escape(m.get("gpu", ""))} · {html.escape(m.get("cpu", ""))} · {html.escape(m.get("method", ""))}/{html.escape(m.get("driver", ""))} ·
Godot {html.escape(m.get("godot", ""))} · 1280×720, vsync off. Frame time in ms (mean over the effect's duration, 3 s for a
loop; the empty scene takes {fmt(s["baseline_ms"]["particle"], 3)} ms). LIVE rasterizes every frame on the CPU; BAKED renders each
frame once on first show (bake column: its extra ms over the first play) and replays textures after; particles run on the GPU.
Crowd: {s["crowd"]} instances at once. Speed-up: LIVE ÷ particles (single: beyond the empty scene). Red: particles slower than LIVE in a crowd.</p>
<p><b>All {a["n"]}:</b> single LIVE {fmt(a["live_ms"], 3)} · BAKED {fmt(a["baked_ms"], 3)} · particles {fmt(a["particle_ms"], 3)} ms;
crowd LIVE {fmt(a["live_crowd_ms"], 1)} · BAKED {fmt(a["baked_crowd_ms"], 1)} · particles {fmt(a["particle_crowd_ms"], 1)} ms;
geometric-mean speed-up ×{fmt(a["x_single"], 1)} single, ×{fmt(a["x_crowd"], 1)} crowd.</p>
<table><tr><th>effect</th><th>LIVE 1</th><th>BAKED 1</th><th>particles 1</th><th>LIVE ×{s["crowd"]}</th><th>BAKED ×{s["crowd"]}</th>
<th>particles ×{s["crowd"]}</th><th>speed-up 1</th><th>speed-up crowd</th><th>bake ms</th></tr>
{"".join(rows)}</table>"""
    open(os.path.join(OUT, "index.html"), "w").write(page)


if __name__ == "__main__":
    main()
