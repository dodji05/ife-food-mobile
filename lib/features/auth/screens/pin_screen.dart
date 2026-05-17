import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';

class PinScreen extends ConsumerStatefulWidget {
  /// `mode` et `phone` sont OPTIONNELS et conservés pour rétro-compat.
  /// La source de vérité est `authProvider.isNewUser` / `authProvider.user.phone`,
  /// le redirect GoRouter pilote la navigation post-action.
  final String? mode;
  final String? phone;
  const PinScreen({super.key, this.mode, this.phone});
  @override ConsumerState<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends ConsumerState<PinScreen> {
  final _ctrl = TextEditingController();
  String? _first;
  String _step = 'enter';
  bool _loading = false;
  String? _error;

  /// Mode dérivé de l'AuthState (isNewUser). Fallback sur la prop `mode`
  /// si on est arrivé ici sans passer par verifyOtp (peu probable).
  bool get _isSetting =>
      ref.read(authProvider).isNewUser || widget.mode == 'set';

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _handle(String pin) async {
    if (_isSetting) {
      // ── Mode 'set' : double saisie pour confirmation ──────────────────
      if (_step == 'enter') {
        setState(() { _first = pin; _step = 'confirm'; });
        _ctrl.clear();
        return;
      }
      if (pin != _first) {
        setState(() {
          _error = 'Les codes ne correspondent pas.';
          _step = 'enter';
          _first = null;
        });
        _ctrl.clear();
        return;
      }
      setState(() => _loading = true);
      final role = await ref.read(authProvider.notifier).setPin(pin);
      if (!mounted) return;
      setState(() => _loading = false);
      if (role == null) {
        // Erreur PIN — message déjà dans authState.error
        final err = ref.read(authProvider).error;
        setState(() => _error = err ?? 'Erreur lors de la création du PIN.');
        _ctrl.clear();
        return;
      }
      // Cas "Modifier mon PIN" depuis le profil : l'utilisateur est déjà
      // complet (hasProfile + PIN antérieur), aucun champ routing ne change
      // → on doit pop manuellement, sinon écran figé.
      final auth = ref.read(authProvider);
      if (auth.isAuthenticated && auth.hasProfile && context.canPop()) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('PIN mis à jour ✓'), duration: Duration(seconds: 2)));
        context.pop();
        return;
      }
      // Cas inscription initiale : pas de pop, le redirect prend la suite
      // (setPin met needsPinSetup:false → bascule vers /auth/complete-profile).
    } else {
      // ── Mode 'login' : saisie simple ───────────────────────────────────
      setState(() => _loading = true);
      // Phone depuis l'AuthState en priorité, fallback prop pour rétro-compat.
      final phone = ref.read(authProvider).user?.phone ?? widget.phone ?? '';
      final ok = await ref.read(authProvider.notifier).verifyPin(phone, pin);
      if (!mounted) return;
      if (!ok) {
        setState(() { _error = 'Code PIN incorrect.'; _loading = false; });
        _ctrl.clear();
      }
      // Pas de context.go : verifyPin met needsPinSetup:false, le redirect
      // envoie vers le dashboard du rôle (ou /auth/pending si non validé).
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _isSetting
        ? (_step == 'enter' ? 'Créez votre PIN' : 'Confirmez votre PIN')
        : 'Votre PIN';
    final pt = PinTheme(width: 60, height: 64,
      textStyle: const TextStyle(fontFamily: 'Nunito', fontSize: 26, fontWeight: FontWeight.w900),
      decoration: BoxDecoration(color: AppColors.lightBg, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.lightBorder, width: 1.5)));

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(child: Padding(padding: const EdgeInsets.all(32), child: Column(children: [
        const SizedBox(height: 32),
        Container(width: 68, height: 68,
          decoration: BoxDecoration(
              // F: withValues() remplace withOpacity() déprécié
              color: AppColors.primary.withOpacity(0.10),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 2)),
          child: const Icon(Icons.lock_outline_rounded, color: AppColors.primary, size: 32)),
        const SizedBox(height: 20),
        Text(title, style: const TextStyle(fontFamily: 'Nunito', fontSize: 24,
            fontWeight: FontWeight.w900, color: AppColors.nearBlack)),
        if (!_isSetting) ...[
          const SizedBox(height: 6),
          Text('Bonjour ${ref.watch(authProvider).user?.firstName ?? ''} !',
            style: const TextStyle(fontFamily: 'Nunito', fontSize: 14, color: AppColors.lightSubtext)),
        ],
        const SizedBox(height: 40),
        Pinput(controller: _ctrl, length: 4, obscureText: true, autofocus: true,
          defaultPinTheme: pt,
          focusedPinTheme: pt.copyDecorationWith(
              border: Border.all(color: AppColors.primary, width: 2.5)),
          onCompleted: _handle),
        if (_error != null) ...[const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: AppColors.danger,
              fontFamily: 'Nunito', fontSize: 13))],
        const Spacer(),
        if (!_isSetting) TextButton(
          onPressed: () async {
            // Bug fix : sans logout préalable, le redirect renvoie immédiatement
            // sur /auth/pin (needsPinSetup:true). On purge la session pour
            // rebasculer en flow non-authentifié.
            final role = ref.read(authProvider).role;
            await ref.read(authProvider.notifier).logout();
            if (context.mounted) context.go('/auth/phone', extra: role);
          },
          child: const Text('Me connecter avec OTP', style: TextStyle(
              fontFamily: 'Nunito', fontWeight: FontWeight.w600, color: AppColors.lightSubtext))),
        if (_loading) const CircularProgressIndicator(color: AppColors.primary),
      ]))),
    );
  }
}
