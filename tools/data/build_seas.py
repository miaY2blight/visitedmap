"""海の一覧(seas.json)の作成。元データは Natural Earth の海洋ポリゴン(パブリックドメイン)。

1 件 = sea_id、name_en、name_ja、lat、lon(代表点。形の内側にある点)。
名前のないポリゴンは除き、同じ名前の複数のポリゴンは 1 つにまとめる。日本語名は、元データの name_ja を使い、
seas_names.csv(手作業。列: name_en, name_ja)があれば、そちらを優先する。
使い方: python build_seas.py   → out/seas.json
"""

import csv
import io
import json
import re
import unicodedata
import zipfile
from pathlib import Path

import shapefile  # pyshp
from shapely.geometry import MultiPolygon, shape
from shapely.ops import unary_union

HERE = Path(__file__).parent
NE_ZIP = HERE / "cache" / "natural_earth" / "ne_10m_geography_marine_polys.zip"


def representative_latlon(geometry) -> tuple[float, float]:
    """形の内側にある点 (lat, lon)。複数の部分(180 度線で分かれた形など)は、最大の部分から選ぶ。"""
    if isinstance(geometry, MultiPolygon):
        geometry = max(geometry.geoms, key=lambda g: g.area)
    p = geometry.representative_point()
    return round(p.y, 4), round(p.x, 4)


def sea_id(name_en: str, used: set[str]) -> str:
    """英語名のスネークケース(ASCII)。重複したら _2、_3 …を付ける。"""
    ascii_name = unicodedata.normalize("NFKD", name_en).encode("ascii", "ignore").decode("ascii")
    base = re.sub(r"[^a-z0-9]+", "_", ascii_name.lower()).strip("_") or "sea"
    candidate, n = base, 2
    while candidate in used:
        candidate, n = f"{base}_{n}", n + 1
    return candidate


def build_seas(records: list[dict], names_ja: dict[str, str]) -> tuple[list[dict], list[str]]:
    """records: {"name", "name_ja", "geometry"} → (海の一覧, 日本語名がない海の英語名の一覧)。"""
    merged: dict[str, dict] = {}
    for r in records:
        name = (r.get("name") or "").strip()
        if not name:
            continue
        m = merged.setdefault(name, {"geoms": [], "name_ja": ""})
        m["geoms"].append(r["geometry"])
        m["name_ja"] = m["name_ja"] or (r.get("name_ja") or "")
    seas, missing, used = [], [], set()
    for name, m in merged.items():
        lat, lon = representative_latlon(unary_union(m["geoms"]))
        name_ja = names_ja.get(name) or m["name_ja"]
        if not name_ja:
            missing.append(name)
        sid = sea_id(name, used)
        used.add(sid)
        seas.append({"sea_id": sid, "name_en": name, "name_ja": name_ja, "lat": lat, "lon": lon})
    return seas, missing


def load_names_ja(path: Path) -> dict[str, str]:
    path = Path(path)
    if not path.exists():
        return {}
    with path.open(encoding="utf-8", newline="") as f:
        return {row["name_en"].strip(): row["name_ja"].strip() for row in csv.DictReader(f) if row.get("name_en")}


def write_seas(seas: list[dict], path: Path) -> None:
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(seas, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")


def load_natural_earth(zip_path: Path = NE_ZIP) -> list[dict]:
    with zipfile.ZipFile(zip_path) as z:
        part = lambda ext: io.BytesIO(z.read(f"ne_10m_geography_marine_polys.{ext}"))  # noqa: E731
        reader = shapefile.Reader(shp=part("shp"), dbf=part("dbf"), shx=part("shx"), encoding="utf-8")
        fields = [f[0] for f in reader.fields[1:]]
        records = []
        for sr in reader.shapeRecords():
            attrs = dict(zip(fields, sr.record))
            records.append(
                {"name": attrs["name"], "name_ja": attrs.get("name_ja", ""), "geometry": shape(sr.shape.__geo_interface__)}
            )
    return records


def main() -> None:
    seas, missing = build_seas(load_natural_earth(), load_names_ja(HERE / "seas_names.csv"))
    write_seas(seas, HERE / "out" / "seas.json")
    size = (HERE / "out" / "seas.json").stat().st_size
    print(f"seas: {len(seas)} 件、name_ja なし: {len(missing)} 件、{size} バイト")
    if missing:
        print("name_ja なし:", missing)


if __name__ == "__main__":
    main()
