import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/router/route_params.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_colors.dart';

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

  /// Mode dérivé de needsPinSetup (vrai après verifyOtp, qu'il s'agisse d'une
  /// nouvelle inscription ou d'un reset via "PIN oublié") ou du paramètre explicite
  /// mode='set' (changement de PIN depuis le profil).
  bool get _isSetting =>
      ref.read(authProvider).needsPinSetup || widget.mode == 'set';

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
      // Phone depuis l'AuthState en priorité, fallback prop pour rétro-compat.
      final phone = ref.read(authProvider).user?.phone ?? widget.phone ?? '';

      // Guard : sans téléphone, verifyPin partirait avec une chaîne vide et
      // le backend répondrait "PIN invalide" (trompeur). Cas possible : deep
      // link direct sur /auth/pin, session corrompue, ou état désynchronisé.
      // On force le retour au flow OTP plutôt que d'afficher une erreur fausse.
      if (phone.isEmpty) {
        setState(() => _error = 'Session perdue. Veuillez vous reconnecter.');
        _ctrl.clear();
        await ref.read(authProvider.notifier).logout();
        // Le redirect GoRouter renverra automatiquement vers /onboarding.
        return;
      }

      setState(() => _loading = true);
      try {
        final ok = await ref.read(authProvider.notifier).verifyPin(phone, pin);
        if (!mounted) return;
        if (!ok) {
          setState(() => _error = 'Code PIN incorrect.');
          _ctrl.clear();
        }
        // Pas de context.go : verifyPin met needsPinSetup:false, le redirect
        // envoie vers le dashboard du rôle (ou /auth/pending si non validé).
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _isSetting
        ? (_step == 'enter' ? 'Créez votre PIN' : 'Confirmez votre PIN')
        : 'Votre PIN';
    final pt = PinTheme(width: 60, height: 64,
      textStyle: const TextStyle(fontFamily: 'Nunito', fontSize: 26, fontWeight: FontWeight.w900),
      decoration: BoxDecoration(color: context.bgColor, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.borderColor, width: 1.5)));

    return Scaffold(
      backgroundColor: context.bgColor,
      bottomNavigationBar: !_isSetting ? SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 8, 28, 16),
          child: _loading
              ? const Center(child: SizedBox(width: 24, height: 24,
                  child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)))
              : TextButton.icon(
                  onPressed: _loading ? null : () async {
                    final auth  = ref.read(authProvider);
                    final phone = auth.user?.phone ?? auth.lastPhone ?? '';
                    if (phone.isEmpty) {
                      await ref.read(authProvider.notifier).logout();
                      if (context.mounted) context.go('/onboarding');
                      return;
                    }
                    final countryCode = auth.user?.countryCode ?? 'BJ';
                    setState(() => _loading = true);
                    try {
                      final result = await ref.read(authProvider.notifier)
                          .startForgotPin(phone, countryCode);
                      if (!context.mounted) return;
                      context.push('/auth/otp', extra: OtpRouteParams(
                        phone: phone,
                        sessionId: result.sessionId,
                        countryCode: countryCode,
                        prefillOtp: result.otp,
                      ));
                    } catch (e) {
                      if (context.mounted) {
                        setState(() => _error = 'Impossible d\'envoyer le code. Réessayez.');
                      }
                    } finally {
                      if (mounted) setState(() => _loading = false);
                    }
                  },
                  icon: const Icon(Icons.lock_reset_rounded, size: 16, color: AppColors.primary),
                  label: const Text('PIN oublié ?', style: TextStyle(
                      fontFamily: 'Nunito', fontWeight: FontWeight.w700,
                      fontSize: 14, color: AppColors.primary)),
                ),
        ),
      ) : null,
      body: SafeArea(child: Padding(padding: const EdgeInsets.all(32), child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 32),
          Container(width: 68, height: 68,
            decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.10),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 2)),
            child: const Icon(Icons.lock_outline_rounded, color: AppColors.primary, size: 32)),
          const SizedBox(height: 20),
          Text(title, style: TextStyle(fontFamily: 'Nunito', fontSize: 24,
              fontWeight: FontWeight.w900, color: context.textPrimary)),
          if (!_isSetting) ...[
            const SizedBox(height: 6),
            Text('Bonjour ${ref.watch(authProvider).user?.firstName ?? ''} !',
              style: TextStyle(fontFamily: 'Nunito', fontSize: 14, color: context.textSecondary)),
          ],
          const SizedBox(height: 40),
          Pinput(controller: _ctrl, length: 4, obscureText: true, autofocus: true,
            defaultPinTheme: pt,
            focusedPinTheme: pt.copyDecorationWith(
                border: Border.all(color: AppColors.primary, width: 2.5)),
            onCompleted: _handle),
          if (_error != null) ...[const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.danger,
                fontFamily: 'Nunito', fontSize: 13))],
        ],
      ))),
    );
  }
}
