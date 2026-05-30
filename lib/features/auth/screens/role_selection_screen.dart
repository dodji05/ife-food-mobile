import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_colors.dart';
import '../../../core/constants/app_constants.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});
  @override State<RoleSelectionScreen> createState() => _State();
}

class _State extends State<RoleSelectionScreen> {
  UserRole? _selected;

  final _roles = [
    _RoleCard(
      role: UserRole.client,
      emoji: '🛒',
      title: 'Je suis client',
      description: 'Je commande des repas et produits et je me fais livrer.',
      color: AppColors.primary,
    ),
    _RoleCard(
      role: UserRole.driver,
      emoji: '🛵',
      title: 'Je suis livreur',
      description: 'Je livre les commandes et je gagne de l\'argent par mission.',
      color: AppColors.info,
    ),
    _RoleCard(
      role: UserRole.professional,
      emoji: '🏪',
      title: 'Je suis professionnel',
      description: 'Je gère un restaurant, épicerie ou autre commerce.',
      color: AppColors.yellow,
    ),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.bgColor,
    appBar: AppBar(
      backgroundColor: context.bgColor,
      elevation: 0,
      leading: BackButton(color: context.textPrimary),
    ),
    body: SafeArea(child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Qui êtes-vous ?',
          style: TextStyle(fontFamily: 'Nunito', fontSize: 28,
              fontWeight: FontWeight.w900, color: context.textPrimary)),
        const SizedBox(height: 6),
        Text('Choisissez votre profil pour personnaliser votre expérience.',
          style: TextStyle(fontFamily: 'Nunito', fontSize: 15,
              color: context.textSecondary, height: 1.5)),
        const SizedBox(height: 32),
        ..._roles.map((card) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GestureDetector(
            onTap: () => setState(() => _selected = card.role),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _selected == card.role
                    ? card.color.withOpacity(0.06) : context.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _selected == card.role ? card.color : context.borderColor,
                  width: _selected == card.role ? 2 : 1,
                ),
              ),
              child: Row(children: [
                Container(width: 52, height: 52,
                  decoration: BoxDecoration(
                    color: card.color.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(14)),
                  child: Center(child: Text(card.emoji,
                      style: const TextStyle(fontSize: 26)))),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(card.title,
                    style: TextStyle(fontFamily: 'Nunito', fontSize: 15,
                        fontWeight: FontWeight.w800, color: context.textPrimary)),
                  const SizedBox(height: 2),
                  Text(card.description,
                    style: TextStyle(fontFamily: 'Nunito', fontSize: 12,
                        color: context.textPrimary.withOpacity(0.5), height: 1.4)),
                ])),
                if (_selected == card.role)
                  Icon(Icons.check_circle_rounded, color: card.color, size: 22),
              ]),
            ),
          ),
        )),
        const Spacer(),
        ElevatedButton(
          onPressed: _selected == null ? null : () =>
              context.go('/auth/phone', extra: _selected),
          child: const Text('Continuer'),
        ),
      ]),
    )),
  );
}

class _RoleCard {
  final UserRole role; final String emoji, title, description; final Color color;
  const _RoleCard({required this.role, required this.emoji,
      required this.title, required this.description, required this.color});
}
