import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_colors.dart';

/// Tuile de sélection du thème (Auto / Clair / Sombre).
/// S'intègre dans n'importe quelle section de profil — thème unifié tous rôles.
class ThemeSelectorTile extends ConsumerWidget {
  const ThemeSelectorTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme   = ref.watch(themeProvider);
    final notifier = ref.read(themeProvider.notifier);

    final labelColor   = context.textPrimary;
    final subColor     = context.textSecondary;
    final chipBg       = context.bgColor;
    const activeBg     = AppColors.primary;
    const activeFg     = Colors.white;

    String sub = switch (theme.override) {
      ThemeOverride.auto  => 'Automatique · sombre 18h–5h UTC',
      ThemeOverride.light => 'Toujours clair',
      ThemeOverride.dark  => 'Toujours sombre',
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        Icon(Icons.brightness_auto_rounded, size: 22,
            color: context.textSecondary),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Apparence', style: TextStyle(
              fontFamily: 'Nunito', fontSize: 15,
              fontWeight: FontWeight.w700, color: labelColor)),
          const SizedBox(height: 2),
          Text(sub, style: TextStyle(
              fontFamily: 'Nunito', fontSize: 12, color: subColor)),
          const SizedBox(height: 10),
          Row(children: [
            _Chip(label: 'Auto',   icon: Icons.brightness_auto_rounded,
                active: theme.override == ThemeOverride.auto,
                activeBg: activeBg, activeFg: activeFg, chipBg: chipBg,
                subColor: subColor,
                onTap: () => notifier.setOverride(ThemeOverride.auto)),
            const SizedBox(width: 8),
            _Chip(label: 'Clair',  icon: Icons.wb_sunny_rounded,
                active: theme.override == ThemeOverride.light,
                activeBg: activeBg, activeFg: activeFg, chipBg: chipBg,
                subColor: subColor,
                onTap: () => notifier.setOverride(ThemeOverride.light)),
            const SizedBox(width: 8),
            _Chip(label: 'Sombre', icon: Icons.nightlight_rounded,
                active: theme.override == ThemeOverride.dark,
                activeBg: activeBg, activeFg: activeFg, chipBg: chipBg,
                subColor: subColor,
                onTap: () => notifier.setOverride(ThemeOverride.dark)),
          ]),
        ])),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final Color activeBg, activeFg, chipBg, subColor;
  final VoidCallback onTap;

  const _Chip({
    required this.label, required this.icon, required this.active,
    required this.activeBg, required this.activeFg,
    required this.chipBg, required this.subColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: active ? activeBg : chipBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active ? activeBg : subColor.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: active ? activeFg : subColor),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(
            fontFamily: 'Nunito', fontSize: 12,
            fontWeight: FontWeight.w700,
            color: active ? activeFg : subColor)),
      ]),
    ),
  );
}
