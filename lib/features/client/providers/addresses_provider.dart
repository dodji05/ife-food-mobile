// ─────────────────────────────────────────────────────────────────────────────
// ifè FOOD — Provider des adresses client
//
// Source de vérité : backend /user-addresses (CRUD).
//
// Providers exposés :
//   - addressesProvider     : FutureProvider.autoDispose<List<UserAddress>>
//   - defaultAddressProvider: Provider.autoDispose<UserAddress?>
//                              (dérivé, find isDefault dans la liste)
//   - addressesNotifierProvider : Provider<AddressesNotifier>
//                                  (mutations create/update/delete/setDefault)
//
// Pattern : chaque mutation invalide addressesProvider pour forcer refresh
// (liste backend toujours canonique, on n'optimistic-update pas pour rester
// safe sur la logique 'one default').
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../shared/models/user_address.dart';

/// Liste des adresses du user authentifié, triées par le backend
/// (default first, puis createdAt desc).
final addressesProvider = FutureProvider.autoDispose<List<UserAddress>>((ref) async {
  final res = await ApiClient.instance.get('/user-addresses');
  final list = res['data'] as List? ?? [];
  return list
      .whereType<Map<String, dynamic>>()
      .map(UserAddress.fromJson)
      .toList();
});

/// Adresse par défaut (find isDefault dans la liste). `null` si pas d'adresse.
/// Utilisé par le checkout pour pré-sélectionner l'adresse de livraison.
final defaultAddressProvider = Provider.autoDispose<UserAddress?>((ref) {
  return ref.watch(addressesProvider).maybeWhen(
    data: (list) {
      if (list.isEmpty) return null;
      // Trouve isDefault, sinon fallback sur la première (le backend devrait
      // toujours avoir au moins une default, mais safety net).
      try {
        return list.firstWhere((a) => a.isDefault);
      } catch (_) {
        return list.first;
      }
    },
    orElse: () => null,
  );
});

/// Notifier pour mutations. Pas d'état local — invalide addressesProvider
/// après chaque mutation pour refetch backend (single source of truth).
class AddressesNotifier {
  final Ref _ref;
  AddressesNotifier(this._ref);

  /// Crée une adresse. Si c'est la 1ère du user, backend la marque auto
  /// comme isDefault. Si isDefault=true passé explicitement, backend
  /// désactive les autres.
  Future<UserAddress> create({
    required String label,
    required String address,
    required String city,
    String? country,
    double? lat,
    double? lng,
    String? instructions,
    bool isDefault = false,
  }) async {
    final res = await ApiClient.instance.post('/user-addresses', data: {
      'label':   label,
      'address': address,
      'city':    city,
      if (country != null) 'country': country,
      if (lat != null)     'lat':    lat,
      if (lng != null)     'lng':    lng,
      if (instructions != null && instructions.isNotEmpty) 'instructions': instructions,
      'isDefault': isDefault,
    });
    _ref.invalidate(addressesProvider);
    return UserAddress.fromJson(res['data'] as Map<String, dynamic>);
  }

  /// Met à jour une adresse. Tous les champs sont optionnels (PATCH partiel).
  Future<UserAddress> update(String id, {
    String? label,
    String? address,
    String? city,
    String? country,
    double? lat,
    double? lng,
    String? instructions,
    bool? isDefault,
  }) async {
    final payload = <String, dynamic>{
      if (label != null)        'label':        label,
      if (address != null)      'address':      address,
      if (city != null)         'city':         city,
      if (country != null)      'country':      country,
      if (lat != null)          'lat':          lat,
      if (lng != null)          'lng':          lng,
      if (instructions != null) 'instructions': instructions,
      if (isDefault != null)    'isDefault':    isDefault,
    };
    final res = await ApiClient.instance.patch('/user-addresses/$id', data: payload);
    _ref.invalidate(addressesProvider);
    return UserAddress.fromJson(res['data'] as Map<String, dynamic>);
  }

  /// Supprime. Si c'était la default, backend promote la suivante.
  Future<void> delete(String id) async {
    await ApiClient.instance.delete('/user-addresses/$id');
    _ref.invalidate(addressesProvider);
  }

  /// Marque comme défaut (désactive les autres côté backend).
  /// Endpoint dédié plus explicite que PATCH avec isDefault:true.
  Future<void> setDefault(String id) async {
    await ApiClient.instance.patch('/user-addresses/$id/default');
    _ref.invalidate(addressesProvider);
  }
}

final addressesNotifierProvider = Provider<AddressesNotifier>((ref) {
  return AddressesNotifier(ref);
});
