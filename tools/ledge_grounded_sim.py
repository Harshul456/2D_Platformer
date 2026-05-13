"""
Quick regression sweep for ledge grounding (matches check_tile_collision + scr_player_movement 2 / 6c).
Run: python tools/ledge_grounded_sim.py
"""
from __future__ import annotations

import re
from pathlib import Path

TW = TH = 32
GROUND_CHECK_DIST = 1
GROUND_PROBE_EDGE_INSET = 12
GROUND_STANDABLE_EMBED_PX = 10
GROUND_LAND_VOTES_MIN_AIR = 2
WALL_SIDE = 0
VSP = 0.0

ROOT = Path(__file__).resolve().parent.parent


def load_sprite_collision(yy_path: Path):
    text = yy_path.read_text(encoding="utf-8")

    def grab_int(key: str) -> int:
        m = re.search(rf'"{key}":\s*(-?\d+)', text)
        if not m:
            raise ValueError(f"missing {key}")
        return int(m.group(1))

    return dict(
        bbox_left=grab_int("bbox_left"),
        bbox_right=grab_int("bbox_right"),
        bbox_top=grab_int("bbox_top"),
        bbox_bottom=grab_int("bbox_bottom"),
        xorigin=grab_int("xorigin"),
        yorigin=grab_int("yorigin"),
    )


def instance_bbox(inst_x: int, inst_y: int, spr: dict) -> tuple[int, int, int, int]:
    left = inst_x + spr["bbox_left"] - spr["xorigin"]
    top = inst_y + spr["bbox_top"] - spr["yorigin"]
    right = inst_x + spr["bbox_right"] - spr["xorigin"]
    bottom = inst_y + spr["bbox_bottom"] - spr["yorigin"]
    return left, top, right, bottom


def inst_y_for_bbox_bottom(spr: dict, bbox_bottom: int) -> int:
    return bbox_bottom - spr["bbox_bottom"] + spr["yorigin"]


def tile_index_at(tm: dict, px: int, py: int) -> int:
    return tm.get((px // TW, py // TH), 0)


def one_way_shelf(idx: int) -> bool:
    return idx in (1, 5, 34, 36)


WF = 0.52
HF = 0.38


def shelf_cap_solid(idx: int, lx: int, ly: int) -> bool:
    """Match tilecol_one_way_cap_shelf_hit: ly in shelf band + cap TL/TR footprint."""
    if ly < 0 or ly > 3:
        return False
    if idx in (5, 34):
        return lx < TW * WF and ly < TH * HF
    if idx in (1, 36):
        lx2 = TW - 1 - lx
        return lx2 < TW * WF and ly < TH * HF
    return False


def shelf_hit(idx: int, lx: int, ly: int) -> bool:
    return shelf_cap_solid(idx, lx, ly)


def point_solid(tm: dict, px: int, py: int, rising: bool = False, feet_b: int | None = None) -> bool:
    idx = tile_index_at(tm, px, py)
    if idx == 0:
        return False
    cx, cy = px // TW, py // TH
    cell_top = cy * TH
    lx = px - cx * TW
    ly = py - cy * TH
    if one_way_shelf(idx):
        if not shelf_hit(idx, lx, ly):
            return False
        sbot = cell_top + 3
        if rising and feet_b is not None and feet_b > sbot:
            return False
        return True
    return True


def cell_thin_floor_tile(tm: dict, px: int, py: int) -> bool:
    idx = tile_index_at(tm, px, py)
    if idx == 0:
        return False
    cx, cy = px // TW, py // TH
    lx = px - cx * TW
    ly = py - cy * TH
    if one_way_shelf(idx):
        return shelf_hit(idx, lx, ly)
    return True


def cell_thin_floor_near_feet(tm: dict, px: int, feet_y: int) -> bool:
    return any(cell_thin_floor_tile(tm, px, feet_y + dy) for dy in (-1, 0, 1, 2))


def floor_standable(tm: dict, px: int, feet_y: int) -> bool:
    if not point_solid(tm, px, feet_y + GROUND_CHECK_DIST):
        return False
    tidx = tile_index_at(tm, px, feet_y + GROUND_CHECK_DIST)
    if tidx != 0 and one_way_shelf(tidx):
        return True
    if point_solid(tm, px, feet_y) and point_solid(tm, px, feet_y - GROUND_STANDABLE_EMBED_PX):
        return False
    return True


def sim_6c(tm: dict, left: int, top: int, right: int, bottom: int) -> bool:
    feet_y = bottom
    p_left = left + 1
    p_right = right - 1
    p_center = (left + right) // 2
    pgl = left + GROUND_PROBE_EDGE_INSET
    pgr = right - GROUND_PROBE_EDGE_INSET
    if pgl >= pgr:
        pgl, pgr = p_left, p_right
    fpy = feet_y + GROUND_CHECK_DIST
    cap_now = any(cell_thin_floor_near_feet(tm, px, feet_y) for px in (p_center, p_left, p_right, pgl, pgr))
    stand_c = floor_standable(tm, p_center, feet_y)
    stand_l = floor_standable(tm, pgl, feet_y)
    stand_r = floor_standable(tm, pgr, feet_y)
    if cap_now:
        stand_l = floor_standable(tm, p_left, feet_y)
        stand_r = floor_standable(tm, p_right, feet_y)
    votes = stand_l + stand_c + stand_r
    raw = sum(1 for px in (p_center, p_left, p_right) if point_solid(tm, px, fpy))
    raw_any = any(point_solid(tm, px, fpy) for px in (p_center, p_left, p_right))
    center_floor = point_solid(tm, p_center, fpy)
    if cap_now:
        on = (
            votes >= GROUND_LAND_VOTES_MIN_AIR
            and raw >= GROUND_LAND_VOTES_MIN_AIR
            and raw_any
            and (stand_l or stand_c or stand_r)
            and center_floor
        )
    else:
        on = votes >= GROUND_LAND_VOTES_MIN_AIR and raw >= GROUND_LAND_VOTES_MIN_AIR and center_floor
    return on


def main() -> None:
    yy = ROOT / "sprites/spr_mc_idle/spr_mc_idle.yy"
    spr = load_sprite_collision(yy)
    feet_b = 2
    inst_y = inst_y_for_bbox_bottom(spr, feet_b)
    print(f"Loaded spr_mc_idle bbox; feet_bottom={feet_b}, inst_y={inst_y}")
    for tile_idx in (1, 5, 34, 36):
        tm = {(0, 0): tile_idx}
        ok = 0
        for ix in range(-15, 50):
            left, top, right, bottom = instance_bbox(ix, inst_y, spr)
            if sim_6c(tm, left, top, right, bottom):
                ok += 1
        print(f"  tile {tile_idx}: 6c grounded x positions ~{ok}/65 (narrow cap band)")


if __name__ == "__main__":
    main()
