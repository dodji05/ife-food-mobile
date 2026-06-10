// ─────────────────────────────────────────────────────────────────────────────
// ifè FOOD — Parrainage (vue pro)
//
// Affiche le code de parrainage du pro, son QR code et un bouton de partage.
// Le code est généré côté backend au premier appel GET /users/me/referral-code.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_colors.dart';
import '../../providers/pro_provider.dart';

class ProReferralScreen extends ConsumerWidget {
  const ProReferralScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncCode = ref.watch(referralCodeProvider);
    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(title: const Text('Mon code de parrainage')),
      body: asyncCode.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => _ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(referralCodeProvider),
        ),
        data: (code) => code.isEmpty
            ? _ErrorState(
                message: 'Impossible de générer votre code.',
                onRetry: () => ref.invalidate(referralCodeProvider),
              )
            : _ReferralBody(code: code),
      ),
    );
  }
}

class _ReferralBody extends StatelessWidget {
  final String code;
  const _ReferralBody({required this.code});

  /// Lien de parrainage partageable (deep-link universel IFE FOOD).
  String get _link => 'https://ifefood.app/referral/$code';

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
        // ── Titre ──────────────────────────────────────────────────────────
        Text('Partagez votre code',
          style: TextStyle(fontFamily: 'Nunito', fontSize: 22,
              fontWeight: FontWeight.w900, color: context.textPrimary)),
        const SizedBox(height: 8),
        Text(
          'Invitez vos clients et partenaires à rejoindre ifè FOOD '
          'avec votre lien personnel.',
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Nunito', fontSize: 14,
              color: context.textSecondary, height: 1.4)),
        const SizedBox(height: 36),

        // ── Code en grand ──────────────────────────────────────────────────
        GestureDetector(
          onTap: () => _copyCode(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withOpacity(0.5), width: 2),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(code,
                style: const TextStyle(
                  fontFamily: 'Nunito', fontSize: 28, fontWeight: FontWeight.w900,
                  color: AppColors.primary, letterSpacing: 4)),
              const SizedBox(width: 12),
              const Icon(Icons.copy_rounded, color: AppColors.primary, size: 22),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        Text('Toucher pour copier',
          style: TextStyle(fontFamily: 'Nunito', fontSize: 11, color: context.textMuted)),
        const SizedBox(height: 36),

        // ── QR Code ────────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.15),
                blurRadius: 16, offset: const Offset(0, 4)),
            ],
          ),
          child: QrImageView(
            data: _link,
            version: QrVersions.auto,
            size: 200,
            backgroundColor: Colors.white,
          ),
        ),
        const SizedBox(height: 10),
        Text(_link,
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Nunito', fontSize: 11,
              color: context.textMuted, letterSpacing: 0.3)),
        const SizedBox(height: 36),

        // ── Boutons partage ────────────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _share(),
            icon: const Icon(Icons.share_rounded, color: Colors.white, size: 20),
            label: const Text('Partager mon lien',
              style: TextStyle(fontFamily: 'Nunito', fontSize: 15,
                  fontWeight: FontWeight.w800, color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _copyCode(context),
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copier le code',
              style: TextStyle(fontFamily: 'Nunito', fontSize: 14, fontWeight: FontWeight.w700)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(height: 32),

        // ── Info parrainage ────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.borderColor),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Comment ça marche ?',
              style: TextStyle(fontFamily: 'Nunito', fontSize: 14,
                  fontWeight: FontWeight.w900, color: context.textPrimary)),
            SizedBox(height: 10),
            _InfoRow(Icons.share_rounded,
              'Partagez votre lien à vos clients ou partenaires'),
            SizedBox(height: 8),
            _InfoRow(Icons.person_add_rounded,
              'Ils s\'inscrivent sur ifè FOOD via votre code'),
            SizedBox(height: 8),
            _InfoRow(Icons.wallet_rounded,
              'Vous recevez une récompense à leur première commande'),
          ]),
        ),
      ]),
    );
  }

  void _copyCode(BuildContext context) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Code copié dans le presse-papier'),
      backgroundColor: AppColors.success,
      duration: Duration(seconds: 2),
    ));
  }

  void _share() {
    Share.share(
      'Rejoignez ifè FOOD avec mon code de parrainage : $code\n$_link',
      subject: 'Rejoignez ifè FOOD — code $code',
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow(this.icon, this.text);
  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Icon(icon, size: 16, color: AppColors.primary),
    const SizedBox(width: 10),
    Expanded(child: Text(text,
      style: TextStyle(fontFamily: 'Nunito', fontSize: 13,
          fontWeight: FontWeight.w600, color: context.textSecondary))),
  ]);
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.danger),
      const SizedBox(height: 12),
      Text(message,
        textAlign: TextAlign.center,
        style: TextStyle(fontFamily: 'Nunito', fontSize: 13, color: context.textSecondary)),
      const SizedBox(height: 16),
      ElevatedButton(onPressed: onRetry,
        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
        child: const Text('Réessayer',
          style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700, color: Colors.white))),
    ],
  ));
}
