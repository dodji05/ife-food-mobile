// ─────────────────────────────────────────────────────────────────────────────
// ifè FOOD — Client / Bottom sheet sélection d'adresse au checkout
//
// Usage :
//   final picked = await showAddressSelector(context);
//   if (picked != null) { /* utiliser picked.address, picked.city, etc. */ }
//
// Affiche la liste des adresses du user + un bouton "Ajouter une nouvelle
// adresse" (redirige vers /addresses/new sans bloquer le checkout — au
// retour le user re-tape sur le bouton sélection).
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_colors.dart';
import '../../../shared/models/user_address.dart';
import '../providers/addresses_provider.dart';

/// Affiche un bottom sheet de sélection. Retourne l'adresse choisie ou null.
Future<UserAddress?> showAddressSelector(BuildContext context) {
  final container = ProviderScope.containerOf(context);
  return showModalBottomSheet<UserAddress>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => UncontrolledProviderScope(
      container: container,
      child: const _Sheet(),
    ),
  );
}

class _Sheet extends ConsumerWidget {
  const _Sheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(addressesProvider);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle drag
        Container(
          width: 40, height: 4,
          decoration: BoxDecoration(
            color: context.borderColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: Text(
            'Choisir l\'adresse de livraison',
            style: TextStyle(fontFamily: 'Nunito', fontSize: 16,
                fontWeight: FontWeight.w900, color: context.textPrimary),
          )),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded),
            iconSize: 22,
          ),
        ]),
        const SizedBox(height: 8),
        Flexible(child: async.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              const Icon(Icons.cloud_off_rounded, color: AppColors.danger, size: 40),
              const SizedBox(height: 8),
              Text(e.toString().replaceAll('Exception: ', ''),
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Nunito', fontSize: 12, color: context.textSecondary)),
            ]),
          ),
          data: (list) => list.isEmpty
              ? _EmptyInline(onAdd: () {
                  Navigator.pop(context);
                  context.push('/addresses/new');
                })
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _AddressOption(
                    address: list[i],
                    onTap: () => Navigator.pop(context, list[i]),
                  ),
                ),
        )),
        const SizedBox(height: 12),
        // CTA ajouter une nouvelle adresse (toujours visible)
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              context.push('/addresses/new');
            },
            icon: const Icon(Icons.add_location_alt_rounded, size: 18),
            label: const Text('Ajouter une nouvelle adresse'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ]),
    );
  }
}

class _AddressOption extends StatelessWidget {
  final UserAddress address;
  final VoidCallback onTap;
  const _AddressOption({required this.address, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: address.isDefault
              ? AppColors.primary.withOpacity(0.4)
              : context.borderColor,
        ),
      ),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(address.labelEmoji, style: const TextStyle(fontSize: 20)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(address.label,
              style: TextStyle(fontFamily: 'Nunito', fontSize: 14,
                  fontWeight: FontWeight.w800, color: context.textPrimary)),
            if (address.isDefault) ...[
              const SizedBox(width: 6),
              const Icon(Icons.star_rounded, color: AppColors.primary, size: 14),
            ],
          ]),
          const SizedBox(height: 2),
          Text('${address.address}, ${address.city}',
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontFamily: 'Nunito', fontSize: 12, color: context.textSecondary)),
        ])),
        Icon(Icons.chevron_right_rounded, color: context.textSecondary),
      ]),
    ),
  );
}

class _EmptyInline extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyInline({required this.onAdd});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(children: [
      Icon(Icons.location_off_rounded, size: 48, color: context.textSecondary),
      const SizedBox(height: 12),
      Text('Aucune adresse sauvegardée',
        style: TextStyle(fontFamily: 'Nunito', fontSize: 14,
            fontWeight: FontWeight.w700, color: context.textPrimary)),
      const SizedBox(height: 4),
      Text('Ajoutez votre 1ère adresse pour passer commande.',
        textAlign: TextAlign.center,
        style: TextStyle(fontFamily: 'Nunito', fontSize: 12, color: context.textSecondary)),
    ]),
  );
}
