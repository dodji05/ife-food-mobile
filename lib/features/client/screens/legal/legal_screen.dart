import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
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
  late final WebViewController _controller;
  bool   _loading = true;
  bool   _error   = false;

  @override
  void initState() {
    super.initState();
    final url = '${AppConstants.adminUrl}/legal/${legalSlug(widget.type)}';
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_)  => setState(() { _loading = true;  _error = false; }),
        onPageFinished: (_) => setState(() { _loading = false; }),
        onWebResourceError: (_) => setState(() { _loading = false; _error = true; }),
        onNavigationRequest: (req) {
          // Empêche de naviguer vers d'autres domaines depuis la page légale.
          final allowed = req.url.startsWith(AppConstants.adminUrl) ||
                          req.url.startsWith('about:');
          return allowed
              ? NavigationDecision.navigate
              : NavigationDecision.prevent;
        },
      ))
      ..loadRequest(Uri.parse(url));
  }

  Future<void> _openInBrowser() async {
    final uri = Uri.parse('${AppConstants.adminUrl}/legal/${legalSlug(widget.type)}');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
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
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_browser_rounded),
            tooltip: 'Ouvrir dans le navigateur',
            onPressed: _openInBrowser,
          ),
        ],
      ),
      body: Stack(children: [

        // ── WebView ──────────────────────────────────────────────────────────
        if (!_error) WebViewWidget(controller: _controller),

        // ── Spinner pendant le chargement ────────────────────────────────────
        if (_loading && !_error)
          const Center(child: CircularProgressIndicator(color: AppColors.primary)),

        // ── Écran d'erreur ───────────────────────────────────────────────────
        if (_error)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.danger.withOpacity(0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 34, color: AppColors.danger),
                ),
                const SizedBox(height: 20),
                Text(label,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Nunito', fontSize: 18,
                    fontWeight: FontWeight.w900, color: context.textPrimary)),
                const SizedBox(height: 10),
                Text('Impossible de charger ce document.\nVérifiez votre connexion.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Nunito', fontSize: 13,
                    color: context.textSecondary, height: 1.5)),
                const SizedBox(height: 24),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() => _error = false);
                      final url = '${AppConstants.adminUrl}/legal/${legalSlug(widget.type)}';
                      _controller.loadRequest(Uri.parse(url));
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Réessayer',
                      style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _openInBrowser,
                    icon: const Icon(Icons.open_in_browser_rounded, size: 16),
                    label: const Text('Navigateur',
                      style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700, fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ]),
              ]),
            ),
          ),
      ]),
    );
  }
}
