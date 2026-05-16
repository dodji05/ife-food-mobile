import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class EmptyState extends StatelessWidget {
  final String emoji, title, subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key, required this.emoji, required this.title, required this.subtitle,
    this.actionLabel, this.onAction,
  });

  @override
  Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(emoji, style: const TextStyle(fontSize: 64)),
      const SizedBox(height: 16),
      Text(title, style: const TextStyle(fontFamily: 'Nunito', fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.nearBlack), textAlign: TextAlign.center),
      const SizedBox(height: 8),
      Text(subtitle, style: const TextStyle(fontFamily: 'Nunito', fontSize: 14, color: AppColors.grey, height: 1.5), textAlign: TextAlign.center),
      if (actionLabel != null && onAction != null) ...[
        const SizedBox(height: 24),
        ElevatedButton(onPressed: onAction, style: ElevatedButton.styleFrom(minimumSize: const Size(200, 48)),
          child: Text(actionLabel!)),
      ],
    ]),
  ));
}
