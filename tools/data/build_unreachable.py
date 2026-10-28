"""到達できない判定マスの一覧を作る(日本と主要都市の別枠だけ)。

判定マス = 区画の `grid_level` 階層のクアッドキーのセル。中心が区画の内側にあるものを、その区画に割り当てる。
判定マスの中の z16 セルのどれにも「存在」(build_presence)がなければ、到達できない。
階層 17 の判定マスは、z16 の親セルの有無で決める(z16 より細かくは分からない)。
"""

from shapely.geometry import Point
from shapely.prepared import prep

from tilemath import lonlat_to_tile, tile_bounds, tile_center

PRESENCE_ZOOM = 16


def _ancestors(presence: set[tuple[int, int]], level: int) -> set[tuple[int, int]]:
    """存在のある z16 セルを、階層 level(≦16)の祖先に直す。"""
    shift = PRESENCE_ZOOM - level
    return {(x >> shift, y >> shift) for x, y in presence}


def analyze_regions(regions: list[dict], presence: set[tuple[int, int]], coverage=None) -> dict[str, dict]:
    """区画 ID → {"assigned": 割り当てた判定マスの数, "unreachable": [(level, x, y), ...]}。

    regions: {"region_id", "geometry"(shapely, 経緯度), "grid_level"}。
    coverage: 判定する範囲(shapely)。OSM の抽出が地点の範囲だけのとき、範囲外のマスは判定しない。
    """
    by_level: dict[int, set[tuple[int, int]]] = {}
    results: dict[str, dict] = {}
    for region in regions:
        level = region["grid_level"]
        geometry = region["geometry"]
        if coverage is not None:
            geometry = geometry.intersection(coverage)
        assigned = 0
        unreachable: list[tuple[int, int, int]] = []
        if not geometry.is_empty:
            if level not in by_level:
                by_level[level] = _ancestors(presence, level) if level <= PRESENCE_ZOOM else set()
            prepared = prep(geometry)
            west, south, east, north = geometry.bounds
            x0, y1 = lonlat_to_tile(west, south, level)  # 南西の角: x 最小、y 最大
            x1, y0 = lonlat_to_tile(east, north, level)
            for x in range(x0, x1 + 1):
                for y in range(y0, y1 + 1):
                    lon, lat = tile_center(level, x, y)
                    if not prepared.contains(Point(lon, lat)):
                        continue
                    assigned += 1
                    if level <= PRESENCE_ZOOM:
                        reachable = (x, y) in by_level[level]
                    else:
                        reachable = (x >> (level - PRESENCE_ZOOM), y >> (level - PRESENCE_ZOOM)) in presence
                    if not reachable:
                        unreachable.append((level, x, y))
        results[region["region_id"]] = {"assigned": assigned, "unreachable": unreachable}
    return results


def unreachable_cells(
    regions: list[dict], presence: set[tuple[int, int]], coverage=None
) -> dict[str, list[tuple[int, int, int]]]:
    """区画 ID → 到達できない判定マス (level, x, y) の一覧。"""
    return {rid: r["unreachable"] for rid, r in analyze_regions(regions, presence, coverage).items()}


def reachable_area_km2(regions: list[dict], presence: set[tuple[int, int]], coverage=None) -> dict[str, float]:
    """区画 ID → 到達できる面積(km²)= 区画の面積 × (割り当てたマス − 到達できないマス) / 割り当てたマス。
    割り当てたマスがない小さな区画は、面積のまま。"""
    out: dict[str, float] = {}
    analysis = analyze_regions(regions, presence, coverage)
    for region in regions:
        r = analysis[region["region_id"]]
        if r["assigned"] == 0:
            out[region["region_id"]] = region["area_km2"]
        else:
            out[region["region_id"]] = region["area_km2"] * (r["assigned"] - len(r["unreachable"])) / r["assigned"]
    return out
