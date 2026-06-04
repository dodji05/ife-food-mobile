import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:country_picker/country_picker.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/router/route_params.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_colors.dart';
import '../../../core/constants/app_constants.dart';

class PhoneScreen extends ConsumerStatefulWidget {
  final UserRole role;
  const PhoneScreen({super.key, required this.role});
  // F2: Renommé _State → _PhoneScreenState
  @override ConsumerState<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends ConsumerState<PhoneScreen> {
  final _ctrl = TextEditingController();
  Country _country = Country(phoneCode:'229',countryCode:'BJ',e164Sc:0,geographic:true,
      level:1,name:'Bénin',example:'',displayName:'Bénin',
      displayNameNoCountryCode:'Bénin',e164Key:'');
  bool _loading = false;
  String? _error;

  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _send() async {
    final phone = '+${_country.phoneCode}${_ctrl.text.trim()}';
    setState(() { _loading = true; _error = null; });
    try {
      final result = await ref.read(authProvider.notifier).sendOtp(phone, _country.countryCode);
      if (mounted) context.push('/auth/otp', extra: OtpRouteParams(
        phone: phone,
        sessionId: result.sessionId,
        role: widget.role,
        countryCode: _country.countryCode,
        prefillOtp: result.otp,
      ));
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final roleColor = switch (widget.role) {
      UserRole.driver       => AppColors.info,
      UserRole.professional => AppColors.yellow,
      _                     => AppColors.primary,
    };
    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(backgroundColor: context.bgColor, elevation: 0,
          leading: BackButton(color: context.textPrimary)),
      body: Column(children: [
        Expanded(child: SafeArea(bottom: false, child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badge rôle
          Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(color: roleColor.withOpacity(0.10),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: roleColor.withOpacity(0.3))),
            child: Text(widget.role.emoji + ' ' + widget.role.label,
              style: TextStyle(fontFamily: 'Nunito', fontSize: 12,
                  fontWeight: FontWeight.w700, color: roleColor))),
          const SizedBox(height: 16),
          Text('Votre numéro', style: TextStyle(fontFamily: 'Nunito',
              fontSize: 26, fontWeight: FontWeight.w900, color: context.textPrimary)),
          const SizedBox(height: 6),
          Text('Nous vous enverrons un code de vérification.',
            style: TextStyle(fontFamily: 'Nunito', fontSize: 14, color: context.textSecondary)),
          const SizedBox(height: 32),
          Container(
            decoration: BoxDecoration(color: context.cardColor, borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.borderColor)),
            child: Row(children: [
              GestureDetector(
                onTap: () => showCountryPicker(context: context, showPhoneCode: true,
                    onSelect: (c) => setState(() => _country = c)),
                child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Row(children: [
                    Text(_country.flagEmoji, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 6),
                    Text('+${_country.phoneCode}', style: const TextStyle(
                        fontFamily: 'Nunito', fontSize: 17, fontWeight: FontWeight.w700)),
                    Icon(Icons.keyboard_arrow_down, size: 18, color: context.textSecondary),
                  ])),
              ),
              Container(width: 1, height: 28, color: context.borderColor),
              Expanded(child: TextField(
                controller: _ctrl, keyboardType: TextInputType.phone, autofocus: true,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(fontFamily: 'Nunito', fontSize: 18, fontWeight: FontWeight.w700),
                decoration: const InputDecoration(
                  hintText: 'Numéro local', border: InputBorder.none,
                  enabledBorder: InputBorder.none, focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16)),
              )),
            ]),
          ),
          if (_error != null) ...[const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: AppColors.danger,
                fontFamily: 'Nunito', fontSize: 13))],
        ],
      )))),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: ElevatedButton(
              onPressed: (_loading || _ctrl.text.trim().isEmpty) ? null : _send,
              style: ElevatedButton.styleFrom(backgroundColor: roleColor),
              child: _loading
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Recevoir le code'),
            ),
          ),
        ),
      ]),
    );
  }
}
