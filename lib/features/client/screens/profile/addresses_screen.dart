import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class AddressesScreen extends StatelessWidget {
  const AddressesScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Mes adresses')),
    body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Text('📍', style: TextStyle(fontSize: 48)),
      const SizedBox(height: 12),
      const Text('Aucune adresse sauvegardée', style: TextStyle(fontFamily: 'Nunito', fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.nearBlack)),
      const SizedBox(height: 24),
      ElevatedButton.icon(icon: const Icon(Icons.add), label: const Text('Ajouter une adresse'),
        style: ElevatedButton.styleFrom(minimumSize: const Size(220, 48)), onPressed: () {}),
    ])),
  );
}
