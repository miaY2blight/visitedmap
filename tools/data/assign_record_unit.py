"""チェックインの単位(record_unit)の割り当て。海外で、チェックインが塗る区画の単位(country / admin1 / admin2)。

規則は暫定。定数を先頭に置き、結果の表を見て調整する。手作業の上書きは record_unit_overrides.csv。
"""

import csv
import math
from pathlib import Path

UNITS = ("country", "admin1", "admin2")

# 暫定の規則
SMALL_COUNTRY_KM2 = 50_000  # これ未満の国は、国の全体を 1 区画にする
ADMIN1_MEAN_LIMIT_KM2 = 300_000  # ADM1 の平均面積がこれ以下なら ADM1。超えるなら ADM2(あれば)
# 観光施設の密度(OSM の tourism・historic などの数/km²)がこれ未満の地域は、単位を 1 段階粗くする。
# None は無効。密度の有効性を測ってから決める(Step 2c Task 4)
LOW_TOURISM_DENSITY: float | None = None


def _check(name: str, value: float | None, allow_none: bool = False) -> None:
    if value is None:
        if allow_none:
            return
        raise ValueError(f"{name} が必要です")
    if not math.isfinite(value) or value < 0:
        raise ValueError(f"{name} が不正です: {value}")


def record_unit(
    admin1_mean_area_km2: float | None,
    country_area_km2: float,
    has_admin2: bool,
    tourism_poi_density: float | None = None,
    override: str | None = None,
    low_tourism_density: float | None = LOW_TOURISM_DENSITY,
) -> str:
    """海外のチェックインが塗る単位を返す。`override` があればそれを優先する。"""
    if override is not None:
        if override not in UNITS:
            raise ValueError(f"override が不正です: {override}")
        return override
    _check("country_area_km2", country_area_km2)
    _check("admin1_mean_area_km2", admin1_mean_area_km2, allow_none=True)
    _check("tourism_poi_density", tourism_poi_density, allow_none=True)

    if country_area_km2 < SMALL_COUNTRY_KM2 or admin1_mean_area_km2 is None:
        unit = "country"
    elif admin1_mean_area_km2 <= ADMIN1_MEAN_LIMIT_KM2:
        unit = "admin1"
    else:
        unit = "admin2" if has_admin2 else "admin1"

    if (
        low_tourism_density is not None
        and tourism_poi_density is not None
        and tourism_poi_density < low_tourism_density
    ):
        unit = {"admin2": "admin1", "admin1": "country", "country": "country"}[unit]
    return unit


def load_overrides(path: Path) -> dict[str, str]:
    """iso3 → record_unit。空行は読み飛ばす。"""
    overrides: dict[str, str] = {}
    with Path(path).open(encoding="utf-8", newline="") as f:
        for row in csv.DictReader(f):
            if row.get("iso3"):
                overrides[row["iso3"].strip()] = row["record_unit"].strip()
    return overrides
