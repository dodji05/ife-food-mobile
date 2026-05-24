// ─────────────────────────────────────────────────────────────────────────────
// ifè FOOD Driver — IncomingMissionDialog
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/mission.dart';
import '../providers/driver_provider.dart';

class IncomingMissionDialog extends ConsumerStatefulWidget {
  final Mission mission;
  const IncomingMissionDialog({super.key, required this.mission});
  @override ConsumerState<IncomingMissionDialog> createState() => _IncomingMissionDialogState();
}

class _IncomingMissionDialogState extends ConsumerState<IncomingMissionDialog>
    with SingleTickerProviderStateMixin {
  static const int _initialCountdown = 30;
  int _countdown = _initialCountdown;
  Timer? _timer;
  late AnimationController _ringCtrl;
  late Animation<double> _ringAnim;
  bool _accepting = false;

  @override
  void initState() {
    super.initState();
    _ringCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..repeat(reverse: true);
    _ringAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
        CurvedAnimation(parent: _ringCtrl, curve: Curves.easeInOut));
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_countdown <= 0) {
        t.cancel();
        if (mounted) Navigator.pop(context, false);
      } else {
        setState(() => _countdown--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ringCtrl.dispose();
    super.dispose();
  }

  Future<void> _accept() async {
    _timer?.cancel();
    setState(() => _accepting = true);
    await ref.read(driverProvider.notifier).acceptMission(widget.mission.orderId);
    if (mounted) Navigator.pop(context, true);
  }

  void _decline() {
    _timer?.cancel();
    ref.read(driverProvider.notifier).declineMission(widget.mission.orderId);
    if (mounted) Navigator.pop(context, false);
  }

  @override
  Widget build(BuildContext context) {
    final mission       = widget.mission;
    final activeMissions = ref.watch(driverProvider).activeMissions;
    final missionCount  = activeMissions.length;

    return Dialog(
      backgroundColor: AppColors.darkCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [

            // ── Icône pulsante ──────────────────────────────────────────────
            AnimatedBuilder(
              animation: _ringAnim,
              builder: (_, __) => Transform.scale(
                scale: _ringAnim.value,
                child: Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: AppColors.primary.withOpacity(0.5), width: 2.5),
                    boxShadow: [BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 20, spreadRadius: 4)],
                  ),
                  child: const Center(child: Text('🛵', style: TextStyle(fontSize: 36))),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Countdown ──────────────────────────────────────────────────
            Stack(alignment: Alignment.center, children: [
              SizedBox(width: 56, height: 56, child: CircularProgressIndicator(
                value: _countdown / _initialCountdown,
                color: _countdown > 10 ? AppColors.primary : AppColors.danger,
                backgroundColor: AppColors.darkBorder, strokeWidth: 4,
              )),
              Text('$_countdown', style: TextStyle(fontFamily: 'Nunito', fontSize: 18,
                fontWeight: FontWeight.w900,
                color: _countdown > 10 ? AppColors.primary : AppColors.danger)),
            ]),
            const SizedBox(height: 20),

            // ── Titre ───────────────────────────────────────────────────────
            const Text('Nouvelle mission !', style: TextStyle(fontFamily: 'Nunito',
                fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.darkText)),
            const SizedBox(height: 8),

            // ── Badge multi-livraisons ──────────────────────────────────────
            if (missionCount > 0) ...[
              _MultiDeliveryBadge(
                current: missionCount,
                mission: mission,
              ),
              const SizedBox(height: 8),
            ],

            // ── Détails établissement ───────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: AppColors.darkSurface, borderRadius: BorderRadius.circular(14)),
              child: Column(children: [
                _Row(Icons.store_rounded, 'Établissement', mission.professionalName,
                    color: AppColors.yellow),
                const SizedBox(height: 10),
                _Row(Icons.location_on_rounded, 'Adresse', mission.professionalAddress,
                    color: AppColors.primary),
                if (mission.deliveryZone.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _Row(Icons.place_rounded, 'Zone de livraison', mission.deliveryZone,
                      color: AppColors.info),
                ],
                const SizedBox(height: 10),
                _Row(Icons.near_me_rounded, 'Livrer à',
                  mission.clientAddress.length > 45
                    ? '${mission.clientAddress.substring(0, 45)}…'
                    : mission.clientAddress,
                  color: AppColors.danger),
              ]),
            ),
            const SizedBox(height: 12),

            // ── Chips métriques ─────────────────────────────────────────────
            Row(children: [
              if (mission.distanceToPickupKm != null)
                Expanded(child: _Chip('📍',
                    '${mission.distanceToPickupKm!.toStringAsFixed(1)} km',
                    'Jusqu\'au resto')),
              if (mission.distanceToPickupKm != null) const SizedBox(width: 6),
              Expanded(child: _Chip('📏',
                  '${mission.distanceKm.toStringAsFixed(1)} km',
                  'Livraison')),
              const SizedBox(width: 6),
              Expanded(child: _Chip('⏱',
                  '~${mission.estimatedMinutes} min',
                  'Durée est.')),
              const SizedBox(width: 6),
              Expanded(child: _Chip('💰',
                  '${mission.deliveryFee.toStringAsFixed(0)} F',
                  'Gain')),
            ]),

            if (mission.items.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                '${mission.items.length} article${mission.items.length > 1 ? 's' : ''}',
                style: const TextStyle(fontFamily: 'Nunito', fontSize: 13,
                    color: AppColors.darkSubtext)),
            ],
            const SizedBox(height: 20),

            // ── Boutons ─────────────────────────────────────────────────────
            if (_accepting)
              const CircularProgressIndicator(color: AppColors.primary)
            else
              Row(children: [
                Expanded(child: OutlinedButton(
                  onPressed: _decline,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.danger),
                    foregroundColor: AppColors.danger,
                    minimumSize: const Size(0, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Refuser',
                      style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700)),
                )),
                const SizedBox(width: 12),
                Expanded(child: ElevatedButton(
                  onPressed: _accept,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  child: const Text('Accepter ✓'),
                )),
              ]),
          ]),
        ),
      ),
    );
  }
}

// ── Badge multi-livraisons ────────────────────────────────────────────────────
class _MultiDeliveryBadge extends StatelessWidget {
  final int current;
  final Mission mission;
  const _MultiDeliveryBadge({required this.current, required this.mission});

  @override
  Widget build(BuildContext context) {
    // Compatibilité itinéraire : même zone de livraison ou même ville pro
    final hasZone     = mission.deliveryZone.isNotEmpty;
    final zoneLabel   = hasZone ? mission.deliveryZone : 'en cours';
    final compatible  = hasZone; // si deliveryZone peuplé = même secteur dispatché

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: (compatible ? AppColors.success : AppColors.accent).withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (compatible ? AppColors.success : AppColors.accent).withOpacity(0.4)),
      ),
      child: Row(children: [
        Icon(
          compatible ? Icons.route_rounded : Icons.warning_amber_rounded,
          size: 16,
          color: compatible ? AppColors.success : AppColors.accent,
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(
          compatible
            ? 'Compatible avec vos $current mission(s) — zone $zoneLabel'
            : "S'ajoutera à vos $current mission(s) en cours",
          style: TextStyle(fontFamily: 'Nunito', fontSize: 11,
              fontWeight: FontWeight.w700,
              color: compatible ? AppColors.success : AppColors.accent),
        )),
      ]),
    );
  }
}

// ── Widgets ───────────────────────────────────────────────────────────────────
class _Row extends StatelessWidget {
  final IconData icon; final String label, value; final Color color;
  const _Row(this.icon, this.label, this.value, {required this.color});
  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Icon(icon, size: 16, color: color),
    const SizedBox(width: 8),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontFamily: 'Nunito', fontSize: 10,
          color: AppColors.darkMuted, fontWeight: FontWeight.w600, letterSpacing: 0.3)),
      Text(value, style: const TextStyle(fontFamily: 'Nunito', fontSize: 13,
          color: AppColors.darkText, fontWeight: FontWeight.w700)),
    ])),
  ]);
}

class _Chip extends StatelessWidget {
  final String emoji, value, label;
  const _Chip(this.emoji, this.value, this.label);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 9),
    decoration: BoxDecoration(
        color: AppColors.darkSurface, borderRadius: BorderRadius.circular(10)),
    child: Column(children: [
      Text(emoji, style: const TextStyle(fontSize: 15)),
      const SizedBox(height: 2),
      Text(value, style: const TextStyle(fontFamily: 'Nunito', fontSize: 11,
          fontWeight: FontWeight.w800, color: AppColors.darkText)),
      Text(label, style: const TextStyle(fontFamily: 'Nunito', fontSize: 9,
          color: AppColors.darkMuted), textAlign: TextAlign.center),
    ]),
  );
}
