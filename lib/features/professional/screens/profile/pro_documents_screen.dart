import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_colors.dart';

// Provider pour les documents du pro
final _docsProvider = FutureProvider.autoDispose<List<_DocEntry>>((ref) async {
  final res = await ApiClient.instance.get('/professionals/me/documents');
  final list = res['data'] as List? ?? [];
  return list.whereType<Map<String, dynamic>>().map(_DocEntry.fromJson).toList();
});

class ProDocumentsScreen extends ConsumerStatefulWidget {
  const ProDocumentsScreen({super.key});
  @override
  ConsumerState<ProDocumentsScreen> createState() => _State();
}

class _State extends ConsumerState<ProDocumentsScreen> {
  // Suivi des uploads en cours par type
  final Set<String> _uploading = {};

  static const _docTypes = [
    _DocTypeInfo('ID_FRONT',     'Pièce d\'identité recto', Icons.credit_card_rounded),
    _DocTypeInfo('ID_BACK',      'Pièce d\'identité verso', Icons.credit_card_rounded),
    _DocTypeInfo('BUSINESS_REG', 'Registre de commerce (RCCM)', Icons.business_center_rounded),
    _DocTypeInfo('TAX_CERT',     'Attestation fiscale', Icons.receipt_long_rounded),
  ];

  Future<void> _upload(String docType) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: context.cardColor,
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          leading: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
          title: Text('Galerie', style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700, color: context.textPrimary)),
          onTap: () => Navigator.pop(context, ImageSource.gallery),
        ),
        ListTile(
          leading: const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
          title: Text('Caméra', style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700, color: context.textPrimary)),
          onTap: () => Navigator.pop(context, ImageSource.camera),
        ),
        const SizedBox(height: 8),
      ])),
    );
    if (source == null || !mounted) return;

    File? file;
    try {
      final picked = await ImagePicker().pickImage(source: source, maxWidth: 1600, imageQuality: 88);
      if (picked == null) return;
      file = File(picked.path);
    } catch (e) {
      if (mounted) _snack('Impossible d\'accéder à l\'image', error: true);
      return;
    }

    setState(() => _uploading.add(docType));
    try {
      final formData = FormData.fromMap({
        'file':    await MultipartFile.fromFile(file.path, filename: '${docType.toLowerCase()}.jpg'),
        'docType': docType,
      });
      await ApiClient.instance.post('/professionals/me/documents', data: formData);
      if (!mounted) return;
      ref.invalidate(_docsProvider);
      _snack('Document envoyé avec succès');
    } catch (e) {
      if (mounted) _snack(e.toString().replaceAll('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _uploading.remove(docType));
    }
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w600)),
      backgroundColor: error ? AppColors.danger : AppColors.success,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_docsProvider);
    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        title: const Text('Mes documents'),
        leading: BackButton(
          onPressed: () => context.canPop() ? context.pop() : context.go('/pro/profile'),
        ),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error:   (e, _) => Center(child: Text(e.toString())),
        data: (docs) {
          final byType = { for (final d in docs) d.type: d };
          return ListView(padding: const EdgeInsets.all(16), children: [
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.info.withOpacity(0.25)),
              ),
              child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.info_outline_rounded, size: 16, color: AppColors.info),
                SizedBox(width: 8),
                Expanded(child: Text(
                  'Ces documents sont utilisés uniquement pour valider votre compte. Formats acceptés : JPG, PNG, PDF (max 10 Mo).',
                  style: TextStyle(fontFamily: 'Nunito', fontSize: 12, color: AppColors.info, height: 1.4),
                )),
              ]),
            ),
            ..._docTypes.map((info) {
              final existing = byType[info.type];
              final uploading = _uploading.contains(info.type);
              return _DocCard(
                info:      info,
                existing:  existing,
                uploading: uploading,
                onUpload:  uploading ? null : () => _upload(info.type),
              );
            }),
            const SizedBox(height: 40),
          ]);
        },
      ),
    );
  }
}

// ── Carte document ─────────────────────────────────────────────────────────────
class _DocCard extends StatelessWidget {
  final _DocTypeInfo info;
  final _DocEntry? existing;
  final bool uploading;
  final VoidCallback? onUpload;
  const _DocCard({required this.info, this.existing, required this.uploading, this.onUpload});

  @override
  Widget build(BuildContext context) {
    final hasDoc = existing != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: hasDoc ? AppColors.primary.withOpacity(0.25) : context.borderColor),
      ),
      child: Row(children: [
        // Icône ou aperçu
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(10),
            color: AppColors.primary.withOpacity(0.12)),
          clipBehavior: Clip.antiAlias,
          child: hasDoc && existing!.url.isNotEmpty
              ? CachedNetworkImage(imageUrl: existing!.url, fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Icon(info.icon, color: AppColors.primary, size: 22))
              : Icon(info.icon, color: AppColors.primary, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(info.label,
            style: TextStyle(fontFamily: 'Nunito', fontSize: 14, fontWeight: FontWeight.w700, color: context.textPrimary)),
          const SizedBox(height: 4),
          if (hasDoc) ...[
            Row(children: [
              Icon(
                existing!.verified ? Icons.verified_rounded : Icons.hourglass_empty_rounded,
                size: 13,
                color: existing!.verified ? AppColors.success : AppColors.warning,
              ),
              const SizedBox(width: 4),
              Text(
                existing!.verified ? 'Vérifié' : 'En attente de vérification',
                style: TextStyle(
                  fontFamily: 'Nunito', fontSize: 11, fontWeight: FontWeight.w600,
                  color: existing!.verified ? AppColors.success : AppColors.warning,
                ),
              ),
            ]),
          ] else
            Text('Non fourni', style: TextStyle(fontFamily: 'Nunito', fontSize: 12, color: context.textSecondary)),
        ])),
        // Bouton upload
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onUpload,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
            ),
            child: uploading
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                : Icon(hasDoc ? Icons.refresh_rounded : Icons.upload_rounded, color: AppColors.primary, size: 18),
          ),
        ),
      ]),
    );
  }
}

// ── Modèles internes ───────────────────────────────────────────────────────────
class _DocTypeInfo {
  final String type, label;
  final IconData icon;
  const _DocTypeInfo(this.type, this.label, this.icon);
}

class _DocEntry {
  final String id, type, url;
  final bool verified;
  const _DocEntry({required this.id, required this.type, required this.url, required this.verified});
  factory _DocEntry.fromJson(Map<String, dynamic> j) => _DocEntry(
    id:       j['id']       as String? ?? '',
    type:     j['type']     as String? ?? '',
    url:      j['url']      as String? ?? '',
    verified: j['verified'] as bool?   ?? false,
  );
}
