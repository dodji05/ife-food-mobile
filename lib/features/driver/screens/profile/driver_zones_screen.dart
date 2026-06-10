import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_colors.dart';
import '../../../../shared/models/driver_zone.dart';
import '../../providers/driver_provider.dart';

class DriverZonesScreen extends ConsumerWidget {
  const DriverZonesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zonesAsync = ref.watch(driverZonesProvider);

    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.surfaceColor,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: context.bgColor, shape: BoxShape.circle),
            child: Icon(Icons.arrow_back_rounded, color: context.textPrimary),
          ),
        ),
        title: Text('Zones de livraison',
          style: TextStyle(fontFamily: 'Nunito', fontSize: 17,
              fontWeight: FontWeight.w800, color: context.textPrimary)),
      ),
      body: zonesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(
          child: Text('Erreur : $e',
              style: const TextStyle(color: AppColors.danger, fontFamily: 'Nunito'))),
        data: (zones) {
          if (zones.isEmpty) return const _EmptyState();
          return Column(children: [
            Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.info.withOpacity(0.25)),
              ),
              child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.info_outline_rounded, size: 16, color: AppColors.info),
                SizedBox(width: 8),
                Expanded(child: Text(
                  'Sélectionnez les zones où vous souhaitez recevoir des missions.',
                  style: TextStyle(fontFamily: 'Nunito', fontSize: 12,
                      color: AppColors.info, height: 1.4),
                )),
              ]),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: zones.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (ctx, i) => _ZoneTile(
                  zone: zones[i],
                  onToggle: () => _toggle(ctx, ref, zones[i]),
                ),
              ),
            ),
          ]);
        },
      ),
    );
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref, DeliveryZone zone) async {
    try {
      if (zone.selected) {
        await ApiClient.instance.delete('/drivers/me/zones/${zone.id}');
      } else {
        await ApiClient.instance.post('/drivers/me/zones/${zone.id}/select');
      }
      ref.invalidate(driverZonesProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppColors.danger,
        ));
      }
    }
  }
}

// ── Tuile de zone ─────────────────────────────────────────────────────────────
class _ZoneTile extends StatelessWidget {
  final DeliveryZone zone;
  final VoidCallback onToggle;
  const _ZoneTile({required this.zone, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: zone.selected
              ? AppColors.primary.withOpacity(0.08)
              : context.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: zone.selected
                ? AppColors.primary.withOpacity(0.5)
                : context.borderColor,
            width: zone.selected ? 1.5 : 1,
          ),
        ),
        child: Row(children: [
          // Icône zone
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: (zone.selected ? AppColors.primary : AppColors.info)
                  .withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.place_rounded,
              color: zone.selected ? AppColors.primary : AppColors.info,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          // Infos
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(zone.name,
              style: TextStyle(
                fontFamily: 'Nunito', fontSize: 15, fontWeight: FontWeight.w800,
                color: zone.selected ? AppColors.primary : context.textPrimary,
              )),
            const SizedBox(height: 3),
            Text(
              _subtitle(zone),
              style: TextStyle(
                  fontFamily: 'Nunito', fontSize: 12, color: context.textSecondary),
            ),
          ])),
          // Toggle
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: zone.selected ? AppColors.primary : Colors.transparent,
              border: Border.all(
                color: zone.selected ? AppColors.primary : context.borderColor,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: zone.selected
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                : null,
          ),
        ]),
      ),
    );
  }

  String _subtitle(DeliveryZone z) {
    final parts = <String>[];
    if (z.fromCity != null) parts.add(z.fromCity!);
    if (z.toCity != null && z.toCity != z.fromCity) parts.add(z.toCity!);
    parts.add(z.country);
    if (z.baseFee > 0) parts.add('${z.baseFee.toStringAsFixed(0)} ${z.currency}');
    return parts.join(' · ');
  }
}

// ── État vide ─────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 72, height: 72,
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.place_rounded, color: AppColors.primary, size: 34),
      ),
      const SizedBox(height: 16),
      Text('Aucune zone disponible',
        style: TextStyle(fontFamily: 'Nunito', fontSize: 17,
            fontWeight: FontWeight.w800, color: context.textPrimary)),
      const SizedBox(height: 6),
      Text('L\'administrateur n\'a pas encore créé\nde zones de livraison.',
        textAlign: TextAlign.center,
        style: TextStyle(fontFamily: 'Nunito', fontSize: 13, color: context.textSecondary)),
    ]),
  );
}
