import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_colors.dart';

final _legalProvider = FutureProvider.autoDispose.family<Map<String, dynamic>?, String>((ref, type) async {
  try {
    final res = await ApiClient.instance.get('/config/legal/$type/fr');
    return res['data'] as Map<String, dynamic>?;
  } catch (_) { return null; }
});

// ── Public helpers ─────────────────────────────────────────────────────────────

/// Ouvre une page légale dans le navigateur intégré (SFSafari / Chrome Custom Tab).
/// Retourne false si l'URL ne peut pas être ouverte.
Future<bool> openLegalPage(String type) async {
  final slug = _legalSlug(type);
  final uri = Uri.parse('${AppConstants.adminUrl}/legal/$slug');
  try {
    return launchUrl(uri, mode: LaunchMode.inAppBrowserView);
  } catch (_) { return false; }
}

String _legalSlug(String type) => switch (type.toUpperCase()) {
  'CGU'            => 'cgu',
  'CGV'            => 'cgv',
  'PRIVACY'        => 'privacy',
  'ABOUT'          => 'about',
  'DRIVER_CHARTER' => 'driver-charter',
  'PRO_CHARTER'    => 'pro-charter',
  _                => type.toLowerCase(),
};

String _legalLabel(String type) => switch (type.toUpperCase()) {
  'CGU'            => "Conditions d'utilisation",
  'CGV'            => 'Conditions de vente',
  'PRIVACY'        => 'Politique de confidentialité',
  'ABOUT'          => 'À propos',
  'DRIVER_CHARTER' => 'Charte livreur',
  'PRO_CHARTER'    => 'Charte professionnel',
  _                => type,
};

// Retire les balises HTML pour l'affichage natif en fallback.
String _stripHtml(String html) => html
  .replaceAll(RegExp(r'<br\s*/?>',          caseSensitive: false), '\n')
  .replaceAll(RegExp(r'</p>',               caseSensitive: false), '\n\n')
  .replaceAll(RegExp(r'</h[1-6]>',          caseSensitive: false), '\n\n')
  .replaceAll(RegExp(r'</li>',              caseSensitive: false), '\n')
  .replaceAll(RegExp(r'<[^>]+>'),           '')
  .replaceAll(RegExp(r'&nbsp;'),            ' ')
  .replaceAll(RegExp(r'&amp;'),             '&')
  .replaceAll(RegExp(r'&lt;'),              '<')
  .replaceAll(RegExp(r'&gt;'),              '>')
  .replaceAll(RegExp(r'&quot;'),            '"')
  .replaceAll(RegExp(r'&#39;'),             "'")
  .replaceAll(RegExp(r'\n{3,}'),            '\n\n')
  .trim();

// ── Widget ─────────────────────────────────────────────────────────────────────

class LegalScreen extends ConsumerStatefulWidget {
  final String type;
  const LegalScreen({super.key, required this.type});
  @override ConsumerState<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends ConsumerState<LegalScreen> {
  bool _browserOpened = false;

  @override
  void initState() {
    super.initState();
    // Tente d'ouvrir le navigateur intégré dès l'affichage de l'écran.
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryBrowser());
  }

  Future<void> _tryBrowser() async {
    final opened = await openLegalPage(widget.type);
    if (mounted) setState(() => _browserOpened = opened);
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(_legalProvider(widget.type));
    final label = _legalLabel(widget.type);

    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        title: Text(label),
        leading: const BackButton(),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_browser_rounded),
            tooltip: 'Ouvrir dans le navigateur',
            onPressed: _tryBrowser,
          ),
        ],
      ),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (_, __) => _ErrorView(onRetry: () => ref.invalidate(_legalProvider(widget.type))),
        data: (page) {
          if (page == null) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('Contenu non disponible.', style: TextStyle(fontFamily: 'Nunito', fontSize: 15, color: context.textSecondary)),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: _tryBrowser,
                  icon: const Icon(Icons.open_in_browser_rounded, size: 16),
                  label: const Text('Ouvrir dans le navigateur'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                ),
              ]),
            );
          }

          final plainText = _stripHtml(page['content'] as String? ?? '');

          return ListView(padding: const EdgeInsets.all(24), children: [
            // Bandeau "version navigateur disponible" si le browser s'est ouvert
            if (_browserOpened) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Row(children: [
                  const Icon(Icons.check_circle_outline_rounded, color: AppColors.primary, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Page ouverte dans le navigateur intégré.',
                    style: TextStyle(fontFamily: 'Nunito', fontSize: 12, color: context.textSecondary))),
                  GestureDetector(
                    onTap: _tryBrowser,
                    child: Text('Rouvrir', style: const TextStyle(fontFamily: 'Nunito', fontSize: 12,
                      fontWeight: FontWeight.w700, color: AppColors.primary)),
                  ),
                ]),
              ),
              const SizedBox(height: 20),
            ],

            Text(page['title'] as String? ?? label,
              style: TextStyle(fontFamily: 'Nunito', fontSize: 22,
                fontWeight: FontWeight.w900, color: context.textPrimary, height: 1.3)),
            const SizedBox(height: 8),
            if (page['version'] != null)
              Text('Version ${page['version']}',
                style: TextStyle(fontFamily: 'Nunito', fontSize: 11, color: context.textMuted)),
            const SizedBox(height: 20),

            SelectableText(plainText,
              style: TextStyle(fontFamily: 'Nunito', fontSize: 15,
                color: context.textSecondary, height: 1.75)),

            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: _tryBrowser,
              icon: const Icon(Icons.open_in_browser_rounded, size: 16),
              label: const Text('Voir la version mise en forme', style: TextStyle(fontFamily: 'Nunito', fontSize: 13)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 40),
          ]);
        },
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorView({required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.wifi_off_rounded, color: context.textMuted, size: 40),
      const SizedBox(height: 12),
      Text('Impossible de charger cette page.',
        style: TextStyle(fontFamily: 'Nunito', fontSize: 14, color: context.textSecondary)),
      const SizedBox(height: 12),
      TextButton(onPressed: onRetry, child: const Text('Réessayer')),
    ]),
  );
}
