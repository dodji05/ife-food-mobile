// ─────────────────────────────────────────────────────────────────────────────
// ifè FOOD — Tracking d'une commande côté client (Sprint 2.4)
//
// Live status via socket /tracking room `order_<orderId>` :
//   - `location_update`  : nouvelle position GPS du livreur → ETA dynamique
//   - `order_status`     : changement de statut
//
// 5 étapes UI :
//   1. Commande reçue   (PAID / ACCEPTED)
//   2. En préparation   (IN_PREPARATION)
//   3. Livreur assigné  (READY_FOR_PICKUP / DRIVER_ASSIGNED / …)
//   4. En route         (PICKED_UP / IN_DELIVERY)
//   5. Livré            (DELIVERED)
//
// Annulation client possible pour PAID / ACCEPTED / IN_PREPARATION.
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../order/order_detail_screen.dart' show orderDetailProvider;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TrackingScreen extends ConsumerStatefulWidget {
  final String orderId;
  const TrackingScreen({super.key, required this.orderId});
  @override
  ConsumerState<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends ConsumerState<TrackingScreen> {
  GoogleMapController? _mapController;
  io.Socket? _socket;
  LatLng _driverPosition = const LatLng(AppConstants.defaultLat, AppConstants.defaultLng);
  LatLng? _deliveryPosition;
  String _status = 'PAID';
  int? _etaMinutes;
  bool _cancelLoading = false;
  final Map<MarkerId, Marker> _markers = {};
  bool _mapError = false;
  static const _storage = FlutterSecureStorage();

  static const _cancellableStatuses = ['PAID', 'ACCEPTED', 'IN_PREPARATION'];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final order = await ref.read(orderDetailProvider(widget.orderId).future);
      if (!mounted) return;
      setState(() {
        if (order.deliveryLat != null && order.deliveryLng != null) {
          _deliveryPosition = LatLng(order.deliveryLat!, order.deliveryLng!);
        }
        _status = order.status;
      });
      _initMarkers();
    } catch (_) {}
    await _connectSocket();
  }

  Future<void> _connectSocket() async {
    final token = await _storage.read(key: AppConstants.accessTokenKey);
    if (token == null) return; // session expirée — ne pas tenter la connexion
    _socket = io.io(
      '${AppConstants.wsUrl}/tracking',
      io.OptionBuilder()
        .setTransports(['websocket'])
        .setAuth({'token': token})
        .setExtraHeaders({'Authorization': 'Bearer $token'})
        .build(),
    );

    _socket!.onConnect((_) {
      _socket!.emit('track_order', {'orderId': widget.orderId});
    });

    _socket!.on('location_update', (data) {
      if (!mounted) return;
      final newPos = LatLng(
        (data['lat'] as num).toDouble(),
        (data['lng'] as num).toDouble(),
      );
      setState(() {
        _driverPosition = newPos;
        _updateDriverMarker();
        if (_deliveryPosition != null) {
          final distKm = _haversineKm(newPos, _deliveryPosition!);
          _etaMinutes = max(1, (distKm * 3 + 2).round());
        }
      });
      _mapController?.animateCamera(CameraUpdate.newLatLng(newPos));
    });

    _socket!.on('order_status', (data) {
      if (!mounted) return;
      final newStatus = data['status'] as String?;
      if (newStatus == null) return;
      setState(() => _status = newStatus);
      ref.invalidate(orderDetailProvider(widget.orderId));
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_statusLabel(newStatus)),
        duration: const Duration(seconds: 2),
        backgroundColor: newStatus == 'CANCELLED'
            ? AppColors.error
            : newStatus == 'DELIVERED'
                ? AppColors.success
                : AppColors.primary,
      ));
      if (newStatus == 'DELIVERED') {
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) context.push('/order/${widget.orderId}/tip');
        });
      }
    });
  }

  void _initMarkers() {
    _markers[const MarkerId('driver')] = Marker(
      markerId: const MarkerId('driver'),
      position: _driverPosition,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      infoWindow: const InfoWindow(title: 'Livreur'),
    );
    if (_deliveryPosition != null) {
      _markers[const MarkerId('delivery')] = Marker(
        markerId: const MarkerId('delivery'),
        position: _deliveryPosition!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: const InfoWindow(title: 'Livraison'),
      );
    }
  }

  void _updateDriverMarker() {
    _markers[const MarkerId('driver')] = Marker(
      markerId: const MarkerId('driver'),
      position: _driverPosition,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      infoWindow: const InfoWindow(title: 'Livreur'),
    );
  }

  double _haversineKm(LatLng a, LatLng b) {
    const r = 6371.0;
    final dLat = (b.latitude  - a.latitude)  * pi / 180;
    final dLng = (b.longitude - a.longitude) * pi / 180;
    final h = sin(dLat / 2) * sin(dLat / 2) +
        cos(a.latitude * pi / 180) * cos(b.latitude * pi / 180) *
        sin(dLng / 2) * sin(dLng / 2);
    return r * 2 * atan2(sqrt(h), sqrt(1 - h));
  }

  @override
  void dispose() {
    _socket?.disconnect();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _callDriver(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Impossible d\'ouvrir le composeur pour $phone'),
        backgroundColor: AppColors.error,
      ));
    }
  }

  Future<void> _cancelOrder() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Annuler la commande',
          style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800)),
        content: const Text('Êtes-vous sûr de vouloir annuler votre commande ?',
          style: TextStyle(fontFamily: 'Nunito')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Non')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Oui, annuler',
              style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _cancelLoading = true);
    try {
      await ApiClient.instance.post('/orders/${widget.orderId}/cancel');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Annulation impossible : ${e.toString()}'),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _cancelLoading = false);
    }
  }

  // ── Helpers métier ──────────────────────────────────────────────────────

  /// 5 étapes : 0-4 → step complété, -1 = non payé, -2 = annulé.
  int get _stepIndex {
    switch (_status) {
      case 'PENDING_PAYMENT': return -1;
      case 'PAID':
      case 'ACCEPTED':            return 0;
      case 'IN_PREPARATION':      return 1;
      case 'READY_FOR_PICKUP':
      case 'DRIVER_ASSIGNED':
      case 'HEADING_TO_PICKUP':
      case 'ARRIVED_AT_PICKUP':   return 2;
      case 'PICKED_UP':
      case 'IN_DELIVERY':         return 3;
      case 'DELIVERED':           return 4;
      case 'CANCELLED':           return -2;
      default:                    return 0;
    }
  }

  String get _statusHeadline {
    switch (_status) {
      case 'ACCEPTED':          return 'Commande acceptée';
      case 'IN_PREPARATION':    return 'En préparation';
      case 'READY_FOR_PICKUP':  return 'Prête, livreur en route';
      case 'DRIVER_ASSIGNED':   return 'Livreur assigné';
      case 'HEADING_TO_PICKUP': return 'Livreur récupère votre commande';
      case 'ARRIVED_AT_PICKUP': return 'Livreur arrivé au restaurant';
      case 'PICKED_UP':         return 'Commande prise par le livreur';
      case 'IN_DELIVERY':       return 'En route vers vous';
      case 'DELIVERED':         return 'Commande livrée !';
      case 'CANCELLED':         return 'Commande annulée';
      default:                  return 'Suivi de votre commande';
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'ACCEPTED':          return 'Le restaurant a accepté votre commande';
      case 'IN_PREPARATION':    return 'Votre commande est en préparation';
      case 'READY_FOR_PICKUP':  return 'Commande prête, recherche du livreur';
      case 'DRIVER_ASSIGNED':   return 'Un livreur a accepté votre commande';
      case 'HEADING_TO_PICKUP': return 'Livreur en route vers le restaurant';
      case 'ARRIVED_AT_PICKUP': return 'Livreur arrivé au restaurant';
      case 'PICKED_UP':         return 'Livreur a pris votre commande';
      case 'IN_DELIVERY':       return 'Livreur en route vers vous';
      case 'DELIVERED':         return 'Commande livrée !';
      case 'CANCELLED':         return 'Commande annulée';
      default:                  return 'Statut mis à jour : $s';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cancelled = _status == 'CANCELLED';
    final delivered = _status == 'DELIVERED';
    final canCancel  = _cancellableStatuses.contains(_status);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        leading: GestureDetector(
          onTap: () => context.pop(),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: const Icon(Icons.arrow_back_rounded, color: AppColors.nearBlack))),
      ),
      body: Stack(children: [
        if (_mapError)
          Container(
            color: const Color(0xFFE8EDE8),
            child: const Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.map_outlined, size: 48, color: Color(0xFF9AA89C)),
                SizedBox(height: 8),
                Text('Carte non disponible', style: TextStyle(
                    fontFamily: 'Nunito', fontSize: 13, color: Color(0xFF9AA89C))),
              ],
            )),
          )
        else
          _MapWidget(
            initialTarget: _deliveryPosition ?? _driverPosition,
            markers: Set<Marker>.of(_markers.values),
            onMapCreated: (ctrl) => _mapController = ctrl,
            onError: () => setState(() => _mapError = true),
          ),
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24), topRight: Radius.circular(24)),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -4))],
            ),
            child: SafeArea(top: false, child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag handle
                  Center(child: Container(
                    width: 36, height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.lightGrey,
                      borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 20),

                  // Headline statut + ETA
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: (cancelled ? AppColors.error : AppColors.primary).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12)),
                      child: Icon(
                        cancelled
                          ? Icons.cancel_rounded
                          : delivered
                              ? Icons.check_circle_rounded
                              : Icons.delivery_dining_rounded,
                        color: cancelled ? AppColors.error : AppColors.primary,
                        size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(_statusHeadline,
                          style: const TextStyle(fontFamily: 'Nunito', fontSize: 16,
                            fontWeight: FontWeight.w800, color: AppColors.nearBlack)),
                        const SizedBox(height: 2),
                        if (_etaMinutes != null && !cancelled && !delivered)
                          Text('ETA environ $_etaMinutes min',
                            style: const TextStyle(fontFamily: 'Nunito',
                              fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600))
                        else
                          const Text('Suivi en temps réel',
                            style: TextStyle(fontFamily: 'Nunito',
                              fontSize: 13, color: AppColors.grey)),
                      ])),
                  ]),

                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 16),

                  // 5 étapes de livraison
                  _StatusStep(
                    label: 'Commande reçue',
                    icon: Icons.check_circle_rounded,
                    done: _stepIndex >= 0,
                    isActive: _stepIndex == 0),
                  _StatusStep(
                    label: 'En préparation',
                    icon: Icons.restaurant_rounded,
                    done: _stepIndex >= 1,
                    isActive: _stepIndex == 1),
                  _StatusStep(
                    label: 'Livreur assigné',
                    icon: Icons.person_pin_circle_rounded,
                    done: _stepIndex >= 2,
                    isActive: _stepIndex == 2),
                  _StatusStep(
                    label: 'En route vers vous',
                    icon: Icons.delivery_dining_rounded,
                    done: _stepIndex >= 3,
                    isActive: _stepIndex == 3),
                  _StatusStep(
                    label: 'Livré',
                    icon: Icons.home_rounded,
                    done: _stepIndex >= 4,
                    isActive: _stepIndex == 4),

                  if (cancelled) Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12)),
                      child: const Row(children: [
                        Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 18),
                        SizedBox(width: 10),
                        Expanded(child: Text(
                          'Cette commande a été annulée. Contactez le support si besoin.',
                          style: TextStyle(fontFamily: 'Nunito', fontSize: 12, color: AppColors.error))),
                      ]),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Card livreur
                  Consumer(builder: (context, ref, _) {
                    final orderAsync = ref.watch(orderDetailProvider(widget.orderId));
                    return orderAsync.maybeWhen(
                      data: (order) {
                        if (!order.hasDriver) {
                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.offWhite,
                              borderRadius: BorderRadius.circular(14)),
                            child: Row(children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: AppColors.warning.withOpacity(0.15),
                                child: const Text('⏳', style: TextStyle(fontSize: 18))),
                              const SizedBox(width: 12),
                              const Expanded(child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text('Recherche d\'un livreur…',
                                    style: TextStyle(fontFamily: 'Nunito', fontSize: 14,
                                      fontWeight: FontWeight.w700, color: AppColors.nearBlack)),
                                  Text('Vous serez notifié dès qu\'un livreur prend votre commande',
                                    style: TextStyle(fontFamily: 'Nunito', fontSize: 11, color: AppColors.grey)),
                                ])),
                            ]),
                          );
                        }
                        final name     = order.driverName ?? 'Livreur';
                        final phone    = order.driverPhone;
                        final plate    = order.driverLicensePlate;
                        final vehicle  = order.driverVehicleType;
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.offWhite,
                            borderRadius: BorderRadius.circular(14)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: AppColors.primary.withOpacity(0.2),
                                  backgroundImage: (order.driverAvatarUrl != null &&
                                      order.driverAvatarUrl!.isNotEmpty)
                                      ? NetworkImage(order.driverAvatarUrl!) : null,
                                  child: (order.driverAvatarUrl == null ||
                                      order.driverAvatarUrl!.isEmpty)
                                      ? const Text('🛵', style: TextStyle(fontSize: 20)) : null),
                                const SizedBox(width: 12),
                                Expanded(child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    const Text('Votre livreur',
                                      style: TextStyle(fontFamily: 'Nunito', fontSize: 12, color: AppColors.grey)),
                                    Text(name,
                                      style: const TextStyle(fontFamily: 'Nunito', fontSize: 15,
                                        fontWeight: FontWeight.w700, color: AppColors.nearBlack)),
                                    if (vehicle != null || plate != null)
                                      Text(
                                        [
                                          if (vehicle != null) vehicle,
                                          if (plate  != null) plate,
                                        ].join(' • '),
                                        style: const TextStyle(fontFamily: 'Nunito',
                                          fontSize: 12, color: AppColors.grey)),
                                  ])),
                                IconButton(
                                  onPressed: phone != null && phone.isNotEmpty
                                      ? () => _callDriver(phone) : null,
                                  tooltip: phone != null ? 'Appeler $name' : 'Téléphone indisponible',
                                  icon: Icon(Icons.phone_rounded,
                                    color: phone != null ? AppColors.primary : AppColors.grey),
                                ),
                                IconButton(
                                  onPressed: () => context.push('/chat/${widget.orderId}'),
                                  tooltip: 'Messagerie livreur',
                                  icon: const Icon(Icons.chat_bubble_rounded,
                                    color: AppColors.primary),
                                ),
                              ]),
                            ],
                          ),
                        );
                      },
                      orElse: () => const SizedBox.shrink(),
                    );
                  }),

                  // Bouton annulation (visible uniquement si statut annulable)
                  if (canCancel) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _cancelLoading ? null : _cancelOrder,
                        icon: _cancelLoading
                            ? const SizedBox(width: 16, height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2,
                                  color: AppColors.error))
                            : const Icon(Icons.cancel_outlined, color: AppColors.error),
                        label: const Text('Annuler la commande',
                          style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700,
                            color: AppColors.error)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.error),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ],
                ]),
            )),
          ),
        ),
      ]),
    );
  }
}

// Wrapper isolant GoogleMap pour capturer les erreurs d'initialisation.
class _MapWidget extends StatefulWidget {
  final LatLng initialTarget;
  final Set<Marker> markers;
  final void Function(GoogleMapController) onMapCreated;
  final VoidCallback onError;
  const _MapWidget({
    required this.initialTarget,
    required this.markers,
    required this.onMapCreated,
    required this.onError,
  });
  @override
  State<_MapWidget> createState() => _MapWidgetState();
}

class _MapWidgetState extends State<_MapWidget> {
  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      initialCameraPosition: CameraPosition(target: widget.initialTarget, zoom: 14),
      onMapCreated: widget.onMapCreated,
      markers: widget.markers,
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
    );
  }
}

class _StatusStep extends StatelessWidget {
  final String label;
  final bool done;
  final IconData icon;
  final bool isActive;
  const _StatusStep({
    required this.label, required this.done, required this.icon,
    this.isActive = false,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      Icon(icon, size: 18,
        color: done ? AppColors.primary
            : (isActive ? AppColors.warning : AppColors.lightGrey)),
      const SizedBox(width: 10),
      Text(label,
        style: TextStyle(fontFamily: 'Nunito', fontSize: 13,
          color: done ? AppColors.nearBlack : AppColors.grey,
          fontWeight: isActive ? FontWeight.w700 : FontWeight.w500)),
      if (isActive) ...[
        const SizedBox(width: 8),
        Container(width: 6, height: 6, decoration: const BoxDecoration(
          color: AppColors.primary, shape: BoxShape.circle)),
      ],
    ]),
  );
}
