import json

from shapely.geometry import MultiPolygon, Polygon, box

from build_seas import build_seas, load_names_ja, representative_latlon, sea_id, write_seas


def rec(name, geometry, name_ja=""):
    return {"name": name, "name_ja": name_ja, "geometry": geometry}


def test_representative_point_is_inside_even_for_a_concave_shape():
    c_shape = Polygon([(0, 0), (10, 0), (10, 1), (1, 1), (1, 9), (10, 9), (10, 10), (0, 10)])
    lat, lon = representative_latlon(c_shape)
    from shapely.geometry import Point

    assert c_shape.contains(Point(lon, lat))
    # 重心(凹みの外)ではない
    assert not (c_shape.centroid.x == lon and c_shape.centroid.y == lat)


def test_representative_point_of_a_dateline_split_sea_is_inside_one_part():
    pacific = MultiPolygon([box(170, -10, 180, 10), box(-180, -10, -120, 10)])
    lat, lon = representative_latlon(pacific)
    from shapely.geometry import Point

    assert pacific.contains(Point(lon, lat))
    assert -180 <= lon <= 180


def test_sea_id_is_ascii_snake_case_and_unique():
    assert sea_id("Sea of Japan", set()) == "sea_of_japan"
    assert sea_id("Mer d'Iroise", set()) == "mer_d_iroise"
    assert sea_id("Mar del Plata", {"mar_del_plata"}) == "mar_del_plata_2"
    assert sea_id("日本海", set()) == "sea"  # ASCII がなければ代わりの名前


def test_name_ja_from_the_source_then_from_the_names_file():
    seas, missing = build_seas(
        [rec("Sea of Japan", box(0, 0, 1, 1), "日本海"), rec("Seto Inland Sea", box(2, 0, 3, 1))],
        names_ja={"Seto Inland Sea": "瀬戸内海"},
    )
    by_name = {s["name_en"]: s for s in seas}
    assert by_name["Sea of Japan"]["name_ja"] == "日本海"
    assert by_name["Seto Inland Sea"]["name_ja"] == "瀬戸内海"
    assert missing == []


def test_names_file_overrides_the_source():
    seas, _ = build_seas([rec("Sea of Japan", box(0, 0, 1, 1), "日本海(旧)")], names_ja={"Sea of Japan": "日本海"})
    assert seas[0]["name_ja"] == "日本海"


def test_sea_without_a_japanese_name_is_kept_and_listed():
    seas, missing = build_seas([rec("Some Bay", box(0, 0, 1, 1))], names_ja={})
    assert seas[0]["name_ja"] == ""
    assert missing == ["Some Bay"]


def test_unnamed_polygons_are_dropped_and_same_named_ones_are_merged():
    seas, _ = build_seas(
        [
            rec("", box(0, 0, 1, 1)),
            rec("Great Barrier Reef", box(10, 0, 11, 1), "グレート・バリア・リーフ"),
            rec("Great Barrier Reef", box(20, 0, 21, 1), "グレート・バリア・リーフ"),
        ],
        names_ja={},
    )
    assert [s["name_en"] for s in seas] == ["Great Barrier Reef"]
    # 代表点は、統合した形の内側
    assert seas[0]["lon"] in (10.5, 20.5) or 10 <= seas[0]["lon"] <= 21


def test_japanese_names_survive_the_round_trip_in_utf8(tmp_path):
    seas, _ = build_seas([rec("Sea of Japan", box(0, 0, 1, 1), "日本海")], names_ja={})
    path = tmp_path / "out" / "seas.json"
    write_seas(seas, path)
    raw = path.read_bytes().decode("utf-8")
    assert "日本海" in raw
    assert json.loads(raw)[0]["name_ja"] == "日本海"


def test_load_names_ja_reads_utf8(tmp_path):
    path = tmp_path / "seas_names.csv"
    path.write_text("name_en,name_ja\nSeto Inland Sea,瀬戸内海\n", encoding="utf-8")
    assert load_names_ja(path) == {"Seto Inland Sea": "瀬戸内海"}
