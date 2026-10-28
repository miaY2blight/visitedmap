"""Web メルカトルのクアッドキー(アプリの CellKey と同じ規約)の計算。"""

import math

MAX_MERCATOR_LAT = 85.0511287798


def lonlat_to_tile(lon: float, lat: float, z: int) -> tuple[int, int]:
    n = 1 << z
    lat = max(-MAX_MERCATOR_LAT, min(MAX_MERCATOR_LAT, lat))
    x = int((lon + 180.0) / 360.0 * n)
    lat_rad = math.radians(lat)
    y = int((1.0 - math.log(math.tan(lat_rad) + 1.0 / math.cos(lat_rad)) / math.pi) / 2.0 * n)
    return max(0, min(n - 1, x)), max(0, min(n - 1, y))


def _lat_of_row(row: float, n: int) -> float:
    return math.degrees(math.atan(math.sinh(math.pi * (1 - 2 * row / n))))


def tile_center(z: int, x: int, y: int) -> tuple[float, float]:
    """(lon, lat)"""
    n = 1 << z
    return (x + 0.5) / n * 360.0 - 180.0, _lat_of_row(y + 0.5, n)


def tile_bounds(z: int, x: int, y: int) -> tuple[float, float, float, float]:
    """(west, south, east, north)"""
    n = 1 << z
    return x / n * 360.0 - 180.0, _lat_of_row(y + 1, n), (x + 1) / n * 360.0 - 180.0, _lat_of_row(y, n)
