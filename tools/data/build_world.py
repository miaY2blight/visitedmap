"""世界の国の簡略境界(アプリに同梱する、世界・大陸・国のレベル用)。元データは Natural Earth 50m の国境(パブリックドメイン)。

1 件 = iso3(ADM0_A3)、name_en、name_ja、continent、geometry(簡略化し、座標は小数 2 桁)。
使い方: python build_world.py   → out/world_countries.json
"""

import io
import json
import zipfile
from pathlib import Path

import shapefile  # pyshp
from shapely.geometry import mapping, shape

HERE = Path(__file__).parent
NE_ZIP = HERE / "cache" / "natural_earth" / "ne_50m_admin_0_countries.zip"
SIMPLIFY_DEGREES = 0.05  # 約 5km。世界・大陸・国のレベルの表示用
DECIMALS = 2


def _round(value):
    if isinstance(value, (list, tuple)):
        return [_round(v) for v in value]
    return round(value, DECIMALS)


def build_world(records: list[dict], tolerance: float = SIMPLIFY_DEGREES) -> list[dict]:
    """records: {"ADM0_A3", "NAME_EN", "NAME_JA", "CONTINENT", "geometry"(shapely)} → 一覧。
    簡略化で形が消える小さな国は、代表点の Point で残す(一覧から落とさない)。"""
    out = []
    for r in records:
        simplified = r["geometry"].simplify(tolerance, preserve_topology=True)
        if simplified.is_empty:
            simplified = r["geometry"].representative_point()
        m = mapping(simplified)
        out.append(
            {
                "iso3": r["ADM0_A3"],
                "name_en": r["NAME_EN"] or "",
                "name_ja": r["NAME_JA"] or "",
                "continent": r["CONTINENT"] or "",
                "geometry": {"type": m["type"], "coordinates": _round(m["coordinates"])},
            }
        )
    return out


def write_world(countries: list[dict], path: Path) -> None:
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(countries, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")


def load_natural_earth(zip_path: Path = NE_ZIP) -> list[dict]:
    with zipfile.ZipFile(zip_path) as z:
        part = lambda ext: io.BytesIO(z.read(f"ne_50m_admin_0_countries.{ext}"))  # noqa: E731
        reader = shapefile.Reader(shp=part("shp"), dbf=part("dbf"), shx=part("shx"), encoding="utf-8")
        fields = [f[0] for f in reader.fields[1:]]
        out = []
        for sr in reader.shapeRecords():
            attrs = dict(zip(fields, sr.record))
            out.append({**{k: attrs.get(k) for k in ("ADM0_A3", "NAME_EN", "NAME_JA", "CONTINENT")}, "geometry": shape(sr.shape.__geo_interface__)})
    return out


def main() -> None:
    countries = build_world(load_natural_earth())
    write_world(countries, HERE / "out" / "world_countries.json")
    size = (HERE / "out" / "world_countries.json").stat().st_size
    print(f"countries: {len(countries)} 件、{size} バイト")


if __name__ == "__main__":
    main()
