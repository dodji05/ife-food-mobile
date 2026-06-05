import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_colors.dart';
import '../../../core/constants/app_constants.dart';

class CompleteProfileScreen extends ConsumerStatefulWidget {
  final UserRole? role;
  const CompleteProfileScreen({super.key, this.role});
  @override ConsumerState<CompleteProfileScreen> createState() => _State();
}

class _State extends ConsumerState<CompleteProfileScreen> {
  final _firstName = TextEditingController();
  final _lastName  = TextEditingController();
  bool _accepted   = false;
  bool _loading    = false;

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      await ref.read(authProvider.notifier).completeProfile({
        'firstName': _firstName.text.trim(),
        'name': _lastName.text.trim(),
      });
      // Acceptation CGU — endpoint dédié (POST /users/me/legal/accept).
      // On capture l'erreur séparément pour ne pas bloquer le flow si
      // l'enregistrement légal échoue (réseau, etc.).
      if (_accepted) {
        try {
          await ApiClient.instance.post('/users/me/legal/accept',
              data: {'documentType': 'CGU', 'version': '1.0'});
          await ApiClient.instance.post('/users/me/legal/accept',
              data: {'documentType': 'PRIVACY', 'version': '1.0'});
        } catch (e) {
          debugPrint('[CGU] Enregistrement acceptation échoué: $e');
        }
      }
      // Cas DRIVER : étape supplémentaire véhicule avant /auth/pending.
      // On navigue explicitement vers /auth/driver-vehicle (whitelisté
      // dans le redirect) plutôt que de laisser le redirect aller direct
      // à /auth/pending. Cf app_router.dart règle 5.
      if (widget.role == UserRole.driver && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) GoRouter.of(context).go('/auth/driver-vehicle');
        });
        return;
      }
      // Sinon (client / pro) : completeProfile met à jour user.firstName,
      // donc hasProfile passe à true et le redirect GoRouter envoie
      // automatiquement vers le dashboard du rôle.
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppColors.danger));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.bgColor,
    appBar: AppBar(
      backgroundColor: AppColors.primary,
      elevation: 0,
      title: const Text('Compléter mon profil',
        style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800, color: Colors.white, fontSize: 17)),
    ),
    bottomNavigationBar: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        child: ElevatedButton(
          onPressed: (_firstName.text.isEmpty || _lastName.text.isEmpty || !_accepted || _loading)
              ? null : _save,
          child: _loading
              ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Créer mon compte'),
        ),
      ),
    ),
    body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Votre identité', style: TextStyle(fontFamily: 'Nunito',
            fontSize: 26, fontWeight: FontWeight.w900, color: context.textPrimary)),
        const SizedBox(height: 6),
        Text('Dernière étape avant de commencer !',
          style: TextStyle(fontFamily: 'Nunito', fontSize: 14, color: context.textSecondary)),
        const SizedBox(height: 32),
        _TF('Prénom *', _firstName, 'Ex: Gildas'),
        const SizedBox(height: 14),
        _TF('Nom *', _lastName, 'Ex: Aclinou'),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: () => setState(() => _accepted = !_accepted),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            AnimatedContainer(duration: const Duration(milliseconds: 150),
              width: 22, height: 22,
              decoration: BoxDecoration(
                color: _accepted ? AppColors.primary : context.cardColor,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: _accepted ? AppColors.primary : context.borderColor, width: 1.5)),
              child: _accepted ? const Icon(Icons.check, color: Colors.white, size: 14) : null),
            const SizedBox(width: 10),
            Expanded(child: Text(
              'J\'accepte les CGU et la Politique de confidentialité d\'ifè FOOD.',
              style: TextStyle(fontFamily: 'Nunito', fontSize: 13, color: context.textPrimary, height: 1.4))),
          ]),
        ),
      ],
    ),
  );

  Widget _TF(String label, TextEditingController ctrl, String hint) => Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontFamily: 'Nunito', fontSize: 12,
          fontWeight: FontWeight.w700, color: context.textSecondary, letterSpacing: 0.3)),
      const SizedBox(height: 6),
      TextField(controller: ctrl, onChanged: (_) => setState(() {}),
        style: const TextStyle(fontFamily: 'Nunito', fontSize: 15, fontWeight: FontWeight.w700),
        decoration: InputDecoration(hintText: hint)),
    ]);
}
