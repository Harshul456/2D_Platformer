"""Create GameMaker normal-map sprites (spr_mc_idle_n, spr_enemy_n, etc.) from import/laigter/normals.

Usage:
  python tools/import_laigter_normal_sprites.py
  python tools/import_laigter_normal_sprites.py --sprites spr_mc_idle
"""
from __future__ import annotations

import argparse
import json
import re
import shutil
import sys
from pathlib import Path

PROJ_ROOT = Path(__file__).resolve().parents[1]
SPRITES_ROOT = PROJ_ROOT / "sprites"
NORMALS_ROOT = PROJ_ROOT / "import" / "laigter" / "normals"
YYP_PATH = PROJ_ROOT / "Action platformer.yyp"

DEFAULT_SPRITES = [
    "spr_mc_idle",
    "spr_mc_jog",
    "spr_mc_sprint",
    "spr_mc_jump",
    "spr_mc_walljump",
    "spr_mc_doublejump",
    "spr_mc_reelback",
    "spr_mc_attack2",
    "spr_mc_hurt",
    "spr_mc_hurt_air",
    "spr_enemy",
    "spr_enemy_windup",
    "spr_enemy_attack",
]


def load_gm_json(path: Path) -> dict:
    text = path.read_text(encoding="utf-8")
    text = re.sub(r",(\s*[}\]])", r"\1", text)
    return json.loads(text)


def write_gm_json(path: Path, data: dict) -> None:
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def replace_name(value: str, source: str, dest: str) -> str:
    return value.replace(source, dest)


def clone_sprite_with_normals(source_name: str) -> bool:
    normals_dir = NORMALS_ROOT / source_name
    if not normals_dir.is_dir():
        print(f"  skip {source_name}: no normals in {normals_dir}")
        return False

    source_dir = SPRITES_ROOT / source_name
    dest_name = f"{source_name}_n"
    dest_dir = SPRITES_ROOT / dest_name

    if dest_dir.exists():
        shutil.rmtree(dest_dir)
    shutil.copytree(source_dir, dest_dir)

    source_yy = source_dir / f"{source_name}.yy"
    dest_yy = dest_dir / f"{dest_name}.yy"
    yy_text = source_yy.read_text(encoding="utf-8")
    yy_text = replace_name(yy_text, source_name, dest_name)
    dest_yy.write_text(yy_text, encoding="utf-8")

    # Remove old yy copy from clone (wrong filename).
    wrong_yy = dest_dir / f"{source_name}.yy"
    if wrong_yy.exists() and wrong_yy != dest_yy:
        wrong_yy.unlink()

    data = load_gm_json(dest_yy)
    frame_names = [frame["name"] for frame in data.get("frames", [])]

    replaced = 0
    for index, frame_name in enumerate(frame_names):
        normal_src = normals_dir / f"{index:03d}_normal.png"
        if not normal_src.is_file():
            normal_src = normals_dir / f"{index:03d}_n.png"
        if not normal_src.is_file():
            print(f"  missing normal frame {index:03d} for {source_name}")
            continue

        targets = [
            dest_dir / f"{frame_name}.png",
        ]
        layer_matches = list(dest_dir.glob(f"layers/*/{frame_name}.png"))
        targets.extend(layer_matches)

        seen: set[Path] = set()
        for target in targets:
            if target in seen or not target.parent.exists():
                continue
            seen.add(target)
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(normal_src, target)
            replaced += 1

    if replaced == 0:
        shutil.rmtree(dest_dir)
        print(f"  failed {source_name}: no PNG targets updated")
        return False

    print(f"  {dest_name}: {replaced} PNG(s) updated")
    return True


def register_in_yyp(sprite_names: list[str]) -> None:
    yyp = load_gm_json(YYP_PATH)
    resources = yyp.get("resources", [])
    existing = {entry["id"]["name"] for entry in resources if "id" in entry}

    added = 0
    for source in sprite_names:
        dest = f"{source}_n"
        if dest in existing:
            continue
        path = f"sprites/{dest}/{dest}.yy"
        if not (PROJ_ROOT / path).is_file():
            continue
        resources.append({"id": {"name": dest, "path": path}})
        existing.add(dest)
        added += 1

    if added:
        resources.sort(key=lambda entry: entry["id"]["name"].lower())
        yyp["resources"] = resources
        write_gm_json(YYP_PATH, yyp)
        print(f"Registered {added} sprite(s) in Action platformer.yyp")
    else:
        print("No new sprites to register in yyp")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--sprites", nargs="*", default=DEFAULT_SPRITES)
    args = parser.parse_args()

    created: list[str] = []
    for sprite in args.sprites:
        print(sprite)
        if clone_sprite_with_normals(sprite):
            created.append(sprite)

    if not created:
        print("\nNothing imported. Run tools/laigter_batch_normals.py first.", file=sys.stderr)
        sys.exit(1)

    register_in_yyp(created)
    print("\nDone. Re-open the project in GameMaker if it is already open.")


if __name__ == "__main__":
    main()
