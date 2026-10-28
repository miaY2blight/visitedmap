"""Nominatim の実測(V-09: エリアの名前、V-11: lookup でポリゴン)。1 回限り、合計 60 リクエスト以内。

規約(https://operations.osmfoundation.org/policies/nominatim/):
  1 秒に 1 回まで(間隔 1.2 秒)、直列、識別できる User-Agent、結果をキャッシュ、同じ要求を繰り返さない。
  座標は points_world.csv の検証地点のみ。個人情報は送らない。
使い方: python nominatim_probe.py [v09|v11|all]    結果: cache/nominatim_cache.json、out/nominatim_results.json
"""

import csv
import json
import sys
import time
from pathlib import Path

import requests

HERE = Path(__file__).parent
CACHE_FILE = HERE / "cache" / "nominatim_cache.json"
RESULT_FILE = HERE / "out" / "nominatim_results.json"
BASE = "https://nominatim.openstreetmap.org"
USER_AGENT = "FogWorld/0.1 (personal learning project)"
INTERVAL_SECONDS = 1.2
MAX_REQUESTS = 60

# V-09 で「エリア」に相当する項目(住所の要素)。上にあるほど細かい
AREA_KEYS = ["neighbourhood", "quarter", "suburb", "city_district", "borough"]
# V-11 の場所(世界の公園、観光地、大きな施設)
PLACES = [
    "Yellowstone National Park",
    "Central Park, New York",
    "Hyde Park, London",
    "上野恩賜公園",
    "東京ディズニーランド",
    "Louvre Museum, Paris",
    "Sydney Opera House",
    "Serengeti National Park",
    "景福宮, 서울",
    "Angkor Wat",
]

_cache = json.loads(CACHE_FILE.read_text(encoding="utf-8")) if CACHE_FILE.exists() else {}
_requests_sent = 0
_session = requests.Session()
_session.headers["User-Agent"] = USER_AGENT


def get(path: str, params: dict) -> dict | list:
    """キャッシュにあれば返す。なければ 1.2 秒間隔で 1 回だけ送る。上限を超えたら中止。"""
    global _requests_sent
    key = path + "?" + "&".join(f"{k}={params[k]}" for k in sorted(params))
    if key in _cache:
        return _cache[key]
    if _requests_sent >= MAX_REQUESTS:
        raise RuntimeError(f"リクエストが上限 {MAX_REQUESTS} に達しました")
    time.sleep(INTERVAL_SECONDS)
    response = _session.get(f"{BASE}/{path}", params=params, timeout=60)
    _requests_sent += 1
    response.raise_for_status()
    data = response.json()
    _cache[key] = data
    CACHE_FILE.parent.mkdir(parents=True, exist_ok=True)
    CACHE_FILE.write_text(json.dumps(_cache, ensure_ascii=False), encoding="utf-8")
    print(f"[{_requests_sent}] {key[:120]}", flush=True)
    return data


def v09() -> list[dict]:
    rows = []
    with (HERE / "points_world.csv").open(encoding="utf-8", newline="") as f:
        for p in csv.DictReader(f):
            data = get("reverse", {"lat": p["lat"], "lon": p["lon"], "format": "jsonv2", "zoom": 18, "addressdetails": 1})
            address = data.get("address", {}) if isinstance(data, dict) else {}
            area_key = next((k for k in AREA_KEYS if k in address), None)
            rows.append(
                {
                    "name": p["name"],
                    "kind": p["kind"],
                    "iso3": p["iso3"],
                    "area_key": area_key,
                    "area_name": address.get(area_key) if area_key else None,
                    "city_district": address.get("city_district"),
                    "county": address.get("county"),
                    "city": address.get("city") or address.get("town") or address.get("village"),
                    "address_keys": sorted(address.keys()),
                    "display_name": (data.get("display_name") if isinstance(data, dict) else None),
                }
            )
    return rows


def v11() -> list[dict]:
    rows = []
    for place in PLACES:
        found = get("search", {"q": place, "format": "jsonv2", "limit": 1})
        if not found:
            rows.append({"place": place, "found": False})
            continue
        top = found[0]
        osm_id = f"{top['osm_type'][0].upper()}{top['osm_id']}"
        looked = get("lookup", {"osm_ids": osm_id, "format": "jsonv2", "polygon_geojson": 1})
        lookup_geom = (looked[0].get("geojson") if looked else None) or {}
        row = {
            "place": place,
            "found": True,
            "osm_id": osm_id,
            "category": top.get("category"),
            "type": top.get("type"),
            "lookup_geometry": lookup_geom.get("type"),
        }
        if lookup_geom.get("type") in (None, "Point"):
            # lookup でポリゴンが返らない場合の代替: search を polygon_geojson 付きで取り直す
            again = get("search", {"q": place, "format": "jsonv2", "limit": 1, "polygon_geojson": 1})
            fallback = (again[0].get("geojson") if again else None) or {}
            row["search_with_polygon_geometry"] = fallback.get("type")
        rows.append(row)
    return rows


def main() -> None:
    which = sys.argv[1] if len(sys.argv) > 1 else "all"
    results = json.loads(RESULT_FILE.read_text(encoding="utf-8")) if RESULT_FILE.exists() else {}
    if which in ("v09", "all"):
        results["v09"] = v09()
    if which in ("v11", "all"):
        results["v11"] = v11()
    RESULT_FILE.parent.mkdir(parents=True, exist_ok=True)
    RESULT_FILE.write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding="utf-8")
    print("requests sent:", _requests_sent, "cached total:", len(_cache))


if __name__ == "__main__":
    main()
