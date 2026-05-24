import 'package:geolocator/geolocator.dart';

/// Vérifie et demande la permission de localisation.
/// Retourne `true` si la permission est accordée, `false` sinon.
/// Lance `openAppSettings()` si la permission est définitivement refusée.
Future<bool> ensureLocationPermission() async {
  var perm = await Geolocator.checkPermission();
  if (perm == LocationPermission.denied) {
    perm = await Geolocator.requestPermission();
  }
  if (perm == LocationPermission.deniedForever) {
    await Geolocator.openAppSettings();
    return false;
  }
  return perm == LocationPermission.whileInUse ||
      perm == LocationPermission.always;
}
