import 'package:flutter/material.dart';
import '../../core/theme/theme_colors.dart';

class AppTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? label, hint, error;
  final bool obscure, autofocus;
  final TextInputType keyboardType;
  final IconData? prefix, suffix;
  final VoidCallback? onSuffixTap;
  final int? maxLines;
  final void Function(String)? onChanged, onSubmitted;

  const AppTextField({
    super.key, this.controller, this.label, this.hint, this.error,
    this.obscure = false, this.autofocus = false,
    this.keyboardType = TextInputType.text,
    this.prefix, this.suffix, this.onSuffixTap,
    this.maxLines = 1, this.onChanged, this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    if (label != null) Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(label!, style: TextStyle(fontFamily: 'Nunito', fontSize: 13, fontWeight: FontWeight.w700, color: context.textSecondary)),
    ),
    TextField(
      controller: controller, obscureText: obscure, autofocus: autofocus,
      keyboardType: keyboardType, maxLines: maxLines, onChanged: onChanged, onSubmitted: onSubmitted,
      style: const TextStyle(fontFamily: 'Nunito', fontSize: 15, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: hint,
        errorText: error,
        prefixIcon: prefix != null ? Icon(prefix, color: context.textMuted, size: 20) : null,
        suffixIcon: suffix != null ? IconButton(icon: Icon(suffix, color: context.textMuted, size: 20), onPressed: onSuffixTap) : null,
      ),
    ),
  ]);
}
