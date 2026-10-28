import osmium
from osmium.osm.mutable import Node, Way

from build_presence import presence_cells
from tilemath import lonlat_to_tile

Z = 16
# 東京周辺の、z16 で離れたセルになる 3 点
A = (139.700, 35.660)
B = (139.760, 35.660)
C = (139.820, 35.700)


def tile(p):
    return lonlat_to_tile(p[0], p[1], Z)


def write_pbf(path, nodes, ways=()):
    with osmium.SimpleWriter(str(path)) as w:
        for node_id, (lon, lat), tags in sorted(nodes, key=lambda t: t[0]):
            w.add_node(Node(id=node_id, location=(lon, lat), tags=tags))
        for way_id, refs, tags in ways:
            w.add_way(Way(id=way_id, nodes=refs, tags=tags))


def test_tagged_node_cell_is_included(tmp_path):
    pbf = tmp_path / "a.osm.pbf"
    write_pbf(pbf, [(1, A, {"building": "yes"}), (2, B, {"place": "village"})])
    assert presence_cells(pbf, Z) == {tile(A), tile(B)}


def test_untagged_node_is_not_included(tmp_path):
    pbf = tmp_path / "a.osm.pbf"
    write_pbf(pbf, [(1, A, {}), (2, B, {"name": "名前だけ"})])
    assert presence_cells(pbf, Z) == set()


def test_peak_only_cell_is_not_included(tmp_path):
    pbf = tmp_path / "a.osm.pbf"
    write_pbf(pbf, [(1, A, {"natural": "peak"})])
    assert presence_cells(pbf, Z) == set()


def test_highway_way_counts_the_cells_of_its_nodes_not_the_interpolated_ones(tmp_path):
    pbf = tmp_path / "a.osm.pbf"
    # A と B の間のセルは、道がまたいでも、ノードがなければ含めない(近似)
    write_pbf(pbf, [(1, A, {}), (2, B, {})], ways=[(10, [1, 2], {"highway": "path"})])
    assert presence_cells(pbf, Z) == {tile(A), tile(B)}


def test_way_without_a_presence_tag_does_not_count(tmp_path):
    pbf = tmp_path / "a.osm.pbf"
    write_pbf(pbf, [(1, A, {}), (2, B, {})], ways=[(10, [1, 2], {"waterway": "river"})])
    assert presence_cells(pbf, Z) == set()


def test_bbox_limits_the_cells(tmp_path):
    pbf = tmp_path / "a.osm.pbf"
    write_pbf(pbf, [(1, A, {"building": "yes"}), (2, C, {"building": "yes"})])
    # south, west, north, east: A だけを含む
    assert presence_cells(pbf, Z, bbox=(35.6, 139.6, 35.68, 139.78)) == {tile(A)}


def test_way_with_nodes_outside_bbox_counts_only_the_inside_ones(tmp_path):
    pbf = tmp_path / "a.osm.pbf"
    write_pbf(pbf, [(1, A, {}), (2, C, {})], ways=[(10, [1, 2], {"highway": "residential"})])
    assert presence_cells(pbf, Z, bbox=(35.6, 139.6, 35.68, 139.78)) == {tile(A)}


def test_other_zoom_levels(tmp_path):
    pbf = tmp_path / "a.osm.pbf"
    write_pbf(pbf, [(1, A, {"amenity": "cafe"})])
    assert presence_cells(pbf, 14) == {lonlat_to_tile(A[0], A[1], 14)}
