from shapely.geometry import box

from build_unreachable import analyze_regions, reachable_area_km2, unreachable_cells
from tilemath import lonlat_to_tile, tile_bounds

# 東京周辺の 0.2 度四方の区画。階層 14(約 2.4km)の判定マス
REGION = {"region_id": "r1", "geometry": box(139.60, 35.60, 139.80, 35.80), "grid_level": 14, "area_km2": 400.0}


def z16_in(lon, lat):
    return lonlat_to_tile(lon, lat, 16)


def judge_cells(region):
    """区画の中心が内側にある判定マス全体を数える(テストの期待値の計算用)"""
    return analyze_regions([region], set())["r1"]["assigned"]


def test_cell_with_presence_is_reachable_and_empty_cells_are_unreachable():
    presence = {z16_in(139.70, 35.70)}  # 1 つの判定マスにだけ存在がある
    result = analyze_regions([REGION], presence)["r1"]
    total = result["assigned"]
    assert total == judge_cells(REGION) > 10
    assert len(result["unreachable"]) == total - 1
    z14 = lonlat_to_tile(139.70, 35.70, 14)
    assert (14, *z14) not in result["unreachable"]


def test_one_z16_cell_inside_a_coarse_cell_is_enough():
    # 階層 12 の判定マスは、中の z16 セル 256 個のどれか 1 つに存在があれば到達できる
    region = {**REGION, "grid_level": 12}
    z12 = lonlat_to_tile(139.70, 35.70, 12)
    west, south, east, north = tile_bounds(12, *z12)
    corner = z16_in(west + 1e-4, north - 1e-4)  # 判定マスの角の z16 セル
    result = analyze_regions([region], {corner})["r1"]
    assert (12, *z12) not in result["unreachable"]
    assert len(result["unreachable"]) == result["assigned"] - 1


def test_level_17_uses_the_parent_z16_cell():
    region = {**REGION, "grid_level": 17, "geometry": box(139.700, 35.700, 139.704, 35.704)}
    result = analyze_regions([region], {z16_in(139.702, 35.702)})["r1"]
    assert result["assigned"] > 0
    # z16 の粒度までしか分からないので、同じ z16 セルの中の z17 は区別しない
    inside = [c for c in result["unreachable"] if (c[1] >> 1, c[2] >> 1) == z16_in(139.702, 35.702)]
    assert inside == []


def test_cells_whose_center_is_outside_the_region_are_not_counted():
    # 区画の縁をまたぐ判定マスは、中心が外側なら数えない
    small = {**REGION, "geometry": box(139.700, 35.700, 139.710, 35.705), "grid_level": 14}
    result = analyze_regions([small], set())["r1"]
    for _, x, y in result["unreachable"]:
        west, south, east, north = tile_bounds(14, x, y)
        assert 139.700 <= (west + east) / 2 <= 139.710 and 35.700 <= (south + north) / 2 <= 35.705


def test_cells_outside_the_coverage_are_not_judged():
    coverage = box(139.60, 35.60, 139.70, 35.80)  # 区画の西半分だけ
    full = analyze_regions([REGION], set())["r1"]["assigned"]
    half = analyze_regions([REGION], set(), coverage=coverage)["r1"]["assigned"]
    assert 0 < half < full
    for _, x, y in analyze_regions([REGION], set(), coverage=coverage)["r1"]["unreachable"]:
        west, south, east, north = tile_bounds(14, x, y)
        assert (west + east) / 2 <= 139.70


def test_unreachable_cells_returns_lists_of_level_x_y_per_region():
    out = unreachable_cells([REGION], set())
    assert set(out) == {"r1"}
    assert all(len(c) == 3 and c[0] == 14 for c in out["r1"])


def test_reachable_area_is_the_total_when_nothing_is_unreachable():
    # すべての判定マスに存在を置く
    all_cells = analyze_regions([REGION], set())["r1"]["unreachable"]
    presence = set()
    for _, x, y in all_cells:
        presence.add(lonlat_to_tile(*tile_bounds_center(14, x, y), 16))
    area = reachable_area_km2([REGION], presence)["r1"]
    assert area == REGION["area_km2"]


def tile_bounds_center(z, x, y):
    west, south, east, north = tile_bounds(z, x, y)
    return (west + east) / 2, (south + north) / 2


def test_reachable_area_shrinks_with_unreachable_cells_and_never_exceeds_total():
    presence = {z16_in(139.70, 35.70)}
    area = reachable_area_km2([REGION], presence)["r1"]
    assert 0 < area < REGION["area_km2"]
    assert reachable_area_km2([REGION], set())["r1"] == 0


def test_region_without_assigned_cells_keeps_its_area():
    tiny = {**REGION, "geometry": box(139.700, 35.700, 139.7001, 35.7001), "grid_level": 12}
    result = analyze_regions([tiny], set())["r1"]
    assert result["assigned"] == 0
    assert reachable_area_km2([tiny], set())["r1"] == tiny["area_km2"]
