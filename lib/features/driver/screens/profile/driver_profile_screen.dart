import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class DriverProfileScreen extends StatelessWidget {
  
  const DriverProfileScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('DriverProfileScreen')),
    backgroundColor: AppColors.lightBg,
    body: const Center(child: Text('⚙️ Intégrer depuis app source',
      style: TextStyle(fontFamily: 'Nunito', fontSize: 14, color: AppColors.lightSubtext))));
}
