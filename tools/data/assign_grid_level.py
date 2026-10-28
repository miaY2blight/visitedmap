"""判定マスの粗さ(grid_level)の割り当て。日本と主要都市の別枠だけで使う(z11〜z17)。

規則は暫定。定数を先頭に置き、結果の表を見て調整する。
"""

import math

MIN_LEVEL = 11  # 人がほとんどいない地域(約 16km)
MAX_LEVEL = 17  # 都心(約 250m)
URBAN_SHARE_BUMP = 0.5  # 市街地の面積割合がこれ以上なら 1 つ細かくする

# (人口密度の下限 人/km², 基本の階層)。上から順に最初に当てはまったもの
DENSITY_LEVELS = [
    (10_000, 17),
    (3_000, 16),
    (1_000, 15),
    (300, 14),
    (100, 13),
    (10, 12),
]


def grid_level(pop_density_per_km2: float, urban_share: float) -> int:
    """人口密度(人/km²)と市街地の面積割合(0〜1)から、判定マスの階層(11〜17)を返す。"""
    if not math.isfinite(pop_density_per_km2) or pop_density_per_km2 < 0:
        raise ValueError(f"人口密度が不正です: {pop_density_per_km2}")
    if not math.isfinite(urban_share) or not 0 <= urban_share <= 1:
        raise ValueError(f"市街地の割合が不正です: {urban_share}")
    level = MIN_LEVEL
    for lower_bound, base in DENSITY_LEVELS:
        if pop_density_per_km2 >= lower_bound:
            level = base
            break
    if urban_share >= URBAN_SHARE_BUMP:
        level += 1
    return min(level, MAX_LEVEL)
