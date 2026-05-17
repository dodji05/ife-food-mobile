import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/theme/app_theme.dart';
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
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(title: Text('Commande #${orderId.substring(0, 8).toUpperCase()}'), leading: const BackButton()),
      body: order.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (o) => ListView(padding: const EdgeInsets.all(16), children: [
          // Status banner — focalisé sur le statut + montant total
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AppColors.primary.withOpacity(0.3), AppColors.darkCard], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 28),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(o.statusLabel, style: const TextStyle(fontFamily: 'Nunito', fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.darkText)),
                Text('Total client : ${o.formattedTotal}', style: const TextStyle(fontFamily: 'Nunito', fontSize: 13, color: AppColors.darkSubtext)),
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
          // ── Livreur (uniquement si assigné) ──────────────────────────────
          if (o.driver != null) ...[
            const SizedBox(height: 10),
            _Card('Livreur', _PersonRow(
              name:      o.driverName ?? '—',
              avatarUrl: o.driver?['avatarUrl'] as String?,
              phone:     o.driverPhone,
              roleIcon:  Icons.two_wheeler_rounded,
              accentColor: AppColors.primary,
            )),
          ],
          const SizedBox(height: 10),
          // Items
          _Card('Articles commandés', Column(children: o.items.map((item) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [
              Container(width: 24, height: 24, decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                child: Center(child: Text('${item.quantity}', style: const TextStyle(fontFamily: 'Nunito', fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primary)))),
              const SizedBox(width: 10),
              Expanded(child: Text(item.productName, style: const TextStyle(fontFamily: 'Nunito', fontSize: 14, color: AppColors.darkText))),
              Text('${item.totalPrice.toStringAsFixed(0)} F', style: const TextStyle(fontFamily: 'Nunito', fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.darkText)),
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
            const Divider(color: AppColors.darkBorder, height: 20),
            _Row('Vos revenus nets', '${o.netRevenue.toStringAsFixed(0)} F', bold: true, green: true),
          ])),
          const SizedBox(height: 10),
          // Delivery
          _Card('Livraison', Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Adresse', style: TextStyle(fontFamily: 'Nunito', fontSize: 11, color: AppColors.darkSubtext, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(o.deliveryAddress, style: const TextStyle(fontFamily: 'Nunito', fontSize: 14, color: AppColors.darkText, fontWeight: FontWeight.w600)),
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
    decoration: BoxDecoration(color: AppColors.darkCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.darkBorder)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontFamily: 'Nunito', fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.darkSubtext, letterSpacing: 0.5)),
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
      Text(label, style: TextStyle(fontFamily: 'Nunito', fontSize: 13, color: AppColors.darkSubtext, fontWeight: bold ? FontWeight.w700 : FontWeight.w500)),
      const Spacer(),
      Text(value, style: TextStyle(
        fontFamily: 'Nunito',
        fontSize: bold ? 16 : 13,
        fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
        color: green  ? AppColors.success
             : danger ? AppColors.danger
             : accent ? AppColors.accent
             : AppColors.darkText,
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
            style: const TextStyle(fontFamily: 'Nunito', fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.darkText),
          )),
        ]),
        if (phone != null && phone!.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            phone!,
            style: const TextStyle(fontFamily: 'Nunito', fontSize: 12, color: AppColors.darkSubtext),
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
