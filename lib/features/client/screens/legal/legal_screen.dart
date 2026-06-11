import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_colors.dart';

// ── Helpers publics ────────────────────────────────────────────────────────────

String legalSlug(String type) => switch (type.toUpperCase()) {
  'CGU'            => 'cgu',
  'CGV'            => 'cgv',
  'PRIVACY'        => 'privacy',
  'ABOUT'          => 'about',
  'DRIVER_CHARTER' => 'driver-charter',
  'PRO_CHARTER'    => 'pro-charter',
  _                => type.toLowerCase(),
};

String legalLabel(String type) => switch (type.toUpperCase()) {
  'CGU'            => "Conditions d'utilisation",
  'CGV'            => 'Conditions de vente',
  'PRIVACY'        => 'Politique de confidentialité',
  'ABOUT'          => 'À propos',
  'DRIVER_CHARTER' => 'Charte livreur',
  'PRO_CHARTER'    => 'Charte professionnel',
  _                => type,
};

IconData legalIcon(String type) => switch (type.toUpperCase()) {
  'CGU'            => Icons.gavel_rounded,
  'CGV'            => Icons.receipt_long_rounded,
  'PRIVACY'        => Icons.privacy_tip_rounded,
  'ABOUT'          => Icons.info_rounded,
  'DRIVER_CHARTER' => Icons.two_wheeler_rounded,
  'PRO_CHARTER'    => Icons.store_rounded,
  _                => Icons.description_rounded,
};

Future<void> openLegalPage(String type) async {
  final uri = Uri.parse('${AppConstants.adminUrl}/legal/${legalSlug(type)}');
  await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
}

// ── Widget ─────────────────────────────────────────────────────────────────────

class LegalScreen extends StatefulWidget {
  final String type;
  const LegalScreen({super.key, required this.type});
  @override State<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends State<LegalScreen> {
  bool _loading = true;
  bool _error   = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  Future<void> _open() async {
    setState(() { _loading = true; _error = false; });
    try {
      final uri = Uri.parse('${AppConstants.adminUrl}/legal/${legalSlug(widget.type)}');
      final ok  = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      if (!mounted) return;
      if (ok) {
        // Navigateur ouvert — on dépile cet écran pour qu'à la fermeture
        // du navigateur l'utilisateur revienne directement sur l'app
        Navigator.of(context).pop();
      } else {
        setState(() { _loading = false; _error = true; });
      }
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = legalLabel(widget.type);
    final icon  = legalIcon(widget.type);

    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        title: Text(label,
          style: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800)),
        leading: const BackButton(),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(mainAxisSize: MainAxisSize.min, children: [

            // Icône du document
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 38, color: AppColors.primary),
            ),
            const SizedBox(height: 24),

            Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Nunito', fontSize: 20,
                fontWeight: FontWeight.w900, color: context.textPrimary)),
            const SizedBox(height: 10),

            if (_loading) ...[
              const SizedBox(height: 8),
              const SizedBox(
                width: 24, height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary),
              ),
              const SizedBox(height: 12),
              Text('Ouverture en cours…',
                style: TextStyle(fontFamily: 'Nunito', fontSize: 13, color: context.textMuted)),
            ] else if (_error) ...[
              const SizedBox(height: 8),
              Text('Impossible d\'ouvrir ce document.\nVérifiez votre connexion.',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Nunito', fontSize: 13,
                  color: context.textSecondary, height: 1.5)),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _open,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Réessayer',
                  style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ] else ...[
              // Navigateur ouvert — affiche un bouton pour rouvrir si besoin
              Text('Document ouvert dans le navigateur.',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Nunito', fontSize: 13, color: context.textMuted)),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: _open,
                icon: const Icon(Icons.open_in_browser_rounded, size: 16),
                label: const Text('Rouvrir',
                  style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700, fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}
