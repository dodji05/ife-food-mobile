import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:country_picker/country_picker.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/theme_colors.dart';

/// Saisie du numéro de téléphone pour les utilisateurs existants.
/// Pas d'envoi OTP — on navigue directement vers le PIN.
class LoginPhoneScreen extends ConsumerStatefulWidget {
  const LoginPhoneScreen({super.key});
  @override
  ConsumerState<LoginPhoneScreen> createState() => _LoginPhoneScreenState();
}

class _LoginPhoneScreenState extends ConsumerState<LoginPhoneScreen> {
  final _ctrl = TextEditingController();
  Country _country = Country(
    phoneCode: '229', countryCode: 'BJ', e164Sc: 0, geographic: true,
    level: 1, name: 'Bénin', example: '', displayName: 'Bénin',
    displayNameNoCountryCode: 'Bénin', e164Key: '',
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final phone = '+${_country.phoneCode}${_ctrl.text.trim()}';
    await ref.read(authProvider.notifier).savePhone(phone, _country.countryCode);
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _ctrl.text.trim().isNotEmpty;
    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.bgColor,
        elevation: 0,
        leading: BackButton(color: context.textPrimary),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Votre numéro', style: TextStyle(
                  fontFamily: 'Nunito', fontSize: 26,
                  fontWeight: FontWeight.w900, color: context.textPrimary)),
              const SizedBox(height: 6),
              Text('Entrez le numéro associé à votre compte.',
                  style: TextStyle(fontFamily: 'Nunito', fontSize: 14,
                      color: context.textSecondary)),
              const SizedBox(height: 32),
              Container(
                decoration: BoxDecoration(
                  color: context.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.borderColor),
                ),
                child: Row(children: [
                  GestureDetector(
                    onTap: () => showCountryPicker(
                      context: context,
                      showPhoneCode: true,
                      onSelect: (c) => setState(() => _country = c),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      child: Row(children: [
                        Text(_country.flagEmoji, style: const TextStyle(fontSize: 22)),
                        const SizedBox(width: 6),
                        Text('+${_country.phoneCode}', style: const TextStyle(
                            fontFamily: 'Nunito', fontSize: 17, fontWeight: FontWeight.w700)),
                        Icon(Icons.keyboard_arrow_down, size: 18, color: context.textSecondary),
                      ]),
                    ),
                  ),
                  Container(width: 1, height: 28, color: context.borderColor),
                  Expanded(child: TextField(
                    controller: _ctrl,
                    keyboardType: TextInputType.phone,
                    autofocus: true,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) { if (canSubmit) _continue(); },
                    style: const TextStyle(
                        fontFamily: 'Nunito', fontSize: 18, fontWeight: FontWeight.w700),
                    decoration: const InputDecoration(
                      hintText: 'Numéro local',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                  )),
                ]),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: canSubmit ? _continue : null,
                child: const Text('Continuer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
