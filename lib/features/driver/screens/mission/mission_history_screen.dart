// ─────────────────────────────────────────────────────────────────────────────
// ifè FOOD — Driver Mission History Screen
// Affiche les livraisons passées : date, montant, itinéraire, statut.
// Source : GET /deliveries/driver/history
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_colors.dart';
import '../../providers/driver_provider.dart';
import '../../widgets/available_mission_card.dart';

final missionHistoryProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await ApiClient.instance.get('/deliveries/driver/history');
  return List<Map<String, dynamic>>.from(res['data'] ?? []);
});

class MissionHistoryScreen extends ConsumerWidget {
  const MissionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(missionHistoryProvider);
    final available = ref.watch(driverProvider).availableMissions;

    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        elevation: 0,
        title: Text('Mes missions',
          style: TextStyle(fontFamily: 'Nunito', fontSize: 17,
              fontWeight: FontWeight.w800, color: context.textPrimary)),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          ref.invalidate(missionHistoryProvider);
          await ref.read(missionHistoryProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            // ── Missions disponibles (en premier, couleur distincte) ─────────
            if (available.isNotEmpty) ...[
              Row(children: [
                const Icon(Icons.bolt_rounded, size: 18, color: AppColors.primary),
                const SizedBox(width: 6),
                Text('Missions disponibles (${available.length})',
                  style: const TextStyle(fontFamily: 'Nunito', fontSize: 14,
                    fontWeight: FontWeight.w900, color: AppColors.primary)),
              ]),
              const SizedBox(height: 12),
              ...available.map((m) => AvailableMissionCard(mission: m)),
              const SizedBox(height: 8),
              Divider(color: context.borderColor),
              const SizedBox(height: 12),
              Text('Historique',
                style: TextStyle(fontFamily: 'Nunito', fontSize: 12,
                  fontWeight: FontWeight.w800, color: context.textSecondary,
                  letterSpacing: 0.5)),
              const SizedBox(height: 12),
            ],

            // ── Historique ───────────────────────────────────────────────────
            ...history.when(
              loading: () => [const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
              )],
              error: (_, __) => [_Empty(
                emoji: '⚠️',
                title: 'Erreur de chargement',
                subtitle: 'Vérifiez votre connexion puis tirez pour réessayer.',
              )],
              data: (list) {
                if (list.isEmpty) {
                  return [available.isEmpty
                    ? _Empty(
                        emoji: '📭',
                        title: 'Aucune mission',
                        subtitle: 'Passez en ligne et acceptez votre\npremière mission !',
                      )
                    : const SizedBox.shrink()];
                }
                return _groupByDate(list).map<Widget>((entry) {
                  if (entry is _DateHeader) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8, top: 4),
                      child: Text(entry.label,
                        style: TextStyle(
                          fontFamily: 'Nunito', fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: context.textSecondary,
                          letterSpacing: 0.5)),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _MissionCard(m: (entry as _DeliveryEntry).data),
                  );
                }).toList();
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Intercale des en-têtes de date entre les livraisons.
  List<Object> _groupByDate(List<Map<String, dynamic>> list) {
    final result = <Object>[];
    String? lastLabel;
    for (final m in list) {
      final dt = DateTime.tryParse(m['createdAt'] as String? ?? '')
          ?.toLocal() ?? DateTime.now();
      final label = _dayLabel(dt);
      if (label != lastLabel) {
        result.add(_DateHeader(label));
        lastLabel = label;
      }
      result.add(_DeliveryEntry(m));
    }
    return result;
  }

  String _dayLabel(DateTime dt) {
    final now = DateTime.now();
    final today    = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final d = DateTime(dt.year, dt.month, dt.day);
    if (d == today)     return "Aujourd'hui";
    if (d == yesterday) return 'Hier';
    final months = ['jan.', 'fév.', 'mar.', 'avr.', 'mai', 'juin',
                    'juil.', 'aoû.', 'sep.', 'oct.', 'nov.', 'déc.'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}

class _DateHeader { final String label; const _DateHeader(this.label); }
class _DeliveryEntry { final Map<String, dynamic> data; const _DeliveryEntry(this.data); }

// ── Carte de mission ──────────────────────────────────────────────────────────
class _MissionCard extends StatefulWidget {
  final Map<String, dynamic> m;
  const _MissionCard({required this.m});
  @override State<_MissionCard> createState() => _MissionCardState();
}

class _MissionCardState extends State<_MissionCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late AnimationController _ctrl;
  late Animation<double> _rotate;

  @override
  void initState() {
    super.initState();
    _ctrl   = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _rotate = Tween<double>(begin: 0, end: 0.5).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    _expanded ? _ctrl.forward() : _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.m;
    final status      = m['status'] as String? ?? '';
    final isDelivered = status == 'DELIVERED';
    final isFailed    = status == 'FAILED';
    final orderId     = (m['orderId'] as String?)
        ?? ((m['order'] as Map<String, dynamic>?)?['id'] as String?)
        ?? '';

    final createdAt    = _parseDate(m['createdAt']);
    final pickupTime   = _parseDate(m['pickupTime']);
    final deliveredAt  = _parseDate(m['deliveredTime']);
    final distanceKm   = (m['distanceKm'] as num?)?.toDouble();

    final order = m['order'] as Map<String, dynamic>?;
    final pro   = order?['professional'] as Map<String, dynamic>?;
    final businessName   = (pro?['businessName'] as String?)  ?? 'Établissement';
    final pickupAddress  = (pro?['address']      as String?)  ?? '';
    final deliveryAddress = (order?['deliveryAddress'] as String?) ?? '';
    final deliveryFee    = (order?['deliveryFee']   as num?)?.toDouble();

    final Color statusColor = isDelivered
        ? AppColors.success
        : isFailed ? AppColors.danger : context.textSecondary;

    return GestureDetector(
      onTap: _toggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _expanded
                ? AppColors.primary.withOpacity(0.3)
                : context.borderColor),
        ),
        child: Column(children: [

          // ── Ligne principale ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              // Icône statut
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12)),
                child: Icon(
                  isDelivered
                    ? Icons.check_circle_rounded
                    : isFailed
                      ? Icons.cancel_rounded
                      : Icons.hourglass_top_rounded,
                  color: statusColor, size: 22),
              ),
              const SizedBox(width: 12),

              // Infos centre
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(businessName,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: 'Nunito', fontSize: 14,
                        fontWeight: FontWeight.w800, color: context.textPrimary)),
                  const SizedBox(height: 3),
                  Row(children: [
                    _StatusBadge(status),
                    const SizedBox(width: 8),
                    Text(_timeStr(createdAt),
                      style: TextStyle(fontFamily: 'Nunito', fontSize: 11,
                          color: context.textSecondary)),
                  ]),
                ],
              )),

              // Montant + chat + chevron
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(
                  isDelivered && deliveryFee != null
                    ? '+ ${deliveryFee.toStringAsFixed(0)} F'
                    : isFailed ? 'Échouée' : '—',
                  style: TextStyle(fontFamily: 'Nunito', fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: isDelivered ? AppColors.success : AppColors.danger)),
                const SizedBox(height: 2),
                if (distanceKm != null)
                  Text('${distanceKm.toStringAsFixed(1)} km',
                    style: TextStyle(fontFamily: 'Nunito', fontSize: 11,
                        color: context.textMuted)),
                const SizedBox(height: 4),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  // Bouton chat — toujours visible même mission terminée
                  if (orderId.isNotEmpty)
                    GestureDetector(
                      onTap: () => context.push('/driver/chat/$orderId'),
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.chat_bubble_outline_rounded,
                            size: 15, color: AppColors.primary),
                      ),
                    ),
                  const SizedBox(width: 6),
                  RotationTransition(
                    turns: _rotate,
                    child: Icon(Icons.keyboard_arrow_down_rounded,
                      color: context.textMuted, size: 18)),
                ]),
              ]),
            ]),
          ),

          // ── Section dépliable ─────────────────────────────────────────────
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _ExpandedDetail(
              pickupAddress:    pickupAddress,
              deliveryAddress:  deliveryAddress,
              createdAt:        createdAt,
              pickupTime:       pickupTime,
              deliveredAt:      deliveredAt,
              distanceKm:       distanceKm,
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ]),
      ),
    );
  }

  DateTime? _parseDate(dynamic v) =>
      v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

  String _timeStr(DateTime? dt) {
    if (dt == null) return '';
    return '${dt.hour.toString().padLeft(2, '0')}h${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ── Détail itinéraire + chronologie ──────────────────────────────────────────
class _ExpandedDetail extends StatelessWidget {
  final String pickupAddress;
  final String deliveryAddress;
  final DateTime? createdAt;
  final DateTime? pickupTime;
  final DateTime? deliveredAt;
  final double? distanceKm;

  const _ExpandedDetail({
    required this.pickupAddress,
    required this.deliveryAddress,
    required this.createdAt,
    required this.pickupTime,
    required this.deliveredAt,
    required this.distanceKm,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Itinéraire
        if (pickupAddress.isNotEmpty || deliveryAddress.isNotEmpty) ...[
          _SectionLabel('ITINÉRAIRE'),
          const SizedBox(height: 8),
          _RouteRow(
            fromAddress: pickupAddress,
            toAddress:   deliveryAddress,
            distanceKm:  distanceKm,
          ),
          const SizedBox(height: 12),
        ],

        // Chronologie
        _SectionLabel('CHRONOLOGIE'),
        const SizedBox(height: 8),
        _Timeline(
          assignedAt:  createdAt,
          pickedUpAt:  pickupTime,
          deliveredAt: deliveredAt,
        ),
      ]),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
    style: TextStyle(fontFamily: 'Nunito', fontSize: 10,
        fontWeight: FontWeight.w800, color: context.textMuted,
        letterSpacing: 0.6));
}

// ── Route pickup → delivery ───────────────────────────────────────────────────
class _RouteRow extends StatelessWidget {
  final String fromAddress, toAddress;
  final double? distanceKm;
  const _RouteRow({
    required this.fromAddress,
    required this.toAddress,
    required this.distanceKm,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Pickup
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Column(children: [
          Container(width: 10, height: 10,
            decoration: BoxDecoration(
              color: AppColors.yellow,
              shape: BoxShape.circle,
              border: Border.all(color: context.bgColor, width: 2))),
          Container(width: 1.5, height: 22, color: context.borderColor),
        ]),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Retrait', style: TextStyle(fontFamily: 'Nunito',
              fontSize: 10, color: context.textMuted, fontWeight: FontWeight.w600)),
          Text(fromAddress.isNotEmpty ? fromAddress : '—',
            style: TextStyle(fontFamily: 'Nunito', fontSize: 12,
                color: context.textPrimary, fontWeight: FontWeight.w600)),
        ])),
      ]),

      // Destination
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Column(children: [
          Container(width: 10, height: 10,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              border: Border.all(color: context.bgColor, width: 2))),
        ]),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Livraison', style: TextStyle(fontFamily: 'Nunito',
              fontSize: 10, color: context.textMuted, fontWeight: FontWeight.w600)),
          Text(toAddress.isNotEmpty ? toAddress : '—',
            style: TextStyle(fontFamily: 'Nunito', fontSize: 12,
                color: context.textPrimary, fontWeight: FontWeight.w600)),
        ])),
        if (distanceKm != null) Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6)),
            child: Text('${distanceKm!.toStringAsFixed(1)} km',
              style: const TextStyle(fontFamily: 'Nunito', fontSize: 11,
                  fontWeight: FontWeight.w800, color: AppColors.primary)),
          ),
        ),
      ]),
    ]);
  }
}

// ── Frise chronologique ───────────────────────────────────────────────────────
class _Timeline extends StatelessWidget {
  final DateTime? assignedAt;
  final DateTime? pickedUpAt;
  final DateTime? deliveredAt;
  const _Timeline({this.assignedAt, this.pickedUpAt, this.deliveredAt});

  @override
  Widget build(BuildContext context) {
    final events = [
      if (assignedAt  != null) _TimelineEvent('Mission assignée',  assignedAt!,  Icons.hourglass_top_rounded, AppColors.info),
      if (pickedUpAt  != null) _TimelineEvent('Commande récupérée', pickedUpAt!, Icons.shopping_bag_rounded,   AppColors.yellow),
      if (deliveredAt != null) _TimelineEvent('Livrée',            deliveredAt!, Icons.check_circle_rounded,  AppColors.success),
    ];

    if (events.isEmpty) {
      return Builder(builder: (ctx) => Text('—', style: TextStyle(fontFamily: 'Nunito',
          fontSize: 12, color: ctx.textMuted)));
    }

    return Column(children: events.asMap().entries.map((e) {
      final isLast = e.key == events.length - 1;
      final ev = e.value;
      return Builder(builder: (ctx) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Column(children: [
          Container(width: 26, height: 26,
            decoration: BoxDecoration(
              color: ev.color.withOpacity(0.15),
              shape: BoxShape.circle),
            child: Icon(ev.icon, color: ev.color, size: 13)),
          if (!isLast) Container(width: 1.5, height: 16, color: ctx.borderColor),
        ]),
        const SizedBox(width: 10),
        Expanded(child: Padding(
          padding: EdgeInsets.only(bottom: isLast ? 0 : 4),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(ev.label, style: TextStyle(fontFamily: 'Nunito',
                fontSize: 12, color: ctx.textPrimary, fontWeight: FontWeight.w600)),
            Text(_fmt(ev.time), style: TextStyle(fontFamily: 'Nunito',
                fontSize: 12, color: ctx.textSecondary)),
          ]),
        )),
      ]));
    }).toList());
  }

  String _fmt(DateTime dt) {
    final d  = dt.toLocal();
    final hm = '${d.hour.toString().padLeft(2, '0')}h${d.minute.toString().padLeft(2, '0')}';
    final now = DateTime.now();
    if (d.year == now.year && d.month == now.month && d.day == now.day) return hm;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} $hm';
  }
}

class _TimelineEvent {
  final String label;
  final DateTime time;
  final IconData icon;
  final Color color;
  const _TimelineEvent(this.label, this.time, this.icon, this.color);
}

// ── Badge statut ──────────────────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge(this.status);

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'DELIVERED' => ('Livrée', AppColors.success),
      'FAILED'    => ('Échouée', AppColors.danger),
      _           => (status, context.textSecondary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(5)),
      child: Text(label,
        style: TextStyle(fontFamily: 'Nunito', fontSize: 10,
            fontWeight: FontWeight.w800, color: color)),
    );
  }
}

// ── État vide ─────────────────────────────────────────────────────────────────
class _Empty extends StatelessWidget {
  final String emoji, title, subtitle;
  const _Empty({required this.emoji, required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    children: [
      const SizedBox(height: 140),
      Center(child: Text(emoji, style: const TextStyle(fontSize: 52))),
      const SizedBox(height: 12),
      Center(child: Text(title,
        style: TextStyle(fontFamily: 'Nunito', fontSize: 18,
          fontWeight: FontWeight.w800, color: context.textPrimary))),
      const SizedBox(height: 8),
      Center(child: Text(subtitle, textAlign: TextAlign.center,
        style: TextStyle(fontFamily: 'Nunito', fontSize: 14,
          color: context.textSecondary))),
    ],
  );
}
