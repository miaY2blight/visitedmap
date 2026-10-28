import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:fogworld/core/domain/game_config/game_config.dart';

/// 点+半径の半径を選ぶ欄(対数スケールのスライダー 20m〜[max]。「標準に戻す」つき)。
///
/// 刻みは、100m 未満は 10m、1km 未満は 50m、10km 未満は 500m、それ以上は 5km。
/// 1,000m 以上は km で表示する。
/// 記録の固定パネル(`RecordPanel`)で使う。状態は持たず、値は呼び出し側が持つ
class RadiusField extends StatelessWidget {
  /// [value] は現在の半径(m)、[standard] は標準の半径(m)、[max] は半径の上限(m。大分類ごと)。
  /// [value] が範囲の外のときは、スライダーの位置だけ範囲の端に寄せる(ラベルは [value] のまま)。
  /// 値が変わると [onChanged] を呼ぶ(「標準に戻す」は [standard] を渡す)。
  /// 操作が終わったとき(スライダーから指を離した、「標準に戻す」を押した)は [onChangeEnd] も呼ぶ
  const RadiusField({
    super.key,
    required this.value,
    required this.standard,
    required this.onChanged,
    this.onChangeEnd,
    this.enabled = true,
    this.max = GameConfig.radiusMaxMeters,
  });

  /// 半径の操作が終わったときの通知(m)。地図を円に合わせ直すのに使う(操作中は地図を動かさない)
  final ValueChanged<int>? onChangeEnd;

  /// 現在の半径(m)
  final int value;

  /// 標準の半径(m)
  final int standard;

  /// 半径の上限(m)。下限は [GameConfig.radiusMinMeters]
  final int max;

  /// 半径が変わったときの通知(m)
  final ValueChanged<int> onChanged;

  /// false のとき、スライダーと「標準に戻す」を押せなくする(記録中など)
  final bool enabled;

  /// スライダーの位置の分割数(位置は 0〜1。値は分割した位置から [snap] で丸める)
  static const int divisions = 1000;

  /// [meters] を、大きさに応じた刻みの、切りのよい値に丸める
  /// (100m 未満は 10m、1km 未満は 50m、10km 未満は 500m、それ以上は 5km)
  static int snap(double meters) {
    final step = meters < 100
        ? 10
        : meters < 1000
            ? 50
            : meters < 10000
                ? 500
                : 5000;
    return (meters / step).round() * step;
  }

  /// 上限 [max] のスライダーで、半径 [meters] に当たる位置(0〜1。範囲の外は端に寄せる)
  static double positionOf(int meters, int max) {
    const min = GameConfig.radiusMinMeters;
    if (max <= min) return 0;
    final m = meters.clamp(min, max);
    return math.log(m / min) / math.log(max / min);
  }

  /// 上限 [max] のスライダーの位置 [position](0〜1)に当たる半径(m)。
  /// 対数スケールの値を [snap] で丸め、20m〜[max] に収める。非有限・範囲外の位置は端に寄せる
  static int valueAt(double position, int max) {
    const min = GameConfig.radiusMinMeters;
    if (max <= min) return min;
    final p = position.isNaN ? 0.0 : position.clamp(0.0, 1.0);
    final raw = min * math.pow(max / min, p);
    return snap(raw.toDouble()).clamp(min, max);
  }

  /// 半径の表示。1,000m 未満は「300m」、以上は「2.5km」「3km」(小数は必要なときだけ、2 桁まで)
  static String format(int meters) {
    if (meters.abs() < 1000) return '${meters}m';
    return '${_km(meters)}km';
  }

  /// 読み上げ用の表示(「300メートル」「2.5キロメートル」)
  static String _spoken(int meters) {
    if (meters.abs() < 1000) return '$metersメートル';
    return '${_km(meters)}キロメートル';
  }

  static String _km(int meters) {
    var s = (meters / 1000).toStringAsFixed(2);
    s = s.replaceFirst(RegExp(r'0+$'), '');
    return s.endsWith('.') ? s.substring(0, s.length - 1) : s;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final position = positionOf(value, max);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('半径 ${format(value)}(標準 ${format(standard)})', style: theme.textTheme.labelLarge),
        Row(
          children: [
            Expanded(
              child: Slider(
                key: const Key('radius-slider'),
                value: position,
                min: 0,
                max: 1,
                divisions: divisions,
                label: format(value),
                semanticFormatterCallback: (v) => '半径 ${_spoken(valueAt(v, max))}',
                onChanged: enabled ? (v) => onChanged(valueAt(v, max)) : null,
                onChangeEnd: enabled && onChangeEnd != null ? (v) => onChangeEnd!(valueAt(v, max)) : null,
              ),
            ),
            TextButton(
              key: const Key('radius-reset'),
              onPressed: enabled
                  ? () {
                      onChanged(standard);
                      onChangeEnd?.call(standard);
                    }
                  : null,
              child: const Text('標準に戻す'),
            ),
          ],
        ),
      ],
    );
  }
}
