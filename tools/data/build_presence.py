"""OSM の抽出(PBF)から、「人の営みがある」z16 セルの集合を作る。

存在とみなすタグ: highway、building、place、railway、aeroway、amenity、tourism(`natural=peak` は含めない)。
近似: 道などの線(way)は、**ノードのあるセルだけ**を数える(ノード間の補間はしない)。
曲がりの少ない長い直線の道は、途中のセルを落とすことがある。建物(way・relation)は、
way の頂点のセルを数える(relation の multipolygon は数えない)。
"""

from array import array
from pathlib import Path

import numpy as np
import osmium

from tilemath import lonlat_to_tile

PRESENCE_KEYS = ("highway", "building", "place", "railway", "aeroway", "amenity", "tourism")


class _Collector(osmium.SimpleHandler):
    def __init__(self, zoom: int, bbox: tuple[float, float, float, float] | None):
        super().__init__()
        self.zoom = zoom
        self.bbox = bbox  # (south, west, north, east)
        self.cells: set[tuple[int, int]] = set()
        # 範囲内のノード ID と、そのセル(x<<32|y)。PBF のノードは ID 昇順
        self.ids = array("q")
        self.codes = array("q")
        self._sorted: tuple[np.ndarray, np.ndarray] | None = None

    def _inside(self, lon: float, lat: float) -> bool:
        if self.bbox is None:
            return True
        s, w, n, e = self.bbox
        return s <= lat <= n and w <= lon <= e

    def node(self, n):
        if not n.location.valid():
            return
        lon, lat = n.location.lon, n.location.lat
        if not self._inside(lon, lat):
            return
        x, y = lonlat_to_tile(lon, lat, self.zoom)
        self.ids.append(n.id)
        self.codes.append((x << 32) | y)
        if any(k in n.tags for k in PRESENCE_KEYS):
            self.cells.add((x, y))

    def way(self, w):
        if not any(k in w.tags for k in PRESENCE_KEYS):
            return
        if self._sorted is None:
            ids = np.frombuffer(self.ids, dtype=np.int64)
            codes = np.frombuffer(self.codes, dtype=np.int64)
            order = np.argsort(ids, kind="stable")
            self._sorted = (ids[order], codes[order])
        ids, codes = self._sorted
        refs = np.fromiter((r.ref for r in w.nodes), dtype=np.int64)
        if refs.size == 0 or ids.size == 0:
            return
        pos = np.searchsorted(ids, refs)
        pos[pos >= ids.size] = ids.size - 1
        found = ids[pos] == refs
        for code in np.unique(codes[pos[found]]):
            self.cells.add((int(code) >> 32, int(code) & 0xFFFFFFFF))


def presence_cells(
    pbf_path: Path, zoom: int = 16, bbox: tuple[float, float, float, float] | None = None
) -> set[tuple[int, int]]:
    """人の営みがある z{zoom} セルの `(x, y)` の集合。`bbox` は (south, west, north, east)。範囲外のノードは数えない。"""
    collector = _Collector(zoom, bbox)
    collector.apply_file(str(pbf_path))
    return collector.cells
