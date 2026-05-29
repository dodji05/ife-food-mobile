import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';

enum ThemeOverride { auto, light, dark }

bool _isNight() {
  final h = DateTime.now().toUtc().hour;
  return h >= AppConstants.darkStartHour || h < AppConstants.darkEndHour;
}

class ThemeState {
  final ThemeOverride override;
  final bool isNight;
  const ThemeState({required this.override, required this.isNight});

  ThemeMode get themeMode => switch (override) {
    ThemeOverride.light => ThemeMode.light,
    ThemeOverride.dark  => ThemeMode.dark,
    ThemeOverride.auto  => isNight ? ThemeMode.dark : ThemeMode.light,
  };
  bool get isDark => themeMode == ThemeMode.dark;
  ThemeState copyWith({ThemeOverride? override, bool? isNight}) =>
      ThemeState(override: override ?? this.override, isNight: isNight ?? this.isNight);
}

class ThemeNotifier extends StateNotifier<ThemeState> {
  final _storage = const FlutterSecureStorage();
  Timer? _timer;

  ThemeNotifier() : super(ThemeState(override: ThemeOverride.auto, isNight: _isNight())) {
    _load();
    _startTimer();
  }

  Future<void> _load() async {
    final saved = await _storage.read(key: AppConstants.themeKey);
    final ov = switch (saved) {
      'light' => ThemeOverride.light,
      'dark'  => ThemeOverride.dark,
      _       => ThemeOverride.auto,
    };
    state = state.copyWith(override: ov, isNight: _isNight());
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (state.override == ThemeOverride.auto) {
        final night = _isNight();
        if (night != state.isNight) state = state.copyWith(isNight: night);
      }
    });
  }

  Future<void> setOverride(ThemeOverride ov) async {
    state = state.copyWith(override: ov, isNight: _isNight());
    await _storage.write(key: AppConstants.themeKey,
        value: ov == ThemeOverride.light ? 'light'
             : ov == ThemeOverride.dark  ? 'dark'
             : 'auto');
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeState>(
    (ref) => ThemeNotifier());
