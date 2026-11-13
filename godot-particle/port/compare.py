# Frames of a particle effect (records/render/<id>/) against the pixel port's reference (godot/records/gallery/<id>/
# anim.webp, lossless and identical to the JS original). Not a pixel match: a reimagining is judged on what it does.
# Both are measured against the same backdrop: the render's, which is the original's pixel for pixel.
#   activity  how much of the canvas the effect covers frame by frame: the curve's shape and its total
#   extent    where it ever draws: IoU of the two footprints, each widened by 3 px
#   colour    which colours it draws: overlap of the two OKLab histograms
#   motion    where its mass is frame by frame: centroid distance against the canvas diagonal
#   score     0.3 activity + 0.25 extent + 0.25 colour + 0.2 motion
# Writes records/compare/<id>/metrics.json, sheet.png (REF above PARTICLE) and side.webp (both, side by side, x2).
#   python3 port/compare.py <ids|categories|*> [--min SCORE] [--json]
import glob, json, os, sys
import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
REF = os.path.join(ROOT, "..", "godot", "records", "gallery")
META = json.load(open(os.path.join(HERE, "meta.json")))
WEIGHTS = {"activity": 0.3, "extent": 0.25, "colour": 0.25, "motion": 0.2}


def ids_for(args):
    out = []
    for a in args:
        if a in ("*", "all"):
            out += sorted(META)
        elif "/" in a and "*" not in a:
            out.append(a)
        else:
            pat = a if "/" in a else a + "/*"
            import fnmatch
            out += sorted(i for i in META if fnmatch.fnmatch(i, pat))
    seen = set()
    return [i for i in out if not (i in seen or seen.add(i))]


ACT = os.path.join(ROOT, "..", "godot", "records", "act")
MODE = {"act": False}


def ref_frames(fid):
    path = os.path.join(ACT, fid.replace("/", "-") + ".webp") if MODE["act"] else os.path.join(REF, fid, "anim.webp")
    if not os.path.exists(path):
        raise FileNotFoundError(f"{path}: render the reference first (cd godot && ./pfx render {fid} --webp --scale 1 --out res://records/gallery)")
    # the encoder merges identical neighbouring frames into one longer frame: spread them back onto 30 fps
    frames, ends, t = [], [], 0
    with Image.open(path) as im:
        for i in range(getattr(im, "n_frames", 1)):
            im.seek(i)
            frames.append(np.asarray(im.convert("RGB")).copy())
            t += im.info.get("duration", 33) or 33
            ends.append(t)
    fps = 60 if MODE["act"] else 30
    n = max(1, int(round(t * fps / 1000)))
    out, j = [], 0
    for k in range(n):
        tk = (k + 0.5) * 1000 / fps
        while j < len(ends) - 1 and ends[j] <= tk:
            j += 1
        out.append(frames[j])
    return out


def pfx_frames(fid):
    d = os.path.join(ROOT, "records", "render-act" if MODE["act"] else "render", fid)
    files = sorted(f for f in glob.glob(os.path.join(d, "[0-9]*.png")))
    if not files:
        raise FileNotFoundError(f"{d}: nothing rendered (./pfxp render {fid})")
    frames = [np.asarray(Image.open(f).convert("RGB")) for f in files]
    bg = np.asarray(Image.open(os.path.join(d, "backdrop.png")).convert("RGB"))
    return frames, bg


def mode_backdrop(frames, k=16):
    """The colour each pixel has most often across k frames: the backdrop under an effect that moves."""
    idx = np.linspace(0, len(frames) - 1, min(k, len(frames))).astype(int)
    a = np.stack([frames[i] for i in idx]).astype(np.uint32)
    packed = (a[..., 0] << 16) | (a[..., 1] << 8) | a[..., 2]          # k, h, w
    k_, h, w = packed.shape
    flat = packed.reshape(k_, -1)
    counts = np.zeros_like(flat)
    for i in range(k_):
        counts[i] = (flat == flat[i]).sum(axis=0)
    best = flat[counts.argmax(axis=0), np.arange(flat.shape[1])]
    out = np.stack([(best >> 16) & 255, (best >> 8) & 255, best & 255], axis=-1).reshape(h, w, 3)
    return out.astype(np.uint8)


def active(frames, bg, t=24):
    """Pixels clearly drawn on (not just faintly lit): what activity, extent and motion measure."""
    return [np.abs(f.astype(int) - bg.astype(int)).max(axis=2) > t for f in frames]


def dilate(m, r):
    out = m.copy()
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            out |= np.roll(np.roll(m, dy, 0), dx, 1)
    return out


def oklab(rgb):
    c = rgb.astype(float) / 255.0
    c = np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)
    l = 0.4122214708 * c[:, 0] + 0.5363325363 * c[:, 1] + 0.0514459929 * c[:, 2]
    m = 0.2119034982 * c[:, 0] + 0.6806995451 * c[:, 1] + 0.1073969566 * c[:, 2]
    s = 0.0883024619 * c[:, 0] + 0.2817188376 * c[:, 1] + 0.6299787005 * c[:, 2]
    l, m, s = np.cbrt(l), np.cbrt(m), np.cbrt(s)
    return np.stack([0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
                     1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
                     0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s], axis=1)


def histogram(frames, masks):
    px = np.concatenate([f[m] for f, m in zip(frames, masks)]) if any(m.any() for m in masks) else np.zeros((0, 3))
    if len(px) == 0:
        return np.zeros(8 * 8 * 8)
    if len(px) > 60000:
        px = px[np.random.default_rng(0).choice(len(px), 60000, replace=False)]
    lab = oklab(px)
    h, _ = np.histogramdd(lab, bins=(8, 8, 8), range=((0, 1), (-0.4, 0.4), (-0.4, 0.4)))
    return h.ravel() / max(1, h.sum())


def centroids(masks):
    out = []
    for m in masks:
        ys, xs = np.nonzero(m)
        out.append((xs.mean(), ys.mean()) if len(xs) else None)
    return out


def score(fid):
    ref = ref_frames(fid)
    pfx, pbg = pfx_frames(fid)
    h, w = ref[0].shape[:2]
    if pfx[0].shape[:2] != (h, w):
        raise ValueError(f"{fid}: canvas {pfx[0].shape[1]}x{pfx[0].shape[0]}, the reference's {w}x{h}")
    # both sides against the same, true backdrop (the render's: core/backdrop.gd draws the original's exactly), so
    # still parts (a stand-in, an orb's glass, a pool of light) count the same on both
    rbg = pbg if pbg.shape == ref[0].shape else mode_backdrop(ref)
    rm = active(ref, rbg)
    pm = active(pfx, pbg)
    # colour also counts faint light, which is most of what a glow is
    rl = active(ref, rbg, 8)
    pl = active(pfx, pbg, 8)
    ra = np.array([m.sum() for m in rm], float)
    best = None
    # the two may be a frame or two apart at the start: take the alignment that fits best
    for s in range(-2, 3):
        pa_all = np.array([m.sum() for m in pm], float)
        pa = np.roll(pa_all, s) if s else pa_all
        n = min(len(ra), len(pa))
        rn = ra[:n] / max(1.0, ra[:n].max())
        pn = pa[:n] / max(1.0, pa[:n].max())
        shape = 1.0 - np.abs(rn - pn).mean()
        mag = min(ra[:n].sum(), pa[:n].sum()) / max(1.0, ra[:n].sum(), pa[:n].sum())
        a = 0.6 * shape + 0.4 * mag
        if best is None or a > best[0]:
            best = (a, s)
    activity, shift = best
    heat_r = np.mean(rm, axis=0)
    heat_p = np.mean(pm, axis=0)
    fr = dilate(heat_r > 0.05, 3)
    fp = dilate(heat_p > 0.05, 3)
    extent = (fr & fp).sum() / max(1, (fr | fp).sum())
    colour = float(np.minimum(histogram(ref, rl), histogram(pfx, pl)).sum())
    cr, cp = centroids(rm), centroids(pm)
    diag = np.hypot(w, h)
    d = [np.hypot(a[0] - b[0], a[1] - b[1]) / diag for a, b in zip(cr, cp[shift:] if shift >= 0 else [None] * -shift + cp) if a and b]
    motion = max(0.0, 1.0 - (np.mean(d) / 0.25)) if d else 0.0
    parts = {"activity": float(activity), "extent": float(extent), "colour": colour, "motion": float(motion)}
    total = sum(WEIGHTS[k] * v for k, v in parts.items())
    return {"id": fid, "score": round(total, 3), **{k: round(v, 3) for k, v in parts.items()}, "shift": shift,
            "frames": [len(ref), len(pfx)], "size": [w, h]}, ref, pfx


def sheet(fid, ref, pfx, out):
    n = 10
    idx = [int(i) for i in np.linspace(0, min(len(ref), len(pfx)) - 1, n)]
    h, w = ref[0].shape[:2]
    k = max(1, min(3, 1400 // (n * w)))
    pad = 14
    img = Image.new("RGB", (n * (w * k + 2), 2 * (h * k + pad)), (40, 40, 40))
    d = ImageDraw.Draw(img)
    for row, (frames, label) in enumerate(((ref, "REF"), (pfx, "PARTICLE"))):
        d.text((2, row * (h * k + pad) + 1), label, fill=(255, 220, 0))
        for j, i in enumerate(idx):
            im = Image.fromarray(frames[i]).resize((w * k, h * k), Image.NEAREST)
            img.paste(im, (j * (w * k + 2), row * (h * k + pad) + pad))
    img.save(os.path.join(out, "sheet.png"))
    m = min(len(ref), len(pfx))
    side = [Image.fromarray(np.concatenate([ref[i], np.full((h, 2, 3), 40, np.uint8), pfx[i]], axis=1)).resize(((2 * w + 2) * 2, h * 2), Image.NEAREST) for i in range(m)]
    side[0].save(os.path.join(out, "side.webp"), save_all=True, append_images=side[1:], duration=17 if MODE["act"] else 33, loop=0, lossless=True, method=0)


def main(argv):
    flags = [a for a in argv if a.startswith("--")]
    args = [a for a in argv if not a.startswith("--")]
    lo = float(argv[argv.index("--min") + 1]) if "--min" in argv else None
    if lo is not None:
        args = [a for a in args if a != str(lo) and a != argv[argv.index("--min") + 1]]
    MODE["act"] = "--act" in argv
    ids = ids_for(args or ["*"])
    rows, bad = [], 0
    for fid in ids:
        out = os.path.join(ROOT, "records", "compare-act" if MODE["act"] else "compare", fid)
        os.makedirs(out, exist_ok=True)
        try:
            r, ref, pfx = score(fid)
            sheet(fid, ref, pfx, out)
        except (FileNotFoundError, ValueError) as e:
            print(f"skip  {fid}: {e}")
            bad += 1
            continue
        json.dump(r, open(os.path.join(out, "metrics.json"), "w"), indent=1)
        rows.append(r)
        flag = "low " if lo is not None and r["score"] < lo else "    "
        bad += flag == "low "
        print(f"{flag}{fid:30s} {r['score']:.3f}  act {r['activity']:.2f}  ext {r['extent']:.2f}  col {r['colour']:.2f}  mot {r['motion']:.2f}  (shift {r['shift']:+d})")
    if rows:
        print(f"\n{len(rows)} compared, mean score {np.mean([r['score'] for r in rows]):.3f}" + (f", {bad} below {lo} or skipped" if lo is not None else ""))
        summ = os.path.join(ROOT, "records", "compare-act" if MODE["act"] else "compare", "summary.json")
        old = json.load(open(summ)) if os.path.exists(summ) else {}
        old.update({r["id"]: r for r in rows})
        json.dump(old, open(summ, "w"), indent=1)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
