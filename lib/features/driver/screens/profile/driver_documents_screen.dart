import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_colors.dart';
import '../../providers/driver_provider.dart';

final _driverDocsProvider = FutureProvider.autoDispose<List<_DocEntry>>((ref) async {
  final res = await ApiClient.instance.get('/drivers/me/documents');
  final list = res['data'] as List? ?? [];
  return list.whereType<Map<String, dynamic>>().map(_DocEntry.fromJson).toList();
});

class DriverDocumentsScreen extends ConsumerStatefulWidget {
  // true = étape d'onboarding (juste après le choix du véhicule) : pas de
  // bouton retour, bouton "Continuer" bloquant tant que tous les documents
  // requis ne sont pas uploadés. false = accès libre depuis le profil.
  final bool isOnboarding;
  const DriverDocumentsScreen({super.key, this.isOnboarding = false});
  @override
  ConsumerState<DriverDocumentsScreen> createState() => _State();
}

class _State extends ConsumerState<DriverDocumentsScreen> {
  final Set<String> _uploading = {};

  // Catalogue complet — le sous-ensemble réellement affiché dépend du
  // véhicule du livreur (voir Driver.requiredDocumentTypes).
  static const _allDocTypes = {
    'ID_CARD':        _DocTypeInfo('ID_CARD',        'Pièce d\'identité',     Icons.credit_card_rounded),
    'DRIVER_LICENSE': _DocTypeInfo('DRIVER_LICENSE', 'Permis de conduire',    Icons.drive_eta_rounded),
    'INSURANCE_PROOF':_DocTypeInfo('INSURANCE_PROOF','Justificatif d\'assurance', Icons.shield_rounded),
  };

  Future<void> _upload(String docType) async {
    final choice = await showModalBottomSheet<_UploadChoice>(
      context: context,
      backgroundColor: context.cardColor,
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          leading: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
          title: Text('Galerie photo', style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700, color: context.textPrimary)),
          onTap: () => Navigator.pop(context, _UploadChoice.gallery),
        ),
        ListTile(
          leading: const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
          title: Text('Caméra', style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700, color: context.textPrimary)),
          onTap: () => Navigator.pop(context, _UploadChoice.camera),
        ),
        ListTile(
          leading: const Icon(Icons.picture_as_pdf_rounded, color: AppColors.primary),
          title: Text('Fichier PDF', style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700, color: context.textPrimary)),
          onTap: () => Navigator.pop(context, _UploadChoice.pdf),
        ),
        const SizedBox(height: 8),
      ])),
    );
    if (choice == null || !mounted) return;

    File? file;
    String filename = '${docType.toLowerCase()}';

    try {
      if (choice == _UploadChoice.pdf) {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf'],
        );
        if (result == null || result.files.single.path == null) return;
        file = File(result.files.single.path!);
        filename = '$filename.pdf';
      } else {
        final src = choice == _UploadChoice.camera ? ImageSource.camera : ImageSource.gallery;
        final picked = await ImagePicker().pickImage(source: src, maxWidth: 1600, imageQuality: 88);
        if (picked == null) return;
        file = File(picked.path);
        filename = '$filename.jpg';
      }
    } catch (e) {
      if (mounted) _snack('Impossible d\'accéder au fichier', error: true);
      return;
    }

    setState(() => _uploading.add(docType));
    try {
      final contentType = filename.endsWith('.pdf') ? 'application/pdf' : 'image/jpeg';
      final formData = FormData.fromMap({
        'file':    await MultipartFile.fromFile(file.path, filename: filename,
            contentType: MediaType.parse(contentType)),
        'docType': docType,
      });
      await ApiClient.instance.post('/drivers/me/documents', data: formData);
      if (!mounted) return;
      ref.invalidate(_driverDocsProvider);
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
    final async = ref.watch(_driverDocsProvider);
    final driver = ref.watch(driverProvider).driver;
    // Fallback ID_CARD si le profil driver n'est pas encore chargé — mieux
    // vaut demander une pièce d'identité par défaut que rien du tout.
    final requiredTypes = driver?.requiredDocumentTypes ?? ['ID_CARD'];
    final docTypes = requiredTypes
        .map((t) => _allDocTypes[t])
        .whereType<_DocTypeInfo>()
        .toList();
    // Tous les documents requis sont-ils uploadés ? (utilisé pour débloquer
    // le bouton "Continuer" en mode onboarding)
    final allUploaded = async.maybeWhen(
      data: (docs) {
        final uploadedTypes = docs.map((d) => d.type).toSet();
        return docTypes.every((info) => uploadedTypes.contains(info.type));
      },
      orElse: () => false,
    );
    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        title: const Text('Mes documents'),
        leading: widget.isOnboarding ? null : const BackButton(),
        automaticallyImplyLeading: !widget.isOnboarding,
      ),
      bottomNavigationBar: widget.isOnboarding ? SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ElevatedButton(
              // Signale au redirect (app_router.dart, section b2) que
              // l'étape driver est terminée — pas de context.go() manuel,
              // ça évite la race avec GoRouterRefreshStream (cf. AuthNotifier).
              onPressed: allUploaded
                  ? () => ref.read(authProvider.notifier).markRoleSetupDone()
                  : null,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Continuer',
                style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800, fontSize: 15)),
            ),
            const SizedBox(height: 8),
            Text(
              allUploaded
                  ? 'Votre dossier sera vérifié sous 24h'
                  : 'Tous les documents ci-dessus sont obligatoires',
              style: TextStyle(fontFamily: 'Nunito', fontSize: 12, color: context.textMuted),
            ),
          ]),
        ),
      ) : null,
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
                  'Ces documents sont utilisés pour valider votre compte livreur. Formats acceptés : JPG, PNG, PDF (max 10 Mo).',
                  style: TextStyle(fontFamily: 'Nunito', fontSize: 12, color: AppColors.info, height: 1.4),
                )),
              ]),
            ),
            ...docTypes.map((info) {
              final existing  = byType[info.type];
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
  final _DocTypeInfo  info;
  final _DocEntry?    existing;
  final bool          uploading;
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
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: AppColors.primary.withOpacity(0.12),
          ),
          clipBehavior: Clip.antiAlias,
          child: hasDoc && existing!.url.isNotEmpty && !existing!.url.endsWith('.pdf')
              ? CachedNetworkImage(imageUrl: existing!.url, fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Icon(info.icon, color: AppColors.primary, size: 22))
              : Icon(
                  hasDoc && existing!.url.endsWith('.pdf')
                      ? Icons.picture_as_pdf_rounded
                      : info.icon,
                  color: AppColors.primary, size: 22,
                ),
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
            Text('Non fourni',
              style: TextStyle(fontFamily: 'Nunito', fontSize: 12, color: context.textSecondary)),
        ])),
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
                ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                : Icon(hasDoc ? Icons.refresh_rounded : Icons.upload_rounded,
                    color: AppColors.primary, size: 18),
          ),
        ),
      ]),
    );
  }
}

// ── Modèles internes ───────────────────────────────────────────────────────────
enum _UploadChoice { gallery, camera, pdf }

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
