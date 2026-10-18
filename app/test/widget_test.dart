import 'package:flutter_test/flutter_test.dart';

import 'package:fogworld/map_page.dart';

void main() {
  // MapLibreMap はネイティブのプラットフォームビューのため、ウィジェットテストでは描画できない。
  // 地図表示・現在地は実機で確認する。
  test('現在地が取れない場合の初期位置は東京駅', () {
    expect(tokyoStation.latitude, closeTo(35.6812, 0.001));
    expect(tokyoStation.longitude, closeTo(139.7671, 0.001));
  });
}
