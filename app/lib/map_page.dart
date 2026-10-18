import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

/// 現在地が取れない場合の初期表示位置(東京駅)
const LatLng tokyoStation = LatLng(35.681236, 139.767125);

const String _styleUrl = 'https://tiles.openfreemap.org/styles/liberty';
// 東京駅フォールバック時は広域、現在地へ移動する時は街区が見えるズーム
const double _fallbackZoom = 11;
const double _currentLocationZoom = 15;
// 直近位置と新規測位がこの距離(m)以上ずれた時だけ再移動する
const double _refineThresholdMeters = 50;

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  MapLibreMapController? _controller;
  bool _locationEnabled = false;

  @override
  void initState() {
    super.initState();
    _moveToCurrentLocation();
  }

  Future<bool> _ensureLocationPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  Future<void> _animateTo(Position position) async {
    await _controller?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(position.latitude, position.longitude),
        _currentLocationZoom,
      ),
    );
  }

  Future<void> _moveToCurrentLocation() async {
    final granted = await _ensureLocationPermission();
    if (!mounted) return;
    if (!granted) {
      _showMessage('位置情報が利用できません。設定で権限と位置情報をオンにしてください');
      return;
    }
    setState(() => _locationEnabled = true);

    // 新規測位は数秒かかるため、端末が保持する直近の位置へ先に移動して即応させる
    final lastKnown = await Geolocator.getLastKnownPosition();
    if (!mounted) return;
    if (lastKnown != null) await _animateTo(lastKnown);

    try {
      final current = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!mounted) return;
      final moved = lastKnown == null ||
          Geolocator.distanceBetween(
                lastKnown.latitude,
                lastKnown.longitude,
                current.latitude,
                current.longitude,
              ) >
              _refineThresholdMeters;
      if (moved) await _animateTo(current);
    } catch (_) {
      if (mounted && lastKnown == null) _showMessage('現在地を取得できませんでした');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MapLibreMap(
        styleString: _styleUrl,
        initialCameraPosition: const CameraPosition(
          target: tokyoStation,
          zoom: _fallbackZoom,
        ),
        myLocationEnabled: _locationEnabled,
        onMapCreated: (controller) => _controller = controller,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _moveToCurrentLocation,
        child: const Icon(Icons.my_location),
      ),
    );
  }
}
