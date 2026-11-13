# The still parts of an effect (a torch's bracket, a brazier's bowl, a fountain's basin), lifted from its colour layer
# (no light, no backdrop: `cd godot && ./pfx export color <id> --out ../godot-particle/records/color`, which this runs
# when it's missing): pixels that keep one colour in at least --share of the frames. The particle
# port draws everything that moves; props aren't effects, so it reuses the original's pixel art for them, as it does
# for the characters.
#   python3 port/props.py <id> [--share 0.6] [--box x0,y0,x1,y1]
# Writes addons/pixelfx_particles/fx/<cat>/<name>/prop.png (canvas-sized, transparent) and prints its used rect.
import json, os, sys
import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from compare import ROOT, META  # noqa: E402


def color_frames(fid):
    d = os.path.join(ROOT, "records", "color", fid)
    if not os.path.exists(os.path.join(d, "color.json")):
        import subprocess
        subprocess.run(["./pfx", "export", "color", fid, "--out", os.path.join(ROOT, "records", "color")],
                       cwd=os.path.join(ROOT, "..", "godot"), check=True, capture_output=True)
    j = json.load(open(os.path.join(d, "color.json")))
    sheet = np.asarray(Image.open(os.path.join(d, "color.png")).convert("RGBA"))
    w, h, cols = j["w"], j["h"], j["cols"]
    return [sheet[(i // cols) * h:(i // cols + 1) * h, (i % cols) * w:(i % cols + 1) * w] for i in range(j["count"])]


def props(fid, share=0.6, box=None):
    rgba = color_frames(fid)
    frames = [f[..., :3] for f in rgba]
    alpha = np.stack([f[..., 3] > 0 for f in rgba])
    a = np.stack(rgba).astype(np.int64)                   # n, h, w, 4: alpha too (hazes and washes are translucent)
    n, h, w, _ = a.shape
    packed = (a[..., 3] << 24) | (a[..., 0] << 16) | (a[..., 1] << 8) | a[..., 2]
    # the most common drawn colour of each pixel, and how often it shows (-1: nothing drawn there)
    packed = np.where(alpha, packed, -1)
    srt = np.sort(packed, axis=0)
    best = srt[0].copy()
    bestc = np.zeros((h, w), int)
    run = np.ones((h, w), int)
    for i in range(1, n):
        same = srt[i] == srt[i - 1]
        run = np.where(same, run + 1, 1)
        better = (run > bestc) & (srt[i] >= 0)
        bestc = np.where(better, run, bestc)
        best = np.where(better, srt[i], best)
    col = np.stack([(best >> 16) & 255, (best >> 8) & 255, best & 255], axis=-1).astype(np.uint8)
    alpha_of = ((best >> 24) & 255).astype(np.uint8)
    keep = (bestc >= share * n) & (best >= 0)
    if box:
        x0, y0, x1, y1 = box
        m = np.zeros_like(keep)
        m[y0:y1, x0:x1] = True
        keep &= m
    out = np.zeros((h, w, 4), np.uint8)
    out[..., :3] = col
    out[..., 3] = np.where(keep, alpha_of, 0)
    cat, name = fid.split("/")
    d = os.path.join(ROOT, "addons", "pixelfx_particles", "fx", cat, name)
    os.makedirs(d, exist_ok=True)
    path = os.path.join(d, "prop.png")
    Image.fromarray(out, "RGBA").save(path)
    ys, xs = np.nonzero(keep)
    rect = [int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1] if len(xs) else None
    return path, int(keep.sum()), rect


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    share = float(sys.argv[sys.argv.index("--share") + 1]) if "--share" in sys.argv else 0.6
    box = [int(v) for v in sys.argv[sys.argv.index("--box") + 1].split(",")] if "--box" in sys.argv else None
    args = [a for a in args if a not in (str(share),) and (box is None or a != sys.argv[sys.argv.index("--box") + 1])]
    for fid in args:
        path, n, rect = props(fid, share, box)
        print(f"{fid}: {n} still pixels in {rect} -> {path}")
