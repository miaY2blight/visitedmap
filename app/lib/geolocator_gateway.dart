import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'location_mover.dart';

class GeolocatorGateway implements LocationGateway {
  const GeolocatorGateway();

  @override
  Future<bool> isServiceEnabled() => Geolocator.isLocationServiceEnabled();

  @override
  Future<LocationAccess> checkAccess() async =>
      _toAccess(await Geolocator.checkPermission());

  @override
  Future<LocationAccess> requestAccess() async =>
      _toAccess(await Geolocator.requestPermission());

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
