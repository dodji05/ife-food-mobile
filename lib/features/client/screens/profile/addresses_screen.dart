// ─────────────────────────────────────────────────────────────────────────────
// ifè FOOD — Client / Mes adresses
//
// Liste les adresses sauvegardées du client. Actions :
//   • FAB '+' -> push /addresses/new (form mode create)
//   • Tap carte -> push /addresses/edit/:id (form mode edit)
//   • PopupMenu : 'Définir par défaut' (si pas déjà) + 'Modifier' + 'Supprimer'
//   • Pull-to-refresh
//   • Empty state explicite avec CTA "Ajouter ma 1ère adresse"
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/user_address.dart';
import '../../providers/addresses_provider.dart';

class AddressesScreen extends ConsumerWidget {
  const AddressesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(addressesProvider);

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(title: const Text('Mes adresses')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/addresses/new'),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_location_alt_rounded, color: Colors.white),
        label: const Text('Ajouter',
          style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800, color: Colors.white)),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => _ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(addressesProvider),
        ),
        data: (list) {
          if (list.isEmpty) return const _EmptyState();
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async => ref.invalidate(addressesProvider),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _AddressCard(address: list[i]),
            ),
          );
        },
      ),
    );
  }
}

// ── Carte adresse avec actions ──────────────────────────────────────────────
class _AddressCard extends ConsumerWidget {
  final UserAddress address;
  const _AddressCard({required this.address});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => context.push('/addresses/edit/${address.id}', extra: address.toJson()),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: address.isDefault
                ? AppColors.primary.withOpacity(0.45)
                : Colors.grey.shade200,
            width: address.isDefault ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Icône + emoji label
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(address.labelEmoji, style: const TextStyle(fontSize: 22)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(
                address.label,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'Nunito', fontSize: 15,
                    fontWeight: FontWeight.w900, color: AppColors.nearBlack),
              )),
              if (address.isDefault) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('Par défaut',
                    style: TextStyle(fontFamily: 'Nunito', fontSize: 10,
                        fontWeight: FontWeight.w800, color: Colors.white)),
                ),
              ],
            ]),
            const SizedBox(height: 4),
            Text(
              '${address.address}, ${address.city}',
              maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: 'Nunito', fontSize: 13,
                  color: AppColors.lightSubtext, height: 1.3),
            ),
            if (address.instructions != null && address.instructions!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.note_outlined, size: 12, color: AppColors.lightSubtext),
                const SizedBox(width: 4),
                Expanded(child: Text(
                  address.instructions!,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Nunito', fontSize: 11,
                      color: AppColors.lightSubtext, fontStyle: FontStyle.italic),
                )),
              ]),
            ],
          ])),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: AppColors.lightSubtext, size: 20),
            onSelected: (v) => _handleAction(context, ref, v),
            itemBuilder: (_) => [
              if (!address.isDefault)
                const PopupMenuItem(
                  value: 'default',
                  child: Row(children: [
                    Icon(Icons.star_rounded, size: 16, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text('Définir par défaut'),
                  ]),
                ),
              const PopupMenuItem(
                value: 'edit',
                child: Row(children: [
                  Icon(Icons.edit_rounded, size: 16),
                  SizedBox(width: 8),
                  Text('Modifier'),
                ]),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(children: [
                  Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.danger),
                  SizedBox(width: 8),
                  Text('Supprimer', style: TextStyle(color: AppColors.danger)),
                ]),
              ),
            ],
          ),
        ]),
      ),
    );
  }

  Future<void> _handleAction(BuildContext context, WidgetRef ref, String action) async {
    switch (action) {
      case 'default': return _setDefault(context, ref);
      case 'edit':    context.push('/addresses/edit/${address.id}', extra: address.toJson()); break;
      case 'delete':  return _confirmDelete(context, ref);
    }
  }

  Future<void> _setDefault(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(addressesNotifierProvider).setDefault(address.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('"${address.label}" est maintenant votre adresse par défaut'),
        backgroundColor: AppColors.success,
      ));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceAll('Exception: ', '')),
        backgroundColor: AppColors.danger,
      ));
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Supprimer "${address.label}" ?'),
        content: Text(
          address.isDefault
              ? 'C\'est votre adresse par défaut. La suivante sera automatiquement '
                'promue par défaut si vous avez d\'autres adresses.'
              : 'Cette action est irréversible.',
          style: const TextStyle(fontFamily: 'Nunito', fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer',
              style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(addressesNotifierProvider).delete(address.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Adresse supprimée'),
        backgroundColor: AppColors.success,
      ));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceAll('Exception: ', '')),
        backgroundColor: AppColors.danger,
      ));
    }
  }
}

// ── States ─────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.location_off_rounded, size: 64, color: AppColors.lightSubtext),
        const SizedBox(height: 16),
        const Text('Aucune adresse sauvegardée',
          style: TextStyle(fontFamily: 'Nunito', fontSize: 16,
              fontWeight: FontWeight.w800, color: AppColors.nearBlack)),
        const SizedBox(height: 6),
        const Text(
          'Ajoutez une adresse pour passer commande plus rapidement.',
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Nunito', fontSize: 13,
              color: AppColors.lightSubtext, height: 1.5),
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: () => GoRouter.of(context).push('/addresses/new'),
          icon: const Icon(Icons.add_location_alt_rounded),
          label: const Text('Ajouter ma 1ère adresse'),
        ),
      ]),
    ),
  );
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.cloud_off_rounded, size: 56, color: AppColors.danger),
        const SizedBox(height: 12),
        Text(message.replaceAll('Exception: ', ''),
          textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: 'Nunito', fontSize: 12, color: AppColors.lightSubtext)),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Réessayer'),
        ),
      ]),
    ),
  );
}
