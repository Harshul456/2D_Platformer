"""Copy Bulb library assets into 2D_Platformer and merge Action platformer.yyp."""
import json
import shutil
import subprocess
import sys
from pathlib import Path

BULB_ROOT = Path(__file__).resolve().parents[2] / "Bulb_temp"
PROJ_ROOT = Path(__file__).resolve().parents[1]
YYP_PATH = PROJ_ROOT / "Action platformer.yyp"

SKIP_SCRIPTS = {"DebugOverlay", "VertexCake"}
LIGHT_SPRITES = {
    "__sprBulbPixel",
    "sLight128",
    "sLight512",
    "sLight1024",
    "sLightTorch",
    "sLightMask",
}


def copy_bulb_folders() -> None:
    src = BULB_ROOT / "folders"
    dst = PROJ_ROOT / "folders"
    for f in src.rglob("*.yy"):
        if f.relative_to(src).parts[0] != "Bulb":
            continue
        dest = dst / f.relative_to(src)
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(f, dest)


def copy_tree(src: Path, dst: Path) -> None:
    if dst.exists():
        shutil.rmtree(dst)
    shutil.copytree(src, dst)


def main() -> None:
    copy_bulb_folders()

    for d in (BULB_ROOT / "scripts").iterdir():
        if not d.is_dir() or d.name in SKIP_SCRIPTS:
            continue
        if not (d.name.startswith("Bulb") or d.name.startswith("__Bulb")):
            continue
        copy_tree(d, PROJ_ROOT / "scripts" / d.name)

    for d in (BULB_ROOT / "shaders").iterdir():
        if not d.is_dir():
            continue
        if not (d.name.startswith("__shdBulb") or d.name == "shdPremultiplyAlpha"):
            continue
        copy_tree(d, PROJ_ROOT / "shaders" / d.name)

    for name in LIGHT_SPRITES:
        src = BULB_ROOT / "sprites" / name
        if src.is_dir():
            copy_tree(src, PROJ_ROOT / "sprites" / name)

    license_src = BULB_ROOT / "datafiles" / "bulb_license.txt"
    license_dst = PROJ_ROOT / "datafiles"
    license_dst.mkdir(exist_ok=True)
    shutil.copy2(license_src, license_dst / "bulb_license.txt")

    new_resources = []
    for d in sorted((PROJ_ROOT / "scripts").iterdir()):
        if d.is_dir() and (d.name.startswith("Bulb") or d.name.startswith("__Bulb")):
            if d.name in SKIP_SCRIPTS:
                continue
            new_resources.append(
                {"id": {"name": d.name, "path": f"scripts/{d.name}/{d.name}.yy"}}
            )

    for d in sorted((PROJ_ROOT / "shaders").iterdir()):
        if d.is_dir() and (d.name.startswith("__shdBulb") or d.name == "shdPremultiplyAlpha"):
            new_resources.append(
                {"id": {"name": d.name, "path": f"shaders/{d.name}/{d.name}.yy"}}
            )

    for name in sorted(LIGHT_SPRITES):
        if (PROJ_ROOT / "sprites" / name).is_dir():
            new_resources.append(
                {"id": {"name": name, "path": f"sprites/{name}/{name}.yy"}}
            )

    with open(YYP_PATH, encoding="utf-8") as f:
        raw = f.read()
    import re
    raw = re.sub(r",(\s*[\]}])", r"\1", raw)
    yyp = json.loads(raw)

    existing = {r["id"]["name"] for r in yyp["resources"]}
    added = 0
    for r in new_resources:
        if r["id"]["name"] not in existing:
            yyp["resources"].append(r)
            added += 1

    existing_folders = {fo["name"] for fo in yyp["Folders"]}
    bulb_root_yy = PROJ_ROOT / "folders" / "Bulb.yy"
    if bulb_root_yy.exists() and "Bulb" not in existing_folders:
        yyp["Folders"].append(
            {
                "$GMFolder": "",
                "%Name": "Bulb",
                "folderPath": "folders/Bulb.yy",
                "name": "Bulb",
                "resourceType": "GMFolder",
                "resourceVersion": "2.0",
            }
        )

    for f in (PROJ_ROOT / "folders" / "Bulb").rglob("*.yy"):
        name = f.stem
        rel_path = "folders/" + str(f.relative_to(PROJ_ROOT / "folders")).replace("\\", "/")
        if name not in existing_folders:
            yyp["Folders"].append(
                {
                    "$GMFolder": "",
                    "%Name": name,
                    "folderPath": rel_path,
                    "name": name,
                    "resourceType": "GMFolder",
                    "resourceVersion": "2.0",
                }
            )
            existing_folders.add(name)

    has_license = any(
        "bulb_license" in str(x) for x in yyp.get("IncludedFiles", [])
    )
    if not has_license:
        yyp.setdefault("IncludedFiles", []).append(
            {
                "$GMIncludedFile": "",
                "%Name": "bulb_license.txt",
                "CopyToMask": -1,
                "filePath": "datafiles",
                "name": "bulb_license.txt",
                "resourceType": "GMIncludedFile",
                "resourceVersion": "2.0",
            }
        )

    # obj_bulb_controller (game integration)
    ctrl_yy = PROJ_ROOT / "objects" / "obj_bulb_controller" / "obj_bulb_controller.yy"
    if ctrl_yy.exists() and "obj_bulb_controller" not in existing:
        yyp["resources"].append(
            {
                "id": {
                    "name": "obj_bulb_controller",
                    "path": "objects/obj_bulb_controller/obj_bulb_controller.yy",
                }
            }
        )
        added += 1

    crystal_yy = PROJ_ROOT / "objects" / "obj_bulb_crystal_light" / "obj_bulb_crystal_light.yy"
    if crystal_yy.exists() and "obj_bulb_crystal_light" not in existing:
        yyp["resources"].append(
            {
                "id": {
                    "name": "obj_bulb_crystal_light",
                    "path": "objects/obj_bulb_crystal_light/obj_bulb_crystal_light.yy",
                }
            }
        )
        added += 1

    with open(YYP_PATH, "w", encoding="utf-8") as f:
        json.dump(yyp, f, indent=2)
        f.write("\n")

    convert_script = PROJ_ROOT / "tools" / "convert_bulb_yy_v2.py"
    subprocess.run([sys.executable, str(convert_script)], check=True)

    print(f"Bulb integration: {added} resources added to yyp.")


if __name__ == "__main__":
    main()
