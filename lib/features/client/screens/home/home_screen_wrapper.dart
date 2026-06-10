// ─────────────────────────────────────────────────────────────────────────────
// ifè FOOD — Wrapper de la page d'accueil client
// Lit homeLayoutProvider et affiche HomeScreen (v1) ou HomeScreenV2 (v2).
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/home_layout_provider.dart';
import 'home_screen.dart';
import 'home_screen_v2.dart';

class HomeScreenWrapper extends ConsumerWidget {
  const HomeScreenWrapper({super.key});

  @override
  Widget build(context, ref) {
    final useV2 = ref.watch(homeLayoutProvider);
    return useV2 ? const HomeScreenV2() : const HomeScreen();
  }
}
