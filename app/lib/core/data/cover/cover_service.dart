import 'dart:isolate';

import 'package:fogworld/core/domain/grid/cell_key.dart';
import 'package:fogworld/core/domain/grid/geo_point.dart';
import 'package:fogworld/core/domain/grid/grid_service.dart';
import 'package:fogworld/core/domain/shape/shape_codec.dart';
import 'package:fogworld/core/domain/shape/spot_shape.dart';

/// 形が大きすぎて、被覆を計算できないことを表す(`GridService` の上限超過)
class CoverTooLargeException implements Exception {
  const CoverTooLargeException(this.message);

  /// 利用者に見せてよい理由(座標や場所名は含めない)
  final String message;

  @override
  String toString() => 'CoverTooLargeException: $message';
}

/// 形 → z19 を含む大小のセルの一覧(被覆)
abstract class CoverService {
  /// [shape] の被覆を返す。互いに重ならず(祖先と子孫が同時に入らない)、`(z, x, y)` の昇順。
  ///
  /// 形が `GridService` の上限を超えるときは [CoverTooLargeException]。
  /// それ以外の不正(面積ゼロのリングなど)は [ArgumentError] のまま伝える。
  /// ただし、メッセージには座標・セル番号を含めない(座標を含まない既知の理由以外は、決まった文にする)
  Future<List<CellKey>> coverOf(SpotShape shape);
}

/// 同じ Isolate で計算する版(テスト用)
class SyncCoverService implements CoverService {
  /// [gridService] は差し替え用。[maxCoverCells]・[maxVisitedCells] は、`GridService` の上限を
  /// 小さくして試すための引数(省略時は `GridService` の既定値)
  const SyncCoverService({
    this.gridService = const GridService(),
    this.maxCoverCells = GridService.maxCoverCells,
    this.maxVisitedCells = GridService.maxVisitedCells,
  });

  final GridService gridService;
  final int maxCoverCells;
  final int maxVisitedCells;

  @override
  Future<List<CellKey>> coverOf(SpotShape shape) async {
    return _computeCover(shape, gridService, maxCoverCells, maxVisitedCells);
  }
}

/// `Isolate.run` で計算する版(本番)。UI を止めない
class IsolateCoverService implements CoverService {
  /// [maxCoverCells]・[maxVisitedCells] は、`GridService` の上限を小さくして試すための引数
  const IsolateCoverService({
    this.maxCoverCells = GridService.maxCoverCells,
    this.maxVisitedCells = GridService.maxVisitedCells,
  });

  final int maxCoverCells;
  final int maxVisitedCells;

  @override
  Future<List<CellKey>> coverOf(SpotShape shape) async {
    // Isolate へ渡せる型(文字列と整数)にする
    final json = const ShapeCodec().encode(shape);
    final maxCover = maxCoverCells;
    final maxVisited = maxVisitedCells;
    final result = await Isolate.run(() => _runInIsolate(json, maxCover, maxVisited));
    final tooLarge = result.$2;
    if (tooLarge != null) throw CoverTooLargeException(tooLarge);
    final flat = result.$1;
    return [
      for (var i = 0; i + 2 < flat.length; i += 3) CellKey(flat[i], flat[i + 1], flat[i + 2]),
    ];
  }
}

/// Isolate の中で動く。結果は (z, x, y を 3 つずつ平らにした列, 上限超過の理由)。
/// 上限超過は例外ではなく値で返す(Isolate をまたいで型を保つため)。それ以外の例外は呼び出し側へ伝わる
(List<int>, String?) _runInIsolate(String json, int maxCoverCells, int maxVisitedCells) {
  final shape = const ShapeCodec().decode(json);
  try {
    final cover = _computeCover(shape, const GridService(), maxCoverCells, maxVisitedCells);
    return ([for (final c in cover) ...[c.z, c.x, c.y]], null);
  } on CoverTooLargeException catch (e) {
    return (const <int>[], e.message);
  }
}

List<CellKey> _computeCover(SpotShape shape, GridService grid, int maxCoverCells, int maxVisitedCells) {
  try {
    final cells = switch (shape) {
      PointRadiusShape() => grid.coverCircle(shape.center, shape.radiusMeters.toDouble()),
      PolygonShape() => [
          for (final ring in shape.outerRings)
            ...grid.coverPolygon(
              _wrapRing(ring),
              maxCoverCells: maxCoverCells,
              maxVisitedCells: maxVisitedCells,
            ),
        ],
    };
    return _removeOverlaps(cells);
  } on ArgumentError catch (e, stackTrace) {
    if (_isLimitExceeded(e)) {
      throw CoverTooLargeException('場所が大きすぎて、範囲を計算できません: ${e.message}');
    }
    // 下の層の ArgumentError は、座標やセル番号をメッセージに含むことがある(NFR-2)。
    // 座標を含まないと分かっている理由だけを残し、それ以外は決まった文に置き換える
    Error.throwWithStackTrace(ArgumentError(_safeReason(e)), stackTrace);
  }
}

/// `normalizeRing` の例外のうち、メッセージに座標を含まないもの(前方一致)
const _safeReasons = [
  '面積がゼロの形は扱えません',
  '経度の幅が180度を超える形は扱えません',
  'リングの頂点は3つ以上が必要です',
];

/// [e] のメッセージが座標を含まない既知の理由ならそのまま、それ以外は決まった文を返す
String _safeReason(ArgumentError e) {
  final message = e.message;
  if (message is String && _safeReasons.any(message.startsWith)) return message;
  return '形が不正なため、範囲を計算できません';
}

/// 経度が 180 を超える連続した表現(180 度線をまたぐ形)を、-180〜180 に折り返す。
/// `GridService.coverPolygon` は折り返した経度を受け取り、内部で連続させ直す
List<GeoPoint> _wrapRing(List<GeoPoint> ring) => [
      for (final p in ring) p.lon > 180 ? GeoPoint(p.lat, p.lon - 360) : p,
    ];

/// `GridService` の上限超過(開始階層のセル数・被覆のセル数・たどるセル数)の `ArgumentError` か。
/// `GridService` はこの 3 つを、メッセージに「上限」を含む `ArgumentError` で表す。
/// 他の引数不正(リングの不正、階層の指定ミス、半径の範囲外)のメッセージには「上限」を含まない
bool _isLimitExceeded(ArgumentError e) => '${e.message}'.contains('上限');

/// 重複を除き、祖先を持つセルを落として、(z, x, y) 昇順にする
List<CellKey> _removeOverlaps(List<CellKey> cells) {
  final set = cells.toSet();
  final result = <CellKey>[
    for (final c in set)
      if (!_hasAncestorIn(c, set)) c,
  ];
  result.sort((a, b) {
    if (a.z != b.z) return a.z.compareTo(b.z);
    if (a.x != b.x) return a.x.compareTo(b.x);
    return a.y.compareTo(b.y);
  });
  return result;
}

bool _hasAncestorIn(CellKey c, Set<CellKey> set) {
  for (var z = c.z - 1; z >= 0; z--) {
    if (set.contains(c.ancestorAt(z))) return true;
  }
  return false;
}
