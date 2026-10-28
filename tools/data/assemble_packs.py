"""データパックの組み立て。区画データ(regions_<ISO3>.json)に、チェックインの単位と判定マスの粗さ、到達できる面積を足す。

出力: out/pack_<ISO3>.json(アプリの BoundaryRepository が読む形)。
- パック全体: `record_unit`(country / admin1 / admin2。判定マスの格子を使わない区画が塗る単位)
- 日本と主要都市の区画(grid_level を割り当てたもの): `record_unit = "grid"`、`grid_level`(11〜17)、`reachable_area_km2`
到達できないマスの一覧は、別ファイル(unreachable_<ISO3>.json)のまま。
使い方: python assemble_packs.py
"""

import copy
import json
from pathlib import Path

HERE = Path(__file__).parent
OUT = HERE / "out"
UNITS = ("country", "admin1", "admin2")


def assemble_pack(
    pack: dict,
    record_unit: str,
    grid_levels: dict[str, int],
    reachable_area_km2: dict[str, float],
) -> dict:
    """入力は変更せず、組み立てたパックを返す。区画 ID が見つからない、値が不正なら ValueError。"""
    if record_unit not in UNITS:
        raise ValueError(f"record_unit が不正です: {record_unit}")
    ids = {r["region_id"] for r in pack["regions"]}
    unknown = sorted(set(grid_levels) - ids)
    if unknown:
        raise ValueError(f"パックにない区画 ID があります: {unknown}")
    for rid, level in grid_levels.items():
        if not 11 <= level <= 17:
            raise ValueError(f"grid_level が範囲外です: {rid}={level}")
    out = copy.deepcopy(pack)
    out["record_unit"] = record_unit
    for r in out["regions"]:
        level = grid_levels.get(r["region_id"])
        if level is None:
            continue
        r["record_unit"] = "grid"
        r["grid_level"] = level
        reach = reachable_area_km2.get(r["region_id"], r["area_km2"])
        r["reachable_area_km2"] = min(reach, r["area_km2"])  # 面積の計算の誤差で超えないようにする
    return out


def write_assembled(pack: dict, path: Path) -> None:
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(pack, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")


def main() -> None:
    report = json.loads((OUT / "assign_report.json").read_text(encoding="utf-8"))
    units = {r["iso3"]: r["record_unit"] for r in report["record_unit"]}
    grid_by_country: dict[str, dict[str, int]] = {}
    for site in report["grid_level"]:
        levels = grid_by_country.setdefault(site["iso3"], {})
        for r in site["regions"]:
            levels[r["region_id"]] = r["grid_level"]
    for path in sorted(OUT.glob("regions_???.json")):
        iso3 = path.stem.split("_")[1]
        reach_file = OUT / f"reachable_{iso3}.json"
        reach = json.loads(reach_file.read_text(encoding="utf-8")) if reach_file.exists() else {}
        grid = {rid: lv for rid, lv in grid_by_country.get(iso3, {}).items() if rid in reach or not reach_file.exists()}
        pack = json.loads(path.read_text(encoding="utf-8"))
        assembled = assemble_pack(pack, units[iso3], grid, reach)
        write_assembled(assembled, OUT / f"pack_{iso3}.json")
        print(iso3, "record_unit=", units[iso3], "grid regions=", len(grid), "bytes=", (OUT / f"pack_{iso3}.json").stat().st_size)


if __name__ == "__main__":
    main()
