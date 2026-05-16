import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
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
      // On capture l'erreur séparément pour ne pas bloquer le flow d'inscription
      // si l'enregistrement légal échoue (réseau, etc.).
      if (_accepted) {
        try {
          await ApiClient.instance.post('/users/me/legal/accept', data: {
            'documentType': 'CGU',
            'version': '1.0',
          });
          await ApiClient.instance.post('/users/me/legal/accept', data: {
            'documentType': 'PRIVACY',
            'version': '1.0',
          });
        } catch (e) {
          debugPrint('[CGU] Enregistrement acceptation échoué: $e');
        }
      }
      if (!mounted) return;
      // Navigation explicite — ne pas dépendre du redirect GoRouter
      final role = ref.read(authProvider).role;
      context.go(_dashboardForRole(role));
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppColors.danger));
    }
  }

  String _dashboardForRole(UserRole? role) => switch (role) {
    UserRole.driver       => '/driver/dashboard',
    UserRole.professional => '/pro/dashboard',
    _                     => '/home',
  };

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(backgroundColor: Colors.white, elevation: 0),
    body: SafeArea(child: Padding(padding: const EdgeInsets.all(24), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Votre identité', style: TextStyle(fontFamily: 'Nunito',
            fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.nearBlack)),
        const SizedBox(height: 6),
        const Text('Dernière étape avant de commencer !',
          style: TextStyle(fontFamily: 'Nunito', fontSize: 14, color: AppColors.lightSubtext)),
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
                color: _accepted ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: _accepted ? AppColors.primary : AppColors.lightBorder, width: 1.5)),
              child: _accepted ? const Icon(Icons.check, color: Colors.white, size: 14) : null),
            const SizedBox(width: 10),
            Expanded(child: const Text(
              'J\'accepte les CGU et la Politique de confidentialité d\'ifè FOOD.',
              style: TextStyle(fontFamily: 'Nunito', fontSize: 13, color: AppColors.nearBlack, height: 1.4))),
          ]),
        ),
        const Spacer(),
        ElevatedButton(
          onPressed: (_firstName.text.isEmpty || _lastName.text.isEmpty || !_accepted || _loading)
              ? null : _save,
          child: _loading
              ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Créer mon compte'),
        ),
      ],
    ))),
  );

  Widget _TF(String label, TextEditingController ctrl, String hint) => Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontFamily: 'Nunito', fontSize: 12,
          fontWeight: FontWeight.w700, color: AppColors.lightSubtext, letterSpacing: 0.3)),
      const SizedBox(height: 6),
      TextField(controller: ctrl, onChanged: (_) => setState(() {}),
        style: const TextStyle(fontFamily: 'Nunito', fontSize: 15, fontWeight: FontWeight.w700),
        decoration: InputDecoration(hintText: hint)),
    ]);
}
