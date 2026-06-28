"""Upgrade Bulb resource .yy files from GMS v1 JSON to v2 type-tagged format."""
from __future__ import annotations

import json
import re
from pathlib import Path

PROJ_ROOT = Path(__file__).resolve().parents[1]

TYPE_TAGS: dict[str, tuple[str, str]] = {
    "GMScript": ("$GMScript", "v1"),
    "GMShader": ("$GMShader", ""),
    "GMSprite": ("$GMSprite", "v2"),
    "GMSpriteFrame": ("$GMSpriteFrame", "v1"),
    "GMImageLayer": ("$GMImageLayer", ""),
    "GMSequence": ("$GMSequence", "v1"),
    "KeyframeStore<MessageEventKeyframe>": ("$KeyframeStore<MessageEventKeyframe>", ""),
    "KeyframeStore<MomentsEventKeyframe>": ("$KeyframeStore<MomentsEventKeyframe>", ""),
    "KeyframeStore<SpriteFrameKeyframe>": ("$KeyframeStore<SpriteFrameKeyframe>", ""),
    "GMSpriteFramesTrack": ("$GMSpriteFramesTrack", ""),
    "Keyframe<SpriteFrameKeyframe>": ("$Keyframe<SpriteFrameKeyframe>", ""),
    "SpriteFrameKeyframe": ("$SpriteFrameKeyframe", ""),
    "GMFolder": ("$GMFolder", ""),
}

BULB_SCRIPT_PREFIXES = ("Bulb", "__Bulb")
BULB_SHADER_PREFIXES = ("__shdBulb",)
BULB_SPRITES = {
    "__sprBulbPixel",
    "sLight128",
    "sLight512",
    "sLight1024",
    "sLightTorch",
    "sLightMask",
}

# Only top-level resources use %Name; nested sequence types must not insert it
# before required fields like builtinName on GMSpriteFramesTrack.
NAME_TAG_TYPES = {
    "GMScript",
    "GMShader",
    "GMSprite",
    "GMSpriteFrame",
    "GMImageLayer",
    "GMSequence",
    "GMFolder",
}


def _has_type_tag(obj: dict) -> bool:
    return any(key.startswith("$") for key in obj)


def _upgrade_object(obj: object, sprite_dims: tuple[int, int] | None = None) -> object:
    if isinstance(obj, list):
        return [_upgrade_object(item, sprite_dims) for item in obj]

    if not isinstance(obj, dict):
        return obj

    resource_type = obj.get("resourceType")
    if resource_type == "GMSprite":
        sprite_dims = (int(obj.get("width", 0)), int(obj.get("height", 0)))

    upgraded: dict = {}
    for key, value in obj.items():
        upgraded[key] = _upgrade_object(value, sprite_dims)

    if resource_type not in TYPE_TAGS:
        return upgraded

    if not _has_type_tag(upgraded):
        tag_key, tag_value = TYPE_TAGS[resource_type]
        name = upgraded.get("name") or upgraded.get("%Name")
        ordered: dict = {tag_key: tag_value}
        if resource_type in NAME_TAG_TYPES and name is not None and "%Name" not in upgraded:
            ordered["%Name"] = name
        if resource_type == "GMSpriteFrame" and name is not None and "name" not in upgraded:
            ordered["name"] = name
        if resource_type == "GMSpriteFramesTrack":
            ordered["builtinName"] = upgraded.get("builtinName", 0)
            for key, value in upgraded.items():
                if key not in {"builtinName", "%Name"}:
                    ordered[key] = value
        else:
            ordered.update(upgraded)
        upgraded = ordered

    if resource_type == "GMSpriteFramesTrack":
        upgraded.pop("%Name", None)
        tag_key = "$GMSpriteFramesTrack"
        if tag_key in upgraded:
            tag_value = upgraded[tag_key]
            rest = {k: v for k, v in upgraded.items() if k != tag_key}
            builtin_name = rest.pop("builtinName", 0)
            upgraded.clear()
            upgraded[tag_key] = tag_value
            upgraded["builtinName"] = builtin_name
            upgraded.update(rest)

    version = upgraded.get("resourceVersion", "")
    if isinstance(version, str) and version.startswith("1."):
        upgraded["resourceVersion"] = "2.0"

    if resource_type == "GMSequence" and sprite_dims:
        width, height = sprite_dims
        if width and "seqWidth" not in upgraded:
            upgraded["seqWidth"] = float(width)
        if height and "seqHeight" not in upgraded:
            upgraded["seqHeight"] = float(height)

    _fix_parent(upgraded)
    return upgraded


def _fix_parent(obj: dict) -> None:
    parent = obj.get("parent")
    if not isinstance(parent, dict):
        return

    path = parent.get("path", "")
    if "Bulb" not in path and "Example" not in path:
        return

    resource_type = obj.get("resourceType")
    if resource_type == "GMScript":
        obj["parent"] = {"name": "Scripts", "path": "folders/Scripts.yy"}
    elif resource_type == "GMShader":
        obj["parent"] = {"name": "Shaders", "path": "folders/Shaders.yy"}
    elif resource_type == "GMSprite":
        obj["parent"] = {"name": "Sprites", "path": "folders/Sprites.yy"}


def _is_bulb_yy(path: Path) -> bool:
    parts = path.parts
    if "scripts" in parts:
        idx = parts.index("scripts")
        if idx + 1 < len(parts):
            name = parts[idx + 1]
            return name.startswith(BULB_SCRIPT_PREFIXES)
    if "shaders" in parts:
        idx = parts.index("shaders")
        if idx + 1 < len(parts):
            name = parts[idx + 1]
            return name.startswith(BULB_SHADER_PREFIXES) or name == "shdPremultiplyAlpha"
    if "sprites" in parts:
        idx = parts.index("sprites")
        if idx + 1 < len(parts):
            return parts[idx + 1] in BULB_SPRITES
    if "folders" in parts and "Bulb" in parts:
        return True
    return False


def convert_yy_file(path: Path) -> bool:
    raw = path.read_text(encoding="utf-8")
    cleaned = re.sub(r",(\s*[\]}])", r"\1", raw)
    data = json.loads(cleaned)
    upgraded = _upgrade_object(data)
    if upgraded == data:
        return False

    path.write_text(json.dumps(upgraded, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    return True


def iter_bulb_yy_files(root: Path) -> list[Path]:
    files: list[Path] = []
    for pattern in ("scripts", "shaders", "sprites", "folders"):
        base = root / pattern
        if not base.is_dir():
            continue
        for path in base.rglob("*.yy"):
            if _is_bulb_yy(path):
                files.append(path)
    return sorted(files)


def remove_orphan_yy_files() -> None:
    orphans = [
        PROJ_ROOT / "scripts/BulbDynamicOccluder/bulb_create_static_occluder.yy",
        PROJ_ROOT / "sprites/sLight1024/spr_light.yy",
        PROJ_ROOT / "shaders/shdPremultiplyAlpha/__shd_bulb_premultiply_alpha.yy",
    ]
    for path in orphans:
        if path.exists():
            path.unlink()


def main() -> None:
    remove_orphan_yy_files()
    converted = 0
    for path in iter_bulb_yy_files(PROJ_ROOT):
        if convert_yy_file(path):
            converted += 1
            print(f"converted: {path.relative_to(PROJ_ROOT)}")
    print(f"Done. Converted {converted} .yy file(s).")


if __name__ == "__main__":
    main()
