import 'package:maplibre_gl/maplibre_gl.dart';

/// 地図に重ねる層(塗り・線・点)の設定。
///
/// [enableInteraction] が true の層は、その上のタップを層の操作(`onFeatureTapped`)に回し、
/// 地図のタップ(`onMapClick`)が届かなくなる。重ねる形はタップで選ばせないため、既定は false
class OverlayLayerSpec {
  const OverlayLayerSpec({
    required this.sourceId,
    required this.layerId,
    required this.properties,
    this.enableInteraction = false,
  });

  final String sourceId;
  final String layerId;
  final LayerProperties properties;
  final bool enableInteraction;
}

/// 層を地図に足す関数の形(`MapLibreMapController.addLayer` の切り出しを渡す。テストでは記録用の関数)
typedef AddLayerFn = Future<void> Function(
  String sourceId,
  String layerId,
  LayerProperties properties, {
  bool enableInteraction,
});

/// [specs] の層を、並びの順(下から上)に [add] で足す。引数は [OverlayLayerSpec] のとおりに渡す
Future<void> addOverlayLayers(AddLayerFn add, List<OverlayLayerSpec> specs) async {
  for (final s in specs) {
    await add(s.sourceId, s.layerId, s.properties, enableInteraction: s.enableInteraction);
  }
}
