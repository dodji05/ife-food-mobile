import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';

class PendingScreen extends ConsumerStatefulWidget {
  const PendingScreen({super.key});
  @override ConsumerState<PendingScreen> createState() => _PendingScreenState();
}

class _PendingScreenState extends ConsumerState<PendingScreen> {
  bool _checking = false;
  String? _message;

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
      backgroundColor: Colors.white,
      body: SafeArea(child: Padding(padding: const EdgeInsets.all(32), child: Column(
        mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('⏳', style: TextStyle(fontSize: 64)),
        const SizedBox(height: 24),
        const Text('Dossier en cours\nde validation', textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Nunito', fontSize: 26,
              fontWeight: FontWeight.w900, color: AppColors.nearBlack, height: 1.2)),
        const SizedBox(height: 12),
        const Text(
          'Notre équipe vérifie votre dossier. Vous serez notifié dès l\'activation de votre compte.\n\nDélai moyen : moins de 24h.',
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Nunito', fontSize: 14,
              color: AppColors.lightSubtext, height: 1.6)),
        const SizedBox(height: 32),
        Container(padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.lightBg, borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.lightBorder)),
          child: Column(children: [
            _Step('✅', 'Dossier soumis', done: true),
            _Step('⏳', 'Vérification documents', active: true),
            _Step('🎉', 'Compte activé'),
          ])),
        const SizedBox(height: 28),

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
              color: _message!.startsWith('✅') ? AppColors.success : AppColors.lightSubtext,
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
        color: done ? AppColors.success : active ? AppColors.warning : AppColors.lightBorder,
        fontWeight: active ? FontWeight.w800 : FontWeight.w500)),
    ]));
}
