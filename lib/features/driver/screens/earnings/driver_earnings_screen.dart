import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class DriverEarningsScreen extends StatelessWidget {
  
  const DriverEarningsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('DriverEarningsScreen')),
    backgroundColor: AppColors.lightBg,
    body: const Center(child: Text('⚙️ Intégrer depuis app source',
      style: TextStyle(fontFamily: 'Nunito', fontSize: 14, color: AppColors.lightSubtext))));
}
