// ─────────────────────────────────────────────────────────────────────────────
// ifè FOOD — Préférence de layout de la page d'accueil client
// Persiste en FlutterSecureStorage, même pattern que ThemeNotifier.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';

class HomeLayoutNotifier extends StateNotifier<bool> {
  // false = v1 (classique)  |  true = v2 (redesign)
  static const _storage = FlutterSecureStorage();

  HomeLayoutNotifier() : super(false) {
    _load();
  }

  Future<void> _load() async {
    final saved = await _storage.read(key: AppConstants.homeLayoutKey);
    state = saved == 'v2';
  }

  Future<void> toggle() => setV2(!state);

  Future<void> setV2(bool useV2) async {
    state = useV2;
    await _storage.write(
      key: AppConstants.homeLayoutKey,
      value: useV2 ? 'v2' : 'v1',
    );
  }
}

/// `true` = HomeScreenV2 (nouveau design)  |  `false` = HomeScreen (classique)
final homeLayoutProvider = StateNotifierProvider<HomeLayoutNotifier, bool>(
  (ref) => HomeLayoutNotifier(),
);
