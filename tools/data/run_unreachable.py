"""Task 5 の実データでの実行: 日本と主要都市の地点ごとに、存在のセル(OSM)と到達できない判定マスを作り、
所要時間・メモリ・出力サイズを記録し、目で確認する画像を出す。

使い方: python run_unreachable.py [地点名の一部 ...]   (引数なしなら、PBF がある全地点)
出力: out/unreachable_<ISO3>.json、out/unreachable_stats.json、out/img/unreachable_<番号>.png
"""

import csv
import json
import os
import sys
import time
from pathlib import Path

import psutil
from shapely.geometry import box, shape

from build_presence import presence_cells
from build_regions import area_km2
from build_unreachable import analyze_regions
from report_assign import site_box
from tilemath import lonlat_to_tile, tile_bounds

HERE = Path(__file__).parent
OUT = HERE / "out"
SITE_PBF = {
    "東京・渋谷": "kanto",
    "埼玉の郊外(東松山付近)": "kanto",
    "上高地周辺": "chubu",
    "パリ": "ile-de-france",
    "シドニー": "new-south-wales",
    "ロサンゼルス": "socal",
    "ソウル・明洞〜江南": "south-korea",
    "ニューヨーク・マンハッタン": "new-york",
}


# OSM の抽出が地点の箱より狭い地点は、判定する範囲を、抽出の範囲(米国の州)に限る。
# 範囲外(ニューヨークの箱に入るニュージャージー側)を判定すると、データがないだけで「到達できない」になる
# 環境変数 FIXED_LEVEL を指定すると、すべての区画の判定マスの階層をそれに固定した変種を実行する
# (区画ごとの階層が粗すぎて判定できない地点を、細かい階層で見るため)。結果のファイルは別名にする
FIXED_LEVEL = int(os.environ["FIXED_LEVEL"]) if os.environ.get("FIXED_LEVEL") else None
SUFFIX = f"_z{FIXED_LEVEL}" if FIXED_LEVEL else ""

COVERAGE_ADM1 = {"ニューヨーク・マンハッタン": "New York"}


def peak_mb() -> float:
    return psutil.Process().memory_info().peak_wset / 1e6


def draw(path: Path, title: str, bbox, presence, regions, analysis) -> None:
    import matplotlib

    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    import numpy as np
    from matplotlib import font_manager

    for name in ("Yu Gothic", "MS Gothic", "Meiryo"):
        if any(f.name == name for f in font_manager.fontManager.ttflist):
            plt.rcParams["font.family"] = name
            break
    south, west, north, east = bbox
    x0, y1 = lonlat_to_tile(west, south, 16)
    x1, y0 = lonlat_to_tile(east, north, 16)
    grid = np.zeros((y1 - y0 + 1, x1 - x0 + 1), dtype=np.uint8)
    for x, y in presence:
        if x0 <= x <= x1 and y0 <= y <= y1:
            grid[y - y0, x - x0] = 1
    for r in regions:
        for level, x, y in analysis[r["region_id"]]["unreachable"]:
            if level > 16:
                shift = level - 16
                cx0, cx1, cy0, cy1 = x >> shift, (x >> shift), y >> shift, (y >> shift)
            else:
                shift = 16 - level
                cx0, cx1, cy0, cy1 = x << shift, ((x + 1) << shift) - 1, y << shift, ((y + 1) << shift) - 1
            xs, xe = max(cx0, x0), min(cx1, x1)
            ys, ye = max(cy0, y0), min(cy1, y1)
            if xs <= xe and ys <= ye:
                grid[ys - y0 : ye - y0 + 1, xs - x0 : xe - x0 + 1] = 2
    fig, ax = plt.subplots(figsize=(9, 9), dpi=110)
    from matplotlib.colors import ListedColormap

    ax.imshow(grid, cmap=ListedColormap(["#f2f2f2", "#9fb6cd", "#e4572e"]), vmin=0, vmax=2, interpolation="nearest")
    for r in regions:
        geom = r["geometry"]
        for poly in getattr(geom, "geoms", [geom]):
            xs, ys = poly.exterior.xy
            px = [(lonlat_to_tile(lo, la, 16)[0] - x0) + 0.5 for lo, la in zip(xs, ys)]
            py = [(lonlat_to_tile(lo, la, 16)[1] - y0) + 0.5 for lo, la in zip(xs, ys)]
            ax.plot(px, py, color="#333", linewidth=0.4)
    ax.set_title(f"{title}  灰=存在なし(判定対象外)  青=存在あり  赤=到達できない判定マス", fontsize=9)
    ax.set_xlim(0, x1 - x0)
    ax.set_ylim(y1 - y0, 0)
    ax.axis("off")
    path.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(path, bbox_inches="tight")
    plt.close(fig)


def main() -> None:
    wanted = sys.argv[1:]
    report = json.loads((OUT / "assign_report.json").read_text(encoding="utf-8"))
    with (HERE / "sample_areas.csv").open(encoding="utf-8", newline="") as f:
        sites = {row["name"]: row for row in csv.DictReader(f)}
    stats_path = OUT / "unreachable_stats.json"
    stats = json.loads(stats_path.read_text(encoding="utf-8")) if stats_path.exists() else {}
    for index, g in enumerate(report["grid_level"]):
        name = g["site"]
        if wanted and not any(w in name for w in wanted):
            continue
        pbf = HERE / "cache" / "osm" / f"{SITE_PBF[name]}-latest.osm.pbf"
        if not pbf.exists():
            print("PBF がないため飛ばします:", name)
            continue
        site = sites[name]
        iso3 = site["iso3"]
        area_box = site_box(float(site["lat"]), float(site["lon"]), float(site["half_size_km"]))
        w, s, e, n = area_box.bounds
        bbox = (s, w, n, e)
        cache_file = HERE / "cache" / f"presence_{index}.json"
        t0 = time.time()
        if cache_file.exists():
            cached = json.loads(cache_file.read_text(encoding="utf-8"))
            presence = {tuple(c) for c in cached["cells"]}
            t_presence = cached["seconds"]
        else:
            presence = presence_cells(pbf, 16, bbox)
            t_presence = time.time() - t0
            cache_file.write_text(
                json.dumps({"seconds": t_presence, "cells": sorted(presence)}, separators=(",", ":")), encoding="utf-8"
            )
        pack = json.loads((OUT / f"regions_{iso3}.json").read_text(encoding="utf-8"))
        geoms = {r["region_id"]: shape(r["geometry"]) for r in pack["regions"] if r["level"] == "admin2"}
        regions = []
        for row in g["regions"]:
            geom = geoms[row["region_id"]]
            regions.append(
                {
                    "region_id": row["region_id"],
                    "geometry": geom.intersection(area_box),
                    "grid_level": FIXED_LEVEL or row["grid_level"],
                    "area_km2": area_km2(geom.intersection(area_box)),
                    "name": row["name"],
                }
            )
        coverage = area_box
        if name in COVERAGE_ADM1:
            state = next(
                shape(r["geometry"])
                for r in pack["regions"]
                if r["level"] == "admin1" and r["name"] == COVERAGE_ADM1[name]
            )
            coverage = area_box.intersection(state.buffer(-0.012))  # 州境から約 1.3km 内側(境界をまたぐセルの向こう側にデータがない)
        t1 = time.time()
        analysis = analyze_regions(regions, presence, coverage=coverage)
        t_unreach = time.time() - t1
        assigned = sum(a["assigned"] for a in analysis.values())
        unreachable = sum(len(a["unreachable"]) for a in analysis.values())
        # 並列に走る別の処理の結果を消さないよう、書く直前に読み直して、自分の地点の分だけ足す
        out_path = OUT / f"unreachable_{iso3}{SUFFIX}.json"
        country = json.loads(out_path.read_text(encoding="utf-8")) if out_path.exists() else {}
        for rid, a in analysis.items():
            country[rid] = [list(c) for c in a["unreachable"]]
        out_path.write_text(json.dumps(country, separators=(",", ":")), encoding="utf-8")
        # 到達できる面積(km²)= 区画の面積(箱で切った範囲)× (割り当てたマス − 到達できないマス) / 割り当てたマス
        reach_path = OUT / f"reachable_{iso3}{SUFFIX}.json"
        reach = json.loads(reach_path.read_text(encoding="utf-8")) if reach_path.exists() else {}
        for r in regions:
            a = analysis[r["region_id"]]
            reach[r["region_id"]] = (
                round(r["area_km2"], 3)
                if a["assigned"] == 0
                else round(r["area_km2"] * (a["assigned"] - len(a["unreachable"])) / a["assigned"], 3)
            )
        reach_path.write_text(json.dumps(reach, separators=(",", ":")), encoding="utf-8")
        total_area = sum(r["area_km2"] for r in regions)
        stats_key = name + (f" [z{FIXED_LEVEL}固定]" if FIXED_LEVEL else "")
        stats[stats_key] = {
            "pbf": pbf.name,
            "pbf_mb": round(pbf.stat().st_size / 1e6),
            "box_km2": round(total_area),
            "presence_cells": len(presence),
            "seconds_presence": round(t_presence, 1),
            "seconds_unreachable": round(t_unreach, 1),
            "peak_mb": round(peak_mb()),
            "judge_cells": assigned,
            "unreachable_cells": unreachable,
            "unreachable_ratio": round(unreachable / assigned, 3) if assigned else None,
            "regions": len(regions),
            "json_bytes_this_site": len(json.dumps({r["region_id"]: analysis[r["region_id"]]["unreachable"] for r in regions}, separators=(",", ":"))),
        }
        draw(OUT / "img" / f"unreachable_{index}{SUFFIX}.png", stats_key, bbox, presence, regions, analysis)
        print(stats_key, json.dumps(stats[stats_key], ensure_ascii=False), flush=True)
        latest = json.loads(stats_path.read_text(encoding="utf-8")) if stats_path.exists() else {}
        latest[stats_key] = stats[stats_key]
        stats_path.write_text(json.dumps(latest, ensure_ascii=False, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()
