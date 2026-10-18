import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'dismiss_fallback.dart';
import 'location_mover.dart';

class GeolocatorGateway implements LocationGateway {
  const GeolocatorGateway();

  @override
  Future<bool> isServiceEnabled() => Geolocator.isLocationServiceEnabled();

  @override
  Future<LocationAccess> checkAccess() async =>
      _toAccess(await Geolocator.checkPermission());

  // ダイアログを「戻る」で閉じても Future が完了しないため、戻った後は現在の権限状態で代替する
  @override
  Future<LocationAccess> requestAccess() => withDismissFallback(
        Geolocator.requestPermission().then(_toAccess),
        checkAccess,
      );

  // Android では、FINE が許可済みなら precise、COARSE のみなら reduced を返す。
  // 判別できない(unknown)場合は、不必要に案内しないよう precise として扱う
  @override
  Future<LocationPrecision> checkPrecision() async {
    final status = await Geolocator.getLocationAccuracy();
    return status == LocationAccuracyStatus.reduced
        ? LocationPrecision.approximate
        : LocationPrecision.precise;
  }

  @override
  Future<LatLng?> lastKnown() async {
    final position = await Geolocator.getLastKnownPosition();
    return position == null
        ? null
        : LatLng(position.latitude, position.longitude);
  }

  @override
  Future<LatLng> current() async {
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );
    return LatLng(position.latitude, position.longitude);
  }

  @override
  double distanceMeters(LatLng a, LatLng b) => Geolocator.distanceBetween(
        a.latitude,
        a.longitude,
        b.latitude,
        b.longitude,
      );

  LocationAccess _toAccess(LocationPermission permission) =>
      switch (permission) {
        LocationPermission.whileInUse ||
        LocationPermission.always =>
          LocationAccess.granted,
        LocationPermission.deniedForever => LocationAccess.deniedForever,
        LocationPermission.denied ||
        LocationPermission.unableToDetermine =>
          LocationAccess.denied,
      };
}
