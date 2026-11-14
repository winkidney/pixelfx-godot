# The review gallery: every compared effect (and act) side by side with the original, for a person to look over.
# Reads records/compare[-act]/<id>/metrics.json and side.webp (port/compare.py writes them) and writes
# records/review/index.html, linking those files where they are. Open it in a browser.
#   python3 port/review.py
import html, json, os

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
REC = os.path.join(ROOT, "records")
META = json.load(open(os.path.join(HERE, "meta.json")))
OUT = os.path.join(REC, "review")


def load(kind):
    base = os.path.join(REC, kind)
    rows = []
    for cat in sorted(os.listdir(base)) if os.path.isdir(base) else []:
        cdir = os.path.join(base, cat)
        if not os.path.isdir(cdir):
            continue
        for name in sorted(os.listdir(cdir)):
            m = os.path.join(cdir, name, "metrics.json")
            if os.path.exists(m) and os.path.exists(os.path.join(cdir, name, "side.webp")):
                d = json.load(open(m))
                d["side"] = os.path.relpath(os.path.join(cdir, name, "side.webp"), OUT)
                rows.append(d)
    return rows


def tone(s):
    return "good" if s >= 0.9 else "ok" if s >= 0.75 else "low"


def card(d):
    meta = META.get(d["id"], {})
    parts = " · ".join(f"{k[:3]} {d[k]:.2f}" for k in ("activity", "extent", "colour", "motion"))
    return (
        f'<figure class="{tone(d["score"])}" data-score="{d["score"]}">'
        f'<img loading="lazy" src="{html.escape(d["side"])}" alt="{html.escape(d["id"])}">'
        f'<figcaption><b>{html.escape(d["id"])}</b> <span class="s">{d["score"]:.3f}</span>'
        f'<br><small>{html.escape(meta.get("name", ""))} — {parts}</small></figcaption></figure>'
    )


def section(title, rows):
    if not rows:
        return ""
    cats = {}
    for d in rows:
        cats.setdefault(d["id"].split("/")[0], []).append(d)
    out = [f"<h2>{html.escape(title)}</h2>"]
    for cat in sorted(cats):
        rs = sorted(cats[cat], key=lambda d: d["score"])
        mean = sum(d["score"] for d in rs) / len(rs)
        out.append(f'<h3 id="{title[:3]}-{cat}">{cat} <small>{len(rs)} · mean {mean:.3f} · lowest first</small></h3>')
        out.append('<div class="grid">' + "".join(card(d) for d in rs) + "</div>")
    return "\n".join(out)


def main():
    os.makedirs(OUT, exist_ok=True)
    fx, acts = load("compare"), load("compare-act")
    allfx = [d for d in fx]
    mean = sum(d["score"] for d in allfx) / max(1, len(allfx))
    low = sum(1 for d in allfx if d["score"] < 0.75)
    page = f"""<!doctype html><meta charset="utf-8"><title>pixelfx particles: review</title>
<style>
body {{ background: #15131a; color: #ddd; font: 14px system-ui, sans-serif; margin: 24px; }}
h2 {{ border-bottom: 1px solid #444; padding-bottom: 4px; }} h3 small, figcaption small {{ color: #999; font-weight: normal; }}
.grid {{ display: flex; flex-wrap: wrap; gap: 14px; }}
figure {{ margin: 0; background: #1e1b25; padding: 8px; border-left: 4px solid #555; }}
figure.good {{ border-color: #3c9a5f; }} figure.ok {{ border-color: #c9a227; }} figure.low {{ border-color: #c94a3a; }}
img {{ image-rendering: pixelated; display: block; max-width: 720px; }}
.s {{ float: right; }}
</style>
<h1>pixelfx particles — original (left) vs Godot native particles (right)</h1>
<p>{len(allfx)} effects, mean score {mean:.3f}, {low} below 0.75; {len(acts)} acts. Score = 0.3 activity + 0.25 extent
+ 0.25 colour + 0.2 motion against the original's frames. Each category lists its lowest scores first. Green ≥ 0.9,
yellow ≥ 0.75, red below.</p>
{section("Effects", fx)}
{section("Acts (with the knight, 60 fps)", acts)}
"""
    open(os.path.join(OUT, "index.html"), "w").write(page)
    print(f"{len(allfx)} effects, {len(acts)} acts -> {os.path.join(OUT, 'index.html')}")


if __name__ == "__main__":
    main()
