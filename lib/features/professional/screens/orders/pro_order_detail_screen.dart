import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_colors.dart';
import '../../../../shared/models/order.dart';
import '../../providers/pro_provider.dart';

final orderDetailProvider = FutureProvider.autoDispose.family<ProOrder, String>((ref, id) async {
  final res = await ApiClient.instance.get('/orders/$id');
  return ProOrder.fromJson(res['data']);
});

class ProOrderDetailScreen extends ConsumerWidget {
  final String orderId;
  const ProOrderDetailScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(orderDetailProvider(orderId));
    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        title: Text('Commande #${orderId.substring(0, 8).toUpperCase()}'),
        leading: BackButton(
          onPressed: () => context.canPop() ? context.pop() : context.go('/pro/orders'),
        ),
      ),
      body: order.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (o) => ListView(padding: const EdgeInsets.all(16), children: [
          // Status banner — focalisé sur le statut + montant total
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AppColors.primary.withOpacity(0.3), context.cardColor], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 28),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(o.statusLabel, style: TextStyle(fontFamily: 'Nunito', fontSize: 18, fontWeight: FontWeight.w900, color: context.textPrimary)),
                Text('Total client : ${o.formattedTotal}', style: TextStyle(fontFamily: 'Nunito', fontSize: 13, color: context.textSecondary)),
              ])),
            ]),
          ),
          const SizedBox(height: 14),
          // ── Client ────────────────────────────────────────────────────────
          _Card('Client', _PersonRow(
            name:      o.clientName,
            avatarUrl: o.clientAvatarUrl,
            phone:     o.clientPhone,
            roleIcon:  Icons.person_rounded,
          )),
          // ── Livreur assigné ───────────────────────────────────────────────
          if (o.driver != null) ...[
            const SizedBox(height: 10),
            _Card('Livreur', Column(children: [
              _PersonRow(
                name:      o.driverName ?? '—',
                avatarUrl: o.driverAvatarUrl,
                phone:     o.driverPhone,
                roleIcon:  Icons.two_wheeler_rounded,
                accentColor: AppColors.primary,
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/pro/chat/${o.id}'),
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                  label: const Text('Messagerie avec le livreur',
                    style: TextStyle(fontFamily: 'Nunito', fontSize: 13, fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ])),
          ],
          // ── Assignation manuelle livreur (READY_FOR_PICKUP sans driver) ───
          if (o.status == 'READY_FOR_PICKUP' && o.driver == null) ...[
            const SizedBox(height: 10),
            _AssignDriverSection(orderId: o.id, onAssigned: () => ref.invalidate(orderDetailProvider(orderId))),
          ],
          const SizedBox(height: 10),
          // Items
          _Card('Articles commandés', Column(children: o.items.map((item) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [
              Container(width: 24, height: 24, decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                child: Center(child: Text('${item.quantity}', style: const TextStyle(fontFamily: 'Nunito', fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primary)))),
              const SizedBox(width: 10),
              Expanded(child: Text(item.productName, style: TextStyle(fontFamily: 'Nunito', fontSize: 14, color: context.textPrimary))),
              Text('${item.totalPrice.toStringAsFixed(0)} F', style: TextStyle(fontFamily: 'Nunito', fontSize: 13, fontWeight: FontWeight.w700, color: context.textPrimary)),
            ]),
          )).toList())),
          const SizedBox(height: 10),
          // Totals
          _Card('Résumé financier', Column(children: [
            _Row('Sous-total', '${o.subtotal.toStringAsFixed(0)} F'),
            _Row('Livraison', '${o.deliveryFee.toStringAsFixed(0)} F'),
            if (o.promoCode != null)
              _Row('Code promo (${o.promoCode})', 'appliqué', accent: true),
            _Row('Commission plateforme', '-${o.commissionAmount.toStringAsFixed(0)} F', danger: true),
            Divider(color: context.borderColor, height: 20),
            _Row('Vos revenus nets', '${o.netRevenue.toStringAsFixed(0)} F', bold: true, green: true),
          ])),
          const SizedBox(height: 10),
          // Delivery
          _Card('Livraison', Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Adresse', style: TextStyle(fontFamily: 'Nunito', fontSize: 11, color: context.textSecondary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(o.deliveryAddress, style: TextStyle(fontFamily: 'Nunito', fontSize: 14, color: context.textPrimary, fontWeight: FontWeight.w600)),
            if (o.isScheduled) ...[
              const SizedBox(height: 10),
              Row(children: [
                const Icon(Icons.schedule_rounded, size: 14, color: AppColors.info),
                const SizedBox(width: 6),
                Expanded(child: Text(
                  'Livraison planifiée le ${o.formattedScheduledAt}',
                  style: const TextStyle(fontFamily: 'Nunito', fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.info),
                )),
              ]),
            ],
            if (o.estimatedDeliveryMin != null) ...[
              const SizedBox(height: 10),
              Row(children: [
                const Icon(Icons.timer_outlined, size: 14, color: AppColors.info),
                const SizedBox(width: 6),
                Text(
                  'Temps estimé : ${o.estimatedDeliveryMin} min',
                  style: const TextStyle(fontFamily: 'Nunito', fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.info),
                ),
              ]),
            ],
            if (o.specialInstructions != null) ...[
              const SizedBox(height: 12),
              const Text('Instructions spéciales', style: TextStyle(fontFamily: 'Nunito', fontSize: 11, color: AppColors.warning, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(o.specialInstructions!, style: const TextStyle(fontFamily: 'Nunito', fontSize: 14, color: AppColors.warning)),
            ],
          ])),
          const SizedBox(height: 40),
        ]),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final String title; final Widget child;
  const _Card(this.title, this.child);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: context.cardColor, borderRadius: BorderRadius.circular(14), border: Border.all(color: context.borderColor)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: TextStyle(fontFamily: 'Nunito', fontSize: 12, fontWeight: FontWeight.w800, color: context.textSecondary, letterSpacing: 0.5)),
      const SizedBox(height: 12), child,
    ]),
  );
}

class _Row extends StatelessWidget {
  final String label, value;
  final bool bold, green, danger, accent;
  const _Row(this.label, this.value,
      {this.bold = false, this.green = false, this.danger = false, this.accent = false});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      Text(label, style: TextStyle(fontFamily: 'Nunito', fontSize: 13, color: context.textSecondary, fontWeight: bold ? FontWeight.w700 : FontWeight.w500)),
      const Spacer(),
      Text(value, style: TextStyle(
        fontFamily: 'Nunito',
        fontSize: bold ? 16 : 13,
        fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
        color: green  ? AppColors.success
             : danger ? AppColors.danger
             : accent ? AppColors.accent
             : context.textPrimary,
      )),
    ]),
  );
}

// ── Ligne client/livreur réutilisable (avatar + nom + tél + bouton appel) ──
class _PersonRow extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final String? phone;
  final IconData roleIcon;
  final Color accentColor;
  const _PersonRow({
    required this.name,
    this.avatarUrl,
    this.phone,
    required this.roleIcon,
    this.accentColor = AppColors.primary,
  });

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  Future<void> _call(BuildContext context) async {
    if (phone == null) return;
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Impossible d\'ouvrir le composeur pour $phone'),
        backgroundColor: AppColors.danger,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasAvatar = avatarUrl != null && avatarUrl!.isNotEmpty;
    return Row(children: [
      ClipOval(
        child: SizedBox(
          width: 44, height: 44,
          child: hasAvatar
              ? CachedNetworkImage(
                  imageUrl: avatarUrl!,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => _initialsFallback(),
                  errorWidget: (_, __, ___) => _initialsFallback(),
                )
              : _initialsFallback(),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(roleIcon, size: 14, color: accentColor),
          const SizedBox(width: 6),
          Expanded(child: Text(
            name,
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontFamily: 'Nunito', fontSize: 15, fontWeight: FontWeight.w800, color: context.textPrimary),
          )),
        ]),
        if (phone != null && phone!.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            phone!,
            style: TextStyle(fontFamily: 'Nunito', fontSize: 12, color: context.textSecondary),
          ),
        ],
      ])),
      if (phone != null && phone!.isNotEmpty)
        Builder(builder: (ctx) => IconButton(
          tooltip: 'Appeler $phone',
          onPressed: () => _call(ctx),
          icon: Container(
            decoration: BoxDecoration(color: AppColors.success.withOpacity(0.15), shape: BoxShape.circle),
            padding: const EdgeInsets.all(8),
            child: const Icon(Icons.call_rounded, size: 18, color: AppColors.success),
          ),
        )),
    ]);
  }

  Widget _initialsFallback() => Container(
    color: accentColor.withOpacity(0.18),
    alignment: Alignment.center,
    child: Text(
      _initials,
      style: TextStyle(
        fontFamily: 'Nunito', fontSize: 16, fontWeight: FontWeight.w800, color: accentColor,
      ),
    ),
  );
}

// ── Assignation manuelle d'un livreur favori ──────────────────────────────────
class _AssignDriverSection extends ConsumerStatefulWidget {
  final String orderId;
  final VoidCallback onAssigned;
  const _AssignDriverSection({required this.orderId, required this.onAssigned});
  @override
  ConsumerState<_AssignDriverSection> createState() => _AssignDriverSectionState();
}

class _AssignDriverSectionState extends ConsumerState<_AssignDriverSection> {
  bool _loading = false;
  List<FavoriteDriverEntry>? _drivers;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await ref.read(proProvider.notifier).availableDriversForOrder();
      if (mounted) setState(() => _drivers = list);
    } catch (_) {
      if (mounted) setState(() => _drivers = []);
    }
  }

  Future<void> _assign(FavoriteDriverEntry driver) async {
    setState(() => _loading = true);
    try {
      await ref.read(proProvider.notifier).assignDriver(widget.orderId, driver.driverId);
      widget.onAssigned();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppColors.danger,
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_drivers == null) {
      return _Card('Assigner un livreur', const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
        ),
      ));
    }
    if (_drivers!.isEmpty) {
      return _Card('Assigner un livreur', Builder(builder: (ctx) => Text(
        'Aucun livreur favori disponible actuellement.\n'
        'Un livreur sera assigné automatiquement.',
        style: TextStyle(fontFamily: 'Nunito', fontSize: 13, color: ctx.textSecondary),
      )));
    }
    return _Card('Assigner un livreur favori', Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Livreurs disponibles',
          style: TextStyle(fontFamily: 'Nunito', fontSize: 11,
              color: context.textSecondary, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        ..._drivers!.map((d) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.15), shape: BoxShape.circle),
              child: const Icon(Icons.two_wheeler_rounded, size: 18, color: AppColors.primary),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(d.userName, style: TextStyle(
                fontFamily: 'Nunito', fontSize: 14, fontWeight: FontWeight.w700, color: context.textPrimary)),
              Text(_vehicleLabel(d.vehicleType),
                style: TextStyle(fontFamily: 'Nunito', fontSize: 11, color: context.textSecondary)),
            ])),
            TextButton(
              onPressed: _loading ? null : () => _assign(d),
              style: TextButton.styleFrom(
                backgroundColor: AppColors.primary.withOpacity(0.12),
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: _loading
                  ? const SizedBox(width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                  : const Text('Assigner',
                      style: TextStyle(fontFamily: 'Nunito', fontSize: 12, fontWeight: FontWeight.w800)),
            ),
          ]),
        )),
      ],
    ));
  }

  String _vehicleLabel(String type) => switch (type) {
    'MOTORCYCLE' => 'Moto',
    'BICYCLE'    => 'Vélo',
    'CAR'        => 'Voiture',
    'TRUCK'      => 'Camion',
    _            => type,
  };
}
