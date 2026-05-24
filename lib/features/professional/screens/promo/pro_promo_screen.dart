// ─────────────────────────────────────────────────────────────────────────────
// ifè FOOD — Codes promo (vue pro)
//
// Liste les codes promo du professionnel, permet d'en créer, modifier
// (toggle actif/inactif) et supprimer.
// Endpoint backend : GET/POST/PATCH/DELETE /professionals/me/promo-codes
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../providers/pro_provider.dart';

class ProPromoScreen extends ConsumerWidget {
  const ProPromoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncPromos = ref.watch(promoCodesProvider);
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(title: const Text('Codes promo')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateSheet(context, ref),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Nouveau code',
          style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800, color: Colors.white)),
      ),
      body: asyncPromos.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => _ErrorState(message: e.toString(), onRetry: () => ref.invalidate(promoCodesProvider)),
        data: (promos) {
          if (promos.isEmpty) return _EmptyState(onAdd: () => _showCreateSheet(context, ref));
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async => ref.invalidate(promoCodesProvider),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: promos.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _PromoCard(
                promo: promos[i],
                onToggle: () async {
                  await ref.read(proProvider.notifier)
                      .updatePromoCode(promos[i].id, {'isActive': !promos[i].isActive});
                  ref.invalidate(promoCodesProvider);
                },
                onEdit: () => _showEditSheet(context, ref, promos[i]),
                onDelete: () => _confirmDelete(context, ref, promos[i]),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Fiche création ─────────────────────────────────────────────────────────
  void _showCreateSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.darkCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _PromoFormSheet(
        onSave: (data) async {
          await ref.read(proProvider.notifier).createPromoCode(data);
          ref.invalidate(promoCodesProvider);
        },
      ),
    );
  }

  // ── Fiche édition ──────────────────────────────────────────────────────────
  void _showEditSheet(BuildContext context, WidgetRef ref, PromoCode promo) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.darkCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _PromoFormSheet(
        promo: promo,
        onSave: (data) async {
          await ref.read(proProvider.notifier).updatePromoCode(promo.id, data);
          ref.invalidate(promoCodesProvider);
        },
      ),
    );
  }

  // ── Suppression avec confirmation ─────────────────────────────────────────
  void _confirmDelete(BuildContext context, WidgetRef ref, PromoCode promo) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.darkCard,
        title: const Text('Supprimer ce code ?',
          style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w900,
              color: AppColors.darkText, fontSize: 16)),
        content: Text(
          'Le code "${promo.code}" sera définitivement supprimé.',
          style: const TextStyle(fontFamily: 'Nunito', fontSize: 14, color: AppColors.darkSubtext)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler', style: TextStyle(color: AppColors.darkSubtext)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(proProvider.notifier).deletePromoCode(promo.id);
              ref.invalidate(promoCodesProvider);
            },
            child: const Text('Supprimer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ── Carte code promo ──────────────────────────────────────────────────────────
class _PromoCard extends StatelessWidget {
  final PromoCode promo;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _PromoCard({
    required this.promo, required this.onToggle,
    required this.onEdit, required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy', 'fr');
    return Container(
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: promo.isActive ? AppColors.primary.withOpacity(0.4) : AppColors.darkBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── En-tête code + badge actif ────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 0),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(promo.code,
                style: const TextStyle(
                  fontFamily: 'Nunito', fontSize: 15, fontWeight: FontWeight.w900,
                  color: AppColors.primary, letterSpacing: 1.5)),
            ),
            const SizedBox(width: 10),
            _StatusBadge(promo.isActive),
            const Spacer(),
            // Toggle rapide actif/inactif
            Switch(
              value: promo.isActive,
              onChanged: (_) => onToggle(),
              activeColor: AppColors.primary,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ]),
        ),
        // ── Détails remise + usage ─────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Wrap(spacing: 12, runSpacing: 6, children: [
            _Chip(Icons.discount_outlined, 'Remise : ${promo.discountLabel}'),
            _Chip(Icons.repeat_rounded,
              'Utilisé : ${promo.usesCount}${promo.maxUses != null ? "/${promo.maxUses}" : ""}'),
            if (promo.minOrderAmount != null)
              _Chip(Icons.shopping_bag_outlined,
                'Min : ${promo.minOrderAmount!.toStringAsFixed(0)} F'),
            if (promo.expiresAt != null)
              _Chip(Icons.calendar_month_outlined,
                'Expire le ${fmt.format(promo.expiresAt!)}',
                danger: promo.expiresAt!.isBefore(DateTime.now())),
          ]),
        ),
        // ── Actions ────────────────────────────────────────────────────────
        OverflowBar(
          alignment: MainAxisAlignment.end,
          children: [
            TextButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Modifier'),
              style: TextButton.styleFrom(foregroundColor: AppColors.darkSubtext),
            ),
            TextButton.icon(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded, size: 16),
              label: const Text('Supprimer'),
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            ),
          ],
        ),
      ]),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool active;
  const _StatusBadge(this.active);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: (active ? AppColors.success : AppColors.darkMuted).withOpacity(0.18),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(active ? 'Actif' : 'Inactif',
      style: TextStyle(
        fontFamily: 'Nunito', fontSize: 11, fontWeight: FontWeight.w700,
        color: active ? AppColors.success : AppColors.darkMuted)),
  );
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool danger;
  const _Chip(this.icon, this.label, {this.danger = false});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 13, color: danger ? AppColors.danger : AppColors.darkSubtext),
    const SizedBox(width: 4),
    Text(label, style: TextStyle(
      fontFamily: 'Nunito', fontSize: 12, fontWeight: FontWeight.w600,
      color: danger ? AppColors.danger : AppColors.darkSubtext)),
  ]);
}

// ── Formulaire création / édition ─────────────────────────────────────────────
class _PromoFormSheet extends StatefulWidget {
  final PromoCode? promo;
  final Future<void> Function(Map<String, dynamic>) onSave;
  const _PromoFormSheet({this.promo, required this.onSave});
  @override
  State<_PromoFormSheet> createState() => _PromoFormSheetState();
}

class _PromoFormSheetState extends State<_PromoFormSheet> {
  late final _code      = TextEditingController(text: widget.promo?.code ?? '');
  late final _value     = TextEditingController(
      text: widget.promo != null ? widget.promo!.discountValue.toStringAsFixed(0) : '');
  late final _min       = TextEditingController(
      text: widget.promo?.minOrderAmount?.toStringAsFixed(0) ?? '');
  late final _maxUses   = TextEditingController(
      text: widget.promo?.maxUses?.toString() ?? '');
  late String _type     = widget.promo?.discountType ?? 'PERCENTAGE';
  late bool   _active   = widget.promo?.isActive ?? true;
  late DateTime? _expires = widget.promo?.expiresAt;
  bool _loading = false;

  bool get _isEdit => widget.promo != null;

  @override
  void dispose() {
    _code.dispose(); _value.dispose();
    _min.dispose();  _maxUses.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final code = _code.text.trim().toUpperCase();
    final val  = double.tryParse(_value.text.trim());
    if (code.isEmpty || val == null) return;
    setState(() => _loading = true);
    try {
      final data = <String, dynamic>{
        'code':          code,
        'discountType':  _type,
        'discountValue': val,
        'isActive':      _active,
        if (_min.text.trim().isNotEmpty)
          'minOrderAmount': double.tryParse(_min.text.trim()),
        if (_maxUses.text.trim().isNotEmpty)
          'maxUses': int.tryParse(_maxUses.text.trim()),
        if (_expires != null)
          'expiresAt': _expires!.toIso8601String(),
      };
      await widget.onSave(data);
      if (mounted) Navigator.pop(context);
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
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottom),
      child: SingleChildScrollView(child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_isEdit ? 'Modifier le code' : 'Nouveau code promo',
            style: const TextStyle(fontFamily: 'Nunito', fontSize: 18,
                fontWeight: FontWeight.w900, color: AppColors.darkText)),
          const SizedBox(height: 20),

          _FL('Code promo *'),
          const SizedBox(height: 6),
          TextField(
            controller: _code,
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(
              fontFamily: 'Nunito', fontSize: 16, fontWeight: FontWeight.w800,
              letterSpacing: 1.5, color: AppColors.primary),
            decoration: const InputDecoration(hintText: 'Ex: PROMO20'),
          ),
          const SizedBox(height: 16),

          _FL('Type de remise'),
          const SizedBox(height: 8),
          Row(children: [
            _TypeChip('Pourcentage (%)', 'PERCENTAGE', _type, (v) => setState(() => _type = v)),
            const SizedBox(width: 10),
            _TypeChip('Montant fixe (F)', 'FIXED_AMOUNT', _type, (v) => setState(() => _type = v)),
          ]),
          const SizedBox(height: 16),

          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _FL('Valeur *'),
              const SizedBox(height: 6),
              TextField(
                controller: _value,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontFamily: 'Nunito', fontSize: 15, color: AppColors.darkText),
                decoration: InputDecoration(
                  hintText: _type == 'PERCENTAGE' ? '20' : '1000',
                  suffixText: _type == 'PERCENTAGE' ? '%' : 'F',
                ),
              ),
            ])),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _FL('Montant min (optionnel)'),
              const SizedBox(height: 6),
              TextField(
                controller: _min,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontFamily: 'Nunito', fontSize: 15, color: AppColors.darkText),
                decoration: const InputDecoration(hintText: '2000', suffixText: 'F'),
              ),
            ])),
          ]),
          const SizedBox(height: 16),

          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _FL('Nb. utilisations max'),
              const SizedBox(height: 6),
              TextField(
                controller: _maxUses,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontFamily: 'Nunito', fontSize: 15, color: AppColors.darkText),
                decoration: const InputDecoration(hintText: '∞'),
              ),
            ])),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _FL('Date d\'expiration'),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.darkCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.darkBorder),
                  ),
                  child: Row(children: [
                    const Icon(Icons.calendar_month_outlined,
                      size: 16, color: AppColors.darkSubtext),
                    const SizedBox(width: 8),
                    Text(
                      _expires != null
                          ? DateFormat('dd/MM/yy', 'fr').format(_expires!)
                          : 'Aucune',
                      style: TextStyle(
                        fontFamily: 'Nunito', fontSize: 13,
                        color: _expires != null ? AppColors.darkText : AppColors.darkSubtext),
                    ),
                  ]),
                ),
              ),
            ])),
          ]),
          const SizedBox(height: 16),

          // Toggle actif / inactif
          Row(children: [
            const Expanded(child: Text('Activer immédiatement',
              style: TextStyle(fontFamily: 'Nunito', fontSize: 14,
                  fontWeight: FontWeight.w700, color: AppColors.darkText))),
            Switch(
              value: _active,
              onChanged: (v) => setState(() => _active = v),
              activeColor: AppColors.primary,
            ),
          ]),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: AppColors.primary.withOpacity(0.35),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _loading
                  ? const SizedBox(width: 22, height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : Text(_isEdit ? 'Enregistrer' : 'Créer le code',
                      style: const TextStyle(fontFamily: 'Nunito', fontSize: 15,
                          fontWeight: FontWeight.w800, color: Colors.white)),
            ),
          ),
        ],
      )),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expires ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _expires = picked);
  }

  Widget _FL(String t) => Text(t,
    style: const TextStyle(fontFamily: 'Nunito', fontSize: 12,
        fontWeight: FontWeight.w700, color: AppColors.darkSubtext, letterSpacing: 0.3));
}

class _TypeChip extends StatelessWidget {
  final String label;
  final String value;
  final String selected;
  final ValueChanged<String> onTap;
  const _TypeChip(this.label, this.value, this.selected, this.onTap);
  @override
  Widget build(BuildContext context) {
    final active = value == selected;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : AppColors.darkCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? AppColors.primary : AppColors.darkBorder),
        ),
        child: Text(label,
          style: TextStyle(
            fontFamily: 'Nunito', fontSize: 12, fontWeight: FontWeight.w700,
            color: active ? Colors.white : AppColors.darkSubtext)),
      ),
    );
  }
}

// ── États vide / erreur ───────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});
  @override
  Widget build(BuildContext context) => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const Icon(Icons.discount_outlined, size: 56, color: AppColors.darkMuted),
      const SizedBox(height: 16),
      const Text('Aucun code promo',
        style: TextStyle(fontFamily: 'Nunito', fontSize: 16,
            fontWeight: FontWeight.w700, color: AppColors.darkText)),
      const SizedBox(height: 6),
      const Text('Créez votre premier code pour fidéliser vos clients',
        textAlign: TextAlign.center,
        style: TextStyle(fontFamily: 'Nunito', fontSize: 13, color: AppColors.darkSubtext)),
      const SizedBox(height: 20),
      ElevatedButton.icon(
        onPressed: onAdd,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Nouveau code',
          style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800, color: Colors.white)),
        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
      ),
    ],
  ));
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.danger),
      const SizedBox(height: 12),
      Text(message,
        textAlign: TextAlign.center,
        style: const TextStyle(fontFamily: 'Nunito', fontSize: 13, color: AppColors.darkSubtext)),
      const SizedBox(height: 16),
      ElevatedButton(onPressed: onRetry,
        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
        child: const Text('Réessayer',
          style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700, color: Colors.white))),
    ],
  ));
}
