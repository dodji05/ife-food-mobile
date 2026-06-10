import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_colors.dart';
import '../../providers/pro_provider.dart';

class ProEarningsScreen extends ConsumerStatefulWidget {
  const ProEarningsScreen({super.key});
  @override
  ConsumerState<ProEarningsScreen> createState() => _State();
}

class _State extends ConsumerState<ProEarningsScreen> {
  int _period = 30; // 7 | 30 | 90

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(earningsProvider(_period));
    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(title: const Text('Revenus')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error:   (e, _) => Center(child: Text(e.toString(), style: const TextStyle(fontFamily: 'Nunito', color: AppColors.danger))),
        data:    (d) => _Body(
          data: d,
          period: _period,
          onPeriod: (p) => setState(() => _period = p),
          onWithdraw: () => _showWithdrawalModal(context, d),
        ),
      ),
    );
  }

  void _showWithdrawalModal(BuildContext context, EarningsData data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProWithdrawalModal(
        availableBalance: data.availableBalance,
        pendingPayouts:   data.pendingPayouts,
        onSuccess: () => ref.invalidate(earningsProvider(_period)),
      ),
    );
  }
}

// ── Corps principal ───────────────────────────────────────────────────────────
class _Body extends StatelessWidget {
  final EarningsData data;
  final int period;
  final ValueChanged<int> onPeriod;
  final VoidCallback onWithdraw;
  const _Body({required this.data, required this.period, required this.onPeriod, required this.onWithdraw});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Hero : revenus nets du mois ──────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(0xFF0A2A14), context.cardColor],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withOpacity(0.3)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Revenus nets — 30 derniers jours',
              style: TextStyle(fontFamily: 'Nunito', fontSize: 12, color: context.textSecondary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text('${_fmt(data.month.net)} F',
              style: const TextStyle(fontFamily: 'Nunito', fontSize: 36, fontWeight: FontWeight.w900, color: AppColors.primary)),
            const SizedBox(height: 16),
            Row(children: [
              _HeroChip("Aujourd'hui", '${_fmt(data.today.net)} F'),
              const SizedBox(width: 10),
              _HeroChip('Cette semaine', '${_fmt(data.week.net)} F'),
            ]),
          ]),
        ),
        const SizedBox(height: 20),

        // ── Sélecteur de période ─────────────────────────────────────────────
        Row(children: [
          for (final p in [7, 30, 90])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _PeriodChip(label: '${p}J', selected: period == p, onTap: () => onPeriod(p)),
            ),
          const Spacer(),
          Text('${data.periodOrders} cmd',
            style: TextStyle(fontFamily: 'Nunito', fontSize: 12, color: context.textSecondary, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 14),

        // ── Graphique ────────────────────────────────────────────────────────
        _RevenueChart(days: data.revenueByDay),
        const SizedBox(height: 20),

        // ── Breakdown financier ──────────────────────────────────────────────
        Builder(builder: (ctx) => Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: ctx.cardColor, borderRadius: BorderRadius.circular(14), border: Border.all(color: ctx.borderColor)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('DÉTAIL FINANCIER', style: TextStyle(fontFamily: 'Nunito', fontSize: 11, fontWeight: FontWeight.w800, color: ctx.textSecondary, letterSpacing: 0.6)),
            const SizedBox(height: 12),
            _BreakRow('Sous-total brut', '${_fmt(data.periodGross)} F', color: context.textPrimary),
            _BreakRow(
              data.commissionRate > 0
                ? 'Commission plateforme (${data.commissionRate.toStringAsFixed(0)}%)'
                : 'Commission plateforme (paliers RPO)',
              '-${_fmt(data.periodCommission)} F',
              color: AppColors.danger,
            ),
            Divider(color: ctx.borderColor, height: 20),
            _BreakRow('Vos revenus nets', '${_fmt(data.periodNet)} F', color: AppColors.primary, bold: true),
          ]),
        )),
        const SizedBox(height: 20),

        // ── Virement ──────────────────────────────────────────────────────────
        _ProWithdrawalCard(
          availableBalance: data.availableBalance,
          pendingPayouts:   data.pendingPayouts,
          onRequest:        onWithdraw,
        ),
        const SizedBox(height: 20),

        // ── Dernières transactions ────────────────────────────────────────────
        if (data.recentOrders.isNotEmpty) ...[
          Builder(builder: (ctx) => Text('TRANSACTIONS RÉCENTES', style: TextStyle(fontFamily: 'Nunito', fontSize: 11, fontWeight: FontWeight.w800, color: ctx.textSecondary, letterSpacing: 0.6))),
          const SizedBox(height: 10),
          ...data.recentOrders.map((o) => _TransactionRow(order: o)),
        ],
        const SizedBox(height: 40),
      ],
    );
  }
}

// ── Graphique revenus nets ────────────────────────────────────────────────────
class _RevenueChart extends StatelessWidget {
  final List<EarningsDayEntry> days;
  const _RevenueChart({required this.days});

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty || days.every((d) => d.net == 0)) {
      return Container(
        height: 160,
        decoration: BoxDecoration(color: context.cardColor, borderRadius: BorderRadius.circular(14), border: Border.all(color: context.borderColor)),
        alignment: Alignment.center,
        child: Text('Aucune donnée pour cette période',
          style: TextStyle(fontFamily: 'Nunito', fontSize: 13, color: context.textSecondary)),
      );
    }

    double maxY = 0;
    final spots = <FlSpot>[];
    for (var i = 0; i < days.length; i++) {
      if (days[i].net > maxY) maxY = days[i].net;
      spots.add(FlSpot(i.toDouble(), days[i].net));
    }
    if (maxY == 0) maxY = 1;

    // N'affiche un label de jour que tous les N points pour éviter le chevauchement
    final step = days.length <= 7 ? 1 : days.length <= 30 ? 7 : 15;

    return Container(
      height: 190,
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      decoration: BoxDecoration(color: context.cardColor, borderRadius: BorderRadius.circular(14), border: Border.all(color: context.borderColor)),
      child: LineChart(LineChartData(
        minY: 0, maxY: maxY * 1.2,
        gridData: FlGridData(
          show: true, drawVerticalLine: false,
          horizontalInterval: maxY / 4,
          getDrawingHorizontalLine: (_) => FlLine(color: context.borderColor, strokeWidth: 0.5, dashArray: [4, 4]),
        ),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(sideTitles: SideTitles(
            showTitles: true, reservedSize: 42,
            interval: maxY / 2,
            getTitlesWidget: (v, _) => Text(_short(v),
              style: TextStyle(fontFamily: 'Nunito', fontSize: 10, color: context.textSecondary)),
          )),
          bottomTitles: AxisTitles(sideTitles: SideTitles(
            showTitles: true, interval: step.toDouble(),
            getTitlesWidget: (v, _) {
              final i = v.toInt();
              if (i < 0 || i >= days.length || i % step != 0) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(_dayLabel(days[i].date),
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
              return LineTooltipItem(
                '${_fmt(t.y)} F nets\n',
                const TextStyle(fontFamily: 'Nunito', fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primary),
                children: [TextSpan(
                  text: i >= 0 && i < days.length ? days[i].date.substring(5) : '',
                  style: TextStyle(fontFamily: 'Nunito', fontSize: 10, color: context.textSecondary),
                )],
              );
            }).toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots, isCurved: true, curveSmoothness: 0.3,
            color: AppColors.primary, barWidth: 2.5,
            dotData: FlDotData(
              show: days.length <= 15,
              getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                radius: 3, color: AppColors.primary, strokeWidth: 1.5, strokeColor: context.bgColor),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [AppColors.primary.withOpacity(0.28), AppColors.primary.withOpacity(0.0)],
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      )),
    );
  }
}

// ── Ligne transaction ─────────────────────────────────────────────────────────
class _TransactionRow extends StatelessWidget {
  final EarningsOrderEntry order;
  const _TransactionRow({required this.order});

  @override
  Widget build(BuildContext context) {
    final dt = order.createdAt;
    final label = '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')} ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: context.cardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: context.borderColor)),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), shape: BoxShape.circle),
          child: const Icon(Icons.receipt_long_rounded, size: 18, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontFamily: 'Nunito', fontSize: 13, fontWeight: FontWeight.w700, color: context.textPrimary)),
          Text('${order.itemCount} article${order.itemCount > 1 ? 's' : ''}  ·  brut ${_fmt(order.subtotal)} F',
            style: TextStyle(fontFamily: 'Nunito', fontSize: 11, color: context.textSecondary)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${_fmt(order.netRevenue)} F',
            style: const TextStyle(fontFamily: 'Nunito', fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.primary)),
          Text('-${_fmt(order.commissionAmount)} F comm.',
            style: const TextStyle(fontFamily: 'Nunito', fontSize: 10, color: AppColors.danger)),
        ]),
      ]),
    );
  }
}

// ── Widgets simples ───────────────────────────────────────────────────────────
class _HeroChip extends StatelessWidget {
  final String label, value;
  const _HeroChip(this.label, this.value);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(color: Colors.black.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontFamily: 'Nunito', fontSize: 11, color: context.textSecondary)),
      Text(value,  style: TextStyle(fontFamily: 'Nunito', fontSize: 13, fontWeight: FontWeight.w800, color: context.textPrimary)),
    ]),
  );
}

class _PeriodChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _PeriodChip({required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color:  selected ? AppColors.primary : context.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: selected ? AppColors.primary : context.borderColor),
      ),
      child: Text(label, style: TextStyle(fontFamily: 'Nunito', fontSize: 13, fontWeight: FontWeight.w800,
        color: selected ? Colors.white : context.textSecondary)),
    ),
  );
}

class _BreakRow extends StatelessWidget {
  final String label, value;
  final Color color;
  final bool bold;
  const _BreakRow(this.label, this.value, {required this.color, this.bold = false});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      Expanded(child: Text(label, style: TextStyle(fontFamily: 'Nunito', fontSize: 13,
        fontWeight: bold ? FontWeight.w800 : FontWeight.w500, color: context.textSecondary))),
      Text(value, style: TextStyle(fontFamily: 'Nunito', fontSize: bold ? 16 : 13,
        fontWeight: bold ? FontWeight.w900 : FontWeight.w700, color: color)),
    ]),
  );
}

// ── Carte virement ────────────────────────────────────────────────────────────
class _ProWithdrawalCard extends StatelessWidget {
  final double availableBalance;
  final double pendingPayouts;
  final VoidCallback onRequest;
  const _ProWithdrawalCard({
    required this.availableBalance,
    required this.pendingPayouts,
    required this.onRequest,
  });

  @override
  Widget build(BuildContext context) {
    final canWithdraw = availableBalance > 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.account_balance_rounded,
                color: AppColors.success, size: 18),
          ),
          const SizedBox(width: 10),
          Text('Virement',
            style: TextStyle(fontFamily: 'Nunito', fontSize: 15,
                fontWeight: FontWeight.w800, color: context.textPrimary)),
        ]),
        const SizedBox(height: 10),
        Text(
          canWithdraw
            ? 'Solde disponible : ${_fmt(availableBalance)} F CFA'
            : 'Aucun solde disponible pour le moment.',
          style: TextStyle(fontFamily: 'Nunito', fontSize: 13,
              color: context.textSecondary, height: 1.4)),
        if (pendingPayouts > 0) ...[
          const SizedBox(height: 6),
          Text(
            '${_fmt(pendingPayouts)} F en cours de traitement.',
            style: const TextStyle(fontFamily: 'Nunito', fontSize: 12,
                color: AppColors.accent, fontWeight: FontWeight.w600)),
        ],
        const SizedBox(height: 14),
        ElevatedButton.icon(
          onPressed: canWithdraw ? onRequest : null,
          icon: const Icon(Icons.send_rounded, size: 16),
          label: const Text('Demander un virement'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            backgroundColor: AppColors.success,
            foregroundColor: Colors.white,
            disabledBackgroundColor: context.borderColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800)),
        ),
      ]),
    );
  }
}

// ── Modal demande de virement ──────────────────────────────────────────────────
class _ProWithdrawalModal extends ConsumerStatefulWidget {
  final double availableBalance;
  final double pendingPayouts;
  final VoidCallback onSuccess;
  const _ProWithdrawalModal({
    required this.availableBalance,
    required this.pendingPayouts,
    required this.onSuccess,
  });
  @override
  ConsumerState<_ProWithdrawalModal> createState() => _ProWithdrawalModalState();
}

class _ProWithdrawalModalState extends ConsumerState<_ProWithdrawalModal> {
  final _ctrl        = TextEditingController();
  final _paymentCtrl = TextEditingController();
  bool   _loading = false;
  String? _error;

  double get _enteredAmount =>
      double.tryParse(_ctrl.text.trim().replaceAll(' ', '')) ?? 0;

  bool get _isValid =>
      _enteredAmount > 0
      && _enteredAmount <= widget.availableBalance
      && _paymentCtrl.text.trim().isNotEmpty;

  @override
  void dispose() {
    _ctrl.dispose();
    _paymentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount      = _enteredAmount;
    final paymentInfo = _paymentCtrl.text.trim();
    if (!_isValid) return;
    setState(() { _loading = true; _error = null; });
    try {
      await ApiClient.instance.post('/professionals/me/withdrawal',
          data: {'amount': amount, 'paymentInfo': paymentInfo});
      widget.onSuccess();
      if (mounted) {
        Navigator.pop(context);
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Demande envoyée — traitement sous 24–48h.'),
          backgroundColor: AppColors.success,
        ));
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final available = widget.availableBalance;
    final overflow  = _enteredAmount > available && _enteredAmount > 0;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24), topRight: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4,
            decoration: BoxDecoration(
              color: context.borderColor,
              borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),

          // En-tête
          Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.account_balance_rounded,
                  color: AppColors.success, size: 22),
            ),
            const SizedBox(width: 12),
            // Expanded évite l'overflow si le solde est élevé
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Demander un virement',
                style: TextStyle(fontFamily: 'Nunito', fontSize: 17,
                    fontWeight: FontWeight.w900, color: context.textPrimary)),
              Text('Solde disponible : ${_fmt(available)} F CFA',
                style: TextStyle(fontFamily: 'Nunito', fontSize: 12,
                    color: context.textSecondary)),
            ])),
          ]),
          if (widget.pendingPayouts > 0) ...[
            const SizedBox(height: 8),
            Text('${_fmt(widget.pendingPayouts)} F en cours de traitement.',
              style: const TextStyle(fontFamily: 'Nunito', fontSize: 12,
                  color: AppColors.accent, fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 20),

          // Champ coordonnées de paiement
          TextField(
            controller: _paymentCtrl,
            keyboardType: TextInputType.text,
            onChanged: (_) => setState(() {}),
            style: TextStyle(fontFamily: 'Nunito', fontSize: 14,
                color: context.textPrimary),
            decoration: InputDecoration(
              hintText: 'Ex: MTN 0022966XXXXXX ou IBAN…',
              hintStyle: TextStyle(fontFamily: 'Nunito', fontSize: 13,
                  color: context.borderColor),
              labelText: 'Numéro Mobile Money / Coordonnées bancaires',
              labelStyle: TextStyle(fontFamily: 'Nunito', fontSize: 13,
                  color: context.textSecondary),
              prefixIcon: const Icon(Icons.phone_android_rounded,
                  color: AppColors.primary, size: 20),
              filled: true,
              fillColor: context.bgColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: context.borderColor)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: context.borderColor)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.primary, width: 2)),
            ),
          ),
          const SizedBox(height: 16),

          // Champ montant
          TextField(
            controller: _ctrl,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() => _error = null),
            style: TextStyle(fontFamily: 'Nunito', fontSize: 24,
                fontWeight: FontWeight.w900, color: context.textPrimary),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: '0',
              hintStyle: TextStyle(fontFamily: 'Nunito', fontSize: 24,
                  fontWeight: FontWeight.w900, color: context.borderColor),
              suffixText: 'F CFA',
              suffixStyle: TextStyle(fontFamily: 'Nunito', fontSize: 16,
                  color: context.textSecondary, fontWeight: FontWeight.w700),
              filled: true,
              fillColor: context.bgColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                    color: overflow ? AppColors.danger : context.borderColor)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                    color: overflow ? AppColors.danger : context.borderColor)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                    color: overflow ? AppColors.danger : AppColors.primary, width: 2)),
            ),
          ),

          // Erreur dépassement
          AnimatedSize(
            duration: const Duration(milliseconds: 150),
            child: overflow || _error != null
              ? Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(children: [
                    const Icon(Icons.info_rounded, color: AppColors.danger, size: 14),
                    const SizedBox(width: 6),
                    Expanded(child: Text(
                      overflow
                        ? 'Montant supérieur au solde disponible (${_fmt(available)} F)'
                        : _error!,
                      style: const TextStyle(fontFamily: 'Nunito', fontSize: 12,
                          color: AppColors.danger, fontWeight: FontWeight.w600),
                    )),
                  ]),
                )
              : const SizedBox.shrink(),
          ),

          // Raccourcis rapides
          const SizedBox(height: 14),
          Row(children: [
            _QuickChip('25 %', available * 0.25, _ctrl, setState),
            const SizedBox(width: 8),
            _QuickChip('50 %', available * 0.50, _ctrl, setState),
            const SizedBox(width: 8),
            _QuickChip('100 %', available, _ctrl, setState),
          ]),

          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: (_isValid && !_loading) ? _submit : null,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              textStyle: const TextStyle(fontFamily: 'Nunito',
                  fontWeight: FontWeight.w900, fontSize: 15)),
            child: _loading
              ? const SizedBox(width: 22, height: 22,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Confirmer le virement'),
          ),
        ]),
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  final String label;
  final double amount;
  final TextEditingController ctrl;
  final void Function(VoidCallback) setStateCallback;
  const _QuickChip(this.label, this.amount, this.ctrl, this.setStateCallback);

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: () => setStateCallback(() => ctrl.text = amount.toStringAsFixed(0)),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.primary.withOpacity(0.2))),
        child: Center(child: Text(label,
          style: const TextStyle(fontFamily: 'Nunito', fontSize: 13,
              fontWeight: FontWeight.w800, color: AppColors.primary))),
      ),
    ),
  );
}

// ── Helpers ───────────────────────────────────────────────────────────────────
String _fmt(double v) {
  if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
  if (v >= 1000)    return '${(v / 1000).toStringAsFixed(v >= 10000 ? 0 : 1)}k';
  return v.toStringAsFixed(0);
}

String _short(double v) {
  if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
  if (v >= 1000)    return '${(v / 1000).toStringAsFixed(0)}k';
  return v.toStringAsFixed(0);
}

String _dayLabel(String date) {
  try {
    final d = DateTime.parse(date);
    const labels = ['Di', 'Lu', 'Ma', 'Me', 'Je', 'Ve', 'Sa'];
    return labels[d.weekday % 7];
  } catch (_) {
    return '';
  }
}
