// ─────────────────────────────────────────────────────────────────────────────
// ifè FOOD — Écran pourboire post-livraison (client)
//
// Accessible via /order/:id/tip — uniquement si order.status == DELIVERED
// et order.tipAmount == 0.
//
// Appelle POST /orders/:id/tip { amount } puis invalide orderDetailProvider.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_colors.dart';
import 'order_detail_screen.dart' show orderDetailProvider;

const _presets = [200, 500, 1000, 2000];

class TipScreen extends ConsumerStatefulWidget {
  final String orderId;
  const TipScreen({super.key, required this.orderId});

  @override
  ConsumerState<TipScreen> createState() => _TipScreenState();
}

class _TipScreenState extends ConsumerState<TipScreen> {
  int? _selected;                        // montant preset sélectionné
  final _customCtrl = TextEditingController();
  bool _useCustom = false;
  bool _loading = false;

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  int? get _effectiveAmount {
    if (_useCustom) {
      final v = int.tryParse(_customCtrl.text.trim());
      return (v != null && v > 0) ? v : null;
    }
    return _selected;
  }

  Future<void> _submit() async {
    final amount = _effectiveAmount;
    if (amount == null) return;

    setState(() => _loading = true);
    try {
      await ApiClient.instance.post('/orders/${widget.orderId}/tip', data: {'amount': amount});
      ref.invalidate(orderDetailProvider(widget.orderId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Merci pour votre pourboire ! 🙏'),
          backgroundColor: AppColors.success,
        ));
        context.go('/order/${widget.orderId}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _skip() => context.go('/order/${widget.orderId}');

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(orderDetailProvider(widget.orderId));

    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        title: const Text('Laisser un pourboire'),
        leading: BackButton(onPressed: _skip),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header — nom du livreur si disponible
              orderAsync.maybeWhen(
                data: (order) => _DriverHeader(
                  name: order.driverName ?? 'votre livreur',
                  avatarUrl: order.driverAvatarUrl,
                ),
                orElse: () => const _DriverHeader(name: 'votre livreur'),
              ),
              const SizedBox(height: 32),

              Text('Montant du pourboire',
                style: TextStyle(fontFamily: 'Nunito', fontSize: 14,
                    fontWeight: FontWeight.w800, color: context.textPrimary)),
              const SizedBox(height: 12),

              // Grille des montants prédéfinis
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 2.4,
                children: _presets.map((amount) {
                  final selected = !_useCustom && _selected == amount;
                  return GestureDetector(
                    onTap: () => setState(() {
                      _selected = amount;
                      _useCustom = false;
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.primary : context.cardColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selected ? AppColors.primary : context.borderColor,
                          width: selected ? 2 : 1,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text('$amount F',
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: selected ? Colors.white : context.textPrimary,
                        )),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Autre montant
              GestureDetector(
                onTap: () => setState(() {
                  _useCustom = true;
                  _selected = null;
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: context.cardColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _useCustom ? AppColors.primary : context.borderColor,
                      width: _useCustom ? 2 : 1,
                    ),
                  ),
                  child: Row(children: [
                    Icon(Icons.edit_rounded, size: 18, color: context.textMuted),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _customCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        onTap: () => setState(() {
                          _useCustom = true;
                          _selected = null;
                        }),
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          hintText: 'Autre montant (F CFA)',
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        style: const TextStyle(fontFamily: 'Nunito', fontSize: 15,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ]),
                ),
              ),

              const Spacer(),

              // CTA
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_loading || _effectiveAmount == null) ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _loading
                    ? const SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(
                        _effectiveAmount != null
                            ? 'Envoyer $_effectiveAmount F à votre livreur'
                            : 'Sélectionner un montant',
                        style: const TextStyle(fontFamily: 'Nunito',
                            fontSize: 15, fontWeight: FontWeight.w800),
                      ),
                ),
              ),
              const SizedBox(height: 12),

              // Passer
              Center(
                child: TextButton(
                  onPressed: _skip,
                  child: Text('Passer pour l\'instant',
                    style: TextStyle(fontFamily: 'Nunito', fontSize: 14,
                        color: context.textMuted, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DriverHeader extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  const _DriverHeader({required this.name, this.avatarUrl});

  @override
  Widget build(BuildContext context) => Row(children: [
    CircleAvatar(
      radius: 30,
      backgroundColor: AppColors.primary.withOpacity(0.15),
      backgroundImage: (avatarUrl != null && avatarUrl!.isNotEmpty)
          ? NetworkImage(avatarUrl!) : null,
      child: (avatarUrl == null || avatarUrl!.isEmpty)
          ? const Text('🛵', style: TextStyle(fontSize: 26)) : null,
    ),
    const SizedBox(width: 16),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Votre commande est livrée ! 🎉',
        style: TextStyle(fontFamily: 'Nunito', fontSize: 15,
            fontWeight: FontWeight.w800, color: context.textPrimary)),
      const SizedBox(height: 4),
      Text('Souhaitez-vous laisser un pourboire à $name ?',
        style: TextStyle(fontFamily: 'Nunito', fontSize: 13,
            color: context.textMuted)),
    ])),
  ]);
}
