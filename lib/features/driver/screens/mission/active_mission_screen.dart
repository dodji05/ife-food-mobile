// ─────────────────────────────────────────────────────────────────────────────
// ifè FOOD Driver — ActiveMissionScreen
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../providers/driver_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/mission.dart';

class ActiveMissionScreen extends ConsumerStatefulWidget {
  const ActiveMissionScreen({super.key});
  @override ConsumerState<ActiveMissionScreen> createState() => _ActiveMissionScreenState();
}

class _ActiveMissionScreenState extends ConsumerState<ActiveMissionScreen>
    with TickerProviderStateMixin {
  GoogleMapController? _mapCtrl;
  late AnimationController _glowCtrl;
  bool _showMap = true;

  static const _steps = [
    _Step('ASSIGNED',          Icons.hourglass_top_rounded,    'Mission assignée',            'Préparez-vous à partir.'),
    _Step('HEADING_TO_PICKUP', Icons.directions_bike_rounded,  'En route vers le restaurant', "Rendez-vous à l'établissement."),
    _Step('ARRIVED_AT_PICKUP', Icons.store_rounded,            'Arrivé au restaurant',        'Signalez votre arrivée.'),
    _Step('PICKED_UP',         Icons.shopping_bag_rounded,     'Commande récupérée',          'En route vers le client !'),
    _Step('IN_DELIVERY',       Icons.delivery_dining_rounded,  'En livraison',                'Direction chez le client !'),
    _Step('DELIVERED',         Icons.check_circle_rounded,     'Livraison confirmée',         'Paiement crédité automatiquement.'),
  ];

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    _mapCtrl?.dispose();
    super.dispose();
  }

  int _stepIndex(String deliveryStatus) {
    final i = _steps.indexWhere((s) => s.id == deliveryStatus);
    return i < 0 ? 0 : i;
  }

  Future<void> _advanceStep(Mission mission) async {
    final idx = _stepIndex(mission.deliveryStatus);
    if (idx >= _steps.length - 1) return;
    final nextStep = _steps[idx + 1];
    await ref.read(driverProvider.notifier)
        .updateDeliveryStep(mission.orderId, nextStep.id);

    if (nextStep.id == 'DELIVERED' && mounted) {
      final remaining = ref.read(driverProvider).activeMissions.length;
      // FIX: afficher le snackbar AVANT de naviguer, sinon le contexte est mort
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            '🎉 Livraison #${mission.orderId.substring(0, 6).toUpperCase()} confirmée ! Gains crédités.'),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 4),
      ));
      if (remaining == 0) {
        context.go('/driver/dashboard');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final driver   = ref.watch(driverProvider);
    final missions = driver.activeMissions;
    final mission  = driver.selectedMission;

    if (missions.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.darkBg,
        body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('📭', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 16),
          const Text('Aucune mission active', style: TextStyle(
              fontFamily: 'Nunito', fontSize: 20,
              fontWeight: FontWeight.w800, color: AppColors.darkText)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.go('/driver/dashboard'),
            child: const Text('Retour au tableau de bord')),
        ])),
      );
    }

    // FIX: selectedMission peut être null même si missions n'est pas vide
    if (mission == null) {
      return Scaffold(
        backgroundColor: AppColors.darkBg,
        body: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }
    final stepIdx       = _stepIndex(mission.deliveryStatus);
    final step          = _steps[stepIdx];
    final isPickupPhase = mission.isPickupPhase;
    final targetLat     = isPickupPhase ? mission.professionalLat : mission.clientLat;
    final targetLng     = isPickupPhase ? mission.professionalLng : mission.clientLng;
    final targetLabel   = isPickupPhase ? mission.professionalName : 'Client';

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: Column(children: [

        // ── Sélecteur de missions ─────────────────────────────────────────────
        if (missions.length > 1)
          Container(
            color: AppColors.darkSurface,
            child: SafeArea(bottom: false, child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: Row(children: [
                  Container(width: 8, height: 8,
                    decoration: const BoxDecoration(
                        color: AppColors.primary, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Text('${missions.length} missions actives',
                    style: const TextStyle(fontFamily: 'Nunito', fontSize: 13,
                        fontWeight: FontWeight.w800, color: AppColors.primary)),
                  const Spacer(),
                  const Text('Appuyez pour changer',
                    style: TextStyle(fontFamily: 'Nunito', fontSize: 11,
                        color: AppColors.darkSubtext)),
                ]),
              ),
              SizedBox(height: 64, child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                itemCount: missions.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (ctx, i) {
                  final m        = missions[i];
                  final isActive = m.orderId == driver.selectedMissionOrderId;
                  return GestureDetector(
                    onTap: () => ref.read(driverProvider.notifier).selectMission(m.orderId),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppColors.primary.withOpacity(0.15)
                            : AppColors.darkCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isActive ? AppColors.primary : AppColors.darkBorder,
                          width: isActive ? 2 : 1),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Icon(
                              m.isPickupPhase
                                ? Icons.store_rounded
                                : Icons.location_on_rounded,
                              color: isActive ? AppColors.primary : AppColors.darkSubtext,
                              size: 14),
                            const SizedBox(width: 5),
                            Text(m.professionalName,
                              style: TextStyle(fontFamily: 'Nunito', fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isActive ? AppColors.primary : AppColors.darkText),
                              overflow: TextOverflow.ellipsis),
                          ]),
                          const SizedBox(height: 2),
                          Text(_stepLabel(m.deliveryStatus),
                            style: TextStyle(fontFamily: 'Nunito', fontSize: 10,
                              color: isActive
                                ? AppColors.primary.withOpacity(0.7)
                                : AppColors.darkSubtext)),
                        ],
                      ),
                    ),
                  );
                },
              )),
            ])),
          ),

        // ── Carte GPS ─────────────────────────────────────────────────────────
        if (_showMap)
          SizedBox(height: 220, child: Stack(children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(
                  target: LatLng(targetLat, targetLng), zoom: 14),
              onMapCreated: (c) => _mapCtrl = c,
              markers: {
                Marker(
                  markerId: const MarkerId('target'),
                  position: LatLng(targetLat, targetLng),
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                    isPickupPhase
                      ? BitmapDescriptor.hueOrange
                      : BitmapDescriptor.hueGreen),
                  infoWindow: InfoWindow(title: targetLabel),
                ),
                if (driver.currentLat != null && driver.currentLng != null) Marker(
                  markerId: const MarkerId('me'),
                  position: LatLng(driver.currentLat!, driver.currentLng!),
                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
                  infoWindow: const InfoWindow(title: 'Ma position'),
                ),
              },
              myLocationEnabled: true, myLocationButtonEnabled: false,
              zoomControlsEnabled: false, mapToolbarEnabled: false,
            ),
            Positioned(top: 12, left: 12, child: GestureDetector(
              onTap: () => setState(() => _showMap = false),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.darkSurface.withOpacity(0.9),
                  shape: BoxShape.circle),
                child: const Icon(Icons.keyboard_arrow_up_rounded,
                    color: AppColors.darkText),
              ),
            )),
            Positioned(bottom: 12, right: 12, child: ElevatedButton.icon(
              onPressed: () => context.push('/navigate',
                  extra: {'lat': targetLat, 'lng': targetLng, 'label': targetLabel}),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.info, foregroundColor: Colors.white,
                minimumSize: const Size(0, 40),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.navigation_rounded, size: 16),
              label: const Text('Naviguer',
                  style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700)),
            )),
          ]))
        else
          SafeArea(bottom: false, child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: GestureDetector(
              onTap: () => setState(() => _showMap = true),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.darkCard, borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.darkBorder)),
                child: const Row(children: [
                  Icon(Icons.map_rounded, color: AppColors.primary, size: 18),
                  SizedBox(width: 8),
                  Text('Afficher la carte', style: TextStyle(fontFamily: 'Nunito',
                      fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary)),
                  Spacer(),
                  Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.darkSubtext),
                ]),
              ),
            ),
          )),

        // ── Détail mission ────────────────────────────────────────────────────
        Expanded(child: ListView(padding: const EdgeInsets.all(16), children: [

          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                AppColors.primary.withOpacity(0.15),
                AppColors.primary.withOpacity(0.05),
              ], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.4), width: 1.5),
            ),
            child: Row(children: [
              Container(width: 50, height: 50,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(13)),
                child: Icon(step.icon, color: AppColors.primary, size: 24)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(step.title, style: const TextStyle(fontFamily: 'Nunito',
                    fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.darkText)),
                const SizedBox(height: 2),
                Text(step.description, style: const TextStyle(fontFamily: 'Nunito',
                    fontSize: 12, color: AppColors.darkSubtext, height: 1.4)),
              ])),
            ]),
          ),
          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.darkCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.darkBorder)),
            child: Column(children: [
              _InfoRow(icon: Icons.store_rounded, color: AppColors.yellow,
                  label: 'Établissement', value: mission.professionalName),
              const SizedBox(height: 10),
              const Divider(color: AppColors.darkBorder),
              const SizedBox(height: 10),
              _InfoRow(icon: Icons.location_on_rounded, color: AppColors.danger,
                  label: 'Livraison', value: mission.clientAddress),
              const SizedBox(height: 10),
              const Divider(color: AppColors.darkBorder),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _MiniStat('💰',
                    '${mission.deliveryFee.toStringAsFixed(0)} F', 'Gains')),
                Container(width: 1, height: 38, color: AppColors.darkBorder),
                Expanded(child: _MiniStat('📦',
                    '${mission.items.length}', 'Articles')),
                Container(width: 1, height: 38, color: AppColors.darkBorder),
                Expanded(child: _MiniStat('📏',
                    '${mission.distanceKm.toStringAsFixed(1)} km', 'Distance')),
              ]),
            ]),
          ),
          const SizedBox(height: 14),

          // Progress steps
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.darkCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.darkBorder)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('#${mission.orderId.substring(0, 8).toUpperCase()}',
                style: const TextStyle(fontFamily: 'Nunito', fontSize: 11,
                    fontWeight: FontWeight.w700, color: AppColors.darkSubtext,
                    letterSpacing: 0.5)),
              const SizedBox(height: 10),
              ..._steps.asMap().entries.map((e) {
                final i = e.key; final s = e.value;
                final isDone   = i < stepIdx;
                final isActive = i == stepIdx;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    Container(width: 26, height: 26,
                      decoration: BoxDecoration(
                        color: isDone
                          ? AppColors.primary
                          : isActive
                            ? AppColors.primary.withOpacity(0.2)
                            : AppColors.darkBorder,
                        shape: BoxShape.circle),
                      child: isDone
                          ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                          : Icon(s.icon,
                              color: isActive ? AppColors.primary : AppColors.darkMuted,
                              size: 13)),
                    const SizedBox(width: 10),
                    Text(s.title, style: TextStyle(fontFamily: 'Nunito', fontSize: 13,
                      color: isDone
                        ? AppColors.primary
                        : isActive ? AppColors.darkText : AppColors.darkMuted,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500)),
                  ]),
                );
              }),
            ]),
          ),
          const SizedBox(height: 20),
        ])),

        // ── Bouton avancement ─────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          color: AppColors.darkSurface,
          child: SafeArea(top: false, child: Column(children: [
            if (missions.length > 1) Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                ...missions.map((m) => Container(
                  width: 8, height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: m.orderId == mission.orderId
                      ? AppColors.primary : AppColors.darkBorder,
                    shape: BoxShape.circle),
                )),
              ]),
            ),
            ElevatedButton(
              onPressed: stepIdx >= _steps.length - 1
                ? null : () => _advanceStep(mission),
              style: ElevatedButton.styleFrom(
                backgroundColor: stepIdx == _steps.length - 2
                  ? AppColors.success : AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                textStyle: const TextStyle(fontFamily: 'Nunito',
                    fontSize: 16, fontWeight: FontWeight.w900),
              ),
              child: Text(_nextStepLabel(step.id)),
            ),
          ])),
        ),
      ]),
    );
  }

  String _stepLabel(String status) => switch (status) {
    'ASSIGNED'          => 'Assignée',
    'HEADING_TO_PICKUP' => 'En route',
    'ARRIVED_AT_PICKUP' => 'Au restaurant',
    'PICKED_UP'         => 'Récupérée',
    'IN_DELIVERY'       => 'En livraison',
    'DELIVERED'         => 'Livrée',
    _                   => status,
  };

  String _nextStepLabel(String currentId) => switch (currentId) {
    'ASSIGNED'          => 'Démarrer la mission',
    'HEADING_TO_PICKUP' => 'Arrivé au restaurant ✓',
    'ARRIVED_AT_PICKUP' => 'Commande récupérée ✓',
    'PICKED_UP'         => 'En livraison ✓',
    'IN_DELIVERY'       => 'Confirmer la livraison ✓',
    _                   => 'Étape suivante',
  };
}

class _Step {
  final String id, title, description;
  final IconData icon;
  const _Step(this.id, this.icon, this.title, this.description);
}

class _InfoRow extends StatelessWidget {
  final IconData icon; final Color color; final String label, value;
  const _InfoRow({required this.icon, required this.color,
                  required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Icon(icon, color: color, size: 18),
    const SizedBox(width: 10),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontFamily: 'Nunito', fontSize: 11,
          color: AppColors.darkMuted, fontWeight: FontWeight.w600)),
      Text(value, style: const TextStyle(fontFamily: 'Nunito', fontSize: 14,
          color: AppColors.darkText, fontWeight: FontWeight.w700)),
    ])),
  ]);
}

class _MiniStat extends StatelessWidget {
  final String emoji, value, label;
  const _MiniStat(this.emoji, this.value, this.label);
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(emoji, style: const TextStyle(fontSize: 18)),
    const SizedBox(height: 2),
    Text(value, style: const TextStyle(fontFamily: 'Nunito', fontSize: 14,
        fontWeight: FontWeight.w800, color: AppColors.darkText)),
    Text(label, style: const TextStyle(fontFamily: 'Nunito', fontSize: 11,
        color: AppColors.darkMuted)),
  ]);
}
