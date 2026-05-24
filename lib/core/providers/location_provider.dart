import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../utils/location_utils.dart';

class LocationState {
  final Position? position;
  final bool isLoading;
  final bool permissionDenied;
  const LocationState({this.position, this.isLoading = false, this.permissionDenied = false});
  LocationState copyWith({Position? position, bool? isLoading, bool? permissionDenied}) =>
      LocationState(position: position ?? this.position,
          isLoading: isLoading ?? this.isLoading,
          permissionDenied: permissionDenied ?? this.permissionDenied);
}

class LocationNotifier extends StateNotifier<LocationState> {
  LocationNotifier() : super(const LocationState()) { fetchLocation(); }

  Future<void> fetchLocation() async {
    state = state.copyWith(isLoading: true);
    try {
      final granted = await ensureLocationPermission();
      if (!granted) {
        state = state.copyWith(isLoading: false, permissionDenied: true);
        return;
      }
      // Medium accuracy : ±100 m suffisant pour la découverte de restaurants.
      // Plus rapide à obtenir et moins gourmand en batterie que high.
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
      );
      state = state.copyWith(position: pos, isLoading: false);
    } catch (_) { state = state.copyWith(isLoading: false); }
  }
}

final locationProvider = StateNotifierProvider<LocationNotifier, LocationState>(
    (ref) => LocationNotifier());
