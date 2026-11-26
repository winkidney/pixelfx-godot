# Every effect's sound: port/sfx/cats/<category>.py maps each effect name to a function of its meta (port/meta.json:
# duration, loop, size, options, act timing) that returns a Sound (its full play on the effect's clock plus the phases
# a game triggers) or Silent (and why). The rules are godot/skills/pixelfx-godot/references/sound.md.
# Writes records/sfx/fx/<id>/{full,<phase>}.wav and records/sfx/manifest.json; checks lengths, loop seams and levels.
# Then exports the pack: <dest>/<category>/<name>/{full,<phase>}.<format> and <dest>/index.json, where dest is the
# addon's sfx/ folder (OGG, imported by Godot; `./pfxp sfx` runs this and then the import) or --out DIR.
#   python3 port/sfx/make.py [ids|categories] [--preview] [--out DIR] [--format ogg|wav]
#   (--preview: records/sfx/fx/<id>/preview.mp4 with the frames)
import concurrent.futures, importlib, json, os, shutil, subprocess, sys, wave
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from synth import SR, Silent, Sound   # noqa: E402

ROOT = os.path.dirname(os.path.dirname(HERE))
META = json.load(open(os.path.join(ROOT, "port", "meta.json")))
OUT = os.path.join(ROOT, "records", "sfx")
RING = 1.5          # a one-shot may ring this long past its duration
ENV_MAX = -24.0     # an environment loop sits at least this quiet (dBFS RMS)
MASTER = 0.5        # one gain for every effect (about -6 dB): levels between effects stay as designed, none clips
GATE_DB = -22.0     # after a one-shot's loudest moment, whatever stays this far under it is cut (rule 6: end clean)
GATE_WIN, GATE_HOLD, GATE_FADE = 0.05, 0.1, 0.12
ADDON_SFX = os.path.join(ROOT, "addons", "pixelfx_particles", "sfx")
OGG_Q = 3           # libvorbis quality (0..10): about 11 MB for the whole pack; lower it if it outgrows MAX_MB
MAX_MB = 20.0
OURS = (".ogg", ".wav")   # what the export writes (and deletes when stale), with Godot's .import beside each
UNGATED = ("start", "loop", "build", "charge", "windup", "rise", "gather", "pen")   # anticipation phases are quiet by design


def db(a):
    return 20 * np.log10(np.sqrt(np.mean(np.square(a))) + 1e-9) if len(a) else -120.0


def write(path, a):
    a = np.asarray(a, float)
    if a.ndim == 1:
        a = np.stack([a, a], 1)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((np.clip(a, -1, 1) * 32767).astype("<i2").tobytes())


def gate(a, ref, after=0):
    """Cut what stays GATE_DB under `ref` (the effect's loudest 50 ms RMS) from sample `after` on: a vague low bed
    after the main sound (faint fizz, ember crackle, a long rumble decay) goes; clear events above it stay, each
    keeping GATE_HOLD of its decay, and every cut fades out over GATE_FADE."""
    n = int(GATE_WIN * SR)
    k = len(a) // n
    if k == 0 or ref <= 0:
        return a
    rms = np.sqrt(np.mean(np.square(a[:k * n].reshape(k, n, 2)), axis=1)).max(1)
    keep = rms >= ref * 10 ** (GATE_DB / 20)
    hold = int(GATE_HOLD / GATE_WIN)
    for i in np.nonzero(keep)[0]:
        keep[i:i + hold + 1] = True
    keep[: after // n] = True
    g = np.repeat(keep.astype(float), n)
    g = np.concatenate([g, np.full(len(a) - len(g), g[-1] if len(g) else 1.0)])
    f = int(GATE_FADE * SR)                        # a smooth close: each drop to 0 becomes a fade
    out = g.copy()
    for i in np.nonzero(np.diff(g) < 0)[0]:
        j = min(len(out), i + 1 + f)
        out[i + 1:j] = np.linspace(1, 0, j - i - 1) if j > i + 1 else out[i + 1:j]
    return a * out[:, None]


def loudest(a):
    n = int(GATE_WIN * SR)
    k = len(a) // n
    if k == 0:
        return 0.0, 0
    rms = np.sqrt(np.mean(np.square(a[:k * n].reshape(k, n, 2)), axis=1)).max(1)
    return float(rms.max()), int(rms.argmax()) * n


def check(fid, m, s):
    """Problems with a Sound, as strings (empty: fine). Fixes what it safely can (pads a short one-shot)."""
    bad = []
    n = int(round(m["duration"] * SR))
    full = np.asarray(s.full, float) * MASTER
    if full.ndim != 2 or full.shape[1] != 2:
        return [f"full must be stereo (n, 2), got {full.shape}"], full
    if m["loop"]:
        if len(full) != n:
            bad.append(f"loop is {len(full) / SR:.3f}s, must be exactly {m['duration']}s")
        elif np.abs(full[0] - full[-1]).max() > 0.5:
            bad.append("loop seam jumps (render X longer and wrap())")
    else:
        if len(full) < n:
            full = np.concatenate([full, np.zeros((n - len(full), 2))])
        if len(full) > n + RING * SR:
            bad.append(f"rings {len(full) / SR - m['duration']:.2f}s past its end (max {RING}s)")
    if not m["loop"]:
        ref, at = loudest(full)
        full = gate(full, ref, at)
    peak = np.abs(full).max() if len(full) else 0
    if peak > 1.0:
        bad.append(f"peak {peak:.2f} > 1 (it was scaled down)")
        full = full / peak * 0.95
    if m["loop"] and fid.split("/")[0] == "weather" and db(full) > ENV_MAX:
        bad.append(f"environment loop at {db(full):.1f} dB, keep it under {ENV_MAX} dB")
    return bad, full


def run(ids, preview=False):
    man_path = os.path.join(OUT, "manifest.json")
    man = json.load(open(man_path)) if os.path.exists(man_path) else {}
    mods, problems = {}, 0
    for fid in ids:
        cat, name = fid.split("/")
        if cat not in mods:
            try:
                mods[cat] = importlib.import_module("cats." + cat)
            except ModuleNotFoundError:
                mods[cat] = None
        fn = getattr(mods[cat], "SOUNDS", {}).get(name) if mods[cat] else None
        if fn is None:
            man[fid] = {"status": "todo"}
            continue
        m = dict(META[fid], id=fid)
        r = fn(m)
        d = os.path.join(OUT, "fx", fid)
        if os.path.isdir(d):                     # phases a function no longer returns don't linger
            for f in os.listdir(d):
                if f.endswith(".wav"):
                    os.remove(os.path.join(d, f))
        if isinstance(r, Silent):
            man[fid] = {"status": "silent", "why": r.why}
            print(f"  -     {fid:34s} silent: {r.why}")
            continue
        bad, full = check(fid, m, r)
        write(os.path.join(d, "full.wav"), full)
        ref = loudest(full)[0]
        for k, v in r.phases.items():
            v = np.asarray(v, float) * MASTER
            if v.ndim == 1:
                v = np.stack([v, v], 1)
            if not m["loop"] and k not in UNGATED:
                v = gate(v, ref)
            write(os.path.join(d, k + ".wav"), v)
        man[fid] = {"status": "sound", "notes": r.notes, "phases": sorted(r.phases), "loop": m["loop"],
                    "rms_db": round(db(full), 1), "peak": round(float(np.abs(full).max()), 2),
                    "secs": round(len(full) / SR, 2), "problems": bad}
        problems += bool(bad)
        print(f"  {'!' if bad else 'ok'}    {fid:34s} {db(full):6.1f} dB  {', '.join(sorted(r.phases)) or '-'}"
              + (f"   PROBLEMS: {'; '.join(bad)}" if bad else ""))
        if preview:
            frames = os.path.join(ROOT, "records", "render", fid)
            if os.path.isdir(frames):
                loops = 3 if m["loop"] else 1
                subprocess.run(["ffmpeg", "-v", "error", "-y", "-stream_loop", str(loops - 1), "-framerate",
                                str(m.get("fps", 30)), "-i", os.path.join(frames, "%04d.png"), "-stream_loop",
                                str(loops - 1), "-i", os.path.join(d, "full.wav"), "-vf",
                                "scale=iw*3:ih*3:flags=neighbor,pad=ceil(iw/2)*2:ceil(ih/2)*2", "-c:v", "libx264",
                                "-pix_fmt", "yuv420p", "-c:a", "aac", "-shortest", os.path.join(d, "preview.mp4")],
                               check=False)
    os.makedirs(OUT, exist_ok=True)
    json.dump(dict(sorted(man.items())), open(man_path, "w"), indent=1, ensure_ascii=False)
    c = {k: sum(1 for v in man.values() if v["status"] == k) for k in ("sound", "silent", "todo")}
    print(f"{len(ids)} done: sound {c['sound']}, silent {c['silent']}, todo {c['todo']} of {len(man)}; "
          f"{problems} with problems -> {man_path}")
    return problems


def ids_for(args):
    if not args:
        return sorted(META)
    out = []
    for a in args:
        got = [a] if a in META else sorted(i for i in META if i.startswith(a + "/"))
        if not got:
            sys.exit(f"no effect or category {a!r}")
        out += got
    return out


def prune(d, want):
    """Delete the export's files in `d` that aren't in `want` (with their .import), then `d` itself and its category
    folder when empty. Only our own kinds of file go: --out may point into a folder with other things in it."""
    if not os.path.isdir(d):
        return
    for f in os.listdir(d):
        base = f[:-len(".import")] if f.endswith(".import") else f
        if base.endswith(OURS) and base not in want:
            os.remove(os.path.join(d, f))
    for x in (d, os.path.dirname(d)):
        if os.path.isdir(x) and not os.listdir(x):
            os.rmdir(x)


def encode(src, dst, fmt):
    """One wav as `fmt`. OGG: mono when both channels are the same, else stereo; bit-exact, so an unchanged sound
    rewrites nothing (git and Godot's import see no change)."""
    if fmt == "wav":
        if not (os.path.exists(dst) and open(src, "rb").read() == open(dst, "rb").read()):
            shutil.copyfile(src, dst)
        return
    with wave.open(src) as w:
        a = np.frombuffer(w.readframes(w.getnframes()), "<i2").reshape(-1, w.getnchannels())
    mono = a.shape[1] == 1 or np.array_equal(a[:, 0], a[:, 1])
    part = dst + ".part"
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", src] + (["-ac", "1"] if mono else [])
                   + ["-c:a", "libvorbis", "-q:a", str(OGG_Q), "-fflags", "+bitexact", "-flags:a", "+bitexact",
                      "-map_metadata", "-1", "-f", "ogg", part], check=True)
    if os.path.exists(dst) and open(part, "rb").read() == open(dst, "rb").read():
        os.remove(part)
    else:
        os.replace(part, dst)


GODOT_LOOP_IMPORT = """[remap]

importer="oggvorbisstr"
type="AudioStreamOggVorbis"

[params]

loop=true
loop_offset=0.0
bpm=0.0
beat_count=0
bar_beats=4
"""


def export(ids, dest, fmt):
    """The pack for `ids` into dest: every phase of each effect with sound as `fmt`, and index.json (every id: sound
    or not and why, loop, duration, phases, notes). Files of phases or effects that are gone are deleted."""
    man = json.load(open(os.path.join(OUT, "manifest.json")))
    idx_path = os.path.join(dest, "index.json")
    index = json.load(open(idx_path)) if os.path.exists(idx_path) else {}
    known = set(index)
    jobs = []
    for fid in ids:
        e, m = man.get(fid, {}), META[fid]
        d = os.path.join(dest, *fid.split("/"))
        if e.get("status") == "sound":
            index[fid] = {"sound": True, "loop": m["loop"], "duration": m["duration"], "length": e["secs"],
                          "phases": e["phases"], "notes": e["notes"]}
            names = ["full"] + e["phases"]
            prune(d, {p + "." + fmt for p in names})
            os.makedirs(d, exist_ok=True)
            jobs += [(os.path.join(OUT, "fx", fid, p + ".wav"), os.path.join(d, p + "." + fmt)) for p in names]
        elif e.get("status") == "silent":
            index[fid] = {"sound": False, "why": e["why"], "loop": m["loop"], "duration": m["duration"]}
            prune(d, set())
        else:                                    # no sound function yet: no entry (./pfxp check fails it)
            index.pop(fid, None)
            prune(d, set())
    for fid in sorted(known | set(META)):   # effects that are gone, or no longer have sound
        if fid not in META:
            index.pop(fid, None)
        if not index.get(fid, {}).get("sound"):
            prune(os.path.join(dest, *fid.split("/")), set())
    with concurrent.futures.ThreadPoolExecutor(os.cpu_count() or 4) as pool:
        list(pool.map(lambda j: encode(*j, fmt), jobs))
    if fmt == "ogg" and os.path.realpath(dest) == os.path.realpath(ADDON_SFX):
        # a loop's full track and every "loop" phase loop when imported (PfxEffect also sets it at run time): written
        # before Godot's first import of the file, whose own .import (with its uid) keeps the flag from then on
        for fid in ids:
            e = index.get(fid, {})
            for p in [] if not e.get("sound") else (["full"] if e.get("loop") else []) + (["loop"] if "loop" in e.get("phases", []) else []):
                imp = os.path.join(dest, *fid.split("/"), p + ".ogg.import")
                if not os.path.exists(imp):
                    open(imp, "w").write(GODOT_LOOP_IMPORT)
                else:
                    t = open(imp).read()
                    if "loop=false" in t:
                        open(imp, "w").write(t.replace("loop=false", "loop=true"))
    os.makedirs(dest, exist_ok=True)
    json.dump(dict(sorted(index.items())), open(idx_path, "w"), indent=1, ensure_ascii=False)
    open(idx_path, "a").write("\n")
    sizes = [os.path.getsize(os.path.join(r, f)) for r, _, fs in os.walk(dest) for f in fs if f.endswith("." + fmt)]
    total, files = sum(sizes), len(sizes)
    n_sound = sum(1 for v in index.values() if v["sound"])
    print(f"exported {len(ids)}: {len(index)} in index.json ({n_sound} with sound), {files} {fmt} files, "
          f"{total / 1e6:.1f} MB -> {dest}")
    if fmt == "ogg" and total > MAX_MB * 1e6:
        print(f"  ! the pack is over {MAX_MB:.0f} MB: lower OGG_Q in port/sfx/make.py")
        return 1
    return 0


def parse(argv):
    ids, opt = [], {"preview": False, "out": None, "format": "ogg"}
    i = 0
    while i < len(argv):
        a = argv[i]
        if a == "--preview":
            opt["preview"] = True
        elif a.split("=")[0] in ("--out", "--format"):
            k, _, v = a[2:].partition("=")
            if not v:
                i += 1
                v = argv[i] if i < len(argv) else ""
            opt[k] = v
        elif a.startswith("--"):
            sys.exit(f"unknown option {a}")
        else:
            ids.append(a)
        i += 1
    if opt["format"] not in ("ogg", "wav"):
        sys.exit("--format is ogg or wav")
    return ids, opt


if __name__ == "__main__":
    args, opt = parse(sys.argv[1:])
    ids = ids_for(args)
    bad = run(ids, opt["preview"])
    bad += export(ids, os.path.abspath(opt["out"]) if opt["out"] else ADDON_SFX, opt["format"])
    sys.exit(1 if bad else 0)
