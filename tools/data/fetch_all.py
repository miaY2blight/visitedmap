"""2c の検証用データを取得する(OSM を除く)。出典は docs/handoff/ref_2c_data_sources.md。

使い方: python fetch_all.py [marine] [geoboundaries] [n03] [ghsl]   (引数なしなら全部)
取得先ごとの間隔は 1 秒以上空ける。結果は cache/MANIFEST.json に追記する(URL・サイズ・sha256・取得日)。
"""

import csv
import datetime
import json
import sys
import time
from pathlib import Path

import requests

from fetch import USER_AGENT, FetchError, _digest, fetch

HERE = Path(__file__).parent
CACHE = HERE / "cache"
MANIFEST = CACHE / "MANIFEST.json"
GB_API = "https://www.geoboundaries.org/api/current/gbOpen/{iso3}/{level}/"
GB_LEVELS = ["ADM0", "ADM1", "ADM2"]
INTERVAL_SECONDS = 1.2

NE_MARINE = "https://naturalearth.s3.amazonaws.com/10m_physical/ne_10m_geography_marine_polys.zip"
N03_PREFECTURES = {"13": "東京", "11": "埼玉", "20": "長野"}
N03_URL = "https://nlftp.mlit.go.jp/ksj/gml/data/N03/N03-2026/N03-20260101_{pref}_GML.zip"
GHSL = "https://jeodpp.jrc.ec.europa.eu/ftp/jrc-opendata/GHSL/"
GHS_SMOD = (
    GHSL + "GHS_SMOD_GLOBE_R2023A/GHS_SMOD_E2020_GLOBE_R2023A_54009_1000/V2-0/"
    "GHS_SMOD_E2020_GLOBE_R2023A_54009_1000_V2_0.zip"
)
GHS_POP_TILE = (
    GHSL + "GHS_POP_GLOBE_R2023A/GHS_POP_E2020_GLOBE_R2023A_54009_1000/V1-0/tiles/"
    "GHS_POP_E2020_GLOBE_R2023A_54009_1000_V1_0_{tile}.zip"
)
# 検証地点を含むタイル(モルワイデ図法の計算値。取得後に範囲を確認する)
GHS_POP_TILES = ["R5_C31", "R5_C30", "R4_C19", "R14_C32", "R5_C8", "R5_C12"]


def load_manifest() -> dict:
    if MANIFEST.exists():
        return json.loads(MANIFEST.read_text(encoding="utf-8"))
    return {}


def record(manifest: dict, key: str, url: str, path: Path, extra: dict | None = None) -> None:
    size, sha = _digest(path)
    manifest[key] = {
        "url": url,
        "path": str(path.relative_to(HERE)).replace("\\", "/"),
        "size": size,
        "sha256": sha,
        "fetched": datetime.date.today().isoformat(),
        **(extra or {}),
    }
    CACHE.mkdir(parents=True, exist_ok=True)
    MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")


def countries() -> list[str]:
    with (HERE / "sample_areas.csv").open(encoding="utf-8", newline="") as f:
        return sorted({row["iso3"] for row in csv.DictReader(f)})


def get_marine(manifest: dict) -> None:
    dest = fetch(NE_MARINE, CACHE / "natural_earth" / "ne_10m_geography_marine_polys.zip")
    record(manifest, "natural_earth_marine", NE_MARINE, dest)
    print("marine ok", dest.stat().st_size)


def get_geoboundaries(manifest: dict) -> None:
    session = requests.Session()
    session.headers["User-Agent"] = USER_AGENT
    for iso3 in countries():
        for level in GB_LEVELS:
            key = f"geoboundaries_{iso3}_{level}"
            dest = CACHE / "geoboundaries" / iso3 / f"{level}.geojson"
            if key in manifest and dest.exists():
                continue
            time.sleep(INTERVAL_SECONDS)
            meta = session.get(GB_API.format(iso3=iso3, level=level), timeout=60)
            meta.raise_for_status()
            info = meta.json()
            if isinstance(info, list):
                info = info[0]
            url = info["simplifiedGeometryGeoJSON"]
            time.sleep(INTERVAL_SECONDS)
            fetch(url, dest)
            record(
                manifest,
                key,
                url,
                dest,
                {
                    "boundaryID": info.get("boundaryID"),
                    "boundaryLicense": info.get("boundaryLicense"),
                    "licenseDetail": info.get("licenseDetail"),
                    "licenseSource": info.get("licenseSource"),
                    "boundarySource": info.get("boundarySource"),
                    "boundaryYearRepresented": info.get("boundaryYearRepresented"),
                    "buildDate": info.get("buildDate"),
                },
            )
            print(key, "ok", dest.stat().st_size)


def get_n03(manifest: dict) -> None:
    for pref, name in N03_PREFECTURES.items():
        url = N03_URL.format(pref=pref)
        dest = fetch(url, CACHE / "n03" / f"N03-20260101_{pref}_GML.zip")
        record(manifest, f"n03_{pref}", url, dest, {"note": name})
        print("n03", pref, name, "ok", dest.stat().st_size)
        time.sleep(INTERVAL_SECONDS)


def get_ghsl(manifest: dict) -> None:
    dest = fetch(GHS_SMOD, CACHE / "ghsl" / "GHS_SMOD_E2020_GLOBE_R2023A_54009_1000_V2_0.zip")
    record(manifest, "ghs_smod_globe", GHS_SMOD, dest)
    print("smod ok", dest.stat().st_size)
    for tile in GHS_POP_TILES:
        time.sleep(INTERVAL_SECONDS)
        url = GHS_POP_TILE.format(tile=tile)
        dest = fetch(url, CACHE / "ghsl" / f"GHS_POP_E2020_54009_1000_{tile}.zip")
        record(manifest, f"ghs_pop_{tile}", url, dest)
        print("pop", tile, "ok", dest.stat().st_size)


# OSM の地域別抽出(Geofabrik。ODbL。利用上限の記載なし)。検証地点を含む 7 地域、合計約 3.1GB
GEOFABRIK = {
    "kanto": "asia/japan/kanto",
    "chubu": "asia/japan/chubu",
    "ile-de-france": "europe/france/ile-de-france",
    "new-south-wales": "australia-oceania/australia/new-south-wales",
    "socal": "north-america/us/california/socal",
    "south-korea": "asia/south-korea",
    "new-york": "north-america/us/new-york",
}


def get_osm(manifest: dict) -> None:
    for name, path in GEOFABRIK.items():
        url = f"https://download.geofabrik.de/{path}-latest.osm.pbf"
        dest = fetch(url, CACHE / "osm" / f"{name}-latest.osm.pbf")
        record(manifest, f"osm_{name}", url, dest)
        print("osm", name, "ok", dest.stat().st_size, flush=True)
        time.sleep(5)  # 連続して取らない


NE_COUNTRIES = "https://naturalearth.s3.amazonaws.com/50m_cultural/ne_50m_admin_0_countries.zip"


def get_world(manifest: dict) -> None:
    """世界の国・大陸のレベル用の簡略境界(Natural Earth 50m。パブリックドメイン)"""
    dest = fetch(NE_COUNTRIES, CACHE / "natural_earth" / "ne_50m_admin_0_countries.zip")
    record(manifest, "natural_earth_countries_50m", NE_COUNTRIES, dest)
    print("world ok", dest.stat().st_size)


STEPS = {
    "marine": get_marine,
    "geoboundaries": get_geoboundaries,
    "n03": get_n03,
    "ghsl": get_ghsl,
    "osm": get_osm,
    "world": get_world,
}


if __name__ == "__main__":
    wanted = sys.argv[1:] or [s for s in STEPS if s != "osm"]  # osm は大きいので、明示したときだけ
    manifest = load_manifest()
    for name in wanted:
        try:
            STEPS[name](manifest)
        except (FetchError, requests.RequestException) as e:
            print(f"FAILED {name}: {e}", file=sys.stderr)
            sys.exit(1)
    print("done")
