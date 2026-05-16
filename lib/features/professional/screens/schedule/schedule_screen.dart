import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../providers/pro_provider.dart';

class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({super.key});
  @override ConsumerState<ScheduleScreen> createState() => _State();
}

class _State extends ConsumerState<ScheduleScreen> {
  final _days = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
  final _dayKeys = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
  Map<String, Map<String, String?>> _hours = {};
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final pro = ref.read(proProvider).professional;
    final hours = pro?.openingHours as Map<String, dynamic>? ?? {};
    for (final key in _dayKeys) {
      final day = hours[key] as Map<String, dynamic>? ?? {'open': '08:00', 'close': '22:00'};
      _hours[key] = {'open': day['open']?.toString(), 'close': day['close']?.toString()};
    }
    if (_hours.isEmpty) {
      for (final key in _dayKeys) { _hours[key] = {'open': '08:00', 'close': '22:00'}; }
    }
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      await ref.read(proProvider.notifier).updateOpeningHours(_hours);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Horaires enregistrés !'), backgroundColor: AppColors.success));
    } finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _pickTime(String day, String type) async {
    final parts = (_hours[day]?[type] ?? '08:00').split(':');
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: int.tryParse(parts[0]) ?? 8, minute: int.tryParse(parts[1]) ?? 0),
      builder: (ctx, child) => Theme(data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: AppColors.primary, surface: AppColors.darkCard)), child: child!),
    );
    if (time != null) {
      setState(() => _hours[day]?[type] = '${time.hour.toString().padLeft(2,'0')}:${time.minute.toString().padLeft(2,'0')}');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.darkBg,
    appBar: AppBar(title: const Text('Horaires d\'ouverture'), leading: const BackButton()),
    body: Column(children: [
      Expanded(child: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Définissez vos horaires d\'ouverture par jour. Votre établissement sera automatiquement ouvert/fermé selon ces horaires.',
          style: TextStyle(fontFamily: 'Nunito', fontSize: 14, color: AppColors.darkSubtext, height: 1.5)),
        const SizedBox(height: 20),
        ..._dayKeys.asMap().entries.map((e) {
          final idx = e.key; final key = e.value;
          final isOpen = _hours[key]?['open'] != null;
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.darkCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.darkBorder)),
            child: Row(children: [
              SizedBox(width: 36, child: Text(_days[idx], style: const TextStyle(fontFamily: 'Nunito', fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.darkText))),
              const SizedBox(width: 12),
              if (isOpen) ...[
                GestureDetector(onTap: () => _pickTime(key, 'open'), child: _TimeChip(_hours[key]?['open'] ?? '08:00', Icons.wb_sunny_rounded)),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('—', style: TextStyle(color: AppColors.darkSubtext))),
                GestureDetector(onTap: () => _pickTime(key, 'close'), child: _TimeChip(_hours[key]?['close'] ?? '22:00', Icons.nights_stay_rounded)),
              ] else
                const Text('Fermé', style: TextStyle(fontFamily: 'Nunito', fontSize: 13, color: AppColors.darkMuted)),
              const Spacer(),
              Switch(
                value: isOpen,
                onChanged: (v) => setState(() { if (v) { _hours[key] = {'open': '08:00', 'close': '22:00'}; } else { _hours[key] = {'open': null, 'close': null}; } }),
                activeColor: AppColors.primary,
              ),
            ]),
          );
        }).toList(),
      ])),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: ElevatedButton(
          onPressed: _loading ? null : _save,
          child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Enregistrer les horaires'),
        ),
      ),
    ]),
  );
}

class _TimeChip extends StatelessWidget {
  final String time; final IconData icon;
  const _TimeChip(this.time, this.icon);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.primary.withOpacity(0.3))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: AppColors.primary),
      const SizedBox(width: 4),
      Text(time, style: const TextStyle(fontFamily: 'Nunito', fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.primary)),
    ]),
  );
}
