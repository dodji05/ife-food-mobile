// ─────────────────────────────────────────────────────────────────────────────
// ifè FOOD — Client / Édition profil (prénom, nom, email)
//
// Comble le manque identifié dans profile_screen.dart : jusqu'ici l'utilisateur
// devait repasser par /auth/complete-profile pour changer son nom. Cet écran
// utilise le même endpoint backend (PATCH /users/me) via AuthNotifier.completeProfile
// mais reste accessible librement depuis le profil (sans relancer le flow d'auth).
//
// Champs éditables :
//   • firstName (requis, identifie le user dans hasProfile)
//   • name (optionnel)
//   • email (optionnel, validé format)
//
// Le téléphone n'est PAS éditable ici (changement de numéro = nouveau OTP →
// flow dédié à créer ultérieurement).
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_colors.dart';

class ClientEditProfileScreen extends ConsumerStatefulWidget {
  const ClientEditProfileScreen({super.key});
  @override
  ConsumerState<ClientEditProfileScreen> createState() => _State();
}

class _State extends ConsumerState<ClientEditProfileScreen> {
  final _firstName = TextEditingController();
  final _name      = TextEditingController();
  final _email     = TextEditingController();
  bool _loading = false;
  String? _emailError;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    _firstName.text = user?.firstName ?? '';
    _name.text      = user?.name      ?? '';
    _email.text     = user?.email     ?? '';
  }

  @override
  void dispose() {
    _firstName.dispose();
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  bool get _canSave =>
      _firstName.text.trim().isNotEmpty &&
      _emailError == null &&
      !_loading;

  /// Validation email basique : si vide → OK (optionnel), sinon doit matcher
  /// un format minimaliste. Pas de regex stricte — on fait confiance au backend
  /// pour la validation finale, on évite juste les fautes évidentes.
  void _validateEmail(String v) {
    final t = v.trim();
    if (t.isEmpty) {
      setState(() => _emailError = null);
      return;
    }
    final ok = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$').hasMatch(t);
    setState(() => _emailError = ok ? null : 'Format email invalide');
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _loading = true);
    try {
      final payload = <String, dynamic>{
        'firstName': _firstName.text.trim(),
        'name':      _name.text.trim().isEmpty  ? null : _name.text.trim(),
        'email':     _email.text.trim().isEmpty ? null : _email.text.trim(),
      };
      await ref.read(authProvider.notifier).completeProfile(payload);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Profil mis à jour ✓'),
        backgroundColor: AppColors.success,
      ));
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceAll('Exception: ', '')),
        backgroundColor: AppColors.danger,
      ));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        title: const Text('Modifier mon profil'),
        leading: const BackButton(),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _canSave ? _save : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: AppColors.primary.withOpacity(0.35),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : const Text('Enregistrer',
                      style: TextStyle(fontFamily: 'Nunito', fontSize: 15,
                          fontWeight: FontWeight.w800, color: Colors.white)),
            ),
          ),
        ),
      ),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        // ── Téléphone (lecture seule) ────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.bgColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.borderColor),
          ),
          child: Row(children: [
            Icon(Icons.phone_rounded, color: context.textMuted, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Téléphone',
                style: TextStyle(fontFamily: 'Nunito', fontSize: 12,
                    fontWeight: FontWeight.w700, color: context.textSecondary)),
              const SizedBox(height: 2),
              Text(user?.phone ?? '—',
                style: TextStyle(fontFamily: 'Nunito', fontSize: 15,
                    fontWeight: FontWeight.w700, color: context.textPrimary)),
            ])),
            Icon(Icons.lock_rounded, color: context.textSecondary, size: 16),
          ]),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Pour changer votre téléphone, contactez le support.',
            style: TextStyle(fontFamily: 'Nunito', fontSize: 11,
                color: context.textSecondary, fontStyle: FontStyle.italic),
          ),
        ),
        const SizedBox(height: 20),

        _Label('Prénom *', context),
        const SizedBox(height: 8),
        TextField(
          controller: _firstName,
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(hintText: 'Ex: Aïcha'),
          style: TextStyle(fontFamily: 'Nunito', fontSize: 15,
              fontWeight: FontWeight.w600, color: context.textPrimary),
        ),
        const SizedBox(height: 16),

        _Label('Nom (optionnel)', context),
        const SizedBox(height: 8),
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(hintText: 'Ex: DOSSOU'),
          style: TextStyle(fontFamily: 'Nunito', fontSize: 15,
              fontWeight: FontWeight.w600, color: context.textPrimary),
        ),
        const SizedBox(height: 16),

        _Label('Email (optionnel)', context),
        const SizedBox(height: 8),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          onChanged: _validateEmail,
          decoration: InputDecoration(
            hintText: 'Ex: aicha@example.com',
            errorText: _emailError,
          ),
          style: TextStyle(fontFamily: 'Nunito', fontSize: 15,
              fontWeight: FontWeight.w600, color: context.textPrimary),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Reçoit les reçus de commande et les notifications importantes.',
            style: TextStyle(fontFamily: 'Nunito', fontSize: 11,
                color: context.textSecondary),
          ),
        ),
      ]),
    );
  }
}

Widget _Label(String t, BuildContext context) => Text(t,
  style: TextStyle(fontFamily: 'Nunito', fontSize: 13,
      fontWeight: FontWeight.w700, color: context.textSecondary, letterSpacing: 0.3));
