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
    if (mounted) Navigator.pop(context, false); // FIX: guard mounted
  }

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: AppColors.darkCard,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Pulsing icon
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

        // Countdown
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

        // Title
        const Text('Nouvelle mission !', style: TextStyle(fontFamily: 'Nunito',
            fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.darkText)),

        // Missions parallèles
        Builder(builder: (ctx) {
          final count = ref.watch(driverProvider).missionCount; // FIX: watch pour réactivité
          if (count == 0) return const SizedBox();
          return Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.accent.withOpacity(0.4)),
            ),
            child: Text("S'ajoutera à vos $count mission(s) en cours",
              style: const TextStyle(fontFamily: 'Nunito', fontSize: 11,
                  fontWeight: FontWeight.w700, color: AppColors.accent)),
          );
        }),
        const SizedBox(height: 16),

        // Mission details
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: AppColors.darkSurface, borderRadius: BorderRadius.circular(14)),
          child: Column(children: [
            _Row(Icons.store_rounded, 'Récupérer chez', widget.mission.professionalName),
            const SizedBox(height: 10),
            _Row(Icons.location_on_rounded, 'Livrer à',
              widget.mission.clientAddress.length > 40
                ? '${widget.mission.clientAddress.substring(0, 40)}…'
                : widget.mission.clientAddress),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _Chip('📏',
                  '${widget.mission.distanceKm.toStringAsFixed(1)} km')),
              const SizedBox(width: 8),
              Expanded(child: _Chip('⏱',
                  '~${widget.mission.estimatedMinutes} min')),
              const SizedBox(width: 8),
              Expanded(child: _Chip('💰',
                  '${widget.mission.deliveryFee.toStringAsFixed(0)} F')),
            ]),
          ]),
        ),

        if (widget.mission.items.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            '${widget.mission.items.length} article${widget.mission.items.length > 1 ? 's' : ''}',
            style: const TextStyle(fontFamily: 'Nunito', fontSize: 13,
                color: AppColors.darkSubtext)),
        ],
        const SizedBox(height: 20),

        // Buttons
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
  );
}

class _Row extends StatelessWidget {
  final IconData icon; final String label, value;
  const _Row(this.icon, this.label, this.value);
  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Icon(icon, size: 16, color: AppColors.primary),
    const SizedBox(width: 8),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontFamily: 'Nunito', fontSize: 11,
          color: AppColors.darkMuted, fontWeight: FontWeight.w600)),
      Text(value, style: const TextStyle(fontFamily: 'Nunito', fontSize: 13,
          color: AppColors.darkText, fontWeight: FontWeight.w700)),
    ])),
  ]);
}

class _Chip extends StatelessWidget {
  final String emoji, label;
  const _Chip(this.emoji, this.label);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 8),
    decoration: BoxDecoration(
        color: AppColors.darkCard, borderRadius: BorderRadius.circular(10)),
    child: Column(children: [
      Text(emoji, style: const TextStyle(fontSize: 16)),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(fontFamily: 'Nunito', fontSize: 11,
          fontWeight: FontWeight.w700, color: AppColors.darkText)),
    ]),
  );
}
