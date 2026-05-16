import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

enum AppButtonVariant { primary, secondary, outline, ghost, danger }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final AppButtonVariant variant;
  final bool loading;
  final bool fullWidth;
  final IconData? icon;
  final double? height;
  final double? fontSize;

  const AppButton({
    super.key, required this.label, this.onTap,
    this.variant = AppButtonVariant.primary, this.loading = false,
    this.fullWidth = true, this.icon, this.height, this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = switch (variant) {
      AppButtonVariant.primary  => (AppColors.primary, Colors.white, AppColors.primary),
      AppButtonVariant.secondary=> (AppColors.yellow, AppColors.nearBlack, AppColors.yellow),
      AppButtonVariant.outline  => (Colors.transparent, AppColors.primary, AppColors.primary),
      AppButtonVariant.ghost    => (Colors.transparent, AppColors.primary, Colors.transparent),
      AppButtonVariant.danger   => (AppColors.error, Colors.white, AppColors.error),
    };

    return SizedBox(
      width: fullWidth ? double.infinity : null,
      height: height ?? 54,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: onTap == null ? 0.5 : 1.0,
        child: Material(
          color: bg, borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: loading ? null : onTap,
            borderRadius: BorderRadius.circular(16),
            child: DecoratedBox(
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: border, width: 1.5)),
              child: Center(child: loading
                ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: fg))
                : Row(mainAxisSize: MainAxisSize.min, children: [
                    if (icon != null) ...[Icon(icon, color: fg, size: 18), const SizedBox(width: 8)],
                    Text(label, style: TextStyle(fontFamily: 'Nunito', fontSize: fontSize ?? 16, fontWeight: FontWeight.w700, color: fg)),
                  ])),
            ),
          ),
        ),
      ),
    );
  }
}
