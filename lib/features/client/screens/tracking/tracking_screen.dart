import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../order/order_detail_screen.dart' show orderDetailProvider;

class TrackingScreen extends ConsumerStatefulWidget {
  final String orderId;
  const TrackingScreen({super.key, required this.orderId});
  @override ConsumerState<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends ConsumerState<TrackingScreen> {
  GoogleMapController? _mapController;
  io.Socket? _socket;
  LatLng _driverPosition = const LatLng(AppConstants.defaultLat, AppConstants.defaultLng);
  LatLng _deliveryPosition = const LatLng(6.3700, 2.4250);
  String _status = 'IN_DELIVERY';
  Map<MarkerId, Marker> _markers = {};
  int _etaMinutes = 12;

  @override
  void initState() {
    super.initState();
    _connectSocket();
    _initMarkers();
  }

  void _connectSocket() {
    _socket = io.io('${AppConstants.wsUrl}/tracking', io.OptionBuilder()
      .setTransports(['websocket'])
      .build());

    _socket!.onConnect((_) {
      _socket!.emit('track_order', {'orderId': widget.orderId});
    });

    _socket!.on('location_update', (data) {
      if (!mounted) return;
      setState(() {
        _driverPosition = LatLng((data['lat'] as num).toDouble(), (data['lng'] as num).toDouble());
        _updateDriverMarker();
        _mapController?.animateCamera(CameraUpdate.newLatLng(_driverPosition));
      });
    });
  }

  void _initMarkers() {
    _markers = {
      const MarkerId('driver'): Marker(
        markerId: const MarkerId('driver'), position: _driverPosition,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: const InfoWindow(title: '🛵 Livreur'),
      ),
      const MarkerId('delivery'): Marker(
        markerId: const MarkerId('delivery'), position: _deliveryPosition,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: const InfoWindow(title: '📍 Livraison'),
      ),
    };
  }

  void _updateDriverMarker() {
    _markers[const MarkerId('driver')] = Marker(
      markerId: const MarkerId('driver'), position: _driverPosition,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      infoWindow: const InfoWindow(title: '🛵 Livreur'),
    );
  }

  @override
  void dispose() { _socket?.disconnect(); _mapController?.dispose(); super.dispose(); }

  // ── Bouton 'Appeler le livreur' (url_launcher tel:) ───────────────────────
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

  /// Chat livreur — pas encore implémenté (module messages/* backend existe
  /// mais aucune UI client. TIER 3 / 5j+ dans CLIENT_TODO.md).
  void _showChatComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Messagerie livreur — bientôt disponible'),
      backgroundColor: AppColors.grey,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        leading: GestureDetector(onTap: () => Navigator.pop(context),
          child: Container(margin: const EdgeInsets.all(8), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: const Icon(Icons.arrow_back_rounded, color: AppColors.nearBlack))),
      ),
      body: Stack(children: [
        // Map
        GoogleMap(
          initialCameraPosition: CameraPosition(target: _driverPosition, zoom: 15),
          onMapCreated: (ctrl) => _mapController = ctrl,
          markers: Set<Marker>.of(_markers.values),
          myLocationEnabled: true, myLocationButtonEnabled: false,
          zoomControlsEnabled: false, mapToolbarEnabled: false,
        ),

        // Status card at bottom
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -4))],
            ),
            child: SafeArea(top: false, child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                // Handle
                Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.lightGrey, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 20),

                // ETA
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.delivery_dining_rounded, color: AppColors.primary, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('En route vers vous', style: const TextStyle(fontFamily: 'Nunito', fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.nearBlack)),
                    const SizedBox(height: 2),
                    Text('Arrivée estimée dans $_etaMinutes min', style: const TextStyle(fontFamily: 'Nunito', fontSize: 13, color: AppColors.grey)),
                  ])),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(12)),
                    child: Text('~$_etaMinutes min', style: const TextStyle(fontFamily: 'Nunito', color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                  ),
                ]),

                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 16),

                // Status steps
                _StatusStep(label: 'Commande confirmée', done: true, icon: Icons.check_circle_rounded),
                _StatusStep(label: 'En préparation', done: true, icon: Icons.restaurant_rounded),
                _StatusStep(label: 'Livreur en route', done: true, icon: Icons.delivery_dining_rounded, isActive: true),
                _StatusStep(label: 'Livré', done: false, icon: Icons.home_rounded),

                const SizedBox(height: 20),

                // Driver info — utilise les vraies données de l'order si livreur assigné
                Consumer(builder: (context, ref, _) {
                  final orderAsync = ref.watch(orderDetailProvider(widget.orderId));
                  return orderAsync.maybeWhen(
                    data: (order) {
                      // Pas encore de livreur assigné -> message d'attente
                      if (!order.hasDriver) {
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: AppColors.offWhite, borderRadius: BorderRadius.circular(14)),
                          child: Row(children: [
                            CircleAvatar(radius: 22, backgroundColor: AppColors.warning.withOpacity(0.15),
                              child: const Text('⏳', style: TextStyle(fontSize: 18))),
                            const SizedBox(width: 12),
                            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('Recherche d\'un livreur…',
                                style: TextStyle(fontFamily: 'Nunito', fontSize: 14,
                                    fontWeight: FontWeight.w700, color: AppColors.nearBlack)),
                              Text('Vous serez notifié dès qu\'un livreur prend votre commande',
                                style: TextStyle(fontFamily: 'Nunito', fontSize: 11, color: AppColors.grey)),
                            ])),
                          ]),
                        );
                      }
                      // Livreur assigné -> infos réelles + bouton appel
                      final name  = order.driverName ?? 'Livreur';
                      final phone = order.driverPhone;
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: AppColors.offWhite, borderRadius: BorderRadius.circular(14)),
                        child: Row(children: [
                          CircleAvatar(radius: 22, backgroundColor: AppColors.primary.withOpacity(0.2),
                            backgroundImage: (order.driverAvatarUrl != null && order.driverAvatarUrl!.isNotEmpty)
                                ? NetworkImage(order.driverAvatarUrl!) : null,
                            child: (order.driverAvatarUrl == null || order.driverAvatarUrl!.isEmpty)
                                ? const Text('🛵', style: TextStyle(fontSize: 20))
                                : null),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Text('Votre livreur',
                              style: TextStyle(fontFamily: 'Nunito', fontSize: 13, color: AppColors.grey)),
                            Text(name,
                              style: const TextStyle(fontFamily: 'Nunito', fontSize: 15,
                                  fontWeight: FontWeight.w700, color: AppColors.nearBlack)),
                          ])),
                          IconButton(
                            onPressed: phone != null && phone.isNotEmpty
                                ? () => _callDriver(phone)
                                : null,
                            tooltip: phone != null ? 'Appeler $name' : 'Téléphone indisponible',
                            icon: Icon(Icons.phone_rounded,
                                color: phone != null ? AppColors.primary : AppColors.grey),
                          ),
                          IconButton(
                            onPressed: _showChatComingSoon,
                            tooltip: 'Messagerie livreur',
                            icon: const Icon(Icons.chat_bubble_rounded, color: AppColors.primary),
                          ),
                        ]),
                      );
                    },
                    orElse: () => const SizedBox.shrink(),
                  );
                }),
              ]),
            )),
          ),
        ),
      ]),
    );
  }
}

class _StatusStep extends StatelessWidget {
  final String label; final bool done; final IconData icon; final bool isActive;
  const _StatusStep({required this.label, required this.done, required this.icon, this.isActive = false});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      Icon(icon, size: 18, color: done ? AppColors.primary : (isActive ? AppColors.yellow : AppColors.lightGrey)),
      const SizedBox(width: 10),
      Text(label, style: TextStyle(fontFamily: 'Nunito', fontSize: 13, color: done ? AppColors.nearBlack : AppColors.grey,
        fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
        decoration: done && !isActive ? TextDecoration.none : null)),
      if (isActive) ...[
        const SizedBox(width: 8),
        Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
      ],
    ]),
  );
}
