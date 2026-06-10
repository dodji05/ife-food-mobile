// ─────────────────────────────────────────────────────────────────────────────
// ifè FOOD — Dashboard pro
//
// Sections :
//   1. Header : bonjour + nom étab + toggle Ouvert/Fermé (tap pour basculer)
//   2. Alerte nouvelles commandes (PAID) → /pro/orders
//   3. 4 KPI cards colorées (revenus jour, à traiter, total commandes, note)
//   4. LineChart revenus 7 derniers jours (fl_chart, gradient fill)
//   5. Top 5 produits (qty vendues, image, prix)
//   6. Actions rapides (grille 6)
//
// Source des données : dashboardProvider → GET /professionals/me/dashboard
// Structure attendue :
//   {
//     revenue: { today, week, month },
//     orders:  { today, pending, total },
//     avgRating, reviewCount,
//     revenueByDay: [{date:'YYYY-MM-DD', revenue, orders}, ...×7],
//     topProducts:  [{productId, quantitySold, product}, ...×5],
//     recentReviews: [...],
//   }
// ─────────────────────────────────────────────────────────────────────────────
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_colors.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/notifications_provider.dart';
import '../../../../shared/models/product.dart';
import '../../providers/pro_provider.dart';

class ProDashboardScreen extends ConsumerWidget {
  const ProDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth      = ref.watch(authProvider);
    final proState  = ref.watch(proProvider);
    final stats     = ref.watch(dashboardProvider);
    final newOrders = ref.watch(liveOrdersProvider('PAID'));

    final user = auth.user;
    final pro  = proState.professional;

    return Scaffold(
      backgroundColor: context.bgColor,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          ref.invalidate(dashboardProvider);
          ref.invalidate(liveOrdersProvider('PAID'));
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── Header ────────────────────────────────────────────────────────
            SliverToBoxAdapter(child: Container(
              color: context.surfaceColor,
              child: SafeArea(bottom: false, child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Bonjour 👋', style: TextStyle(
                        fontFamily: 'Nunito', fontSize: 13, color: context.textSecondary)),
                    const SizedBox(height: 2),
                    Text(pro?.businessName ?? user?.displayName ?? 'Mon établissement',
                      style: TextStyle(fontFamily: 'Nunito', fontSize: 20,
                          fontWeight: FontWeight.w900, color: context.textPrimary)),
                  ])),
                  // Cloche notifs avec badge non-lus
                  _NotifBell(unread: ref.watch(unreadCountProvider)),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => ref.read(proProvider.notifier).toggleOpen(),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: (pro?.isOpen ?? false)
                            ? AppColors.success.withOpacity(0.15)
                            : context.cardColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: (pro?.isOpen ?? false)
                              ? AppColors.success.withOpacity(0.4)
                              : context.borderColor),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(width: 7, height: 7, decoration: BoxDecoration(
                          color: (pro?.isOpen ?? false) ? AppColors.success : context.textMuted,
                          shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Text((pro?.isOpen ?? false) ? 'Ouvert' : 'Fermé',
                          style: TextStyle(fontFamily: 'Nunito', fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: (pro?.isOpen ?? false) ? AppColors.success : context.textSecondary)),
                      ]),
                    ),
                  ),
                ]),
              )),
            )),

            // ── Alerte nouvelles commandes ─────────────────────────────────────
            newOrders.when(
              loading: () => const SliverToBoxAdapter(),
              error: (_, __) => const SliverToBoxAdapter(),
              data: (list) => list.isEmpty ? const SliverToBoxAdapter() : SliverToBoxAdapter(
                child: GestureDetector(
                  onTap: () => context.go('/pro/orders'),
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.accent.withOpacity(0.5), width: 2),
                    ),
                    child: Row(children: [
                      const Text('🔔', style: TextStyle(fontSize: 28)),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${list.length} nouvelle${list.length > 1 ? 's' : ''} commande${list.length > 1 ? 's' : ''}',
                          style: const TextStyle(fontFamily: 'Nunito', fontSize: 15,
                              fontWeight: FontWeight.w800, color: AppColors.accent)),
                        Text('Appuyez pour accepter ou refuser',
                          style: TextStyle(fontFamily: 'Nunito', fontSize: 12,
                              color: context.textSecondary)),
                      ])),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.accent),
                    ]),
                  ),
                ),
              ),
            ),

            // ── KPI cards + chart + top produits ─────────────────────────────
            SliverToBoxAdapter(child: stats.when(
              loading: () => const _DashboardShimmer(),
              error: (e, _) => _ErrorBlock(message: e.toString(), onRetry: () => ref.invalidate(dashboardProvider)),
              data: (data) => _DashboardBody(data: data),
            )),

            // ── Actions rapides ───────────────────────────────────────────────
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Text('Actions rapides', style: TextStyle(fontFamily: 'Nunito',
                  fontSize: 16, fontWeight: FontWeight.w800, color: context.textPrimary)),
            )),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              sliver: SliverGrid.count(crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10,
                childAspectRatio: 1.1,
                children: [
                  _QuickAction('📋', 'Commandes', () => context.go('/pro/orders')),
                  _QuickAction('🍽️', 'Catalogue', () => context.go('/pro/catalogue')),
                  _QuickAction('💰', 'Revenus',   () => context.go('/pro/earnings')),
                  _QuickAction('⏰', 'Horaires',  () => context.push('/pro/schedule')),
                  _QuickAction('⭐', 'Avis',      () => context.push('/pro/reviews')),
                  _QuickAction('🛵', 'Livreurs',  () => context.push('/pro/favorite-drivers')),
                  _QuickAction('🎟️', 'Promos',    () => context.push('/pro/promo')),
                  _QuickAction('🤝', 'Parrainage',() => context.push('/pro/referral')),
                  _QuickAction('👤', 'Profil',    () => context.go('/pro/profile')),
                ],
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }
}

// ── Body : KPIs + chart + top produits ─────────────────────────────────────
class _DashboardBody extends StatelessWidget {
  final Map<String, dynamic> data;
  const _DashboardBody({required this.data});

  @override
  Widget build(BuildContext context) {
    final revenue = (data['revenue'] as Map?) ?? {};
    final orders  = (data['orders']  as Map?) ?? {};
    final today   = (revenue['today'] as num?)?.toDouble() ?? 0;
    final week    = (revenue['week']  as num?)?.toDouble() ?? 0;
    final month   = (revenue['month'] as num?)?.toDouble() ?? 0;
    final pending = (orders['pending'] as num?)?.toInt() ?? 0;
    final total   = (orders['total']   as num?)?.toInt() ?? 0;
    final rating  = (data['avgRating'] as num?)?.toDouble() ?? 0;
    final reviewCount = (data['reviewCount'] as num?)?.toInt() ?? 0;
    final revenueByDay  = (data['revenueByDay']  as List?) ?? const [];
    final topProducts   = (data['topProducts']   as List?) ?? const [];
    final recentReviews = (data['recentReviews'] as List?) ?? const [];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text("Aujourd'hui", style: TextStyle(fontFamily: 'Nunito',
            fontSize: 16, fontWeight: FontWeight.w800, color: context.textPrimary)),
        const SizedBox(height: 12),

        // 4 KPI cards en 2x2
        Row(children: [
          Expanded(child: _KpiCard(
            emoji: '💰',
            label: 'Revenus du jour',
            value: '${today.toStringAsFixed(0)} F',
            sub: 'Mois : ${_shortAmount(month)} F',
            color: AppColors.success,
          )),
          const SizedBox(width: 10),
          Expanded(child: _KpiCard(
            emoji: '🛎️',
            label: 'À traiter',
            value: '$pending',
            sub: pending > 0 ? 'Voir les commandes' : 'Tout est à jour',
            color: pending > 0 ? AppColors.accent : context.textSecondary,
          )),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _KpiCard(
            emoji: '📦',
            label: 'Commandes livrées',
            value: '$total',
            sub: 'Semaine : ${week.toStringAsFixed(0)} F',
            color: AppColors.info,
          )),
          const SizedBox(width: 10),
          Expanded(child: _KpiCard(
            emoji: '⭐',
            label: 'Note moyenne',
            value: rating > 0 ? rating.toStringAsFixed(1) : '—',
            sub: reviewCount > 0 ? '$reviewCount avis' : 'Pas encore d\'avis',
            color: AppColors.warning,
          )),
        ]),

        const SizedBox(height: 24),

        // LineChart 7 derniers jours
        Text('Revenus — 7 derniers jours',
          style: TextStyle(fontFamily: 'Nunito', fontSize: 16, fontWeight: FontWeight.w800, color: context.textPrimary)),
        const SizedBox(height: 12),
        _RevenueChart(revenueByDay: revenueByDay.cast<Map>().toList()),

        const SizedBox(height: 24),

        // Top produits
        Text('Top produits',
          style: TextStyle(fontFamily: 'Nunito', fontSize: 16, fontWeight: FontWeight.w800, color: context.textPrimary)),
        const SizedBox(height: 12),
        if (topProducts.isEmpty)
          Builder(builder: (ctx) => Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: ctx.cardColor,
                borderRadius: BorderRadius.circular(14), border: Border.all(color: ctx.borderColor)),
            child: Row(children: [
              Icon(Icons.bar_chart_rounded, color: ctx.textSecondary, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text('Pas encore de produit vendu',
                style: TextStyle(fontFamily: 'Nunito', fontSize: 13, color: ctx.textSecondary))),
            ]),
          ))
        else
          ...topProducts.cast<Map<String, dynamic>>().map((t) => _TopProductRow(entry: t)),

        // ── Avis récents ──────────────────────────────────────────────────
        if (recentReviews.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Avis récents',
            style: TextStyle(fontFamily: 'Nunito', fontSize: 16, fontWeight: FontWeight.w800, color: context.textPrimary)),
          const SizedBox(height: 12),
          ...recentReviews.cast<Map<String, dynamic>>().map((r) => _ReviewRow(review: r)),
        ],
      ]),
    );
  }
}

// ── KPI card colorée ─────────────────────────────────────────────────────────
class _KpiCard extends StatelessWidget {
  final String emoji, label, value, sub;
  final Color color;
  const _KpiCard({
    required this.emoji, required this.label, required this.value,
    required this.sub, required this.color,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: context.cardColor,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: context.borderColor),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const Spacer(),
        Flexible(child: Text(label,
          textAlign: TextAlign.end, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(fontFamily: 'Nunito', fontSize: 11,
              fontWeight: FontWeight.w600, color: context.textSecondary))),
      ]),
      const SizedBox(height: 12),
      Text(value, style: TextStyle(fontFamily: 'Nunito', fontSize: 20,
          fontWeight: FontWeight.w900, color: color)),
      const SizedBox(height: 2),
      Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis,
        style: TextStyle(fontFamily: 'Nunito', fontSize: 11, color: context.textSecondary)),
    ]),
  );
}

// ── Revenue chart (fl_chart) ─────────────────────────────────────────────────
class _RevenueChart extends StatelessWidget {
  /// Format : [{date:'YYYY-MM-DD', revenue:12500, orders:3}, ...×7] oldest→newest.
  final List<Map> revenueByDay;
  const _RevenueChart({required this.revenueByDay});

  @override
  Widget build(BuildContext context) {
    if (revenueByDay.isEmpty) {
      return Container(
        height: 180,
        decoration: BoxDecoration(color: context.cardColor,
            borderRadius: BorderRadius.circular(14), border: Border.all(color: context.borderColor)),
        alignment: Alignment.center,
        child: Text('Aucune donnée',
          style: TextStyle(fontFamily: 'Nunito', fontSize: 13, color: context.textSecondary)),
      );
    }

    // Construction des spots + min/max pour le scaling.
    final spots = <FlSpot>[];
    double maxY = 0;
    for (var i = 0; i < revenueByDay.length; i++) {
      final r = (revenueByDay[i]['revenue'] as num?)?.toDouble() ?? 0;
      if (r > maxY) maxY = r;
      spots.add(FlSpot(i.toDouble(), r));
    }
    // Si tout est à 0 → forcer une plage non-nulle pour éviter l'axe écrasé.
    if (maxY == 0) maxY = 1;

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      height: 200,
      decoration: BoxDecoration(color: context.cardColor,
          borderRadius: BorderRadius.circular(14), border: Border.all(color: context.borderColor)),
      child: LineChart(LineChartData(
        minY: 0, maxY: maxY * 1.2, // 20% headroom au-dessus du max
        gridData: FlGridData(
          show: true, drawVerticalLine: false,
          horizontalInterval: maxY / 4,
          getDrawingHorizontalLine: (_) => FlLine(
            color: context.borderColor, strokeWidth: 0.5, dashArray: [4, 4],
          ),
        ),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 38,
            interval: maxY / 2,
            getTitlesWidget: (v, _) => Text(
              _shortAmount(v),
              style: TextStyle(fontFamily: 'Nunito', fontSize: 10, color: context.textSecondary),
            ),
          )),
          bottomTitles: AxisTitles(sideTitles: SideTitles(
            showTitles: true, interval: 1,
            getTitlesWidget: (v, _) {
              final i = v.toInt();
              if (i < 0 || i >= revenueByDay.length) return const SizedBox.shrink();
              final date = revenueByDay[i]['date'] as String? ?? '';
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(_dayLabel(date),
                  style: TextStyle(fontFamily: 'Nunito', fontSize: 10, color: context.textSecondary)),
              );
            },
          )),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => context.bgColor,
            tooltipBorder: const BorderSide(color: AppColors.primary),
            getTooltipItems: (touched) => touched.map((t) {
              final i = t.x.toInt();
              final date = (i >= 0 && i < revenueByDay.length)
                  ? (revenueByDay[i]['date'] as String? ?? '')
                  : '';
              return LineTooltipItem(
                '${t.y.toStringAsFixed(0)} F\n',
                const TextStyle(fontFamily: 'Nunito', fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primary),
                children: [TextSpan(text: _dayLabel(date),
                  style: TextStyle(fontFamily: 'Nunito', fontSize: 10, fontWeight: FontWeight.w500, color: context.textSecondary))],
              );
            }).toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: AppColors.primary,
            barWidth: 3,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                radius: 3.5, color: AppColors.primary,
                strokeWidth: 1.5, strokeColor: context.bgColor,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withOpacity(0.30),
                  AppColors.primary.withOpacity(0.00),
                ],
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      )),
    );
  }


}

// ── Ligne top produit ───────────────────────────────────────────────────────
class _TopProductRow extends StatelessWidget {
  /// Format : `{productId, quantitySold, product: {...}|null}`
  final Map<String, dynamic> entry;
  const _TopProductRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final qty = (entry['quantitySold'] as num?)?.toInt() ?? 0;
    final productJson = entry['product'] as Map<String, dynamic>?;
    if (productJson == null) {
      // Produit supprimé — on garde l'entrée mais sans détails
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: context.cardColor,
            borderRadius: BorderRadius.circular(12), border: Border.all(color: context.borderColor)),
        child: Row(children: [
          Icon(Icons.delete_outline_rounded, color: context.textMuted, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text('Produit supprimé',
            style: TextStyle(fontFamily: 'Nunito', fontSize: 13, color: context.textMuted))),
          Text('× $qty', style: TextStyle(fontFamily: 'Nunito', fontSize: 13, color: context.textSecondary)),
        ]),
      );
    }
    final product = Product.fromJson(productJson);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: context.cardColor,
          borderRadius: BorderRadius.circular(12), border: Border.all(color: context.borderColor)),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 44, height: 44,
            child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: product.imageUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(color: context.bgColor),
                    errorWidget: (_, __, ___) => Container(
                      color: context.bgColor,
                      child: Icon(Icons.fastfood_rounded, color: context.textMuted, size: 18),
                    ),
                  )
                : Container(
                    color: context.bgColor,
                    child: Icon(Icons.fastfood_rounded, color: context.textMuted, size: 18),
                  ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(product.localizedName('fr'),
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontFamily: 'Nunito', fontSize: 14, fontWeight: FontWeight.w800, color: context.textPrimary)),
          const SizedBox(height: 2),
          Text(product.formattedPrice,
            style: const TextStyle(fontFamily: 'Nunito', fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
        ])),
        // Badge quantité vendue
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.success.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.trending_up_rounded, size: 14, color: AppColors.success),
            const SizedBox(width: 4),
            Text('$qty',
              style: const TextStyle(fontFamily: 'Nunito', fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.success)),
          ]),
        ),
      ]),
    );
  }
}

// ── Ligne avis récent ────────────────────────────────────────────────────────
class _ReviewRow extends StatelessWidget {
  final Map<String, dynamic> review;
  const _ReviewRow({required this.review});

  @override
  Widget build(BuildContext context) {
    final rating   = (review['professionalRating'] as num?)?.toInt() ?? 0;
    final comment  = review['comment']  as String?;
    final reviewer = review['reviewer'] as Map<String, dynamic>?;
    final name     = (reviewer?['name'] ?? reviewer?['firstName'] ?? 'Client') as String;
    final createdAt = DateTime.tryParse(review['createdAt'] as String? ?? '');
    final dateStr = createdAt != null
        ? '${createdAt.day.toString().padLeft(2,'0')}/${createdAt.month.toString().padLeft(2,'0')}'
        : '';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          // Étoiles
          Row(children: List.generate(5, (i) => Icon(
            i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
            size: 14,
            color: AppColors.warning,
          ))),
          const SizedBox(width: 8),
          Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontFamily: 'Nunito', fontSize: 13,
                fontWeight: FontWeight.w700, color: context.textPrimary))),
          if (dateStr.isNotEmpty)
            Text(dateStr, style: TextStyle(fontFamily: 'Nunito', fontSize: 11,
                color: context.textMuted)),
        ]),
        if (comment != null && comment.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(comment, maxLines: 2, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontFamily: 'Nunito', fontSize: 12,
                color: context.textSecondary, height: 1.4)),
        ],
      ]),
    );
  }
}

// ── Quick action grid ───────────────────────────────────────────────────────
class _QuickAction extends StatelessWidget {
  final String emoji, label;
  final VoidCallback onTap;
  const _QuickAction(this.emoji, this.label, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      decoration: BoxDecoration(color: context.cardColor,
          borderRadius: BorderRadius.circular(14), border: Border.all(color: context.borderColor)),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 6),
        Text(label, style: TextStyle(fontFamily: 'Nunito', fontSize: 11,
            fontWeight: FontWeight.w700, color: context.textSecondary)),
      ]),
    ),
  );
}

// ── Bell icon avec badge non-lus → /pro/notifications ──────────────────────
class _NotifBell extends StatelessWidget {
  final int unread;
  const _NotifBell({required this.unread});
  @override
  Widget build(BuildContext context) => Stack(clipBehavior: Clip.none, children: [
    Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => GoRouter.of(context).push('/pro/notifications'),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(
            unread > 0 ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
            color: unread > 0 ? AppColors.accent : context.textSecondary,
            size: 26,
          ),
        ),
      ),
    ),
    if (unread > 0) Positioned(
      right: 2, top: 2,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        constraints: const BoxConstraints(minWidth: 18, minHeight: 16),
        decoration: BoxDecoration(
          color: AppColors.danger,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: context.bgColor, width: 1.5),
        ),
        alignment: Alignment.center,
        child: Text(
          unread > 99 ? '99+' : '$unread',
          style: const TextStyle(
            fontFamily: 'Nunito', fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white,
          ),
        ),
      ),
    ),
  ]);
}

// ── Shimmer placeholder (loading state) ─────────────────────────────────────
class _DashboardShimmer extends StatelessWidget {
  const _DashboardShimmer();
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 120, height: 18, decoration: BoxDecoration(
          color: context.cardColor, borderRadius: BorderRadius.circular(8))),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _shimmerBox(context, 90)),
        const SizedBox(width: 10),
        Expanded(child: _shimmerBox(context, 90)),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _shimmerBox(context, 90)),
        const SizedBox(width: 10),
        Expanded(child: _shimmerBox(context, 90)),
      ]),
      const SizedBox(height: 24),
      _shimmerBox(context, 200),
    ]),
  );

  Widget _shimmerBox(BuildContext context, double h) => Container(height: h, decoration: BoxDecoration(
      color: context.cardColor, borderRadius: BorderRadius.circular(14)));
}

// ── Error block (avec bouton réessayer) ─────────────────────────────────────
class _ErrorBlock extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorBlock({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: context.cardColor,
          borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.danger.withOpacity(0.5))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.cloud_off_rounded, color: AppColors.danger, size: 20),
          const SizedBox(width: 10),
          Text('Impossible de charger les statistiques',
            style: TextStyle(fontFamily: 'Nunito', fontSize: 14, fontWeight: FontWeight.w800, color: context.textPrimary)),
        ]),
        const SizedBox(height: 8),
        Text(message.replaceAll('Exception: ', ''),
          style: TextStyle(fontFamily: 'Nunito', fontSize: 12, color: context.textSecondary)),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text('Réessayer'),
        ),
      ]),
    ),
  );
}

// ── Helpers top-level ────────────────────────────────────────────────────────
String _shortAmount(double v) {
  if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
  if (v >= 1000)    return '${(v / 1000).toStringAsFixed(v >= 10000 ? 0 : 1)}k';
  return v.toStringAsFixed(0);
}

/// Convertit 'YYYY-MM-DD' en libellé court ('Lu', 'Ma', 'Me', …).
String _dayLabel(String date) {
  try {
    final d = DateTime.parse(date);
    const labels = ['Di', 'Lu', 'Ma', 'Me', 'Je', 'Ve', 'Sa'];
    return labels[d.weekday % 7];
  } catch (_) {
    return '';
  }
}

