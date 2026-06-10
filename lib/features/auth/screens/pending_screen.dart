import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_colors.dart';

class PendingScreen extends ConsumerStatefulWidget {
  const PendingScreen({super.key});
  @override ConsumerState<PendingScreen> createState() => _PendingScreenState();
}

class _PendingScreenState extends ConsumerState<PendingScreen> {
  bool _checking = false;
  String? _message;
  // null = pas encore vérifié, true = profile driver existe, false = manquant
  bool? _hasDriverProfile;

  @override
  void initState() {
    super.initState();
    // Si le user est driver, on check si son Driver row existe en DB.
    // Si manquante (cas user qui a skippé /auth/driver-vehicle ou kill app),
    // on propose un CTA pour compléter le profil véhicule.
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkDriverProfile());
  }

  Future<void> _checkDriverProfile() async {
    final user = ref.read(authProvider).user;
    if (user?.role != UserRole.driver) {
      // Pour les pros : on suppose que le Professional row existe (créée
      // lors de l'OTP / completeProfile pour role=pro). Pas de check ici.
      setState(() => _hasDriverProfile = true);
      return;
    }
    try {
      await ApiClient.instance.get('/drivers/me');
      if (mounted) setState(() => _hasDriverProfile = true);
    } catch (e) {
      // 404 → driver profile inexistant. Le user doit completer son véhicule.
      if (mounted) setState(() => _hasDriverProfile = false);
    }
  }

  Future<void> _checkStatus() async {
    setState(() { _checking = true; _message = null; });
    try {
      // Rafraîchit le profil depuis le serveur
      await ref.read(authProvider.notifier).refreshProfile();
      final user = ref.read(authProvider).user;

      if (user?.status == 'ACTIVE') {
        // Compte validé → GoRouterRefreshStream redirige automatiquement
        // vers le bon tableau de bord (isPending=false → redirect re-évalue)
        if (mounted) setState(() => _message = '✅ Compte activé !');
      } else {
        if (mounted) setState(() => _message = 'Votre dossier est encore en cours de vérification.');
      }
    } catch (_) {
      if (mounted) setState(() => _message = 'Impossible de vérifier. Réessayez.');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgColor,
      body: SafeArea(child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
        mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('⏳', style: TextStyle(fontSize: 64)),
        const SizedBox(height: 24),
        Text('Dossier en cours\nde validation', textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Nunito', fontSize: 26,
              fontWeight: FontWeight.w900, color: context.textPrimary, height: 1.2)),
        const SizedBox(height: 12),
        Text(
          'Notre équipe vérifie votre dossier. Vous serez notifié dès l\'activation de votre compte.\n\nDélai moyen : moins de 24h.',
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Nunito', fontSize: 14,
              color: context.textSecondary, height: 1.6)),
        const SizedBox(height: 32),
        Container(padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: context.cardColor, borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.borderColor)),
          child: Column(children: [
            _Step('✅', 'Dossier soumis', done: true),
            _Step('⏳', 'Vérification documents', active: true),
            _Step('🎉', 'Compte activé'),
          ])),
        const SizedBox(height: 24),

        // CTA "Compléter mon profil livreur" : visible UNIQUEMENT si le user
        // est driver ET que son Driver row n'existe pas en DB. Cas typique :
        // user qui a fait OTP + complete-profile, puis a kill l'app AVANT
        // d'avoir validé /auth/driver-vehicle -> il revient sur /auth/pending
        // mais sans Driver row, son onboarding n'est pas terminé.
        if (_hasDriverProfile == false) ...[
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.warning.withOpacity(0.4)),
            ),
            child: Row(children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 22),
              const SizedBox(width: 10),
              Expanded(child: Text(
                'Profil incomplet : il manque les infos de votre véhicule.',
                style: TextStyle(fontFamily: 'Nunito', fontSize: 13,
                  fontWeight: FontWeight.w600, color: context.textPrimary),
              )),
            ]),
          ),
          ElevatedButton.icon(
            onPressed: () => context.go('/auth/driver-vehicle'),
            icon: const Icon(Icons.directions_bike_rounded),
            label: const Text('Compléter mon profil livreur'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Bouton vérifier statut
        ElevatedButton.icon(
          onPressed: _checking ? null : _checkStatus,
          icon: _checking
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.refresh_rounded),
          label: Text(_checking ? 'Vérification…' : 'Vérifier mon statut'),
        ),

        if (_message != null) ...[
          const SizedBox(height: 12),
          Text(_message!, textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Nunito', fontSize: 13, fontWeight: FontWeight.w600,
              color: _message!.startsWith('✅') ? AppColors.success : context.textSecondary,
            )),
        ],

        const SizedBox(height: 16),
        TextButton(
          onPressed: () => ref.read(authProvider.notifier).logout(),
          child: const Text('Se déconnecter', style: TextStyle(
              fontFamily: 'Nunito', color: AppColors.danger, fontWeight: FontWeight.w700))),
      ]))),
    );
  }
}

class _Step extends StatelessWidget {
  final String emoji, label; final bool done, active;
  const _Step(this.emoji, this.label, {this.done = false, this.active = false});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [
      Text(emoji, style: const TextStyle(fontSize: 16)),
      const SizedBox(width: 10),
      Text(label, style: TextStyle(fontFamily: 'Nunito', fontSize: 13,
        color: done ? AppColors.success : active ? AppColors.warning : context.borderColor,
        fontWeight: active ? FontWeight.w800 : FontWeight.w500)),
    ]));
}
