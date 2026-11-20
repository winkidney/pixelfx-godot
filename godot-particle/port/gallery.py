# The particle port's renders as lossless animated WebP, laid out as the pixel port's are, so the same tools (the
# video, the review) read both: records/render/<id>/NNNN.png -> records/gallery/<id>/anim.webp (the effect's fps) and
# records/render-act/<id>/NNNN.png -> records/act/<cat>-<name>.webp (60 fps). Render first (./pfxp render, or
# ./pfxp compare, which renders).
#   python3 port/gallery.py [ids|categories]
import glob, json, os, sys
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
REC = os.path.join(ROOT, "records")
META = json.load(open(os.path.join(HERE, "meta.json")))


def frames(d):
    return [Image.open(f).convert("RGB") for f in sorted(glob.glob(os.path.join(d, "[0-9][0-9][0-9][0-9].png")))]


def pack(fs, out, fps):
    os.makedirs(os.path.dirname(out), exist_ok=True)
    fs[0].save(out, save_all=True, append_images=fs[1:], duration=round(1000 / fps), loop=0, lossless=True, method=0)


def main(args):
    want = [i for i in sorted(META) if not args or any(i == a or i.startswith(a.rstrip("/") + "/") for a in args)]
    n = acts = 0
    for fid in want:
        fs = frames(os.path.join(REC, "render", fid))
        if fs:
            pack(fs, os.path.join(REC, "gallery", fid, "anim.webp"), META[fid].get("fps", 30))
            n += 1
        fs = frames(os.path.join(REC, "render-act", fid))
        if fs:
            pack(fs, os.path.join(REC, "act", fid.replace("/", "-") + ".webp"), 60)
            acts += 1
    print(f"{n} effects, {acts} acts -> {os.path.join(REC, 'gallery')}, {os.path.join(REC, 'act')}")


if __name__ == "__main__":
    main(sys.argv[1:])
