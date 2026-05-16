import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/cart_provider.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});
  @override ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  String _selectedPayment = 'KKIAPAY';
  final _addressCtrl = TextEditingController(text: 'Cotonou, Bénin');
  final _noteCtrl = TextEditingController();
  bool _loading = false;

  final _paymentMethods = [
    {'id': 'KKIAPAY', 'label': 'Mobile Money', 'sub': 'MTN, Moov, Orange, Wave', 'icon': '📱'},
    {'id': 'STRIPE', 'label': 'Carte bancaire', 'sub': 'Visa, Mastercard', 'icon': '💳'},
    {'id': 'PAYPAL', 'label': 'PayPal', 'sub': 'Compte PayPal', 'icon': '🅿️'},
    {'id': 'FEDAPAY', 'label': 'FedaPay', 'sub': 'Paiement local', 'icon': '🏦'},
  ];

  Future<void> _placeOrder() async {
    final cart = ref.read(cartProvider);
    if (cart.isEmpty || cart.professionalId == null) return;

    setState(() => _loading = true);
    try {
      final orderItems = cart.items.map((i) => {'productId': i.product.id, 'quantity': i.quantity}).toList();
      final res = await ApiClient.instance.post('/orders', data: {
        'professionalId': cart.professionalId,
        'items': orderItems,
        'deliveryAddress': _addressCtrl.text,
        'deliveryLat': AppConstants.defaultLat,
        'deliveryLng': AppConstants.defaultLng,
        'deliveryCity': 'Cotonou',
        'deliveryCountry': 'BJ',
        'currency': 'XOF',
        'paymentMethod': _selectedPayment,
        'specialInstructions': _noteCtrl.text.isEmpty ? null : _noteCtrl.text,
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

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(title: const Text('Confirmer la commande'), leading: const BackButton()),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        // Delivery address
        _Section(title: '📍 Adresse de livraison', child: TextField(
          controller: _addressCtrl,
          decoration: const InputDecoration(hintText: 'Entrez votre adresse'),
          style: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w600),
        )),
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
            : Text('Payer ${cart.subtotal.toStringAsFixed(0)} F'),
        ),
        const SizedBox(height: 40),
      ]),
    );
  }
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
