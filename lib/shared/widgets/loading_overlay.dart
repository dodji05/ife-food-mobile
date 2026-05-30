import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_colors.dart';

class LoadingOverlay extends StatelessWidget {
  final Widget child;
  final bool isLoading;
  final String? message;

  const LoadingOverlay({super.key, required this.child, required this.isLoading, this.message});

  @override
  Widget build(BuildContext context) => Stack(children: [
    child,
    if (isLoading) Positioned.fill(child: Container(
      color: Colors.black.withOpacity(0.3),
      child: Center(child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: context.cardColor, borderRadius: BorderRadius.circular(16)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const CircularProgressIndicator(color: AppColors.primary),
          if (message != null) ...[
            const SizedBox(height: 12),
            Text(message!, style: TextStyle(fontFamily: 'Nunito', fontSize: 14, fontWeight: FontWeight.w600, color: context.textSecondary)),
          ],
        ]),
      )),
    )),
  ]);
}
