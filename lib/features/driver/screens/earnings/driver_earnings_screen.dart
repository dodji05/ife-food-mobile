// ─────────────────────────────────────────────────────────────────────────────
// ifè FOOD — Driver Earnings Screen
// Solde disponible · Commissions · Pourboires · Demande de virement
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_colors.dart';
import '../../providers/driver_provider.dart';

class DriverEarningsScreen extends ConsumerStatefulWidget {
  const DriverEarningsScreen({super.key});
  @override ConsumerState<DriverEarningsScreen> createState() => _State();
}

class _State extends ConsumerState<DriverEarningsScreen> {
  @override
  Widget build(BuildContext context) {
    final stats    = ref.watch(driverDashboardProvider);
    final earnings = ref.watch(earningsProvider);

    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: AppColors.darkSurface,
        elevation: 0,
        title: Text('Mes gains',
          style: TextStyle(fontFamily: 'Nunito', fontSize: 17,
              fontWeight: FontWeight.w800, color: context.textPrimary)),
      ),
      body: stats.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(e.toString(), textAlign: TextAlign.center,
            style: TextStyle(color: context.textSecondary, fontFamily: 'Nunito')),
        )),
        data: (data) => RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            ref.invalidate(driverDashboardProvider);
            ref.invalidate(earningsProvider);
            await ref.read(driverDashboardProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [

              // ── Hero : solde disponible ───────────────────────────────────
              _BalanceHero(data: data),
              const SizedBox(height: 14),

              // ── Breakdown gains ───────────────────────────────────────────
              _EarningsBreakdown(data: data),
              const SizedBox(height: 14),

              // ── Stats activité ────────────────────────────────────────────
              Row(children: [
                Expanded(child: _StatTile('📦',
                    '${data['todayDeliveries'] ?? 0}', "Livraisons\naujourd'hui")),
                const SizedBox(width: 10),
                Expanded(child: _StatTile('⭐',
                    '${(data['avgRating'] ?? 0.0).toStringAsFixed(1)}', 'Note\nmoyenne')),
                const SizedBox(width: 10),
                Expanded(child: _StatTile('🏆',
                    '${data['allDeliveries'] ?? 0}', 'Total\nlivraisons')),
              ]),
              const SizedBox(height: 14),

              // ── Demande de virement ───────────────────────────────────────
              _WithdrawalCard(
                availableBalance: (data['availableBalance'] as num?)?.toDouble() ?? 0,
                pendingPayouts:   (data['pendingPayouts']   as num?)?.toDouble() ?? 0,
                onRequest: () => _showWithdrawalModal(context, data),
              ),
              const SizedBox(height: 24),

              // ── Historique transactions ───────────────────────────────────
              Text('Historique',
                style: TextStyle(fontFamily: 'Nunito', fontSize: 16,
                    fontWeight: FontWeight.w800, color: context.textPrimary)),
              const SizedBox(height: 12),

              earnings.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CircularProgressIndicator(
                      color: AppColors.primary)),
                ),
                error: (_, __) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text('Impossible de charger les transactions',
                    style: TextStyle(fontFamily: 'Nunito',
                        color: context.textSecondary)),
                ),
                data: (list) => list.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: Text(
                        'Aucune transaction pour l\'instant',
                        style: TextStyle(fontFamily: 'Nunito',
                            color: context.textMuted))),
                    )
                  : Column(children: list.map((tx) =>
                        _TxRow(tx: tx)).toList()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showWithdrawalModal(BuildContext context, Map<String, dynamic> data) {
    final available = (data['availableBalance'] as num?)?.toDouble() ?? 0;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _WithdrawalModal(
        availableBalance: available,
        onSuccess: () {
          ref.invalidate(driverDashboardProvider);
          ref.invalidate(earningsProvider);
        },
      ),
    );
  }
}

// ── Hero solde disponible ──────────────────────────────────────────────────────
class _BalanceHero extends StatelessWidget {
  final Map<String, dynamic> data;
  const _BalanceHero({required this.data});

  @override
  Widget build(BuildContext context) {
    final balance  = (data['availableBalance'] as num?)?.toDouble() ?? 0;
    final pending  = (data['pendingPayouts']   as num?)?.toDouble() ?? 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF0D3320), context.cardColor],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.account_balance_wallet_rounded,
                color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 10),
          Text('Solde disponible',
            style: TextStyle(fontFamily: 'Nunito', fontSize: 13,
                color: context.textSecondary, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 10),
        Text('${balance.toStringAsFixed(0)} F CFA',
          style: const TextStyle(fontFamily: 'Nunito', fontSize: 38,
              fontWeight: FontWeight.w900, color: AppColors.primary)),
        if (pending > 0) ...[
          const SizedBox(height: 6),
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6)),
              child: Text(
                '${pending.toStringAsFixed(0)} F en attente',
                style: const TextStyle(fontFamily: 'Nunito', fontSize: 11,
                    fontWeight: FontWeight.w700, color: AppColors.accent)),
            ),
          ]),
        ],
        const SizedBox(height: 16),
        // Chips périodes (livraisons seulement, sans tips)
        Row(children: [
          _PeriodChip("Auj.", '${(data['todayEarnings']  ?? 0).toStringAsFixed(0)} F'),
          const SizedBox(width: 8),
          _PeriodChip('Sem.', '${(data['weekEarnings']   ?? 0).toStringAsFixed(0)} F'),
          const SizedBox(width: 8),
          _PeriodChip('Mois', '${(data['monthEarnings']  ?? 0).toStringAsFixed(0)} F'),
        ]),
      ]),
    );
  }
}

class _PeriodChip extends StatelessWidget {
  final String label, value;
  const _PeriodChip(this.label, this.value);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.black.withOpacity(0.2),
      borderRadius: BorderRadius.circular(10)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontFamily: 'Nunito', fontSize: 10,
          color: context.textSecondary)),
      Text(value, style: TextStyle(fontFamily: 'Nunito', fontSize: 13,
          fontWeight: FontWeight.w800, color: context.textPrimary)),
    ]),
  );
}

// ── Breakdown gains nets + pourboires ────────────────────────────────────────
class _EarningsBreakdown extends StatelessWidget {
  final Map<String, dynamic> data;
  const _EarningsBreakdown({required this.data});

  @override
  Widget build(BuildContext context) {
    final netEarnings   = (data['totalEarnings']                as num?)?.toDouble() ?? 0;
    final commDeducted  = (data['totalDriverCommissionDeducted'] as num?)?.toDouble() ?? 0;
    final tips          = (data['totalTips']                    as num?)?.toDouble() ?? 0;
    final hasTips       = tips > 0;

    // Sous-titre : nombre de livraisons + commission déduite si applicable
    final deliverySub = commDeducted > 0
      ? '${data['allDeliveries'] ?? 0} livr. · comm −${commDeducted.toStringAsFixed(0)} F'
      : '${data['allDeliveries'] ?? 0} livraisons';

    return Row(children: [
      Expanded(child: _BreakdownTile(
        icon:  Icons.delivery_dining_rounded,
        color: AppColors.info,
        label: 'Gains livraison',
        value: '${netEarnings.toStringAsFixed(0)} F',
        sub:   deliverySub,
      )),
      if (hasTips) ...[
        const SizedBox(width: 10),
        Expanded(child: _BreakdownTile(
          icon:  Icons.volunteer_activism_rounded,
          color: AppColors.yellow,
          label: 'Pourboires',
          value: '${tips.toStringAsFixed(0)} F',
          sub:   'Total reçu',
        )),
      ],
    ]);
  }
}

class _BreakdownTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label, value, sub;
  const _BreakdownTile({
    required this.icon, required this.color,
    required this.label, required this.value, required this.sub,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: context.cardColor,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: context.borderColor)),
    child: Row(children: [
      Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 18),
      ),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontFamily: 'Nunito', fontSize: 11,
            color: context.textSecondary, fontWeight: FontWeight.w600)),
        Text(value, style: TextStyle(fontFamily: 'Nunito', fontSize: 15,
            fontWeight: FontWeight.w900, color: context.textPrimary)),
        Text(sub, style: TextStyle(fontFamily: 'Nunito', fontSize: 10,
            color: context.textMuted)),
      ])),
    ]),
  );
}

// ── Carte virement ────────────────────────────────────────────────────────────
class _WithdrawalCard extends StatelessWidget {
  final double availableBalance;
  final double pendingPayouts;
  final VoidCallback onRequest;
  const _WithdrawalCard({
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
            ? 'Solde disponible : ${availableBalance.toStringAsFixed(0)} F CFA'
            : 'Aucun solde disponible pour le moment.',
          style: TextStyle(fontFamily: 'Nunito', fontSize: 13,
              color: context.textSecondary, height: 1.4)),
        if (pendingPayouts > 0) ...[
          const SizedBox(height: 6),
          Text(
            '${pendingPayouts.toStringAsFixed(0)} F en cours de traitement.',
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
            disabledBackgroundColor: AppColors.darkBorder,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(
                fontFamily: 'Nunito', fontWeight: FontWeight.w800)),
        ),
      ]),
    );
  }
}

// ── Ligne de transaction ──────────────────────────────────────────────────────
class _TxRow extends StatelessWidget {
  final Map<String, dynamic> tx;
  const _TxRow({required this.tx});

  @override
  Widget build(BuildContext context) {
    final type      = tx['type']?.toString() ?? 'DELIVERY_FEE';
    final amount    = (tx['amount'] as num?)?.toDouble() ?? 0;
    final status    = tx['status']?.toString() ?? 'COMPLETED';
    final createdAt = DateTime.tryParse(
        tx['createdAt']?.toString() ?? '')?.toLocal() ?? DateTime.now();

    final isWithdrawal = type == 'WITHDRAWAL';
    final isPending    = status == 'PENDING';

    final (emoji, label, color) = switch (type) {
      'TIP'        => ('🎁', 'Pourboire',       AppColors.yellow),
      'WITHDRAWAL' => ('💸', 'Virement demandé', AppColors.accent),
      _            => ('📦', 'Commission',       AppColors.success),
    };

    final amountText = isWithdrawal
        ? '− ${amount.toStringAsFixed(0)} F'
        : '+ ${amount.toStringAsFixed(0)} F';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.borderColor)),
      child: Row(children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontFamily: 'Nunito', fontSize: 14,
              fontWeight: FontWeight.w600, color: context.textPrimary)),
          Text(
            '${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.year}'
            ' · ${createdAt.hour.toString().padLeft(2, '0')}h${createdAt.minute.toString().padLeft(2, '0')}',
            style: TextStyle(fontFamily: 'Nunito', fontSize: 11,
                color: context.textMuted)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(amountText, style: TextStyle(fontFamily: 'Nunito', fontSize: 14,
              fontWeight: FontWeight.w800, color: color)),
          if (isPending)
            Container(
              margin: const EdgeInsets.only(top: 3),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4)),
              child: const Text('En attente',
                style: TextStyle(fontFamily: 'Nunito', fontSize: 9,
                    fontWeight: FontWeight.w700, color: AppColors.accent)),
            ),
        ]),
      ]),
    );
  }
}

// ── StatTile ──────────────────────────────────────────────────────────────────
class _StatTile extends StatelessWidget {
  final String emoji, value, label;
  const _StatTile(this.emoji, this.value, this.label);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 14),
    decoration: BoxDecoration(
      color: context.cardColor,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: context.borderColor)),
    child: Column(children: [
      Text(emoji, style: const TextStyle(fontSize: 22)),
      const SizedBox(height: 6),
      Text(value, style: const TextStyle(fontFamily: 'Nunito', fontSize: 18,
          fontWeight: FontWeight.w900, color: AppColors.primary)),
      const SizedBox(height: 2),
      Text(label, textAlign: TextAlign.center,
        style: TextStyle(fontFamily: 'Nunito', fontSize: 10,
            color: context.textSecondary, height: 1.3)),
    ]),
  );
}

// ── Modal demande de virement ──────────────────────────────────────────────────
class _WithdrawalModal extends ConsumerStatefulWidget {
  final double availableBalance;
  final VoidCallback onSuccess;
  const _WithdrawalModal({
    required this.availableBalance,
    required this.onSuccess,
  });
  @override ConsumerState<_WithdrawalModal> createState() => _WithdrawalModalState();
}

class _WithdrawalModalState extends ConsumerState<_WithdrawalModal> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  String? _error;

  double get _enteredAmount =>
      double.tryParse(_ctrl.text.trim().replaceAll(' ', '')) ?? 0;

  bool get _isValid =>
      _enteredAmount > 0 && _enteredAmount <= widget.availableBalance;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = _enteredAmount;
    if (!_isValid) return;
    setState(() { _loading = true; _error = null; });
    try {
      await ApiClient.instance.post('/drivers/me/withdrawal',
          data: {'amount': amount});
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
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.darkSurface,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24), topRight: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4,
            decoration: BoxDecoration(
              color: context.borderColor,
              borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),

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
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Demander un virement',
                style: TextStyle(fontFamily: 'Nunito', fontSize: 17,
                    fontWeight: FontWeight.w900, color: context.textPrimary)),
              Text('Solde disponible : ${available.toStringAsFixed(0)} F CFA',
                style: TextStyle(fontFamily: 'Nunito', fontSize: 12,
                    color: context.textSecondary)),
            ]),
          ]),
          const SizedBox(height: 24),

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
                    color: overflow ? AppColors.danger : AppColors.primary,
                    width: 2)),
            ),
          ),

          // Erreur dépassement solde
          AnimatedSize(
            duration: const Duration(milliseconds: 150),
            child: overflow || _error != null
              ? Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(children: [
                    Icon(Icons.info_rounded,
                        color: AppColors.danger, size: 14),
                    const SizedBox(width: 6),
                    Expanded(child: Text(
                      overflow
                        ? 'Montant supérieur au solde disponible '
                          '(${available.toStringAsFixed(0)} F)'
                        : _error!,
                      style: const TextStyle(fontFamily: 'Nunito',
                          fontSize: 12, color: AppColors.danger,
                          fontWeight: FontWeight.w600),
                    )),
                  ]),
                )
              : const SizedBox.shrink(),
          ),

          // Raccourcis rapides
          const SizedBox(height: 14),
          Row(children: [
            _QuickAmount('25 %', available * 0.25, _ctrl, setState),
            const SizedBox(width: 8),
            _QuickAmount('50 %', available * 0.50, _ctrl, setState),
            const SizedBox(width: 8),
            _QuickAmount('100 %', available,        _ctrl, setState),
          ]),

          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: (_isValid && !_loading) ? _submit : null,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              textStyle: const TextStyle(
                  fontFamily: 'Nunito', fontWeight: FontWeight.w900,
                  fontSize: 15)),
            child: _loading
              ? const SizedBox(width: 22, height: 22,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : const Text('Confirmer le virement'),
          ),
        ]),
      ),
    );
  }
}

class _QuickAmount extends StatelessWidget {
  final String label;
  final double amount;
  final TextEditingController ctrl;
  final void Function(VoidCallback) setStateCallback;
  const _QuickAmount(this.label, this.amount, this.ctrl,
      this.setStateCallback);

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: () => setStateCallback(() =>
          ctrl.text = amount.toStringAsFixed(0)),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: AppColors.primary.withOpacity(0.2))),
        child: Center(child: Text(label,
          style: const TextStyle(fontFamily: 'Nunito', fontSize: 13,
              fontWeight: FontWeight.w800, color: AppColors.primary))),
      ),
    ),
  );
}
