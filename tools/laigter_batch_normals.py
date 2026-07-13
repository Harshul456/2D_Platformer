"""Export sprite frames and batch-generate normal maps with Laigter CLI.

Usage (from project root):
  python tools/laigter_batch_normals.py
  python tools/laigter_batch_normals.py --sprites spr_mc_idle
  python tools/laigter_batch_normals.py --laigter "C:/Path/To/laigter.exe"
  python tools/laigter_batch_normals.py --preset "C:/Path/To/my_preset.json"

Laigter writes files like 000_n.png (NOT 000_normal.png). This script normalizes
those to 000_normal.png for the GameMaker import step.

Then run:
  python tools/import_laigter_normal_sprites.py
"""
from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

PROJ_ROOT = Path(__file__).resolve().parents[1]
SPRITES_ROOT = PROJ_ROOT / "sprites"
IMPORT_ROOT = PROJ_ROOT / "import" / "laigter"
DIFFUSE_ROOT = IMPORT_ROOT / "diffuse"
NORMALS_ROOT = IMPORT_ROOT / "normals"

DEFAULT_SPRITES = [
    "spr_mc_idle",
    "spr_mc_jog",
    "spr_mc_sprint",
    "spr_mc_jump",
    "spr_mc_walljump",
    "spr_mc_doublejump",
    "spr_mc_reelback",
    "spr_mc_attack2",
    "spr_enemy",
]

LAIGTER_SEARCH_PATHS = [
    Path(r"C:/Program Files/Laigter/laigter.exe"),
    Path(r"C:/Program Files (x86)/Laigter/laigter.exe"),
    Path.home() / "AppData/Local/Programs/laigter/laigter.exe",
    Path.home() / "AppData/Local/Programs/Laigter/laigter.exe",
]


def find_laigter(explicit: str | None) -> Path | None:
    if explicit:
        path = Path(explicit)
        return path if path.is_file() else None
    found = shutil.which("laigter")
    if found:
        return Path(found)
    for candidate in LAIGTER_SEARCH_PATHS:
        if candidate.is_file():
            return candidate
    return None


def load_gm_json(path: Path) -> dict:
    text = path.read_text(encoding="utf-8")
    text = re.sub(r",(\s*[}\]])", r"\1", text)
    return json.loads(text)


def frame_names_from_yy(sprite_dir: Path) -> list[str]:
    yy_path = sprite_dir / f"{sprite_dir.name}.yy"
    data = load_gm_json(yy_path)
    return [frame["name"] for frame in data.get("frames", [])]


def export_diffuse_frames(sprite_name: str) -> list[str]:
    """Copy GM sprite frames to import/laigter/diffuse/<sprite>/000.png ..."""
    sprite_dir = SPRITES_ROOT / sprite_name
    if not sprite_dir.is_dir():
        raise FileNotFoundError(sprite_dir)

    out_dir = DIFFUSE_ROOT / sprite_name
    if out_dir.exists():
        shutil.rmtree(out_dir)
    out_dir.mkdir(parents=True)

    stems: list[str] = []
    for index, frame_name in enumerate(frame_names_from_yy(sprite_dir)):
        src = sprite_dir / f"{frame_name}.png"
        if not src.is_file():
            layer_src = next(sprite_dir.glob(f"layers/*/{frame_name}.png"), None)
            if layer_src is None:
                print(f"  skip missing frame: {sprite_name}/{frame_name}")
                continue
            src = layer_src

        stem = f"{index:03d}"
        dst = out_dir / f"{stem}.png"
        shutil.copy2(src, dst)
        stems.append(stem)
    return stems


def find_laigter_normal(output_dir: Path, stem: str) -> Path | None:
    """Laigter CLI naming varies by version — try all common suffixes."""
    candidates = [
        output_dir / f"{stem}_n.png",
        output_dir / f"{stem}_normal.png",
        output_dir / f"{stem}-normal.png",
        output_dir / f"{stem}.normal.png",
    ]
    for path in candidates:
        if path.is_file():
            return path
    return None


def normalize_laigter_outputs(output_dir: Path, stems: list[str]) -> tuple[int, list[str]]:
    """Rename Laigter *_n.png outputs to 000_normal.png for the GM import script."""
    ok = 0
    missing: list[str] = []
    for stem in stems:
        src = find_laigter_normal(output_dir, stem)
        dst = output_dir / f"{stem}_normal.png"
        if src is None:
            missing.append(stem)
            continue
        if src.resolve() != dst.resolve():
            shutil.copy2(src, dst)
        ok += 1
        print(f"  frame {stem} -> {dst.name} (from {src.name})")
    return ok, missing


def run_laigter_on_sprite(laigter: Path, sprite_name: str, preset: Path | None) -> tuple[int, list[str]]:
    print(f"\n{sprite_name}")
    stems = export_diffuse_frames(sprite_name)
    if not stems:
        print("  no frames exported")
        return 0, []

    diffuse_dir = DIFFUSE_ROOT / sprite_name
    output_dir = NORMALS_ROOT / sprite_name
    if output_dir.exists():
        shutil.rmtree(output_dir)
    output_dir.mkdir(parents=True)

    cmd = [
        str(laigter),
        "--no-gui",
        "-d",
        str(diffuse_dir),
        "-n",
        "-l",
        str(output_dir),
        "--flatten",
    ]
    if preset is not None:
        cmd.extend(["-r", str(preset)])

    print(f"  laigter batch: {len(stems)} frame(s)")
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, check=False)
    except OSError as exc:
        print(f"  ERROR: could not run Laigter: {exc}", file=sys.stderr)
        return 0, stems

    if result.returncode != 0:
        print(f"  ERROR: Laigter exited {result.returncode}", file=sys.stderr)
        if result.stderr:
            print(result.stderr, file=sys.stderr)
        if result.stdout:
            print(result.stdout, file=sys.stderr)
        return 0, stems

    ok, missing = normalize_laigter_outputs(output_dir, stems)
    if missing:
        print(f"  WARNING: missing normals for: {', '.join(missing)}", file=sys.stderr)
        print(f"  Files in output dir: {[p.name for p in sorted(output_dir.glob('*.png'))]}", file=sys.stderr)
    return ok, missing


def main() -> None:
    parser = argparse.ArgumentParser(description="Batch-generate Laigter normal maps for diffuse sprites.")
    parser.add_argument("--sprites", nargs="*", default=DEFAULT_SPRITES)
    parser.add_argument("--laigter", default=None, help="Path to laigter.exe")
    parser.add_argument("--preset", default=None, help="Laigter preset file (save from GUI after tuning one frame)")
    args = parser.parse_args()

    laigter = find_laigter(args.laigter)
    if not laigter:
        print("ERROR: Laigter not found.", file=sys.stderr)
        print("Install from https://azagaya.itch.io/laigter", file=sys.stderr)
        print('Then run: python tools/laigter_batch_normals.py --laigter "C:/Path/To/laigter.exe"', file=sys.stderr)
        sys.exit(1)

    preset = Path(args.preset) if args.preset else None
    if preset is not None and not preset.is_file():
        print(f"ERROR: preset not found: {preset}", file=sys.stderr)
        sys.exit(1)

    print(f"Using Laigter: {laigter}")
    if preset:
        print(f"Using preset: {preset}")

    total = 0
    all_missing: list[str] = []
    for sprite in args.sprites:
        ok, missing = run_laigter_on_sprite(laigter, sprite, preset)
        total += ok
        if missing:
            all_missing.extend(f"{sprite}/{m}" for m in missing)

    print(f"\nDone. Generated {total} normal frame(s).")
    if all_missing:
        print(f"Failed frames ({len(all_missing)}): see warnings above.", file=sys.stderr)
        sys.exit(1)
    print("Next: close GameMaker, then run:")
    print("  python tools/import_laigter_normal_sprites.py")


if __name__ == "__main__":
    main()
