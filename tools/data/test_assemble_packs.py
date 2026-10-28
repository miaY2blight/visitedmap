import json

from assemble_packs import assemble_pack, write_assembled


def base_pack():
    return {
        "iso3": "XXX",
        "missing_levels": [],
        "regions": [
            {"region_id": "c", "level": "country", "name": "国", "parent_id": None, "area_km2": 100.0, "external_code": ""},
            {"region_id": "a1", "level": "admin1", "name": "州", "parent_id": "c", "area_km2": 50.0, "external_code": ""},
            {"region_id": "b1", "level": "admin2", "name": "区", "parent_id": "a1", "area_km2": 10.0, "external_code": "13101"},
            {"region_id": "b2", "level": "admin2", "name": "郡", "parent_id": "a1", "area_km2": 40.0, "external_code": ""},
        ],
    }


def by_id(pack):
    return {r["region_id"]: r for r in pack["regions"]}


def test_pack_level_record_unit_is_set():
    out = assemble_pack(base_pack(), record_unit="admin1", grid_levels={}, reachable_area_km2={})
    assert out["record_unit"] == "admin1"
    assert all("grid_level" not in r for r in out["regions"])


def test_grid_regions_get_grid_level_reachable_area_and_unit_grid():
    out = assemble_pack(
        base_pack(), record_unit="admin1", grid_levels={"b1": 17}, reachable_area_km2={"b1": 9.5}
    )
    b1, b2 = by_id(out)["b1"], by_id(out)["b2"]
    assert (b1["record_unit"], b1["grid_level"], b1["reachable_area_km2"]) == ("grid", 17, 9.5)
    assert "record_unit" not in b2 and "grid_level" not in b2 and "reachable_area_km2" not in b2


def test_reachable_area_never_exceeds_the_region_area():
    out = assemble_pack(base_pack(), record_unit="admin1", grid_levels={"b1": 17}, reachable_area_km2={"b1": 99.0})
    assert by_id(out)["b1"]["reachable_area_km2"] == 10.0


def test_missing_reachable_area_falls_back_to_the_region_area():
    out = assemble_pack(base_pack(), record_unit="admin1", grid_levels={"b1": 16}, reachable_area_km2={})
    assert by_id(out)["b1"]["reachable_area_km2"] == 10.0


def test_unknown_region_ids_are_reported_not_ignored():
    try:
        assemble_pack(base_pack(), record_unit="admin1", grid_levels={"zzz": 17}, reachable_area_km2={})
    except ValueError as e:
        assert "zzz" in str(e)
    else:
        raise AssertionError("ValueError が必要")


def test_invalid_record_unit_or_grid_level_is_rejected():
    for kwargs in (
        dict(record_unit="grid", grid_levels={}, reachable_area_km2={}),
        dict(record_unit="admin1", grid_levels={"b1": 10}, reachable_area_km2={}),
        dict(record_unit="admin1", grid_levels={"b1": 18}, reachable_area_km2={}),
    ):
        try:
            assemble_pack(base_pack(), **kwargs)
        except ValueError:
            continue
        raise AssertionError(f"ValueError が必要: {kwargs}")


def test_input_is_not_modified_and_output_is_utf8(tmp_path):
    pack = base_pack()
    out = assemble_pack(pack, record_unit="admin1", grid_levels={"b1": 17}, reachable_area_km2={"b1": 9.0})
    assert "record_unit" not in pack and "grid_level" not in by_id(pack)["b1"]
    path = tmp_path / "out" / "pack_XXX.json"
    write_assembled(out, path)
    assert json.loads(path.read_bytes().decode("utf-8"))["regions"][0]["name"] == "国"
