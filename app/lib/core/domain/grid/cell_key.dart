import 'dart:math' as math;

import 'package:fogworld/core/domain/grid/geo_point.dart';

/// 保存するセルの階層(z19 は、東京付近で一辺およそ 62m)
const int storageZoom = 19;

/// Web メルカトルで表せる緯度の限界(度)
const double _maxMercatorLat = 85.0511287798;

/// Web メルカトルのクアッドキー(階層 z、列 x、行 y)のセル。
/// `Set` と `Map` のキーに使える
class CellKey {
  /// 階層が 0〜[storageZoom] の外、または x・y が範囲外なら [ArgumentError]
  CellKey(this.z, this.x, this.y) {
    if (z < 0 || z > storageZoom) {
      throw ArgumentError.value(z, 'z', '階層は 0〜$storageZoom');
    }
    final n = 1 << z;
    if (x < 0 || x >= n || y < 0 || y >= n) {
      throw ArgumentError('x・y が範囲外です: $z/$x/$y');
    }
  }

  /// 点を含む階層 [z] のセル。緯度は Web メルカトルの範囲にクランプし、経度 180 は最東のセルに入れる。
  /// NaN・無限大・範囲外(|lat| > 90、|lon| > 180)は [ArgumentError]
  factory CellKey.fromPoint(GeoPoint p, int z) {
    if (z < 0 || z > storageZoom) {
      throw ArgumentError.value(z, 'z', '階層は 0〜$storageZoom');
    }
    if (!p.lat.isFinite || !p.lon.isFinite || p.lat.abs() > 90 || p.lon.abs() > 180) {
      throw ArgumentError('緯度経度が範囲外です: $p');
    }
    final n = 1 << z;
    final lat = p.lat.clamp(-_maxMercatorLat, _maxMercatorLat).toDouble();
    final latRad = lat * math.pi / 180;
    final mercatorY = math.log(math.tan(latRad) + 1 / math.cos(latRad));
    final x = ((p.lon + 180) / 360 * n).floor().clamp(0, n - 1);
    final y = ((1 - mercatorY / math.pi) / 2 * n).floor().clamp(0, n - 1);
    return CellKey(z, x, y);
  }

  final int z;
  final int x;
  final int y;

  /// 階層 [targetZoom] の祖先(自分自身を含む)。自分より大きい階層、または 0 未満は [ArgumentError]
  CellKey ancestorAt(int targetZoom) {
    if (targetZoom < 0 || targetZoom > z) {
      throw ArgumentError.value(targetZoom, 'targetZoom', '0〜$z の階層だけ指定できます');
    }
    final shift = z - targetZoom;
    return CellKey(targetZoom, x >> shift, y >> shift);
  }

  /// 4つの子。北西・北東・南西・南東の順。階層 19 では [StateError]
  List<CellKey> get children {
    if (z >= storageZoom) {
      throw StateError('階層 $storageZoom のセルは分割できません');
    }
    final cz = z + 1;
    return [
      CellKey(cz, x * 2, y * 2),
      CellKey(cz, x * 2 + 1, y * 2),
      CellKey(cz, x * 2, y * 2 + 1),
      CellKey(cz, x * 2 + 1, y * 2 + 1),
    ];
  }

  /// [other] が自分と同じか、子孫なら true
  bool contains(CellKey other) => other.z >= z && other.ancestorAt(z) == this;

  /// このセルが覆う z19 セルの数(4^(19 - z))
  int get z19Count => 1 << (2 * (storageZoom - z));

  GeoBounds get bounds {
    final n = 1 << z;
    return GeoBounds(
      _latOfRow(y + 1, n),
      x / n * 360 - 180,
      _latOfRow(y, n),
      (x + 1) / n * 360 - 180,
    );
  }

  GeoPoint get center {
    final n = 1 << z;
    return GeoPoint(_latOfRow(y + 0.5, n), (x + 0.5) / n * 360 - 180);
  }

  static double _latOfRow(num row, int n) {
    final mercatorY = math.pi * (1 - 2 * row / n);
    return math.atan((math.exp(mercatorY) - math.exp(-mercatorY)) / 2) * 180 / math.pi;
  }

  @override
  bool operator ==(Object other) =>
      other is CellKey && other.z == z && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(z, x, y);

  @override
  String toString() => '$z/$x/$y';
}
