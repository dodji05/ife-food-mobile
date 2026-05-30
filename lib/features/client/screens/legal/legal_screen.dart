import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_colors.dart';

final legalProvider = FutureProvider.autoDispose.family<Map<String, dynamic>?, String>((ref, type) async {
  try {
    final res = await ApiClient.instance.get('/config/legal/$type/fr');
    return res['data'];
  } catch (_) { return null; }
});

class LegalScreen extends ConsumerWidget {
  final String type;
  const LegalScreen({super.key, required this.type});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(legalProvider(type));
    return Scaffold(
      appBar: AppBar(title: Text(_typeLabel(type)), leading: const BackButton()),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(child: Text('Erreur de chargement')),
        data: (page) => page == null
          ? const Center(child: Text('Page introuvable'))
          : ListView(padding: const EdgeInsets.all(24), children: [
              Text(page['title'] ?? '', style: TextStyle(fontFamily: 'Nunito', fontSize: 22, fontWeight: FontWeight.w800, color: context.textPrimary, height: 1.3)),
              const SizedBox(height: 16),
              Text(page['content'] ?? '', style: TextStyle(fontFamily: 'Nunito', fontSize: 15, color: context.textSecondary, height: 1.7)),
              const SizedBox(height: 40),
              Text('Version ${page['version'] ?? '1.0'}', style: TextStyle(fontFamily: 'Nunito', fontSize: 11, color: context.textMuted)),
            ]),
      ),
    );
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'CGU': return "Conditions d'utilisation";
      case 'CGV': return 'Conditions de vente';
      case 'PRIVACY': return 'Confidentialité';
      case 'ABOUT': return 'À propos';
      case 'DRIVER_CHARTER': return 'Charte livreur';
      case 'PRO_CHARTER': return 'Charte professionnel';
      default: return type;
    }
  }
}
