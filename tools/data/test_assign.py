import math

import pytest

from assign_grid_level import grid_level
from assign_record_unit import load_overrides, record_unit


# --- record_unit ------------------------------------------------------------


def test_small_country_is_country_unit():
    assert record_unit(admin1_mean_area_km2=None, country_area_km2=730, has_admin2=False) == "country"
    assert record_unit(admin1_mean_area_km2=10, country_area_km2=49_999, has_admin2=True) == "country"


def test_country_without_admin1_is_country_unit():
    assert record_unit(admin1_mean_area_km2=None, country_area_km2=2_000_000, has_admin2=False) == "country"


def test_usa_like_is_admin1():
    assert record_unit(admin1_mean_area_km2=190_000, country_area_km2=9_800_000, has_admin2=True) == "admin1"


def test_brazil_like_is_admin2_when_admin2_exists():
    assert record_unit(admin1_mean_area_km2=315_000, country_area_km2=8_500_000, has_admin2=True) == "admin2"


def test_australia_like_is_admin2():
    assert record_unit(admin1_mean_area_km2=960_000, country_area_km2=7_700_000, has_admin2=True) == "admin2"


def test_huge_admin1_without_admin2_falls_back_to_admin1():
    assert record_unit(admin1_mean_area_km2=960_000, country_area_km2=7_700_000, has_admin2=False) == "admin1"


def test_boundary_values():
    assert record_unit(admin1_mean_area_km2=300_000, country_area_km2=5_000_000, has_admin2=True) == "admin1"
    assert record_unit(admin1_mean_area_km2=300_001, country_area_km2=5_000_000, has_admin2=True) == "admin2"
    assert record_unit(admin1_mean_area_km2=100, country_area_km2=50_000, has_admin2=True) == "admin1"


def test_override_wins():
    assert (
        record_unit(
            admin1_mean_area_km2=190_000, country_area_km2=9_800_000, has_admin2=True, override="country"
        )
        == "country"
    )


def test_rejects_invalid_inputs():
    for bad in (-1.0, math.nan, math.inf):
        with pytest.raises(ValueError):
            record_unit(admin1_mean_area_km2=100, country_area_km2=bad, has_admin2=True)
    with pytest.raises(ValueError):
        record_unit(admin1_mean_area_km2=-5, country_area_km2=1000, has_admin2=True)
    with pytest.raises(ValueError):
        record_unit(admin1_mean_area_km2=100, country_area_km2=1000, has_admin2=True, override="bogus")


def test_low_tourism_density_makes_the_unit_coarser_one_step():
    kwargs = dict(admin1_mean_area_km2=12_000, country_area_km2=580_000, has_admin2=True)
    assert record_unit(**kwargs, tourism_poi_density=None) == "admin1"
    assert record_unit(**kwargs, tourism_poi_density=0.0001, low_tourism_density=0.001) == "country"
    assert record_unit(**kwargs, tourism_poi_density=0.5, low_tourism_density=0.001) == "admin1"
    # 閾値が未設定(既定)なら、密度は結果を変えない
    assert record_unit(**kwargs, tourism_poi_density=0.0001) == "admin1"


def test_load_overrides_reads_utf8_and_skips_blank_lines(tmp_path):
    path = tmp_path / "record_unit_overrides.csv"
    path.write_text("iso3,record_unit,理由\nKEN,country,観光の細かさが低い\n\nDEU,admin1,州で十分\n", encoding="utf-8")
    assert load_overrides(path) == {"KEN": "country", "DEU": "admin1"}


# --- grid_level -------------------------------------------------------------


def test_central_tokyo_is_17():
    assert grid_level(14_000, 0.95) == 17


def test_regional_city_is_14():
    assert grid_level(400, 0.1) == 14


def test_mountain_town_is_12():
    assert grid_level(20, 0.0) == 12


def test_almost_uninhabited_is_11():
    assert grid_level(3, 0.0) == 11


def test_thresholds_belong_to_the_denser_side():
    assert grid_level(10_000, 0.0) == 17
    assert grid_level(9_999.9, 0.0) == 16
    assert grid_level(300, 0.0) == 14
    assert grid_level(299.9, 0.0) == 13
    assert grid_level(10, 0.0) == 12
    assert grid_level(9.9, 0.0) == 11


def test_urban_share_makes_it_one_level_finer_but_not_above_17():
    assert grid_level(400, 0.5) == 15
    assert grid_level(400, 0.49) == 14
    assert grid_level(20_000, 1.0) == 17


def test_grid_level_rejects_invalid_inputs():
    for bad in (-1.0, math.nan):
        with pytest.raises(ValueError):
            grid_level(bad, 0.5)
        with pytest.raises(ValueError):
            grid_level(100, bad)
    with pytest.raises(ValueError):
        grid_level(100, 1.5)
