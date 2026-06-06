// ─────────────────────────────────────────────────────────────────────────────
// ifè FOOD — Avatar éditable (client + driver profile)
//
// CircleAvatar + tap pour pickeer image (caméra ou galerie) -> upload via
// authProvider.uploadAvatar(File) -> auto-refresh via PATCH /users/me.
// Le badge caméra discret en bas indique que c'est cliquable.
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_colors.dart';

class EditableAvatar extends ConsumerStatefulWidget {
  final String? currentUrl;
  /// Fallback initiale affichée si pas de photo (typiquement la première
  /// lettre du nom). Le caller la construit lui-même pour rester souple.
  final String fallbackText;
  final double radius;
  /// Couleur du cercle vide. Sur header coloré on passe Colors.white.withOpacity(0.25).
  final Color  backgroundColor;
  /// Couleur du texte fallback. Sur header coloré : Colors.white.
  final Color  textColor;

  const EditableAvatar({
    super.key,
    required this.currentUrl,
    required this.fallbackText,
    this.radius = 30,
    this.backgroundColor = AppColors.primary,
    this.textColor = Colors.white,
  });

  @override
  ConsumerState<EditableAvatar> createState() => _State();
}

class _State extends ConsumerState<EditableAvatar> {
  bool _busy = false;

  Future<void> _pickAndUpload() async {
    final hasPhoto = widget.currentUrl != null && widget.currentUrl!.isNotEmpty;

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: context.cardColor,
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          leading: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
          title: Text('Choisir depuis la galerie',
            style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700, color: context.textPrimary)),
          onTap: () => Navigator.pop(context, 'gallery'),
        ),
        ListTile(
          leading: const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
          title: Text('Prendre une photo',
            style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700, color: context.textPrimary)),
          onTap: () => Navigator.pop(context, 'camera'),
        ),
        if (hasPhoto) ...[
          const Divider(height: 1, indent: 16, endIndent: 16),
          ListTile(
            leading: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
            title: Text('Supprimer la photo',
              style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700, color: AppColors.danger)),
            onTap: () => Navigator.pop(context, 'delete'),
          ),
        ],
        const SizedBox(height: 8),
      ])),
    );
    if (action == null) return;

    // ── Suppression ────────────────────────────────────────────────────────
    if (action == 'delete') {
      setState(() => _busy = true);
      try {
        await ref.read(authProvider.notifier).deleteAvatar();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Photo de profil supprimée'),
          backgroundColor: AppColors.success,
        ));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppColors.danger,
        ));
      } finally {
        if (mounted) setState(() => _busy = false);
      }
      return;
    }

    // ── Sélection + upload ─────────────────────────────────────────────────
    final source = action == 'gallery' ? ImageSource.gallery : ImageSource.camera;
    try {
      final picked = await ImagePicker().pickImage(
        source: source, maxWidth: 1024, imageQuality: 85,
      );
      if (picked == null) return;
      setState(() => _busy = true);
      await ref.read(authProvider.notifier).uploadAvatar(File(picked.path));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Photo de profil mise à jour ✓'),
        backgroundColor: AppColors.success,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceAll('Exception: ', '')),
        backgroundColor: AppColors.danger,
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasUrl = widget.currentUrl != null && widget.currentUrl!.isNotEmpty;
    final size = widget.radius * 2;
    return GestureDetector(
      onTap: _busy ? null : _pickAndUpload,
      child: Stack(clipBehavior: Clip.none, children: [
        SizedBox(
          width: size, height: size,
          child: ClipOval(
            child: hasUrl
                ? CachedNetworkImage(
                    imageUrl: widget.currentUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => _initialsFallback(),
                    errorWidget: (_, __, ___) => _initialsFallback(),
                  )
                : _initialsFallback(),
          ),
        ),
        if (_busy)
          Positioned.fill(child: Container(
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), shape: BoxShape.circle),
            alignment: Alignment.center,
            child: const SizedBox(width: 22, height: 22,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)),
          ))
        else
          Positioned(
            right: 0, bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: AppColors.primary, shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 11),
            ),
          ),
      ]),
    );
  }

  Widget _initialsFallback() => Container(
    color: widget.backgroundColor,
    alignment: Alignment.center,
    child: Text(
      widget.fallbackText.isEmpty ? '?' : widget.fallbackText[0].toUpperCase(),
      style: TextStyle(
        fontFamily: 'Nunito',
        fontSize: widget.radius * 0.8,
        fontWeight: FontWeight.w800,
        color: widget.textColor,
      ),
    ),
  );
}
