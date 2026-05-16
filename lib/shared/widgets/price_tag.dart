import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class PriceTag extends StatelessWidget {
  final double amount;
  final String currency;
  final double fontSize;
  final Color? color;

  const PriceTag({super.key, required this.amount, this.currency = 'F CFA', this.fontSize = 16, this.color});

  @override
  Widget build(BuildContext context) => RichText(text: TextSpan(children: [
    TextSpan(text: amount.toStringAsFixed(0),
      style: TextStyle(fontFamily: 'Nunito', fontSize: fontSize, fontWeight: FontWeight.w800, color: color ?? AppColors.primary)),
    TextSpan(text: ' $currency',
      style: TextStyle(fontFamily: 'Nunito', fontSize: fontSize * 0.7, fontWeight: FontWeight.w600, color: color ?? AppColors.grey)),
  ]));
}
