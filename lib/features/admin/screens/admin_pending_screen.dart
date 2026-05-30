// ─────────────────────────────────────────────────────────────────────────────
// ifè FOOD — Admin / Validation des comptes pros et drivers
//
// Interface minimaliste pour valider/refuser les comptes PENDING :
//   • TabBar : Pros (count) | Livreurs (count)
//   • Cartes : nom, business/véhicule, tél, email, date inscription, documents
//   • Boutons : Valider (vert, instantané) / Refuser (dialog avec raison obligatoire)
//   • Pull-to-refresh, empty state, error state
//
// Le backend (admin.service.ts) :
//   - Met le status pro/driver à VALIDATED/REJECTED
//   - Met le user.status à ACTIVE/SUSPENDED
//   - Envoie une notif push au compte (déjà câblé)
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_colors.dart';
import '../providers/admin_provider.dart';

class AdminPendingScreen extends ConsumerStatefulWidget {
  const AdminPendingScreen({super.key});
  @override
  ConsumerState<AdminPendingScreen> createState() => _State();
}

class _State extends ConsumerState<AdminPendingScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final pros = ref.watch(pendingProfessionalsProvider);
    final drivers = ref.watch(pendingDriversProvider);

    final prosCount = pros.maybeWhen(data: (l) => l.length, orElse: () => 0);
    final driversCount = drivers.maybeWhen(data: (l) => l.length, orElse: () => 0);

    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        title: const Text('Comptes en attente'),
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            onPressed: () {
              ref.invalidate(pendingProfessionalsProvider);
              ref.invalidate(pendingDriversProvider);
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Déconnexion',
            onPressed: () => ref.read(authProvider.notifier).logout(),
            icon: const Icon(Icons.logout_rounded, color: AppColors.danger),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: context.textSecondary,
          labelStyle: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800, fontSize: 13),
          tabs: [
            Tab(text: 'Pros ($prosCount)'),
            Tab(text: 'Livreurs ($driversCount)'),
          ],
        ),
      ),
      body: TabBarView(controller: _tabs, children: [
        _PendingList(
          async: pros,
          onRefresh: () => ref.invalidate(pendingProfessionalsProvider),
          itemBuilder: (item) => _ProTile(pro: item),
          emptyLabel: 'Aucun pro en attente de validation',
        ),
        _PendingList(
          async: drivers,
          onRefresh: () => ref.invalidate(pendingDriversProvider),
          itemBuilder: (item) => _DriverTile(driver: item),
          emptyLabel: 'Aucun livreur en attente de validation',
        ),
      ]),
    );
  }
}

// ── Liste générique pending (réutilisée par les 2 tabs) ─────────────────────
class _PendingList extends StatelessWidget {
  final AsyncValue<List<Map<String, dynamic>>> async;
  final VoidCallback onRefresh;
  final Widget Function(Map<String, dynamic>) itemBuilder;
  final String emptyLabel;
  const _PendingList({
    required this.async, required this.onRefresh,
    required this.itemBuilder, required this.emptyLabel,
  });

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    color: AppColors.primary,
    onRefresh: () async => onRefresh(),
    child: async.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (e, _) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 80),
          const Icon(Icons.cloud_off_rounded, size: 56, color: AppColors.danger),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(e.toString().replaceAll('Exception: ', ''),
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Nunito', fontSize: 12, color: context.textSecondary)),
          ),
          const SizedBox(height: 16),
          Center(child: OutlinedButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Réessayer'),
          )),
        ],
      ),
      data: (list) {
        if (list.isEmpty) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              const SizedBox(height: 80),
              const Icon(Icons.check_circle_outline_rounded, size: 64, color: AppColors.success),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(emptyLabel,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Nunito', fontSize: 14,
                      fontWeight: FontWeight.w700, color: context.textPrimary)),
              ),
            ],
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => itemBuilder(list[i]),
        );
      },
    ),
  );
}

// ── Carte Pro pending ───────────────────────────────────────────────────────
class _ProTile extends ConsumerWidget {
  final Map<String, dynamic> pro;
  const _ProTile({required this.pro});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = pro['user'] as Map<String, dynamic>?;
    final docs = (pro['documents'] as List?)?.length ?? 0;
    return _BaseValidationCard(
      title: (pro['businessName'] as String?) ?? 'Établissement',
      subtitle: '${(pro['category'] as String?) ?? '?'} • ${(pro['city'] as String?) ?? ''}',
      ownerName: (user?['name'] as String?) ?? '—',
      phone: user?['phone'] as String?,
      email: user?['email'] as String?,
      address: pro['address'] as String?,
      createdAt: pro['createdAt'] as String?,
      documentsCount: docs,
      onApprove: () => _doValidate(context, ref, pro['id'] as String, approve: true),
      onReject:  () => _showRejectDialog(context, ref, pro['id'] as String),
    );
  }

  Future<void> _doValidate(BuildContext context, WidgetRef ref, String id,
      {required bool approve, String? note}) async {
    try {
      await ref.read(adminNotifierProvider).validateProfessional(id, approve: approve, note: note);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(approve ? 'Pro validé ✓' : 'Pro refusé'),
        backgroundColor: approve ? AppColors.success : AppColors.warning,
      ));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceAll('Exception: ', '')),
        backgroundColor: AppColors.danger,
      ));
    }
  }

  Future<void> _showRejectDialog(BuildContext context, WidgetRef ref, String id) async {
    final note = await _promptRejectReason(context);
    if (note == null) return;
    await _doValidate(context, ref, id, approve: false, note: note);
  }
}

// ── Carte Driver pending ────────────────────────────────────────────────────
class _DriverTile extends ConsumerWidget {
  final Map<String, dynamic> driver;
  const _DriverTile({required this.driver});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = driver['user'] as Map<String, dynamic>?;
    final docs = (driver['documents'] as List?)?.length ?? 0;
    final vehicleType  = driver['vehicleType']  as String?;
    final vehiclePlate = driver['vehiclePlate'] as String?;
    return _BaseValidationCard(
      title: '${(user?['name'] as String?) ?? 'Livreur'}',
      subtitle: vehicleType != null
          ? '$vehicleType${vehiclePlate != null ? " • $vehiclePlate" : ""}'
          : 'Véhicule non renseigné',
      ownerName: (user?['name'] as String?) ?? '—',
      phone: user?['phone'] as String?,
      email: user?['email'] as String?,
      address: null,
      createdAt: driver['createdAt'] as String?,
      documentsCount: docs,
      onApprove: () => _doValidate(context, ref, driver['id'] as String, approve: true),
      onReject:  () => _showRejectDialog(context, ref, driver['id'] as String),
    );
  }

  Future<void> _doValidate(BuildContext context, WidgetRef ref, String id,
      {required bool approve, String? note}) async {
    try {
      await ref.read(adminNotifierProvider).validateDriver(id, approve: approve, note: note);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(approve ? 'Livreur validé ✓' : 'Livreur refusé'),
        backgroundColor: approve ? AppColors.success : AppColors.warning,
      ));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceAll('Exception: ', '')),
        backgroundColor: AppColors.danger,
      ));
    }
  }

  Future<void> _showRejectDialog(BuildContext context, WidgetRef ref, String id) async {
    final note = await _promptRejectReason(context);
    if (note == null) return;
    await _doValidate(context, ref, id, approve: false, note: note);
  }
}

// ── Dialog raison de refus (réutilisé pro + driver) ─────────────────────────
Future<String?> _promptRejectReason(BuildContext context) async {
  final ctrl = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: ctx.cardColor,
      title: Text('Raison du refus',
        style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w900, color: ctx.textPrimary, fontSize: 16)),
      content: TextField(
        controller: ctrl,
        maxLines: 4,
        minLines: 2,
        maxLength: 300,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          hintText: 'Précisez pourquoi le compte est refusé (visible par le user)',
        ),
        style: TextStyle(fontFamily: 'Nunito', fontSize: 14, color: ctx.textPrimary),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text('Annuler', style: TextStyle(color: ctx.textSecondary)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: () {
            final n = ctrl.text.trim();
            if (n.isEmpty) return;
            Navigator.pop(ctx, n);
          },
          child: const Text('Refuser le compte', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        ),
      ],
    ),
  );
}

// ── Carte commune (squelette pro/driver) ────────────────────────────────────
class _BaseValidationCard extends StatelessWidget {
  final String  title;
  final String  subtitle;
  final String  ownerName;
  final String? phone;
  final String? email;
  final String? address;
  final String? createdAt;
  final int     documentsCount;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _BaseValidationCard({
    required this.title,
    required this.subtitle,
    required this.ownerName,
    this.phone, this.email, this.address, this.createdAt,
    this.documentsCount = 0,
    required this.onApprove, required this.onReject,
  });

  String _formatDate(String? iso) {
    if (iso == null) return '—';
    final d = DateTime.tryParse(iso);
    if (d == null) return '—';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: context.cardColor,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.warning.withOpacity(0.3)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Header
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: AppColors.warning.withOpacity(0.18), shape: BoxShape.circle),
            alignment: Alignment.center,
            child: const Icon(Icons.hourglass_top_rounded, color: AppColors.warning, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontFamily: 'Nunito', fontSize: 15, fontWeight: FontWeight.w900, color: context.textPrimary)),
            Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontFamily: 'Nunito', fontSize: 12, color: context.textSecondary)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: context.bgColor, borderRadius: BorderRadius.circular(6)),
            child: Text(_formatDate(createdAt),
              style: TextStyle(fontFamily: 'Nunito', fontSize: 11, color: context.textSecondary)),
          ),
        ]),
      ),
      // Infos
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _row(Icons.person_outline_rounded, 'Propriétaire', ownerName),
          if (phone != null && phone!.isNotEmpty) _row(Icons.phone_rounded, 'Téléphone', phone!),
          if (email != null && email!.isNotEmpty) _row(Icons.email_rounded, 'Email', email!),
          if (address != null && address!.isNotEmpty) _row(Icons.location_on_rounded, 'Adresse', address!),
          _row(
            Icons.description_rounded,
            'Documents',
            documentsCount == 0 ? 'Aucun document fourni' : '$documentsCount fichier(s)',
            warn: documentsCount == 0,
          ),
        ]),
      ),
      // Actions
      Divider(color: context.borderColor, height: 1),
      Row(children: [
        Expanded(child: TextButton.icon(
          onPressed: onReject,
          icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.danger),
          label: const Text('Refuser',
            style: TextStyle(fontFamily: 'Nunito', fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.danger)),
        )),
        Container(width: 1, height: 40, color: context.borderColor),
        Expanded(child: TextButton.icon(
          onPressed: onApprove,
          icon: const Icon(Icons.check_rounded, size: 16, color: AppColors.success),
          label: const Text('Valider',
            style: TextStyle(fontFamily: 'Nunito', fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.success)),
        )),
      ]),
    ]),
  );

  Widget _row(IconData icon, String label, String value, {bool warn = false}) => Builder(
    builder: (context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 13, color: warn ? AppColors.warning : context.textSecondary),
        const SizedBox(width: 6),
        Expanded(child: Text.rich(TextSpan(children: [
          TextSpan(text: '$label : ',
            style: TextStyle(fontFamily: 'Nunito', fontSize: 12, color: context.textSecondary)),
          TextSpan(text: value,
            style: TextStyle(
              fontFamily: 'Nunito', fontSize: 12, fontWeight: FontWeight.w700,
              color: warn ? AppColors.warning : context.textPrimary,
            )),
        ]))),
      ]),
    ),
  );
}
