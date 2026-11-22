# Frames lifted from the original for bodies that aren't effects (a critter, a coin, a chest): the pixel port's
# transparent sprite sheet (`./pfx sheets <id>`, light baked in as alpha) as fx/<cat>/<name>/frames.png and
# frames.json {cols, rows, count, fps, pivot}, which build.gd frames() plays frame by frame.
#   python3 port/frames.py <ids>
import json, os, shutil, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
GODOT = os.path.join(ROOT, "..", "godot")


def lift(fid):
    tmp = os.path.join(ROOT, "records", "sheets")
    subprocess.run(["./pfx", "sheets", fid, "--out", tmp], cwd=GODOT, check=True, capture_output=True)
    j = json.load(open(os.path.join(tmp, fid + ".json")))
    px = j["meta"]["pixelfx"]
    cols = px["columns"]
    count = len(j["frames"])
    out = os.path.join(ROOT, "addons", "pixelfx_particles", "fx", fid)
    os.makedirs(out, exist_ok=True)
    shutil.copy(os.path.join(tmp, fid + ".png"), os.path.join(out, "frames.png"))
    info = {"cols": cols, "rows": -(-count // cols), "count": count, "fps": px["fps"], "pivot": px["pivot"],
            "size": [j["frames"][0]["sourceSize"]["w"], j["frames"][0]["sourceSize"]["h"]]}
    json.dump(info, open(os.path.join(out, "frames.json"), "w"))
    return info


if __name__ == "__main__":
    for fid in sys.argv[1:]:
        print(fid, lift(fid))
