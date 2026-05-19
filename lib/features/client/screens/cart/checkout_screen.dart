import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/cart_provider.dart';
import '../../providers/addresses_provider.dart';
import '../../widgets/address_selector_modal.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/models/user_address.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});
  @override ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  String _selectedPayment = 'KKIAPAY';
  final _noteCtrl = TextEditingController();
  bool _loading = false;
  /// Adresse sélectionnée manuellement par l'utilisateur. Si null, on
  /// retombe sur defaultAddressProvider (cf. effectiveAddress dans build).
  UserAddress? _manuallySelectedAddress;

  final _paymentMethods = [
    {'id': 'KKIAPAY', 'label': 'Mobile Money', 'sub': 'MTN, Moov, Orange, Wave', 'icon': '📱'},
    {'id': 'STRIPE', 'label': 'Carte bancaire', 'sub': 'Visa, Mastercard', 'icon': '💳'},
    {'id': 'PAYPAL', 'label': 'PayPal', 'sub': 'Compte PayPal', 'icon': '🅿️'},
    {'id': 'FEDAPAY', 'label': 'FedaPay', 'sub': 'Paiement local', 'icon': '🏦'},
  ];

  /// Calcule l'adresse effective : sélection manuelle si user a tapé "Changer",
  /// sinon adresse par défaut du provider. `null` si user n'a aucune adresse.
  UserAddress? _effectiveAddress() {
    return _manuallySelectedAddress ?? ref.read(defaultAddressProvider);
  }

  Future<void> _placeOrder() async {
    final cart = ref.read(cartProvider);
    if (cart.isEmpty || cart.professionalId == null) return;

    final addr = _effectiveAddress();
    if (addr == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Veuillez choisir une adresse de livraison'),
        backgroundColor: AppColors.danger,
      ));
      return;
    }

    setState(() => _loading = true);
    try {
      final orderItems = cart.items.map((i) => {'productId': i.product.id, 'quantity': i.quantity}).toList();
      final res = await ApiClient.instance.post('/orders', data: {
        'professionalId': cart.professionalId,
        'items': orderItems,
        'deliveryAddress': addr.address,
        // Fallback sur defaults si l'adresse n'a pas de coords (rare).
        'deliveryLat': addr.lat ?? AppConstants.defaultLat,
        'deliveryLng': addr.lng ?? AppConstants.defaultLng,
        'deliveryCity': addr.city,
        'deliveryCountry': addr.country,
        'currency': 'XOF',
        'paymentMethod': _selectedPayment,
        // Combine instructions de l'adresse + note de la commande si les deux
        // sont présentes (utile pour le livreur : "Code 1234. Sans oignons.").
        'specialInstructions': _composeInstructions(addr.instructions, _noteCtrl.text),
        if (cart.promoCode != null) 'promoCode': cart.promoCode,
      });

      final orderId = res['data']['id'];

      // Initiate payment
      await ApiClient.instance.post('/payments/$orderId/initiate/$_selectedPayment');

      ref.read(cartProvider.notifier).clearCart();
      if (mounted) context.go('/order/$orderId');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Combine instructions adresse + note checkout en un seul champ
  /// `specialInstructions` côté commande. Évite que le livreur loupe l'une
  /// des deux. Sépare par ' — ' si les deux présentes.
  String? _composeInstructions(String? addrInstr, String checkoutNote) {
    final a = addrInstr?.trim() ?? '';
    final c = checkoutNote.trim();
    if (a.isEmpty && c.isEmpty) return null;
    if (a.isEmpty) return c;
    if (c.isEmpty) return a;
    return '$a — $c';
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final defaultAddr = ref.watch(defaultAddressProvider);
    final effectiveAddr = _manuallySelectedAddress ?? defaultAddr;

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(title: const Text('Confirmer la commande'), leading: const BackButton()),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        // ── Adresse de livraison (sélecteur tappable) ──────────────────────
        _Section(
          title: '📍 Adresse de livraison',
          child: _AddressTile(
            address: effectiveAddr,
            onTap: () async {
              final picked = await showAddressSelector(context);
              if (picked != null) {
                setState(() => _manuallySelectedAddress = picked);
              }
            },
          ),
        ),
        const SizedBox(height: 16),

        // Order summary
        _Section(title: '🧾 Récapitulatif', child: Column(children: [
          ...cart.items.map((item) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              Text('${item.quantity}×', style: const TextStyle(fontFamily: 'Nunito', fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary)),
              const SizedBox(width: 8),
              Expanded(child: Text(item.product.localizedName('fr'), style: const TextStyle(fontFamily: 'Nunito', fontSize: 14))),
              Text('${item.total.toStringAsFixed(0)} F', style: const TextStyle(fontFamily: 'Nunito', fontSize: 14, fontWeight: FontWeight.w700)),
            ]),
          )).toList(),
          const Divider(height: 20),
          Row(children: [
            const Text('Sous-total', style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w600, color: AppColors.grey)),
            const Spacer(),
            Text('${cart.subtotal.toStringAsFixed(0)} F', style: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700)),
          ]),
          if (cart.hasPromo) ...[
            const SizedBox(height: 6),
            Row(children: [
              Text('Code promo (${cart.promoCode})',
                style: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w600, color: AppColors.grey)),
              const Spacer(),
              Text('-${cart.promoDiscount.toStringAsFixed(0)} F',
                style: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700, color: AppColors.success)),
            ]),
          ],
          const SizedBox(height: 6),
          const Row(children: [
            Text('Livraison', style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w600, color: AppColors.grey)),
            Spacer(),
            Text('Calculée à la commande',
              style: TextStyle(fontFamily: 'Nunito', fontSize: 12, color: AppColors.grey)),
          ]),
          const Divider(height: 20),
          Row(children: [
            const Text('À payer (hors livraison)',
              style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800, fontSize: 15)),
            const Spacer(),
            Text('${cart.totalAfterPromo.toStringAsFixed(0)} F',
              style: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.primary)),
          ]),
        ])),
        const SizedBox(height: 16),

        // Payment method
        _Section(title: '💳 Mode de paiement', child: Column(
          children: _paymentMethods.map((pm) => GestureDetector(
            onTap: () => setState(() => _selectedPayment = pm['id']!),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _selectedPayment == pm['id'] ? AppColors.primary.withOpacity(0.08) : AppColors.offWhite,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _selectedPayment == pm['id'] ? AppColors.primary : AppColors.lightGrey, width: _selectedPayment == pm['id'] ? 2 : 1),
              ),
              child: Row(children: [
                Text(pm['icon']!, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(pm['label']!, style: const TextStyle(fontFamily: 'Nunito', fontSize: 14, fontWeight: FontWeight.w700)),
                  Text(pm['sub']!, style: const TextStyle(fontFamily: 'Nunito', fontSize: 12, color: AppColors.grey)),
                ])),
                if (_selectedPayment == pm['id']) const Icon(Icons.check_circle_rounded, color: AppColors.primary),
              ]),
            ),
          )).toList(),
        )),
        const SizedBox(height: 16),

        // Note
        _Section(title: '📝 Instructions spéciales (optionnel)', child: TextField(
          controller: _noteCtrl, maxLines: 2,
          decoration: const InputDecoration(hintText: 'Ex: sans oignons, sonner 2 fois…'),
        )),
        const SizedBox(height: 32),

        // Place order
        ElevatedButton(
          onPressed: _loading ? null : _placeOrder,
          child: _loading
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            // Affiche le total APRÈS promo (vs subtotal avant) pour cohérence
            // avec le récap au-dessus. Le frais de livraison est ajouté côté
            // backend dans /orders et apparait sur la confirmation order.
            : Text('Payer ${cart.totalAfterPromo.toStringAsFixed(0)} F + livraison'),
        ),
        const SizedBox(height: 40),
      ]),
    );
  }
}

// ── Tile sélecteur d'adresse (utilisée dans la section adresse) ────────────
class _AddressTile extends StatelessWidget {
  final UserAddress? address;
  final VoidCallback onTap;
  const _AddressTile({required this.address, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.offWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lightGrey),
      ),
      child: Row(children: [
        if (address == null) ...[
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: AppColors.danger.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.add_location_alt_rounded, color: AppColors.danger, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Aucune adresse',
              style: TextStyle(fontFamily: 'Nunito', fontSize: 14,
                  fontWeight: FontWeight.w800, color: AppColors.nearBlack)),
            Text('Toucher pour ajouter une adresse de livraison',
              style: TextStyle(fontFamily: 'Nunito', fontSize: 12, color: AppColors.lightSubtext)),
          ])),
        ] else ...[
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(address!.labelEmoji, style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(address!.label,
              style: const TextStyle(fontFamily: 'Nunito', fontSize: 14,
                  fontWeight: FontWeight.w800, color: AppColors.nearBlack)),
            const SizedBox(height: 2),
            Text('${address!.address}, ${address!.city}',
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: 'Nunito', fontSize: 12, color: AppColors.lightSubtext)),
          ])),
        ],
        const Icon(Icons.chevron_right_rounded, color: AppColors.lightSubtext),
      ]),
    ),
  );
}

class _Section extends StatelessWidget {
  final String title; final Widget child;
  const _Section({required this.title, required this.child});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.lightGrey.withOpacity(0.8))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontFamily: 'Nunito', fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.nearBlack)),
      const SizedBox(height: 12), child,
    ]),
  );
}
