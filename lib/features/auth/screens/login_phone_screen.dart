import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:country_picker/country_picker.dart';
import '../../../core/api/api_client.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
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
  bool _loading = false;
  String? _errorMsg;

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
    setState(() { _loading = true; _errorMsg = null; });
    try {
      final res = await ApiClient.instance.get('/auth/exists', params: {'phone': phone});
      final exists = res['exists'] == true || (res['data'] as Map?)?['exists'] == true;
      if (!mounted) return;
      if (!exists) {
        setState(() {
          _loading = false;
          _errorMsg = 'Ce numéro n\'est pas associé à un compte.';
        });
        return;
      }
      await ref.read(authProvider.notifier).savePhone(phone, _country.countryCode);
      if (mounted) context.go('/login');
    } catch (_) {
      if (mounted) setState(() { _loading = false; _errorMsg = 'Erreur réseau. Vérifiez votre connexion.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _ctrl.text.trim().isNotEmpty && !_loading;
    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.bgColor,
        elevation: 0,
        leading: BackButton(color: context.textPrimary),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: ElevatedButton(
            onPressed: canSubmit ? _continue : null,
            child: _loading
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Continuer'),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
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
                    onChanged: (_) => setState(() { _errorMsg = null; }),
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
              if (_errorMsg != null) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.danger.withOpacity(0.25)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.info_outline_rounded, color: AppColors.danger, size: 18),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_errorMsg!,
                      style: const TextStyle(fontFamily: 'Nunito', fontSize: 13,
                          fontWeight: FontWeight.w600, color: AppColors.danger, height: 1.4))),
                  ]),
                ),
                const SizedBox(height: 16),
                SizedBox(width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => context.push('/auth/role'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Créer un compte',
                      style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700, fontSize: 14)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
