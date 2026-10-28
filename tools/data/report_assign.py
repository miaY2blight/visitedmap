"""Task 4 の結果の表を作る(record_unit と grid_level)。出力: out/assign_report.json と標準出力。

grid_level は、日本と主要都市の地点(40km 四方)で、ADM2 の区画ごとに、箱で切り取った範囲の
GHS-POP(人口/km²)と GHS-SMOD(市街地の割合)から割り当てる。あわせて、1km セル単位の階層の分布も出す。
"""

import csv
import json
import math
from collections import defaultdict
from pathlib import Path

import numpy as np
import rasterio
from rasterio.features import geometry_mask
from rasterio.warp import transform, transform_geom
from rasterio.windows import from_bounds
from shapely.geometry import box, mapping, shape

from assign_grid_level import grid_level
from assign_record_unit import load_overrides, record_unit

HERE = Path(__file__).parent
OUT = HERE / "out"
URBAN_CLASSES = {22, 23, 30}  # GHS-SMOD: セミ高密度クラスター、高密度クラスター、都市中心
POP_TILES = ["R5_C31", "R5_C30", "R4_C19", "R14_C32", "R5_C8", "R5_C12"]


def load_pack(iso3: str) -> dict:
    return json.loads((OUT / f"regions_{iso3}.json").read_text(encoding="utf-8"))


def record_unit_table(countries: list[str]) -> list[dict]:
    overrides = load_overrides(HERE / "record_unit_overrides.csv")
    rows = []
    for iso3 in countries:
        pack = load_pack(iso3)
        by_level = defaultdict(list)
        for r in pack["regions"]:
            by_level[r["level"]].append(r["area_km2"])
        country_area = by_level["country"][0]
        a1 = by_level["admin1"]
        a2 = by_level["admin2"]
        mean_a1 = sum(a1) / len(a1) if a1 else None
        has_admin2 = len(a2) > len(a1)  # ADM1 と同数以下なら、実質の下位区分ではない
        unit = record_unit(mean_a1, country_area, has_admin2, override=overrides.get(iso3))
        areas = by_level[unit]
        rows.append(
            {
                "iso3": iso3,
                "country_area_km2": round(country_area),
                "admin1_count": len(a1),
                "admin1_mean_km2": round(mean_a1) if mean_a1 else None,
                "admin2_count": len(a2),
                "has_real_admin2": has_admin2,
                "record_unit": unit,
                "unit_regions": len(areas),
                "unit_mean_km2": round(sum(areas) / len(areas)),
                "unit_max_km2": round(max(areas)),
                "unit_min_km2": round(min(areas), 1),
            }
        )
    return rows


def open_pop_tile_for(lon: float, lat: float):
    for tile in POP_TILES:
        zp = HERE / "cache" / "ghsl" / f"GHS_POP_E2020_54009_1000_{tile}.zip"
        tif = f"GHS_POP_E2020_GLOBE_R2023A_54009_1000_V1_0_{tile}.tif"
        ds = rasterio.open(f"zip://{zp}!{tif}")
        xs, ys = transform("EPSG:4326", ds.crs, [lon], [lat])
        b = ds.bounds
        if b.left <= xs[0] <= b.right and b.bottom <= ys[0] <= b.top:
            return ds
        ds.close()
    raise RuntimeError(f"人口のタイルが見つかりません: {lat},{lon}")


def read_window(ds, geom_wgs84):
    """WGS84 の形の外接矩形に当たる範囲を読む。(配列, 変換, 窓)"""
    g = transform_geom("EPSG:4326", ds.crs, mapping(geom_wgs84), precision=-1)
    gb = shape(g).bounds
    raw = from_bounds(*gb, transform=ds.transform)
    col0, row0 = math.floor(raw.col_off), math.floor(raw.row_off)
    col1 = max(math.ceil(raw.col_off + raw.width), col0 + 1)  # 1 セルより小さい形でも 1 セルは読む
    row1 = max(math.ceil(raw.row_off + raw.height), row0 + 1)
    win = rasterio.windows.Window(col0, row0, col1 - col0, row1 - row0)
    win = win.intersection(rasterio.windows.Window(0, 0, ds.width, ds.height))
    data = ds.read(1, window=win, masked=True)
    return data, ds.window_transform(win), g


def site_box(lat: float, lon: float, half_km: float):
    dlat = half_km / 111.32
    dlon = half_km / (111.32 * math.cos(math.radians(lat)))
    return box(lon - dlon, lat - dlat, lon + dlon, lat + dlat)


def grid_level_for_site(site: dict, pack: dict, smod_ds) -> dict:
    lat, lon, half = float(site["lat"]), float(site["lon"]), float(site["half_size_km"])
    area_box = site_box(lat, lon, half)
    pop_ds = open_pop_tile_for(lon, lat)
    regions = [r for r in pack["regions"] if r["level"] == "admin2"]
    rows = []
    for r in regions:
        geom = shape(r["geometry"])
        if not geom.intersects(area_box):
            continue
        clipped = geom.intersection(area_box)
        if clipped.is_empty:
            continue
        pop, transform_, g = read_window(pop_ds, clipped)
        mask = geometry_mask([g], out_shape=pop.shape, transform=transform_, invert=True)
        vals = np.ma.array(pop, mask=pop.mask | ~mask)
        n = vals.count()
        smod, smod_tr, _ = read_window(smod_ds, clipped)
        smask = geometry_mask([g], out_shape=smod.shape, transform=smod_tr, invert=True)
        sv = np.ma.array(smod, mask=smod.mask | ~smask)
        if n == 0:  # 1km セルより小さい区画は、代表点のセルで代用
            pt = clipped.representative_point()
            xs, ys = transform("EPSG:4326", pop_ds.crs, [pt.x], [pt.y])
            density = max(float(next(pop_ds.sample([(xs[0], ys[0])]))[0]), 0.0)
            urban = 0.0
        else:
            density = float(vals.mean())
            urban = float(np.isin(sv.compressed(), list(URBAN_CLASSES)).mean()) if sv.count() else 0.0
        rows.append(
            {
                "name": r["name"],
                "region_id": r["region_id"],
                "area_km2": round(clipped.area * 0 + _area(clipped), 1),
                "density": round(density, 1),
                "urban_share": round(urban, 3),
                "grid_level": grid_level(density, urban),
            }
        )
    # 1km セル単位の階層の分布(箱の全体)
    pop_all, _, _ = read_window(pop_ds, area_box)
    smod_all, _, _ = read_window(smod_ds, area_box)
    land = np.ones(pop_all.shape, dtype=bool)
    if smod_all.shape == pop_all.shape:  # 2 つのラスタは同じ 1km 格子。水域(クラス 10)を除く
        land = ~np.ma.getdata(smod_all == 10)
    else:
        print("警告: SMOD と POP の窓が一致しません。水域を除きません", smod_all.shape, pop_all.shape)
    cells = np.ma.array(pop_all, mask=pop_all.mask | ~land).compressed()
    cell_levels = [grid_level(max(float(v), 0.0), 0.0) for v in cells]
    cell_hist = defaultdict(int)
    for lv in cell_levels:
        cell_hist[lv] += 1
    total_area = sum(r["area_km2"] for r in rows) or 1.0
    by_level = defaultdict(lambda: {"regions": 0, "area_km2": 0.0, "top": []})
    for r in sorted(rows, key=lambda x: -x["area_km2"]):
        e = by_level[r["grid_level"]]
        e["regions"] += 1
        e["area_km2"] += r["area_km2"]
        if len(e["top"]) < 5:
            e["top"].append(r["name"] or "(名前なし)")
    pop_ds.close()
    return {
        "site": site["name"],
        "kind": site["kind"],
        "iso3": site["iso3"],
        "regions_in_box": len(rows),
        "regions": rows,
        "by_region_level": {
            lv: {
                "regions": e["regions"],
                "area_share": round(e["area_km2"] / total_area, 3),
                "top_names": e["top"],
            }
            for lv, e in sorted(by_level.items())
        },
        "cell_level_share": {lv: round(c / max(len(cell_levels), 1), 3) for lv, c in sorted(cell_hist.items())},
    }


def _area(geometry) -> float:
    from build_regions import area_km2

    return area_km2(geometry)


def main() -> None:
    with (HERE / "sample_areas.csv").open(encoding="utf-8", newline="") as f:
        sites = list(csv.DictReader(f))
    countries = sorted({s["iso3"] for s in sites})
    report = {"record_unit": record_unit_table(countries), "grid_level": []}
    smod_zip = HERE / "cache" / "ghsl" / "GHS_SMOD_E2020_GLOBE_R2023A_54009_1000_V2_0.zip"
    smod_ds = rasterio.open(f"zip://{smod_zip}!GHS_SMOD_E2020_GLOBE_R2023A_54009_1000_V2_0.tif")
    packs = {}
    for s in sites:
        if s["kind"] not in ("japan", "major_city"):
            continue
        pack = packs.setdefault(s["iso3"], load_pack(s["iso3"]))
        res = grid_level_for_site(s, pack, smod_ds)
        report["grid_level"].append(res)
        print(json.dumps(res, ensure_ascii=False))
    (OUT / "assign_report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print("\n== record_unit ==")
    for r in report["record_unit"]:
        print(json.dumps(r, ensure_ascii=False))


if __name__ == "__main__":
    main()
