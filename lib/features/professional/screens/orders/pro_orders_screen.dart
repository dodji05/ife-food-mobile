import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/pro_socket_service.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../providers/pro_provider.dart';
import '../../../../shared/models/order.dart';

class ProOrdersScreen extends ConsumerStatefulWidget {
  const ProOrdersScreen({super.key});
  @override ConsumerState<ProOrdersScreen> createState() => _State();
}

class _State extends ConsumerState<ProOrdersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  StreamSubscription<Map<String, dynamic>>? _newOrderSub;
  int _newOrderBadge = 0;

  final _tabLabels = ['Nouvelles', 'En cours', 'Livrées', 'Annulées'];
  final _tabStatuses = ['PAID', 'active', 'DELIVERED', 'CANCELLED'];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _connectSocket());
  }

  void _connectSocket() {
    final token = ref.read(authProvider).accessToken;
    if (token == null || token.isEmpty) return;
    final svc = ref.read(proSocketServiceProvider);
    svc.connect(token);
    _newOrderSub = svc.newOrders.listen((payload) {
      if (!mounted) return;
      // Rafraîchit la liste des nouvelles commandes.
      ref.invalidate(liveOrdersProvider('PAID'));
      // Alerte haptique + badge visuel.
      HapticFeedback.heavyImpact();
      setState(() => _newOrderBadge++);
      // Snackbar discret avec le montant.
      final amount = (payload['totalAmount'] as num?)?.toStringAsFixed(0) ?? '?';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 4),
        content: Row(children: [
          const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(
            'Nouvelle commande — $amount F CFA',
            style: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700, color: Colors.white),
          )),
        ]),
        action: SnackBarAction(
          label: 'Voir',
          textColor: Colors.white,
          onPressed: () {
            _tabs.animateTo(0);
            setState(() => _newOrderBadge = 0);
          },
        ),
      ));
    });
  }

  @override
  void dispose() {
    _newOrderSub?.cancel();
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.darkBg,
    appBar: AppBar(
      title: const Text('Commandes'),
      actions: [
        if (_newOrderBadge > 0)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Stack(alignment: Alignment.topRight, children: [
              IconButton(
                icon: const Icon(Icons.notifications_active_rounded),
                onPressed: () { _tabs.animateTo(0); setState(() => _newOrderBadge = 0); },
              ),
              Positioned(
                right: 6, top: 6,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
                  child: Text('$_newOrderBadge',
                    style: const TextStyle(fontFamily: 'Nunito', fontSize: 9,
                        fontWeight: FontWeight.w900, color: Colors.white)),
                ),
              ),
            ]),
          ),
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          onPressed: () {
            ref.invalidate(liveOrdersProvider);
            setState(() => _newOrderBadge = 0);
          },
        ),
      ],
      bottom: TabBar(
        controller: _tabs,
        isScrollable: true, tabAlignment: TabAlignment.start,
        indicatorColor: AppColors.primary,
        labelColor: AppColors.primary, unselectedLabelColor: AppColors.darkSubtext,
        labelStyle: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700, fontSize: 13),
        unselectedLabelStyle: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w500, fontSize: 13),
        tabs: _tabLabels.map((l) => Tab(text: l)).toList(),
        indicatorWeight: 3,
      ),
    ),
    body: TabBarView(controller: _tabs, children: _tabStatuses.map((s) => _OrdersList(status: s)).toList()),
  );
}

class _OrdersList extends ConsumerWidget {
  final String status;
  const _OrdersList({required this.status});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(liveOrdersProvider(status));
    return RefreshIndicator(
      color: AppColors.primary, backgroundColor: AppColors.darkCard,
      onRefresh: () async => ref.invalidate(liveOrdersProvider(status)),
      child: orders.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(child: Text(e.toString(), style: const TextStyle(color: AppColors.darkSubtext))),
        data: (list) => list.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text('📭', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              Text('Aucune commande ${_statusLabel(status).toLowerCase()}', style: const TextStyle(fontFamily: 'Nunito', fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.darkText)),
            ]))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) => _OrderCard(order: list[i], status: status),
            ),
      ),
    );
  }
  String _statusLabel(String s) { switch(s) { case 'PAID': return 'Nouvelles'; case 'active': return 'En cours'; case 'DELIVERED': return 'Livrées'; default: return 'Annulées'; } }
}

class _OrderCard extends ConsumerWidget {
  final ProOrder order; final String status;
  const _OrderCard({required this.order, required this.status});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isNew = status == 'PAID';
    return GestureDetector(
      onTap: () => context.push('/pro/order/${order.id}'),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: isNew ? AppColors.accent.withOpacity(0.08) : AppColors.darkCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isNew ? AppColors.accent.withOpacity(0.5) : AppColors.darkBorder, width: isNew ? 2 : 1),
        ),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text('#${order.id.substring(0, 8).toUpperCase()}',
                  style: const TextStyle(fontFamily: 'Nunito', fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.darkSubtext))),
                _StatusBadge(order.status),
              ]),
              const SizedBox(height: 8),
              // Avatar + nom client + bouton appel (si tel dispo) + montant total
              Row(children: [
                _ClientAvatar(name: order.clientName, url: order.clientAvatarUrl, size: 28),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  order.clientName,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Nunito', fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.darkText),
                )),
                if (order.clientPhone != null && order.clientPhone!.isNotEmpty)
                  _CallButton(phone: order.clientPhone!),
                const SizedBox(width: 4),
                Text(
                  order.formattedTotal,
                  style: const TextStyle(fontFamily: 'Nunito', fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.primary),
                ),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                Text(
                  '${order.items.length} article${order.items.length > 1 ? 's' : ''} • ${order.createdAt.hour.toString().padLeft(2,'0')}h${order.createdAt.minute.toString().padLeft(2,'0')}',
                  style: const TextStyle(fontFamily: 'Nunito', fontSize: 12, color: AppColors.darkSubtext),
                ),
                if (order.estimatedDeliveryMin != null) ...[
                  const SizedBox(width: 8),
                  _MiniChip(icon: Icons.timer_outlined, text: '${order.estimatedDeliveryMin} min', color: AppColors.info),
                ],
                if (order.promoCode != null) ...[
                  const SizedBox(width: 6),
                  _MiniChip(icon: Icons.local_offer_rounded, text: order.promoCode!, color: AppColors.accent),
                ],
              ]),
              // Bandeau livreur si assigné (DRIVER_ASSIGNED, IN_DELIVERY…)
              if (order.driver != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    const Icon(Icons.two_wheeler_rounded, size: 14, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Expanded(child: Text(
                      'Livreur : ${order.driverName ?? '—'}',
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: 'Nunito', fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
                    )),
                    if (order.driverPhone != null && order.driverPhone!.isNotEmpty)
                      _CallButton(phone: order.driverPhone!, color: AppColors.primary, compact: true),
                  ]),
                ),
              ],
              if (order.specialInstructions != null && order.specialInstructions!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(children: [
                  const Icon(Icons.note_rounded, size: 12, color: AppColors.warning),
                  const SizedBox(width: 4),
                  Expanded(child: Text(order.specialInstructions!, style: const TextStyle(fontFamily: 'Nunito', fontSize: 12, color: AppColors.warning), maxLines: 1, overflow: TextOverflow.ellipsis)),
                ]),
              ],
            ]),
          ),
          // Quick action buttons for new orders
          if (isNew) Container(
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.darkBorder))),
            child: Row(children: [
              Expanded(child: TextButton.icon(
                onPressed: () => _showRejectDialog(context, ref, order),
                icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.danger),
                label: const Text('Refuser', style: TextStyle(fontFamily: 'Nunito', fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.danger)),
              )),
              Container(width: 1, height: 40, color: AppColors.darkBorder),
              Expanded(child: TextButton.icon(
                onPressed: () async {
                  await ref.read(proProvider.notifier).acceptOrder(order.id);
                  ref.invalidate(liveOrdersProvider('PAID'));
                },
                icon: const Icon(Icons.check_rounded, size: 16, color: AppColors.success),
                label: const Text('Accepter', style: TextStyle(fontFamily: 'Nunito', fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.success)),
              )),
            ]),
          ) else if (order.status == 'ACCEPTED') Container(
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.darkBorder))),
            child: TextButton.icon(
              onPressed: () async {
                await ref.read(proProvider.notifier).markInPreparation(order.id);
                ref.invalidate(liveOrdersProvider('active'));
              },
              icon: const Icon(Icons.restaurant_rounded, size: 16, color: AppColors.primary),
              label: const Text('Démarrer la préparation', style: TextStyle(fontFamily: 'Nunito', fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary)),
            ),
          ) else if (order.status == 'IN_PREPARATION') Container(
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.darkBorder))),
            child: TextButton.icon(
              onPressed: () async {
                await ref.read(proProvider.notifier).markReady(order.id);
                ref.invalidate(liveOrdersProvider('active'));
              },
              icon: const Icon(Icons.check_circle_rounded, size: 16, color: AppColors.success),
              label: const Text('Commande prête — Appeler le livreur', style: TextStyle(fontFamily: 'Nunito', fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.success)),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Reject dialog : raisons préset + détails optionnels ─────────────────────
//
// Ouvert depuis le bouton "Refuser" d'une carte commande PAID.
// L'utilisateur choisit un motif rapide OU sélectionne "Autre" et rédige
// un message libre (rendu obligatoire dans ce cas). Le motif final envoyé
// au backend (`cancelledReason`) combine preset + détails si les deux.
Future<void> _showRejectDialog(BuildContext context, WidgetRef ref, ProOrder order) async {
  final reason = await showDialog<String>(
    context: context,
    builder: (_) => _RejectDialog(orderId: order.id, clientName: order.clientName),
  );
  if (reason == null || reason.isEmpty) return; // annulé
  try {
    await ref.read(proProvider.notifier).rejectOrder(order.id, reason);
    ref.invalidate(liveOrdersProvider('PAID'));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Commande refusée'),
        backgroundColor: AppColors.warning,
      ));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceAll('Exception: ', '')),
        backgroundColor: AppColors.danger,
      ));
    }
  }
}

class _RejectDialog extends StatefulWidget {
  final String orderId;
  final String clientName;
  const _RejectDialog({required this.orderId, required this.clientName});
  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  // Presets ordonnés par fréquence d'usage attendue.
  static const _presets = [
    'Rupture de stock',
    'Trop de commandes en cours',
    'Établissement fermé',
    'Commande hors zone',
    'Autre',
  ];
  String _selected = _presets.first;
  final _detailsCtrl = TextEditingController();

  @override
  void dispose() {
    _detailsCtrl.dispose();
    super.dispose();
  }

  bool get _isOther => _selected == 'Autre';
  bool get _canSubmit {
    // 'Autre' impose un détail non vide. Les autres presets sont auto-suffisants.
    if (_isOther) return _detailsCtrl.text.trim().isNotEmpty;
    return true;
  }

  /// Construit la raison finale envoyée au backend.
  /// - preset standard : `"<preset>"` ou `"<preset> — <détails>"` si l'utilisateur a précisé.
  /// - 'Autre' : `<détails>` brut (le mot 'Autre' n'apporte rien au client final).
  String _composeReason() {
    final details = _detailsCtrl.text.trim();
    if (_isOther) return details;
    return details.isEmpty ? _selected : '$_selected — $details';
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: AppColors.darkCard,
    title: const Text(
      'Refuser la commande ?',
      style: TextStyle(fontFamily: 'Nunito', fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.darkText),
    ),
    contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
    content: SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(
          'Le client ${widget.clientName} recevra le motif. '
          'Sélectionnez la raison la plus précise pour qu\'il comprenne.',
          style: const TextStyle(fontFamily: 'Nunito', fontSize: 13, color: AppColors.darkSubtext, height: 1.4),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 6, runSpacing: 6,
          children: _presets.map((p) {
            final selected = p == _selected;
            return ChoiceChip(
              label: Text(p, style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppColors.darkText,
              )),
              selected: selected,
              onSelected: (_) => setState(() => _selected = p),
              backgroundColor: AppColors.darkBg,
              selectedColor: AppColors.danger,
              side: BorderSide(color: selected ? AppColors.danger : AppColors.darkBorder),
            );
          }).toList(),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _detailsCtrl,
          maxLines: 3,
          minLines: 2,
          maxLength: 200,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => setState(() {}), // refresh _canSubmit
          style: const TextStyle(fontFamily: 'Nunito', fontSize: 14, color: AppColors.darkText),
          decoration: InputDecoration(
            hintText: _isOther
                ? 'Précisez la raison (obligatoire)…'
                : 'Précisions (optionnel)…',
            counterStyle: const TextStyle(fontFamily: 'Nunito', fontSize: 10, color: AppColors.darkMuted),
          ),
        ),
      ]),
    ),
    actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Annuler',
          style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700, color: AppColors.darkSubtext)),
      ),
      ElevatedButton.icon(
        onPressed: _canSubmit ? () => Navigator.pop(context, _composeReason()) : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.danger,
          disabledBackgroundColor: AppColors.danger.withOpacity(0.4),
        ),
        icon: const Icon(Icons.close_rounded, size: 16),
        label: const Text('Refuser',
          style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800)),
      ),
    ],
  );
}

// ── Avatar client : photo si dispo, sinon cercle avec initiales ─────────────
class _ClientAvatar extends StatelessWidget {
  final String name;
  final String? url;
  final double size;
  const _ClientAvatar({required this.name, this.url, this.size = 32});

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final hasUrl = url != null && url!.isNotEmpty;
    return ClipOval(
      child: SizedBox(
        width: size, height: size,
        child: hasUrl
            ? CachedNetworkImage(
                imageUrl: url!,
                fit: BoxFit.cover,
                placeholder: (_, __) => _initialsFallback(),
                errorWidget: (_, __, ___) => _initialsFallback(),
              )
            : _initialsFallback(),
      ),
    );
  }

  Widget _initialsFallback() => Container(
    color: AppColors.primary.withOpacity(0.18),
    alignment: Alignment.center,
    child: Text(
      _initials,
      style: TextStyle(
        fontFamily: 'Nunito',
        fontSize: size * 0.42,
        fontWeight: FontWeight.w800,
        color: AppColors.primary,
      ),
    ),
  );
}

// ── Bouton "Appeler" — url_launcher tel: ────────────────────────────────────
class _CallButton extends StatelessWidget {
  final String phone;
  final Color color;
  final bool compact;
  const _CallButton({required this.phone, this.color = AppColors.success, this.compact = false});

  Future<void> _call(BuildContext context) async {
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
    final size = compact ? 28.0 : 32.0;
    return SizedBox(
      width: size, height: size,
      child: IconButton(
        padding: EdgeInsets.zero,
        tooltip: 'Appeler $phone',
        onPressed: () => _call(context),
        icon: Container(
          decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
          padding: EdgeInsets.all(compact ? 5 : 6),
          child: Icon(Icons.call_rounded, size: compact ? 14 : 16, color: color),
        ),
      ),
    );
  }
}

// ── Mini chip (timer, promo, …) ──────────────────────────────────────────────
class _MiniChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _MiniChip({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color.withOpacity(0.14),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 10, color: color),
      const SizedBox(width: 3),
      Text(text, style: TextStyle(
        fontFamily: 'Nunito', fontSize: 10, fontWeight: FontWeight.w800, color: color,
      )),
    ]),
  );
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge(this.status);
  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      'PAID'             => (AppColors.accent, 'Nouvelle'),
      'ACCEPTED'         => (AppColors.info, 'Acceptée'),
      'IN_PREPARATION'   => (AppColors.warning, 'En préparation'),
      'READY_FOR_PICKUP' => (AppColors.success, 'Prête !'),
      'DRIVER_ASSIGNED'  => (AppColors.primary, 'Livreur assigné'),
      'IN_DELIVERY'      => (AppColors.primary, 'En livraison'),
      'DELIVERED'        => (AppColors.success, 'Livrée'),
      'CANCELLED'        => (AppColors.danger, 'Annulée'),
      _                  => (AppColors.darkSubtext, status),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(fontFamily: 'Nunito', fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}
