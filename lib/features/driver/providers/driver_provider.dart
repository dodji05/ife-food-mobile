// ─────────────────────────────────────────────────────────────────────────────
// ifè FOOD Driver — DriverProvider
// Emplacement canonique : features/driver/providers/driver_provider.dart
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:async';
import '../../../core/api/api_client.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/notifications/fcm_service.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/models/driver.dart';
import '../../../shared/models/driver_zone.dart';
import '../../../shared/models/mission.dart';
import '../../../core/providers/auth_provider.dart';
import '../widgets/incoming_mission_dialog.dart';

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
  final Ref _ref;
  io.Socket? _socket;

  // Garde-fou anti-spam : on n'ouvre pas deux fois le dialog pour la même
  // mission (le backend peut broadcaster plusieurs fois en cas de reconnect
  // ou de retry). Et on ignore une mission déjà acceptée.
  bool _missionDialogOpen = false;
  final Set<String> _seenMissionIds = <String>{};

  // Stream GPS natif — s'active uniquement si le livreur bouge de ≥10 m.
  // Bien moins consommateur qu'un Timer + getCurrentPosition toutes les 5 s
  // qui force un cold fix GPS à chaque tick.
  StreamSubscription<Position>? _locationSub;

  DriverNotifier(this._ref) : super(const DriverState()) {
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
        await _connectSocket();
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
        await _connectSocket();
        await loadActiveMissions();
        // Filet de sécurité : garantit que le token FCM est enregistré pour
        // recevoir les missions push même app fermée (cas fcmToken NULL).
        FcmService.ensureTokenRegistered(_ref);
      } else {
        _stopLocationUpdates();
        _socket?.disconnect();
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void _startLocationUpdates() {
    _stopLocationUpdates();
    // getPositionStream délègue au gestionnaire de localisation natif du OS.
    // distanceFilter: 10 m → aucune mise à jour si le livreur est immobile,
    // ce qui économise la batterie comparé à un Timer + cold GPS fix toutes les 5 s.
    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );
    _locationSub = Geolocator.getPositionStream(locationSettings: settings).listen(
      (pos) async {
        try {
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
      onError: (_) {},
      cancelOnError: false,
    );
  }

  void _stopLocationUpdates() {
    _locationSub?.cancel();
    _locationSub = null;
  }

  Future<void> _connectSocket() async {
    _socket?.disconnect();
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: AppConstants.accessTokenKey) ?? '';
    _socket = io.io(
      '${AppConstants.wsUrl}/tracking',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
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

    // ── Trigger IncomingMissionDialog ────────────────────────────────────
    // Le backend broadcast `new_mission` à la room `drivers_online` dès qu'une
    // commande passe au statut PAID. On parse le payload en Mission puis on
    // affiche le dialog au-dessus de l'écran courant via le navigatorKey du
    // GoRouter (pas de navigatorKey global nécessaire — GoRouter en crée un).
    _socket?.on('new_mission', (data) {
      try {
        if (data is! Map) return;
        final json = Map<String, dynamic>.from(data);
        final orderId = (json['orderId'] ?? json['id'])?.toString();
        if (orderId == null || orderId.isEmpty) return;

        // Idempotence : ignore un broadcast déjà vu ou une mission déjà active.
        if (_seenMissionIds.contains(orderId)) return;
        if (state.activeMissions.any((m) => m.orderId == orderId)) return;
        _seenMissionIds.add(orderId);

        final mission = Mission.fromOrderJson({...json, 'id': orderId});
        _showIncomingMissionDialog(mission);
      } catch (e) {
        // Best-effort : un payload malformé ne doit pas crasher le socket.
        debugPrint('[DriverNotifier] new_mission parse failed: $e');
      }
    });
  }

  /// Point d'entrée public — appelé par FcmService quand le driver tape une
  /// notification NEW_MISSION depuis l'arrière-plan ou l'app tuée.
  void showIncomingMission(Mission mission) => _showIncomingMissionDialog(mission);

  /// Affiche le dialog mission entrante par-dessus l'écran courant.
  /// Joue une vibration heavyImpact pour attirer l'attention (le son est
  /// joué par la notif FCM côté système / channel `ife_orders`).
  void _showIncomingMissionDialog(Mission mission) {
    if (_missionDialogOpen) return;
    final router = _ref.read(routerProvider);
    final navState = router.routerDelegate.navigatorKey.currentState;
    if (navState == null) return;

    // Vibration immédiate (le son est délégué au heads-up FCM + son default
    // local notification — cf. fcm_service.dart channel `ife_orders`).
    HapticFeedback.heavyImpact();
    // Boucle douce de vibration pendant le countdown (3 pulses).
    Timer(const Duration(milliseconds: 600), HapticFeedback.heavyImpact);
    Timer(const Duration(milliseconds: 1200), HapticFeedback.mediumImpact);

    _missionDialogOpen = true;
    showDialog(
      context: navState.context,
      barrierDismissible: false,
      builder: (_) => IncomingMissionDialog(mission: mission),
    ).whenComplete(() {
      _missionDialogOpen = false;
    });
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
    try {
      await _api.post('/drivers/missions/$orderId/decline');
    } catch (_) {
      // Best-effort : même si l'appel échoue, le timeout backend gère la réattribution.
    }
  }

  Future<void> updateDeliveryStep(
    String orderId,
    String status, {
    String? confirmPhoto,
    String? confirmCode,
  }) async {
    try {
      await _api.patch(
        '/drivers/missions/$orderId/status',
        data: {
          'status': status,
          if (confirmPhoto != null) 'confirmPhoto': confirmPhoto,
          if (confirmCode  != null) 'confirmCode':  confirmCode,
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
    _locationSub?.cancel();
    _socket?.disconnect();
    super.dispose();
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────
final driverProvider = StateNotifierProvider<DriverNotifier, DriverState>(
    (ref) => DriverNotifier(ref));

final driverDashboardProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final res = await ApiClient.instance.get('/drivers/me/dashboard');
  return res['data'] as Map<String, dynamic>? ?? {};
});

final earningsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await ApiClient.instance.get('/drivers/me/earnings');
  return List<Map<String, dynamic>>.from(res['data'] ?? []);
});

// Config driver-facing : timeout acceptation mission + fournisseur navigation.
// Non-autoDispose : chargé une fois au démarrage, pas besoin de refetch.
final driverConfigProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  try {
    final res = await ApiClient.instance.get('/drivers/config');
    return res['data'] as Map<String, dynamic>? ?? {};
  } catch (_) {
    return const {'missionTimeoutSeconds': 30, 'navigationProvider': 'GOOGLE_MAPS'};
  }
});

// Zones de livraison admin avec flag selected — autoDispose pour reload
// immédiat après sélection/désélection.
final driverZonesProvider = FutureProvider.autoDispose<List<DeliveryZone>>((ref) async {
  final res = await ApiClient.instance.get('/drivers/me/zones');
  final list = res['data'] as List? ?? [];
  return list.whereType<Map<String, dynamic>>().map(DeliveryZone.fromJson).toList();
});
