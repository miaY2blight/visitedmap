"""区画データの作成。geoBoundaries の ADM0〜2 に区画 ID(shapeID)を共通の region_id として付け、
日本は国土数値情報 N03 の全国地方公共団体コード(5桁)を external_code に付ける。

使い方: python build_regions.py   (cache/ の取得済みデータから out/regions_<ISO3>.json と out/regions_report.json を作る)
"""

import csv
import json
import math
import zipfile
from pathlib import Path

import numpy as np
import shapely
from shapely.geometry import mapping, shape
from shapely.ops import unary_union
from shapely.strtree import STRtree
from shapely.validation import make_valid

HERE = Path(__file__).parent
EARTH_RADIUS_KM = 6371.0088
COORD_DECIMALS = 5  # 約 1m
LEVELS = [("ADM0", "country"), ("ADM1", "admin1"), ("ADM2", "admin2")]


def _valid(geometry):
    return geometry if geometry.is_valid else make_valid(geometry)


def area_km2(geometry) -> float:
    """面積(km²)。球面上の正積円筒図法(x = R·λ, y = R·sin φ)で測る。経度が 180 を超える連続した形も扱える。"""

    def project(coords):
        out = np.empty_like(coords, dtype=float)
        out[:, 0] = EARTH_RADIUS_KM * np.radians(coords[:, 0])
        out[:, 1] = EARTH_RADIUS_KM * np.sin(np.radians(coords[:, 1]))
        return out

    return shapely.transform(_valid(geometry), project).area


def load_n03_units(features: list[dict]) -> list[dict]:
    """N03 の地物を、市区町村の単位(コード → 名前と形)にまとめる。

    - 同じコードの複数のポリゴン(島など)は 1 つにまとめる。
    - 政令指定都市の区(`N03_005` あり)は、市のコード(区コードの下 2 桁を 00 にしたもの)に集約する。
      geoBoundaries の ADM2 は市全体の 1 区画のため。東京の特別区は区ごとのまま。
    - コードがない地物と、所属未定地(コードの下 3 桁が 000)は除く。
    """
    units: dict[str, dict] = {}
    for f in features:
        p = f["properties"]
        code = p.get("N03_007")
        if not code or code.endswith("000"):
            continue
        if p.get("N03_005"):
            code = code[:-2] + "00"
        unit = units.setdefault(code, {"code": code, "name": p.get("N03_004") or "", "parts": []})
        unit["parts"].append(_valid(shape(f["geometry"])))
    return [
        {"code": u["code"], "name": u["name"], "geometry": unary_union(u["parts"])}
        for u in units.values()
    ]


def match_jis(gb_regions: list[dict], n03_regions: list[dict]) -> tuple[dict[str, str], list[str]]:
    """geoBoundaries の区画 ID → 全国地方公共団体コード、と、対応できなかった区画 ID の一覧。

    区画の形(飛び地を含む全体)と重なる面積が最大の市区町村に対応させる。
    同じコードを 2 つの区画に割り当てず、重なりの大きい方を優先する(他は未対応に出す)。
    """
    geoms = [_valid(r["geometry"]) for r in gb_regions]
    n03_geoms = [_valid(r["geometry"]) for r in n03_regions]
    pairs: list[tuple[float, int, int]] = []
    if n03_geoms:
        tree = STRtree(n03_geoms)
        for i, g in enumerate(geoms):
            for j in tree.query(g):
                overlap = g.intersection(n03_geoms[int(j)]).area
                if overlap > 0:
                    pairs.append((overlap, i, int(j)))
    pairs.sort(key=lambda t: (-t[0], t[1], t[2]))
    mapping_: dict[str, str] = {}
    used_codes: set[str] = set()
    for _, i, j in pairs:
        region_id, code = gb_regions[i]["region_id"], n03_regions[j]["code"]
        if region_id in mapping_ or code in used_codes:
            continue
        mapping_[region_id] = code
        used_codes.add(code)
    unmatched = [r["region_id"] for r in gb_regions if r["region_id"] not in mapping_]
    return mapping_, unmatched


def _round_coords(value):
    if isinstance(value, (list, tuple)):
        return [_round_coords(v) for v in value]
    return round(value, COORD_DECIMALS)


def _geometry_json(geometry) -> dict:
    m = mapping(geometry)
    return {"type": m["type"], "coordinates": _round_coords(m["coordinates"])}


def _find_parent(child_geom, parents: list[dict], tree: STRtree | None) -> str | None:
    """代表点を含む親。なければ重なり最大の親。親がなければ None。"""
    if not parents or tree is None:
        return None
    point = _valid(child_geom).representative_point()
    candidates = [int(j) for j in tree.query(child_geom)]
    for j in candidates:
        if parents[j]["shape"].contains(point):
            return parents[j]["id"]
    best, best_overlap = None, 0.0
    for j in candidates:
        overlap = _valid(child_geom).intersection(parents[j]["shape"]).area
        if overlap > best_overlap:
            best, best_overlap = parents[j]["id"], overlap
    return best


def build_country(
    iso3: str,
    levels: dict[str, list[dict]],
    external_codes: dict[str, str] | None = None,
    local_names: dict[str, str] | None = None,
) -> dict:
    """国 1 つのデータパック(regions_<ISO3>.json の中身)を組み立てる。

    levels: "ADM0"/"ADM1"/"ADM2" → geoBoundaries の GeoJSON の地物の一覧。
    external_codes / local_names: 区画 ID → 全国地方公共団体コード / 現地語の名前(日本の ADM2 で使う)。
    ADM2 などの階層が空なら、`missing_levels` に出す。
    """
    external_codes = external_codes or {}
    local_names = local_names or {}
    regions: list[dict] = []
    missing: list[str] = []
    parents: list[dict] = []  # 1 つ上の階層
    for adm, level in LEVELS:
        features = levels.get(adm) or []
        if not features:
            missing.append(level)
            continue
        tree_parents = parents
        tree = STRtree([p["shape"] for p in tree_parents]) if tree_parents else None
        current: list[dict] = []
        for f in features:
            props = f["properties"]
            region_id = props["shapeID"]
            geometry = _valid(shape(f["geometry"]))
            if level == "country":
                parent_id = None
            else:
                parent_id = _find_parent(geometry, tree_parents, tree)
                if parent_id is None and tree_parents:
                    parent_id = tree_parents[0]["id"]
            regions.append(
                {
                    "region_id": region_id,
                    "external_code": external_codes.get(region_id, ""),
                    "level": level,
                    "name": local_names.get(region_id) or props.get("shapeName") or "",
                    "parent_id": parent_id,
                    "geometry": _geometry_json(geometry),
                    "area_km2": round(area_km2(geometry), 3),
                }
            )
            current.append({"id": region_id, "shape": geometry})
        parents = current
    return {"iso3": iso3, "regions": regions, "missing_levels": missing}


def write_pack(pack: dict, path: Path) -> None:
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(pack, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")


# --- 実データでの実行 ---------------------------------------------------------


def _load_geojson(path: Path) -> list[dict]:
    return json.loads(path.read_text(encoding="utf-8"))["features"]


def _load_n03_features(cache: Path) -> list[dict]:
    features: list[dict] = []
    for zp in sorted((cache / "n03").glob("N03-*_GML.zip")):
        with zipfile.ZipFile(zp) as z:
            name = next(n for n in z.namelist() if n.endswith(".geojson"))
            features += json.loads(z.read(name).decode("utf-8"))["features"]
    return features


def main() -> None:
    cache, out = HERE / "cache", HERE / "out"
    with (HERE / "sample_areas.csv").open(encoding="utf-8", newline="") as f:
        countries = sorted({row["iso3"] for row in csv.DictReader(f)})
    report: dict = {}
    for iso3 in countries:
        levels = {
            adm: _load_geojson(cache / "geoboundaries" / iso3 / f"{adm}.geojson") for adm, _ in LEVELS
        }
        external_codes: dict[str, str] = {}
        local_names: dict[str, str] = {}
        extra: dict = {}
        if iso3 == "JPN":
            units = load_n03_units(_load_n03_features(cache))
            covered = unary_union([u["geometry"] for u in units])
            gb_adm2 = [
                {"region_id": f["properties"]["shapeID"], "geometry": shape(f["geometry"]), "name": f["properties"]["shapeName"]}
                for f in levels["ADM2"]
            ]
            targets = [r for r in gb_adm2 if covered.contains(_valid(r["geometry"]).representative_point())]
            mapping_, unmatched = match_jis(targets, units)
            external_codes = mapping_
            names = {u["code"]: u["name"] for u in units}
            local_names = {rid: names[code] for rid, code in mapping_.items()}
            extra = {
                "n03_units": len(units),
                "gb_adm2_in_n03_coverage": len(targets),
                "matched": len(mapping_),
                "match_rate": round(len(mapping_) / len(targets), 4) if targets else None,
                "unmatched": [
                    {"region_id": r["region_id"], "name": r["name"]} for r in targets if r["region_id"] in set(unmatched)
                ],
                "n03_units_without_region": sorted(set(names) - set(mapping_.values())),
            }
        pack = build_country(iso3, levels, external_codes, local_names)
        write_pack(pack, out / f"regions_{iso3}.json")
        by_level = {lvl: sum(1 for r in pack["regions"] if r["level"] == lvl) for _, lvl in LEVELS}
        size = (out / f"regions_{iso3}.json").stat().st_size
        report[iso3] = {
            "counts": by_level,
            "missing_levels": pack["missing_levels"],
            "empty_names": sum(1 for r in pack["regions"] if not r["name"]),
            "bytes": size,
            "adm2_equals_adm1_count": by_level["admin1"] == by_level["admin2"],
            **extra,
        }
        print(iso3, json.dumps({k: v for k, v in report[iso3].items() if k != "unmatched"}, ensure_ascii=False))
    (out / "regions_report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()
