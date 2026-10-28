import json

from shapely.geometry import MultiPolygon, box

from build_regions import (
    area_km2,
    build_country,
    load_n03_units,
    match_jis,
    write_pack,
)


def gb(region_id, geometry):
    return {"region_id": region_id, "geometry": geometry}


def n03(code, geometry):
    return {"code": code, "geometry": geometry}


# --- match_jis -------------------------------------------------------------


def test_matches_the_municipality_that_contains_the_region():
    mapping, unmatched = match_jis(
        [gb("g1", box(0.2, 0.2, 0.8, 0.8))],
        [n03("13101", box(0, 0, 1, 1)), n03("13102", box(1, 0, 2, 1))],
    )
    assert mapping == {"g1": "13101"}
    assert unmatched == []


def test_picks_the_candidate_with_the_largest_overlap():
    mapping, _ = match_jis(
        [gb("g1", box(0.5, 0, 2.0, 1))],  # 13101 と 0.5、13102 と 1.0 重なる
        [n03("13101", box(0, 0, 1, 1)), n03("13102", box(1, 0, 3, 1))],
    )
    assert mapping == {"g1": "13102"}


def test_region_without_a_match_goes_to_unmatched_instead_of_being_dropped():
    mapping, unmatched = match_jis(
        [gb("g1", box(0, 0, 1, 1)), gb("far", box(50, 50, 51, 51))],
        [n03("13101", box(0, 0, 1, 1))],
    )
    assert mapping == {"g1": "13101"}
    assert unmatched == ["far"]


def test_same_code_is_not_assigned_to_two_regions():
    # 合併で 2 つの旧区画が 1 つの市区町村に入った場合。重なりの大きい方だけが対応し、他は未対応
    mapping, unmatched = match_jis(
        [gb("big", box(0, 0, 0.9, 1)), gb("small", box(0.9, 0, 1, 1))],
        [n03("13101", box(0, 0, 1, 1))],
    )
    assert mapping == {"big": "13101"}
    assert unmatched == ["small"]


def test_enclave_does_not_decide_the_match_total_overlap_does():
    enclave_region = MultiPolygon([box(0, 0, 0.9, 1), box(1.2, 0, 1.3, 0.1)])
    mapping, _ = match_jis(
        [gb("g1", enclave_region)],
        [n03("A", box(0, 0, 1, 1)), n03("B", box(1.1, 0, 1.5, 1))],
    )
    assert mapping == {"g1": "A"}


def test_empty_inputs():
    assert match_jis([], [n03("A", box(0, 0, 1, 1))]) == ({}, [])
    assert match_jis([gb("g", box(0, 0, 1, 1))], []) == ({}, ["g"])


# --- N03 の市区町村単位 ------------------------------------------------------


def n03_feature(code, city, ward, geometry):
    return {
        "type": "Feature",
        "properties": {
            "N03_001": "テスト県",
            "N03_003": None,
            "N03_004": city,
            "N03_005": ward,
            "N03_007": code,
        },
        "geometry": geometry,
    }


def test_designated_city_wards_are_merged_into_the_city_code():
    features = [
        n03_feature("11101", "さいたま市", "西区", box(0, 0, 1, 1).__geo_interface__),
        n03_feature("11102", "さいたま市", "北区", box(1, 0, 2, 1).__geo_interface__),
        n03_feature("13101", "千代田区", None, box(5, 0, 6, 1).__geo_interface__),
    ]
    units = {u["code"]: u for u in load_n03_units(features)}
    assert set(units) == {"11100", "13101"}  # 区は市(下 2 桁 00)に集約。特別区はそのまま
    assert units["11100"]["name"] == "さいたま市"
    assert units["11100"]["geometry"].area == 2.0


def test_multiple_polygons_of_one_municipality_are_merged():
    features = [
        n03_feature("13361", "大島町", None, box(0, 0, 1, 1).__geo_interface__),
        n03_feature("13361", "大島町", None, box(3, 3, 4, 4).__geo_interface__),
    ]
    (unit,) = load_n03_units(features)
    assert unit["geometry"].area == 2.0


def test_features_without_a_code_are_skipped():
    features = [n03_feature(None, "不明", None, box(0, 0, 1, 1).__geo_interface__)]
    assert load_n03_units(features) == []


# --- area_km2 ---------------------------------------------------------------


def test_area_of_a_one_degree_square_at_the_equator():
    assert abs(area_km2(box(0, 0, 1, 1)) - 12364) < 100  # 約 111.2km × 111.2km


def test_area_of_a_dateline_split_region_matches_the_unsplit_one():
    unsplit = box(179, 0, 181, 1)
    split = MultiPolygon([box(179, 0, 180, 1), box(-180, 0, -179, 1)])
    assert abs(area_km2(unsplit) - area_km2(split)) < 1e-6


# --- build_country / write_pack ---------------------------------------------


def feature(shape_id, name, geometry):
    return {
        "type": "Feature",
        "properties": {"shapeID": shape_id, "shapeName": name},
        "geometry": geometry.__geo_interface__,
    }


def test_builds_levels_with_parent_ids_and_areas():
    levels = {
        "ADM0": [feature("c", "Land", box(0, 0, 4, 4))],
        "ADM1": [feature("a1", "West", box(0, 0, 2, 4)), feature("a2", "East", box(2, 0, 4, 4))],
        "ADM2": [feature("b1", "Town", box(0.5, 0.5, 1.5, 1.5))],
    }
    pack = build_country("XXX", levels)
    by_id = {r["region_id"]: r for r in pack["regions"]}
    assert by_id["c"]["level"] == "country" and by_id["c"]["parent_id"] is None
    assert by_id["a1"]["level"] == "admin1" and by_id["a1"]["parent_id"] == "c"
    assert by_id["b1"]["level"] == "admin2" and by_id["b1"]["parent_id"] == "a1"
    assert by_id["b1"]["external_code"] == ""
    assert by_id["c"]["area_km2"] > by_id["a1"]["area_km2"] > by_id["b1"]["area_km2"] > 0
    assert pack["missing_levels"] == []


def test_country_without_adm2_reports_missing_levels():
    levels = {
        "ADM0": [feature("c", "Land", box(0, 0, 4, 4))],
        "ADM1": [feature("a1", "West", box(0, 0, 4, 4))],
        "ADM2": [],
    }
    pack = build_country("XXX", levels)
    assert pack["missing_levels"] == ["admin2"]
    assert [r["level"] for r in pack["regions"]] == ["country", "admin1"]


def test_external_codes_and_local_names_are_applied_to_admin2():
    levels = {
        "ADM0": [feature("c", "Japan", box(0, 0, 4, 4))],
        "ADM1": [feature("a1", "Tokyo", box(0, 0, 4, 4))],
        "ADM2": [feature("b1", "Chiyoda", box(0, 0, 1, 1)), feature("b2", None, box(2, 2, 3, 3))],
    }
    pack = build_country(
        "JPN",
        levels,
        external_codes={"b1": "13101"},
        local_names={"b1": "千代田区"},
    )
    by_id = {r["region_id"]: r for r in pack["regions"]}
    assert by_id["b1"]["external_code"] == "13101"
    assert by_id["b1"]["name"] == "千代田区"
    assert by_id["b2"]["name"] == ""  # 名前がない区画も捨てない
    assert by_id["b2"]["external_code"] == ""


def test_names_in_japanese_korean_and_arabic_survive_the_round_trip(tmp_path):
    levels = {
        "ADM0": [feature("c", "日本", box(0, 0, 4, 4))],
        "ADM1": [feature("a1", "서울특별시", box(0, 0, 4, 4))],
        "ADM2": [feature("b1", "الجزائر", box(0, 0, 1, 1))],
    }
    pack = build_country("XXX", levels)
    path = tmp_path / "out" / "regions_XXX.json"
    write_pack(pack, path)
    raw = path.read_bytes().decode("utf-8")
    assert "서울특별시" in raw and "الجزائر" in raw and "日本" in raw  # \u エスケープされない
    loaded = json.loads(raw)
    assert [r["name"] for r in loaded["regions"]] == ["日本", "서울특별시", "الجزائر"]


def test_geometry_coordinates_are_rounded_to_five_decimals():
    levels = {
        "ADM0": [feature("c", "Land", box(0.123456789, 0.123456789, 4.987654321, 4.987654321))],
        "ADM1": [],
        "ADM2": [],
    }
    pack = build_country("XXX", levels)
    ring = pack["regions"][0]["geometry"]["coordinates"][0]
    assert all(len(str(x).split(".")[-1]) <= 5 for x, _ in ring)
