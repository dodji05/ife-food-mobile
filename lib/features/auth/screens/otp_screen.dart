import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';
import 'dart:async';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';

class OtpScreen extends ConsumerStatefulWidget {
  final String phone, sessionId, countryCode;
  final UserRole role;
  final String? prefillOtp; // renvoyé par le backend en mode dev/test
  const OtpScreen({
    super.key,
    required this.phone,
    required this.sessionId,
    required this.countryCode,
    required this.role,
    this.prefillOtp,
  });
  @override ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _ctrl = TextEditingController();
  int _countdown = AppConstants.otpResendSec;
  Timer? _timer;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startTimer();
    // Auto-remplissage si le backend renvoie l'OTP directement (mode dev/test)
    if (widget.prefillOtp != null) {
      // Vérification immédiate sans délai — le délai de 400ms laissait
      // le temps au GoRouter redirect de démonter l'écran avant que
      // _verify() soit appelé, résultant en aucune requête serveur.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _ctrl.text = widget.prefillOtp!;
        _verify(widget.prefillOtp!);
      });
    }
  }

  void _startTimer() {
    _countdown = AppConstants.otpResendSec;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_countdown <= 0) t.cancel(); else setState(() => _countdown--);
    });
  }

  @override
  void dispose() { _timer?.cancel(); _ctrl.dispose(); super.dispose(); }

  Future<void> _verify(String code) async {
    if (code.length != AppConstants.otpLength) return;
    setState(() { _loading = true; _error = null; });
    try {
      final isNew = await ref.read(authProvider.notifier).verifyOtp(
          phone: widget.phone, code: code,
          sessionId: widget.sessionId, role: widget.role);
      if (!mounted) return;
      if (isNew) {
        context.go('/auth/pin', extra: {'mode': 'set', 'phone': widget.phone});
      } else {
        context.go('/auth/pin', extra: {'mode': 'login', 'phone': widget.phone});
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _loading = false;
      });
      _ctrl.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pt = PinTheme(
      width: 54, height: 60,
      textStyle: const TextStyle(
          fontFamily: 'Nunito', fontSize: 24, fontWeight: FontWeight.w900),
      decoration: BoxDecoration(
          color: AppColors.lightBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.lightBorder, width: 1.5)));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
          backgroundColor: Colors.white, elevation: 0,
          leading: const BackButton(color: AppColors.nearBlack)),
      body: SafeArea(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Code de vérification', style: TextStyle(
              fontFamily: 'Nunito', fontSize: 26, fontWeight: FontWeight.w900,
              color: AppColors.nearBlack)),
          const SizedBox(height: 6),
          Text('Envoyé au ${widget.phone}', style: const TextStyle(
              fontFamily: 'Nunito', fontSize: 14, color: AppColors.lightSubtext)),
          const SizedBox(height: 40),
          Center(child: Pinput(
            controller: _ctrl,
            length: AppConstants.otpLength,
            autofocus: widget.prefillOtp == null,
            // Lecture automatique du SMS entrant (affiche une dialog Android)
            androidSmsAutofillMethod: AndroidSmsAutofillMethod.smsUserConsentApi,
            defaultPinTheme: pt,
            focusedPinTheme: pt.copyDecorationWith(
                border: Border.all(color: AppColors.primary, width: 2.5)),
            submittedPinTheme: pt.copyDecorationWith(
                border: Border.all(color: AppColors.success, width: 2)),
            onCompleted: _verify,
          )),
          if (_loading) ...[
            const SizedBox(height: 24),
            const Center(child: CircularProgressIndicator(color: AppColors.primary)),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            Center(child: Text(_error!, style: const TextStyle(
                color: AppColors.danger, fontFamily: 'Nunito', fontSize: 13))),
          ],
          const SizedBox(height: 24),
          Center(child: _countdown > 0
            ? Text('Renvoyer dans ${_countdown}s', style: const TextStyle(
                fontFamily: 'Nunito', fontSize: 13, color: AppColors.lightSubtext))
            : TextButton(
                onPressed: () async {
                  _startTimer();
                  final result = await ref.read(authProvider.notifier)
                      .sendOtp(widget.phone, widget.countryCode);
                  if (result.otp != null && mounted) {
                    _ctrl.text = result.otp!;
                    _verify(result.otp!);
                  }
                },
                child: const Text('Renvoyer le code', style: TextStyle(
                    fontFamily: 'Nunito', fontWeight: FontWeight.w700,
                    color: AppColors.primary)))),
          const Spacer(),
        ]),
      )),
    );
  }
}
