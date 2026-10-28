import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:fogworld/core/data/db/spot_repository.dart';
import 'package:fogworld/core/domain/grid/geo_point.dart';
import 'package:fogworld/core/domain/shape/spot_shape.dart';
import 'package:fogworld/features/map/map_style.dart';
import 'package:fogworld/features/record_spot/presentation/widgets/radius_field.dart';

/// 記録が保存されたあと、地図の下に出す「「〇〇」を記録しました」のシート
class SavedSheet extends StatelessWidget {
  const SavedSheet({super.key, required this.spot, required this.onClose});

  /// 記録したスポット
  final SavedSpot spot;

  /// 「閉じる」を押したとき
  final VoidCallback onClose;

  /// 説明の文言
  static const String body = '端末に保存しました。霧が晴れる表示と点数は、次の Step で加わります。';

  /// 訪問日・形の種類・チェーン店かを 1 行にした文言(例: 「訪問日 2026-10-26 ・ 点 + 半径 300m」)
  static String metaOf(SavedSpot spot) {
    final shape = switch (spot.shape) {
      PolygonShape() => '取得した形',
      PointRadiusShape(:final radiusMeters) => '点 + 半径 ${RadiusField.format(radiusMeters)}',
    };
    final chain = spot.scoring == SpotScoring.recordOnly ? ' ・ チェーン店(系列で 1 回)' : '';
    return '訪問日 ${spot.visitedOn} ・ $shape$chain';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MapPalette.card,
      elevation: 12,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
          child: Semantics(
            liveRegion: true,
            // 長い名前・大きい文字でも画面の下にはみ出さないよう、高さに上限を置き、
            // 文章の部分だけをスクロールにする(「閉じる」は常に見えて押せる)
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            '「${spot.name}」を記録しました',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: MapPalette.text,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(metaOf(spot), style: const TextStyle(fontSize: 12.5, color: MapPalette.muted)),
                          const SizedBox(height: 8),
                          const Text(body, style: TextStyle(fontSize: 13.5, color: MapPalette.text)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: MapPalette.accent,
                      foregroundColor: MapPalette.onAccent,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    onPressed: onClose,
                    child: const Text('閉じる'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 記録した形へ地図を寄せるときの表示範囲(south, west, north, east)。
///
/// ポリゴンは全外周の最小・最大、点+半径は半径ぶんの箱。180 度線をまたぐ(経度が -180〜180 の外に出る)、
/// 極に近くて経度の幅が求まらないなど、地図の範囲指定に渡せないときは null を返す
/// (呼び出し側は代表点へ寄せる)。例外は投げない
GeoBounds? cameraBoundsOf(SpotShape shape) {
  double south;
  double west;
  double north;
  double east;
  switch (shape) {
    case PolygonShape(:final outerRings):
      south = double.infinity;
      west = double.infinity;
      north = double.negativeInfinity;
      east = double.negativeInfinity;
      for (final ring in outerRings) {
        for (final p in ring) {
          south = math.min(south, p.lat);
          north = math.max(north, p.lat);
          west = math.min(west, p.lon);
          east = math.max(east, p.lon);
        }
      }
    case PointRadiusShape(:final center, :final radiusMeters):
      const metersPerDeg = 111320.0;
      final cosLat = math.cos(center.lat * math.pi / 180);
      if (cosLat < 1e-6) return null;
      final dLat = radiusMeters / metersPerDeg;
      final dLon = radiusMeters / (metersPerDeg * cosLat);
      south = center.lat - dLat;
      north = center.lat + dLat;
      west = center.lon - dLon;
      east = center.lon + dLon;
  }
  if (!south.isFinite || !north.isFinite || !west.isFinite || !east.isFinite) return null;
  if (south < -90 || north > 90 || west < -180 || east > 180 || south > north || west > east) {
    return null;
  }
  return GeoBounds(south, west, north, east);
}
