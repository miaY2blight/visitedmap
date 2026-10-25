/// 緯度経度の点(度)。範囲の検証は、使う側(`CellKey.fromPoint` など)で行う
class GeoPoint {
  const GeoPoint(this.lat, this.lon);

  final double lat;
  final double lon;

  @override
  bool operator ==(Object other) =>
      other is GeoPoint && other.lat == lat && other.lon == lon;

  @override
  int get hashCode => Object.hash(lat, lon);

  @override
  String toString() => 'GeoPoint($lat, $lon)';
}

/// 緯度経度の矩形(度)
class GeoBounds {
  const GeoBounds(this.south, this.west, this.north, this.east);

  final double south;
  final double west;
  final double north;
  final double east;
}
