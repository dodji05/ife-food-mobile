// ─────────────────────────────────────────────────────────────────────────────
// ifè FOOD Driver — DriverProvider
// Emplacement canonique : features/driver/providers/driver_provider.dart
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'dart:async';
import '../../../core/api/api_client.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/models/driver.dart';
import '../../../shared/models/mission.dart';
import '../../../core/providers/auth_provider.dart';

// Sentinel pour copyWith : distingue "ne pas changer" de "mettre à null"
const _keep = Object();

// ── État ──────────────────────────────────────────────────────────────────────
class DriverState {
  final Driver? driver;
  final bool isOnline;
  final bool isLoading;
  final List<Mission> activeMissions;
  final String? selectedMissionOrderId;
  final double? currentLat, currentLng;
  final String? error;

  const DriverState({
    this.driver,
    this.isOnline         = false,
    this.isLoading        = false,
    this.activeMissions   = const [],
    this.selectedMissionOrderId,
    this.currentLat,
    this.currentLng,
    this.error,
  });

  Mission? get selectedMission {
    if (selectedMissionOrderId != null) {
      try {
        return activeMissions.firstWhere((m) => m.orderId == selectedMissionOrderId);
      } catch (_) {}
    }
    return activeMissions.isEmpty ? null : activeMissions.first;
  }

  Mission? get activeMission => selectedMission;

  bool get hasMissions  => activeMissions.isNotEmpty;
  int  get missionCount => activeMissions.length;

  DriverState copyWith({
    Driver? driver,
    bool? isOnline,
    bool? isLoading,
    List<Mission>? activeMissions,
    Object? selectedMissionOrderId = _keep, // FIX: sentinel pour distinguer null explicite de "non fourni"
    double? currentLat,
    double? currentLng,
    String? error,
  }) => DriverState(
    driver:                 driver                 ?? this.driver,
    isOnline:               isOnline               ?? this.isOnline,
    isLoading:              isLoading              ?? this.isLoading,
    activeMissions:         activeMissions         ?? this.activeMissions,
    selectedMissionOrderId: selectedMissionOrderId == _keep
        ? this.selectedMissionOrderId
        : selectedMissionOrderId as String?,
    currentLat:             currentLat             ?? this.currentLat,
    currentLng:             currentLng             ?? this.currentLng,
    error:                  error,
  );

  DriverState removeMission(String orderId) {
    final remaining = activeMissions.where((m) => m.orderId != orderId).toList();
    return copyWith(
      activeMissions:         remaining,
      selectedMissionOrderId: remaining.isEmpty ? null : remaining.first.orderId,
    );
  }

  DriverState updateMissionStep(String orderId, String step) {
    final updated = activeMissions.map((m) {
      return m.orderId == orderId ? m.withStep(step) : m;
    }).toList();
    return copyWith(activeMissions: updated);
  }
}

// ── Notifier ──────────────────────────────────────────────────────────────────
class DriverNotifier extends StateNotifier<DriverState> {
  final _api = ApiClient.instance;
  io.Socket? _socket;
  Timer? _locationTimer;

  DriverNotifier() : super(const DriverState()) {
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final res  = await _api.get('/drivers/me');
      final data = res['data'] as Map<String, dynamic>?;
      if (data == null) return;
      final driver = Driver.fromJson(data);
      state = state.copyWith(driver: driver, isOnline: driver.isOnline);

      if (driver.isOnline) {
        _startLocationUpdates();
        _connectSocket();
        await loadActiveMissions();
      }
    } catch (e) {
      state = state.copyWith(error: e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> loadActiveMissions() async {
    try {
      final res  = await _api.get('/drivers/me/active-missions');
      final list = (res['data'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map((d) => Mission.fromDeliveryJson(d))
          .toList();
      state = state.copyWith(
        activeMissions:         list,
        selectedMissionOrderId: list.isEmpty ? null : list.first.orderId,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> toggleAvailability() async {
    state = state.copyWith(isLoading: true);
    try {
      final res    = await _api.patch('/drivers/me/toggle-availability');
      final driver = Driver.fromJson(res['data']);
      final goingOnline = driver.isOnline;
      state = state.copyWith(driver: driver, isOnline: goingOnline, isLoading: false);

      if (goingOnline) {
        _startLocationUpdates();
        _connectSocket();
        await loadActiveMissions();
      } else {
        _stopLocationUpdates();
        _socket?.disconnect();
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void _startLocationUpdates() {
    _stopLocationUpdates(); // FIX: annule le timer existant avant d'en créer un nouveau
    _locationTimer = Timer.periodic(
      Duration(milliseconds: AppConstants.locationUpdateIntervalMs),
      (_) async {
        try {
          final pos = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high);
          await _api.patch('/drivers/me/location',
              data: {'lat': pos.latitude, 'lng': pos.longitude});
          state = state.copyWith(
              currentLat: pos.latitude, currentLng: pos.longitude);

          for (final mission in state.activeMissions) {
            _socket?.emit('driver_location', {
              'orderId':  mission.orderId,
              'driverId': state.driver?.id,
              'lat':      pos.latitude,
              'lng':      pos.longitude,
            });
          }
        } catch (_) {}
      },
    );
  }

  void _stopLocationUpdates() {
    _locationTimer?.cancel();
    _locationTimer = null;
  }

  void _connectSocket() {
    _socket?.disconnect(); // FIX: ferme le socket existant avant d'en créer un nouveau
    _socket = io.io(
      '${AppConstants.wsUrl}/tracking',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableReconnection()
          .setReconnectionAttempts(10)
          .setReconnectionDelay(2000)
          .build(),
    );

    void joinMissionRooms() {
      for (final m in state.activeMissions) {
        _socket?.emit('join_mission', {'orderId': m.orderId});
      }
    }

    _socket?.onConnect((_) => joinMissionRooms());
    _socket?.onReconnect((_) => joinMissionRooms());
  }

  Future<void> acceptMission(String orderId) async {
    try {
      await _api.post('/drivers/missions/$orderId/accept');
      final res     = await _api.get('/orders/$orderId');
      final mission = Mission.fromOrderJson(res['data']);
      final updated = [...state.activeMissions, mission];
      state = state.copyWith(
        activeMissions:         updated,
        selectedMissionOrderId: mission.orderId,
      );
      _socket?.emit('join_mission', {'orderId': orderId});
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> declineMission(String orderId) async {
    // Backend réassigne automatiquement
  }

  Future<void> updateDeliveryStep(
    String orderId,
    String status, {
    String? confirmPhoto,
  }) async {
    try {
      await _api.patch(
        '/drivers/missions/$orderId/status',
        data: {
          'status': status,
          if (confirmPhoto != null) 'confirmPhoto': confirmPhoto,
        },
      );

      if (status == 'DELIVERED') {
        _socket?.emit('leave_mission', {'orderId': orderId});
        state = state.removeMission(orderId);
      } else {
        state = state.updateMissionStep(orderId, status);
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  void selectMission(String orderId) {
    state = state.copyWith(selectedMissionOrderId: orderId);
  }

  @override
  void dispose() {
    _stopLocationUpdates();
    _socket?.disconnect();
    super.dispose();
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────
final driverProvider = StateNotifierProvider<DriverNotifier, DriverState>(
    (ref) => DriverNotifier());

final driverDashboardProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final res = await ApiClient.instance.get('/drivers/me/dashboard');
  return res['data'] as Map<String, dynamic>? ?? {};
});

final earningsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await ApiClient.instance.get('/drivers/me/earnings');
  return List<Map<String, dynamic>>.from(res['data'] ?? []);
});
