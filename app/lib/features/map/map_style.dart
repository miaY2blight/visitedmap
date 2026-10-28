import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

/// Android の地図を TextureView で描くか(`MapLibreMap.useHybridComposition` に渡す値)。
///
/// true にした理由: 既定(false、SurfaceView)では、地図の上に画面が重なる・外れる遷移
/// (検索画面との往復、「記録する」の直後など)のたびに、
/// 地図のビューが合成し直され、画面が一瞬真っ黒になることがある(手動テストの不具合 3)。
/// TextureView は Flutter の他の部品と同じように合成されるため、このちらつきが出にくい。
///
/// 代わりに描画の負荷が上がり、地図の操作がもたつくことがある。
/// 実機で性能が下がる(拡大・移動が重い、電池の減りが速い)場合は false に戻す。
/// 名前に反して Flutter の「Hybrid Composition」を選ぶ設定ではない(maplibre_gl 0.27.1 の説明)
const bool mapUseTextureView = true;

/// 地図の描き方の設定([mapUseTextureView])を入れる。
/// 最初の地図を作る前(`runApp` の前)に 1 回だけ呼ぶ。作った後の地図には効かない
void configureMapPlatformView() {
  MapLibreMap.useHybridComposition = mapUseTextureView;
}

/// 地図の画面の配色(ゴールモック `step3_goal_mock.html` の明るい配色に合わせる)。
///
/// アプリにはまだテーマが無いため、地図の画面の部品はここの色を使う
abstract final class MapPalette {
  /// アクセント(保存した形の線と面、主ボタン)
  static const Color accent = Color(0xFF0E7C86);

  /// アクセントの上の文字
  static const Color onAccent = Color(0xFFFFFFFF);

  /// カード(検索ボックス、チップ、シート)の地
  static const Color card = Color(0xFFFFFFFF);

  /// 本文の文字
  static const Color text = Color(0xFF18262A);

  /// 補足の文字
  static const Color muted = Color(0xFF5D7176);

  /// 警告の文字
  static const Color warn = Color(0xFF8A5A00);

  /// 警告の地
  static const Color warnSoft = Color(0xFFFBEFD2);

  /// [accent] の `#rrggbb`(地図のレイヤーの色に使う)
  static const String accentHex = '#0e7c86';
}
