// ─────────────────────────────────────────────────────────────────────────────
// ifè FOOD — Livreurs favoris (pro)
//
// Deux sections :
//   • Livreurs privés   : isPrivate == true, exclusifs à cet établissement
//   • Autres favoris    : les livreurs favoris non-privés
//
// Actions par livreur :
//   • Appel direct (url_launcher tel:)
//   • Toggle privé/non-privé (PATCH .../mark-private)
//   • Retirer des favoris (DELETE)
//
// Ajout : FAB → bottom sheet de recherche par téléphone
//
// Pour réactiver l'ajout de livreur : passer _kAddDriverVisible à true
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_colors.dart';
import '../../providers/pro_provider.dart';

// Pour réactiver l'ajout de livreur favori : passer à true
// ignore: constant_identifier_names
const bool _kAddDriverVisible = false;

class FavoriteDriversScreen extends ConsumerStatefulWidget {
  const FavoriteDriversScreen({super.key});
  @override
  ConsumerState<FavoriteDriversScreen> createState() => _FavoriteDriversScreenState();
}

class _FavoriteDriversScreenState extends ConsumerState<FavoriteDriversScreen> {
  void _refresh() => ref.invalidate(favoriteDriversProvider);

  Future<void> _openAddSheet() => _showAddDriverSheet(context, ref);

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(favoriteDriversProvider);

    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        title: const Text('Livreurs favoris'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refresh,
          ),
        ],
      ),
      floatingActionButton: _kAddDriverVisible
          ? FloatingActionButton.extended(
              onPressed: _openAddSheet,
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.person_add_rounded, color: Colors.white),
              label: const Text('Ajouter',
                  style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800, color: Colors.white)),
            )
          : null,
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => _ErrorState(
          message: e.toString(),
          onRetry: _refresh,
        ),
        data: (list) {
          if (list.isEmpty) return _EmptyState(onAdd: _openAddSheet);
          final privateList = list.where((d) => d.isPrivate).toList();
          final publicList  = list.where((d) => !d.isPrivate).toList();
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async => _refresh(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                if (privateList.isNotEmpty) ...[
                  _SectionHeader(
                    icon: Icons.lock_rounded,
                    title: 'Livreurs privés',
                    subtitle: 'Exclusifs à votre établissement',
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 10),
                  ...privateList.map((d) => _DriverCard(driver: d)),
                  const SizedBox(height: 20),
                ],
                if (publicList.isNotEmpty) ...[
                  _SectionHeader(
                    icon: Icons.star_rounded,
                    title: 'Autres favoris',
                    subtitle: 'Livreurs que vous préférez',
                    color: AppColors.warning,
                  ),
                  const SizedBox(height: 10),
                  ...publicList.map((d) => _DriverCard(driver: d)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Recherche + ajout d'un livreur ───────────────────────────────────────────
Future<void> _showAddDriverSheet(BuildContext context, WidgetRef ref) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.cardColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    // Theme.dark force les InputDecoration, ElevatedButton, etc. à hériter
    // du thème sombre plutôt que du thème clair global de l'app.
    builder: (_) => Theme(
      data: AppTheme.dark,
      child: _AddDriverSheet(
        onSearch: (phone) => ref.read(proProvider.notifier).searchDriverByPhone(phone),
        onAdd:    (id)    => ref.read(proProvider.notifier).addFavoriteDriver(id),
      ),
    ),
  );
  ref.invalidate(favoriteDriversProvider);
}

class _AddDriverSheet extends StatefulWidget {
  final Future<FavoriteDriverEntry> Function(String phone) onSearch;
  final Future<void> Function(String driverId) onAdd;
  const _AddDriverSheet({required this.onSearch, required this.onAdd});
  @override
  State<_AddDriverSheet> createState() => _AddDriverSheetState();
}

class _AddDriverSheetState extends State<_AddDriverSheet> {
  final _phoneCtrl = TextEditingController();
  FavoriteDriverEntry? _found;
  bool _searching = false;
  bool _adding    = false;
  String? _error;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.length < 8) return;
    setState(() { _searching = true; _found = null; _error = null; });
    try {
      final driver = await widget.onSearch(phone);
      setState(() => _found = driver);
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _addToFavorites() async {
    if (_found == null) return;
    setState(() => _adding = true);
    try {
      await widget.onAdd(_found!.driverId);
      if (mounted) Navigator.pop(context);
      AppMessenger.show('Livreur ajouté aux favoris ✓');
    } catch (e) {
      AppMessenger.show(e.toString().replaceAll('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Handle
        Center(child: Container(width: 40, height: 4,
          decoration: BoxDecoration(color: context.borderColor, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 16),
        Text('Ajouter un livreur',
          style: TextStyle(fontFamily: 'Nunito', fontSize: 18, fontWeight: FontWeight.w900, color: context.textPrimary)),
        const SizedBox(height: 4),
        Text('Recherchez par numéro de téléphone',
          style: TextStyle(fontFamily: 'Nunito', fontSize: 13, color: context.textSecondary)),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: TextStyle(fontFamily: 'Nunito', fontSize: 16, color: context.textPrimary),
              decoration: InputDecoration(
                hintText: 'Ex: 22961234567',
                prefixIcon: Icon(Icons.phone_rounded, color: context.textSecondary, size: 20),
              ),
              onSubmitted: (_) => _search(),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _searching ? null : _search,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(horizontal: 18),
              ),
              child: _searching
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.search_rounded, color: Colors.white),
            ),
          ),
        ]),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.danger.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.danger.withOpacity(0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(_error!,
                style: const TextStyle(fontFamily: 'Nunito', fontSize: 13, color: AppColors.danger))),
            ]),

          ),
        ],
        if (_found != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
            ),
            child: Row(children: [
              _DriverAvatar(name: _found!.userName, url: _found!.avatarUrl, size: 44),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_found!.userName,
                  style: TextStyle(fontFamily: 'Nunito', fontSize: 15,
                      fontWeight: FontWeight.w800, color: context.textPrimary)),
                const SizedBox(height: 2),
                Text(_vehicleLabel(_found!.vehicleType),
                  style: TextStyle(fontFamily: 'Nunito', fontSize: 12, color: context.textSecondary)),
              ])),
              _StatusDot(_found!.isAvailable),
            ]),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: _found!.alreadyFavorite
                ? ElevatedButton.icon(
                    onPressed: null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.borderColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      disabledBackgroundColor: context.borderColor,
                    ),
                    icon: Icon(Icons.check_circle_rounded, color: context.textSecondary),
                    label: Text('Déjà dans vos favoris',
                      style: TextStyle(fontFamily: 'Nunito', fontSize: 15,
                          fontWeight: FontWeight.w800, color: context.textSecondary)),
                  )
                : ElevatedButton.icon(
                    onPressed: _adding ? null : _addToFavorites,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: _adding
                        ? const SizedBox(width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_rounded, color: Colors.white),
                    label: Text(_adding ? 'Ajout en cours…' : 'Ajouter aux favoris',
                      style: const TextStyle(fontFamily: 'Nunito', fontSize: 15,
                          fontWeight: FontWeight.w800, color: Colors.white)),
                  ),
          ),
        ],
        const SizedBox(height: 8),
      ]),
    );
  }
}

// ── Carte livreur ────────────────────────────────────────────────────────────
class _DriverCard extends ConsumerStatefulWidget {
  final FavoriteDriverEntry driver;
  const _DriverCard({required this.driver});
  @override
  ConsumerState<_DriverCard> createState() => _DriverCardState();
}

class _DriverCardState extends ConsumerState<_DriverCard> {
  bool _toggling  = false;
  bool _removing  = false;

  Future<void> _call() async {
    if (widget.driver.phone == null) return;
    final uri = Uri(scheme: 'tel', path: widget.driver.phone!);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _togglePrivate() async {
    setState(() => _toggling = true);
    try {
      await ref.read(proProvider.notifier).markDriverPrivate(
        widget.driver.driverId,
        isPrivate: !widget.driver.isPrivate,
      );
      ref.invalidate(favoriteDriversProvider);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceAll('Exception: ', '')),
        backgroundColor: AppColors.danger,
      ));
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  Future<void> _remove() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.cardColor,
        title: Text('Retirer ${widget.driver.userName} ?',
          style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800,
              color: context.textPrimary, fontSize: 16)),
        content: Text('Ce livreur sera retiré de vos favoris.',
          style: TextStyle(fontFamily: 'Nunito', color: context.textSecondary, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
            child: Text('Annuler', style: TextStyle(color: context.textSecondary))),
          TextButton(onPressed: () => Navigator.pop(context, true),
            child: const Text('Retirer', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w800))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _removing = true);
    try {
      await ref.read(proProvider.notifier).removeFavoriteDriver(widget.driver.driverId);
      ref.invalidate(favoriteDriversProvider);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceAll('Exception: ', '')),
        backgroundColor: AppColors.danger,
      ));
    } finally {
      if (mounted) setState(() => _removing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.driver;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: d.isPrivate ? AppColors.primary.withOpacity(0.4) : context.borderColor,
          width: d.isPrivate ? 1.5 : 1,
        ),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _DriverAvatar(name: d.userName, url: d.avatarUrl, size: 46),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(d.userName,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontFamily: 'Nunito', fontSize: 15,
                  fontWeight: FontWeight.w800, color: context.textPrimary))),
            _StatusDot(d.isAvailable),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            Icon(Icons.two_wheeler_rounded, size: 13, color: context.textSecondary),
            const SizedBox(width: 4),
            Text(_vehicleLabel(d.vehicleType),
              style: TextStyle(fontFamily: 'Nunito', fontSize: 12, color: context.textSecondary)),
            if (d.licensePlate != null && d.licensePlate!.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: context.bgColor,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: context.borderColor),
                ),
                child: Text(d.licensePlate!,
                  style: TextStyle(fontFamily: 'Nunito', fontSize: 11,
                      fontWeight: FontWeight.w700, color: context.textPrimary)),
              ),
            ],
          ]),
          const SizedBox(height: 8),
          // Actions inline : appel + toggle privé
          Row(children: [
            if (d.phone != null && d.phone!.isNotEmpty)
              _ActionChip(
                icon: Icons.call_rounded,
                label: 'Appeler',
                color: AppColors.success,
                onTap: _call,
              ),
            const SizedBox(width: 8),
            _ActionChip(
              icon: d.isPrivate ? Icons.lock_open_rounded : Icons.lock_rounded,
              label: d.isPrivate ? 'Rendre public' : 'Privé',
              color: d.isPrivate ? AppColors.warning : AppColors.primary,
              loading: _toggling,
              onTap: _togglePrivate,
            ),
          ]),
        ])),
        const SizedBox(width: 4),
        if (_removing)
          const SizedBox(width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.danger))
        else
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            icon: const Icon(Icons.remove_circle_outline_rounded, color: AppColors.danger, size: 20),
            tooltip: 'Retirer',
            onPressed: _remove,
          ),
      ]),
    );
  }
}

// ── Widgets helpers ──────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Color color;
  const _SectionHeader({required this.icon, required this.title, required this.subtitle, required this.color});
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(
      width: 32, height: 32,
      decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
      child: Icon(icon, size: 16, color: color),
    ),
    const SizedBox(width: 10),
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: TextStyle(fontFamily: 'Nunito', fontSize: 14,
          fontWeight: FontWeight.w900, color: color)),
      Text(subtitle, style: TextStyle(fontFamily: 'Nunito', fontSize: 11,
          color: context.textSecondary)),
    ]),
  ]);
}

class _StatusDot extends StatelessWidget {
  final bool online;
  const _StatusDot(this.online);
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(
      width: 8, height: 8,
      decoration: BoxDecoration(
        color: online ? AppColors.success : context.textMuted,
        shape: BoxShape.circle,
      ),
    ),
    const SizedBox(width: 4),
    Text(online ? 'Disponible' : 'Hors ligne',
      style: TextStyle(fontFamily: 'Nunito', fontSize: 11, fontWeight: FontWeight.w600,
          color: online ? AppColors.success : context.textMuted)),
  ]);
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool loading;
  final VoidCallback onTap;
  const _ActionChip({required this.icon, required this.label, required this.color,
      this.loading = false, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: loading ? null : onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: loading
          ? SizedBox(width: 14, height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: color))
          : Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(fontFamily: 'Nunito', fontSize: 11,
                  fontWeight: FontWeight.w700, color: color)),
            ]),
    ),
  );
}

class _DriverAvatar extends StatelessWidget {
  final String name;
  final String? url;
  final double size;
  const _DriverAvatar({required this.name, this.url, this.size = 40});

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final hasUrl = url != null && url!.isNotEmpty;
    return ClipOval(
      child: SizedBox(
        width: size, height: size,
        child: hasUrl
            ? Image.network(url!, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fallback())
            : _fallback(),
      ),
    );
  }

  Widget _fallback() => Container(
    color: AppColors.primary.withOpacity(0.18),
    alignment: Alignment.center,
    child: Text(_initials, style: TextStyle(
      fontFamily: 'Nunito', fontSize: size * 0.38,
      fontWeight: FontWeight.w800, color: AppColors.primary,
    )),
  );
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.two_wheeler_rounded, size: 64, color: context.textMuted),
        const SizedBox(height: 16),
        Text('Aucun livreur favori',
          style: TextStyle(fontFamily: 'Nunito', fontSize: 16, fontWeight: FontWeight.w800, color: context.textPrimary)),
        const SizedBox(height: 6),
        Text('Ajoutez des livreurs pour les retrouver rapidement ou les marquer comme exclusifs.',
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Nunito', fontSize: 13, color: context.textSecondary, height: 1.5)),
        if (_kAddDriverVisible) ...[
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.person_add_rounded),
            label: const Text('Ajouter un livreur'),
          ),
        ],
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
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.danger),
      const SizedBox(height: 12),
      Text(message.replaceAll('Exception: ', ''),
        textAlign: TextAlign.center,
        style: TextStyle(fontFamily: 'Nunito', fontSize: 13, color: context.textSecondary)),
      const SizedBox(height: 16),
      OutlinedButton.icon(onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Réessayer')),
    ]),
  );
}

String _vehicleLabel(String type) => switch (type.toUpperCase()) {
  'MOTORCYCLE' => 'Moto',
  'BICYCLE'    => 'Vélo',
  'CAR'        => 'Voiture',
  'TRUCK'      => 'Camion',
  _            => type,
};
