import json

from shapely.geometry import MultiPolygon, box

from build_world import build_world, write_world


def rec(adm0, iso, name, name_ja, continent, geometry):
    return {"ADM0_A3": adm0, "ISO_A3": iso, "NAME_EN": name, "NAME_JA": name_ja, "CONTINENT": continent, "geometry": geometry}


def test_uses_adm0_a3_as_the_id_and_keeps_names_and_continent():
    out = build_world([rec("FRA", "-99", "France", "フランス", "Europe", box(0, 40, 5, 45))])
    assert out[0]["iso3"] == "FRA"
    assert out[0]["name_en"] == "France" and out[0]["name_ja"] == "フランス"
    assert out[0]["continent"] == "Europe"


def test_coordinates_are_rounded_and_geometry_is_simplified():
    # 頂点が多い円に近い形は、簡略化で頂点が減る
    circle = box(0, 0, 0.0001, 0.0001).buffer(2.0, quad_segs=64)
    out = build_world([rec("AAA", "AAA", "A", "", "Asia", circle)], tolerance=0.05)
    ring = out[0]["geometry"]["coordinates"][0]
    assert len(ring) < len(circle.exterior.coords)
    assert all(len(str(c).split(".")[-1]) <= 2 for p in ring for c in p)


def test_multipolygon_is_kept_and_japanese_survives_utf8(tmp_path):
    islands = MultiPolygon([box(0, 0, 3, 3), box(10, 10, 13, 13)])
    out = build_world([rec("JPN", "JPN", "Japan", "日本", "Asia", islands)])
    assert out[0]["geometry"]["type"] == "MultiPolygon"
    path = tmp_path / "world.json"
    write_world(out, path)
    assert json.loads(path.read_bytes().decode("utf-8"))[0]["name_ja"] == "日本"


def test_tiny_features_that_vanish_after_simplification_are_still_listed():
    # 小さな島国は、簡略化で形が消えても、一覧からは落とさない(点として残す)
    out = build_world([rec("TUV", "TUV", "Tuvalu", "ツバル", "Oceania", box(179.0, -8.0, 179.001, -7.999))], tolerance=0.5)
    assert [c["iso3"] for c in out] == ["TUV"]
    assert out[0]["geometry"]["type"] in ("Polygon", "MultiPolygon", "Point")
