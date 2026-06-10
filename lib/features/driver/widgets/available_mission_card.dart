// ─────────────────────────────────────────────────────────────────────────────
// ifè FOOD — Carte "mission disponible" (livreur)
//
// Affichée dans le dashboard et l'onglet Missions (en premier, couleur
// distincte). Compte à rebours live du temps restant pour accepter, basé sur
// `mission.acceptDeadline`. Bouton "Accepter" → driverProvider.acceptMission.
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_colors.dart';
import '../../../shared/models/mission.dart';
import '../providers/driver_provider.dart';

class AvailableMissionCard extends ConsumerStatefulWidget {
  final Mission mission;
  const AvailableMissionCard({super.key, required this.mission});

  @override
  ConsumerState<AvailableMissionCard> createState() => _AvailableMissionCardState();
}

class _AvailableMissionCardState extends ConsumerState<AvailableMissionCard> {
  Timer? _ticker;
  bool _accepting = false;

  @override
  void initState() {
    super.initState();
    // Tick chaque seconde pour rafraîchir le compte à rebours.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  int get _remainingSeconds {
    final d = widget.mission.acceptDeadline;
    if (d == null) return 0;
    return d.difference(DateTime.now()).inSeconds.clamp(0, 999999);
  }

  String get _countdownLabel {
    final s = _remainingSeconds;
    final m = s ~/ 60;
    final sec = s % 60;
    return m > 0 ? '$m min ${sec.toString().padLeft(2, '0')}s' : '${sec}s';
  }

  Future<void> _accept() async {
    if (_accepting) return;
    setState(() => _accepting = true);
    try {
      await ref.read(driverProvider.notifier).acceptMission(widget.mission.orderId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppLocalizations.of(context).driverMissionAccepted),
          backgroundColor: AppColors.success,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().contains('already')
              ? AppLocalizations.of(context).driverMissionAlreadyTaken
              : e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppColors.danger,
        ));
      }
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final m = widget.mission;
    final remaining = _remainingSeconds;
    // Couleur distincte (vert électrique livreur) + urgence (rouge) si <15s.
    final accent = remaining <= 15 ? AppColors.danger : AppColors.driverGreen;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        // Fond distinct des missions normales (teinte verte électrique).
        color: AppColors.driverGreen.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withOpacity(0.6), width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Bandeau temps restant ──────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: accent.withOpacity(0.15),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
          ),
          child: Row(children: [
            Icon(Icons.bolt_rounded, size: 16, color: accent),
            const SizedBox(width: 6),
            Text(t.driverNewMission,
              style: TextStyle(fontFamily: 'Nunito', fontSize: 11,
                fontWeight: FontWeight.w900, color: accent, letterSpacing: 0.5)),
            const Spacer(),
            Icon(Icons.timer_rounded, size: 14, color: accent),
            const SizedBox(width: 4),
            Text(_countdownLabel,
              style: TextStyle(fontFamily: 'Nunito', fontSize: 13,
                fontWeight: FontWeight.w900, color: accent)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Restaurant
            Row(children: [
              const Icon(Icons.store_rounded, size: 16, color: AppColors.yellow),
              const SizedBox(width: 8),
              Expanded(child: Text(m.professionalName,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: 'Nunito', fontSize: 15,
                  fontWeight: FontWeight.w800, color: context.textPrimary))),
            ]),
            const SizedBox(height: 6),
            // Livraison
            Row(children: [
              const Icon(Icons.location_on_rounded, size: 16, color: AppColors.danger),
              const SizedBox(width: 8),
              Expanded(child: Text(m.clientAddress,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: 'Nunito', fontSize: 13,
                  color: context.textSecondary))),
            ]),
            const SizedBox(height: 12),
            // Métriques — Wrap évite le débordement si les 3 chips sont présents
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _chip('💰', '${m.deliveryFee.toStringAsFixed(0)} ${m.currency}'),
                _chip('📏', '${m.distanceKm.toStringAsFixed(1)} km'),
                if (m.distanceToPickupKm != null)
                  _chip('🛵', '${m.distanceToPickupKm!.toStringAsFixed(1)} km'),
              ],
            ),
            const SizedBox(height: 14),
            // Bouton Accepter
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_accepting || remaining <= 0) ? null : _accept,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.driverGreen,
                  disabledBackgroundColor: AppColors.driverGreen.withOpacity(0.4),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _accepting
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black))
                    : Text(remaining <= 0 ? t.driverMissionExpired : t.driverAcceptMission,
                        style: const TextStyle(fontFamily: 'Nunito', fontSize: 15,
                          fontWeight: FontWeight.w900)),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _chip(String emoji, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: context.cardColor,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: context.borderColor),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(emoji, style: const TextStyle(fontSize: 12)),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontFamily: 'Nunito', fontSize: 12,
        fontWeight: FontWeight.w700, color: context.textPrimary)),
    ]),
  );
}
