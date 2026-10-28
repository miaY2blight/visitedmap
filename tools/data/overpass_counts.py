"""検証地点(40km 四方)の観光施設(OSM の tourism・historic)の件数を Overpass API で数える。
`record_unit` の入力(観光施設の密度)の有効性を測るため。件数だけを返す軽いクエリ(out count)を、
1 地点 1 回、直列、10 秒以上の間隔で投げる。結果は cache/overpass_counts.json にキャッシュし、同じ地点は再取得しない。
規約: https://wiki.openstreetmap.org/wiki/Overpass_API (User-Agent で識別、並列にしない、429/504 の後は待つ)
"""

import csv
import json
import math
import sys
import time
from pathlib import Path

import requests

from fetch import USER_AGENT

HERE = Path(__file__).parent
CACHE_FILE = HERE / "cache" / "overpass_counts.json"
ENDPOINT = "https://overpass-api.de/api/interpreter"
INTERVAL_SECONDS = 10
HALF_SIZE_KM = 20  # 40km 四方に揃える(region_only も同じ大きさで比べる)
QUERY = """[out:json][timeout:120];
(
  nwr["tourism"]({s},{w},{n},{e});
  nwr["historic"]({s},{w},{n},{e});
);
out count;"""


def bbox(lat: float, lon: float, half_km: float) -> tuple[float, float, float, float]:
    dlat = half_km / 111.32
    dlon = half_km / (111.32 * math.cos(math.radians(lat)))
    return lat - dlat, lon - dlon, lat + dlat, lon + dlon


def box_area_km2(lat: float, half_km: float) -> float:
    return (2 * half_km) ** 2  # 緯度経度とも、実距離で 2*half の箱


def main() -> None:
    results = json.loads(CACHE_FILE.read_text(encoding="utf-8")) if CACHE_FILE.exists() else {}
    with (HERE / "sample_areas.csv").open(encoding="utf-8", newline="") as f:
        sites = list(csv.DictReader(f))
    failures = 0
    for site in sites:
        key = f"{site['name']}"
        if site["kind"] == "dateline":
            continue  # 180 度線をまたぐ範囲は Overpass の bbox にできない。密度の測定対象外
        if key in results and "total" in results[key]:
            continue
        s, w, n, e = bbox(float(site["lat"]), float(site["lon"]), HALF_SIZE_KM)
        query = QUERY.format(s=round(s, 5), w=round(w, 5), n=round(n, 5), e=round(e, 5))
        for attempt in (1, 2):
            time.sleep(INTERVAL_SECONDS)
            try:
                res = requests.post(ENDPOINT, data={"data": query}, headers={"User-Agent": USER_AGENT}, timeout=200)
            except requests.RequestException as exc:
                print(key, "通信エラー", exc, flush=True)
                res = None
            if res is not None and res.status_code == 200:
                tags = res.json()["elements"][0]["tags"]
                total = int(tags["total"])
                results[key] = {
                    "iso3": site["iso3"],
                    "kind": site["kind"],
                    "total": total,
                    "nodes": int(tags["nodes"]),
                    "ways": int(tags["ways"]),
                    "relations": int(tags["relations"]),
                    "box_km2": box_area_km2(float(site["lat"]), HALF_SIZE_KM),
                    "density_per_km2": round(total / box_area_km2(float(site["lat"]), HALF_SIZE_KM), 4),
                }
                print(key, results[key]["total"], results[key]["density_per_km2"], flush=True)
                failures = 0
                break
            if res is not None:
                print(key, "HTTP", res.status_code, flush=True)
            time.sleep(30)  # 429/504 の後は待つ
        else:
            failures += 1
            if failures >= 2:
                print("2 地点連続で失敗したため中止します", file=sys.stderr)
                break
        CACHE_FILE.parent.mkdir(parents=True, exist_ok=True)
        CACHE_FILE.write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding="utf-8")
    CACHE_FILE.write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding="utf-8")
    print("done", len(results), "sites")


if __name__ == "__main__":
    main()
