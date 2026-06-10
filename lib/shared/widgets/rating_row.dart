import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_colors.dart';

class RatingRow extends StatelessWidget {
  final double rating;
  final int? count;
  final double size;

  const RatingRow({super.key, required this.rating, this.count, this.size = 16});

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    RatingBarIndicator(
      rating: rating, itemSize: size, itemCount: 5,
      itemBuilder: (_, __) => const Icon(Icons.star_rounded, color: AppColors.yellow),
    ),
    const SizedBox(width: 4),
    Text(rating.toStringAsFixed(1),
      style: TextStyle(fontFamily: 'Nunito', fontSize: size * 0.85, fontWeight: FontWeight.w700, color: context.textPrimary)),
    if (count != null) Text(' ($count)',
      style: TextStyle(fontFamily: 'Nunito', fontSize: size * 0.75, color: context.textMuted)),
  ]);
}
