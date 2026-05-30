// ─────────────────────────────────────────────────────────────────────────────
// LoginScreen — connexion rapide téléphone + PIN
//
// Affiché aux utilisateurs qui se sont déjà connectés une fois et ont défini
// leur PIN. Évite de repasser par le flow OTP complet (onboarding → téléphone
// → SMS → PIN) à chaque déconnexion.
//
// Flow "PIN oublié" :
//   1. L'utilisateur tape son numéro → "PIN oublié ?"
//   2. Un OTP est envoyé au numéro affiché
//   3. OtpScreen vérifie l'OTP (forgotPinMode=true dans AuthState)
//   4. PinScreen s'ouvre en mode "set" → nouveau PIN créé
//   5. Redirect vers le dashboard
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/router/route_params.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_colors.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _pinCtrl = TextEditingController();
  bool _loading = false;
  bool _forgotLoading = false;
  String? _error;

  @override
  void dispose() {
    _pinCtrl.dispose();
    super.dispose();
  }

  String get _phone => ref.read(authProvider).lastPhone ?? '';
  String get _countryCode => ref.read(authProvider).user?.countryCode ?? 'BJ';

  /// Connexion par PIN — appelle POST /auth/pin/verify
  Future<void> _login(String pin) async {
    if (_loading) return;
    setState(() { _loading = true; _error = null; });
    try {
      final ok = await ref.read(authProvider.notifier).verifyPin(_phone, pin);
      if (!mounted) return;
      if (!ok) {
        final err = ref.read(authProvider).error ?? 'Code PIN incorrect.';
        setState(() {
          _error = err.contains('PIN not set')
              ? 'Aucun PIN défini pour ce compte.'
              : err.contains('Invalid PIN') || err.contains('invalide')
                  ? 'Code PIN incorrect.'
                  : err.replaceAll('Exception: ', '');
        });
        _pinCtrl.clear();
      }
      // Succès : le redirect GoRouter prend la main (isAuthenticated → dashboard)
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Démarre le flow "PIN oublié" : envoie un OTP puis navigue vers OtpScreen
  Future<void> _forgotPin() async {
    if (_forgotLoading || _phone.isEmpty) return;
    setState(() { _forgotLoading = true; _error = null; });
    try {
      final result = await ref.read(authProvider.notifier)
          .startForgotPin(_phone, _countryCode);
      if (!mounted) return;
      context.push('/auth/otp', extra: OtpRouteParams(
        phone: _phone,
        sessionId: result.sessionId,
        countryCode: _countryCode,
        prefillOtp: result.otp,
      ));
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Impossible d\'envoyer le code. Réessayez.');
      }
    } finally {
      if (mounted) setState(() => _forgotLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pt = PinTheme(
      width: 64, height: 68,
      textStyle: const TextStyle(
          fontFamily: 'Nunito', fontSize: 28, fontWeight: FontWeight.w900),
      decoration: BoxDecoration(
          color: context.bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.borderColor, width: 1.5)),
    );

    return Scaffold(
      backgroundColor: context.bgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 24),

              // Logo
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Center(
                  child: Text('ifè', style: TextStyle(
                      fontFamily: 'Nunito', fontSize: 22,
                      fontWeight: FontWeight.w900, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 28),

              Text('Bon retour !', style: TextStyle(
                  fontFamily: 'Nunito', fontSize: 28,
                  fontWeight: FontWeight.w900, color: context.textPrimary)),
              const SizedBox(height: 8),

              // Numéro de téléphone affiché
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: context.bgColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.borderColor),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.phone_rounded, size: 16, color: context.textSecondary),
                  const SizedBox(width: 8),
                  Text(_phone, style: TextStyle(
                      fontFamily: 'Nunito', fontSize: 16,
                      fontWeight: FontWeight.w700, color: context.textPrimary)),
                ]),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => context.go('/onboarding'),
                style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                child: Text('Utiliser un autre compte',
                  style: TextStyle(fontFamily: 'Nunito', fontSize: 12,
                      fontWeight: FontWeight.w600, color: context.textSecondary)),
              ),
              const SizedBox(height: 36),

              Text('Entrez votre code PIN', style: TextStyle(
                  fontFamily: 'Nunito', fontSize: 15,
                  fontWeight: FontWeight.w700, color: context.textPrimary)),
              const SizedBox(height: 20),

              // Saisie PIN
              Pinput(
                controller: _pinCtrl,
                length: AppConstants.pinLength,
                obscureText: true,
                autofocus: true,
                defaultPinTheme: pt,
                focusedPinTheme: pt.copyDecorationWith(
                    border: Border.all(color: AppColors.primary, width: 2.5)),
                errorPinTheme: pt.copyDecorationWith(
                    border: Border.all(color: AppColors.danger, width: 2)),
                onCompleted: _loading ? null : _login,
              ),

              if (_error != null) ...[
                const SizedBox(height: 14),
                Text(_error!, textAlign: TextAlign.center, style: const TextStyle(
                    color: AppColors.danger, fontFamily: 'Nunito', fontSize: 13)),
              ],

              if (_loading) ...[
                const SizedBox(height: 20),
                const CircularProgressIndicator(color: AppColors.primary),
              ],

              const Spacer(),

              // Bouton PIN oublié
              TextButton.icon(
                onPressed: _forgotLoading ? null : _forgotPin,
                icon: _forgotLoading
                    ? const SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                    : const Icon(Icons.lock_reset_rounded, size: 16, color: AppColors.primary),
                label: Text(_forgotLoading ? 'Envoi en cours…' : 'PIN oublié ?',
                  style: const TextStyle(
                      fontFamily: 'Nunito', fontWeight: FontWeight.w700,
                      fontSize: 14, color: AppColors.primary)),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
