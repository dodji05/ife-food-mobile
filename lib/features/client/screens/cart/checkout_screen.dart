import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
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
  String _selectedPayment = '';
  final _noteCtrl = TextEditingController();
  final _manualAddressCtrl = TextEditingController();
  bool _loading = false;
  bool _geoLoading = false;
  bool _showManualInput = false;
  UserAddress? _manuallySelectedAddress;

  // Scheduled delivery
  bool _isScheduled = false;
  DateTime? _scheduledDate;
  TimeOfDay? _scheduledTime;

  // Payment methods loaded from backend
  List<Map<String, String>> _paymentMethods = [];

  static const _gatewayMeta = {
    'KKIAPAY':          {'label': 'Mobile Money',           'sub': 'MTN, Moov, Orange, Wave', 'icon': '📱'},
    'STRIPE':           {'label': 'Carte bancaire',         'sub': 'Visa, Mastercard',        'icon': '💳'},
    'PAYPAL':           {'label': 'PayPal',                 'sub': 'Compte PayPal',           'icon': '🅿️'},
    'FEDAPAY':          {'label': 'FedaPay',                'sub': 'Paiement local',          'icon': '🏦'},
    'CASH_ON_DELIVERY': {'label': 'Espèces à la livraison', 'sub': 'Payez au livreur',        'icon': '💵'},
  };

  @override
  void initState() {
    super.initState();
    _loadPaymentGateways();
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    _manualAddressCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPaymentGateways() async {
    try {
      final res = await ApiClient.instance.get('/payments/gateways');
      final gateways = res['data'] as Map<String, dynamic>? ?? {};
      final methods = <Map<String, String>>[];
      for (final entry in gateways.entries) {
        if (entry.value == true) {
          final meta = _gatewayMeta[entry.key];
          if (meta != null) {
            methods.add({'id': entry.key, 'label': meta['label']!, 'sub': meta['sub']!, 'icon': meta['icon']!});
          }
        }
      }
      if (!mounted) return;
      setState(() {
        _paymentMethods = methods.isNotEmpty ? methods : _fallbackMethods();
        if (_selectedPayment.isEmpty || !_paymentMethods.any((m) => m['id'] == _selectedPayment)) {
          _selectedPayment = _paymentMethods.first['id']!;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _paymentMethods = _fallbackMethods();
        if (_selectedPayment.isEmpty) _selectedPayment = 'KKIAPAY';
      });
    }
  }

  List<Map<String, String>> _fallbackMethods() => [
    {'id': 'KKIAPAY', 'label': 'Mobile Money', 'sub': 'MTN, Moov, Orange, Wave', 'icon': '📱'},
    {'id': 'CASH_ON_DELIVERY', 'label': 'Espèces à la livraison', 'sub': 'Payez au livreur', 'icon': '💵'},
  ];

  Future<void> _useGeolocation() async {
    setState(() => _geoLoading = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Permission de localisation refusée'),
          backgroundColor: AppColors.danger,
        ));
        return;
      }
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (!mounted) return;
      final now = DateTime.now();
      setState(() {
        _manuallySelectedAddress = UserAddress(
          id: 'gps',
          userId: '',
          label: 'Ma position actuelle',
          address: 'Position GPS (${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)})',
          city: '',
          country: 'BJ',
          lat: pos.latitude,
          lng: pos.longitude,
          isDefault: false,
          createdAt: now,
          updatedAt: now,
        );
        _showManualInput = false;
        _manualAddressCtrl.clear();
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Localisation échouée : $e'),
        backgroundColor: AppColors.danger,
      ));
    } finally {
      if (mounted) setState(() => _geoLoading = false);
    }
  }

  void _applyManualAddress() {
    final text = _manualAddressCtrl.text.trim();
    if (text.isEmpty) return;
    final now = DateTime.now();
    setState(() {
      _manuallySelectedAddress = UserAddress(
        id: 'manual',
        userId: '',
        label: 'Adresse saisie',
        address: text,
        city: '',
        country: 'BJ',
        isDefault: false,
        createdAt: now,
        updatedAt: now,
      );
      _showManualInput = false;
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduledDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 7)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary, onPrimary: Colors.white),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _scheduledDate = picked);
  }

  Future<void> _pickTime() async {
    final now = TimeOfDay.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: _scheduledTime ?? TimeOfDay(hour: (now.hour + 1) % 24, minute: 0),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary, onPrimary: Colors.white),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    // Reject past times when scheduled date is today
    final date = _scheduledDate ?? DateTime.now();
    final isToday = date.year == DateTime.now().year &&
        date.month == DateTime.now().month &&
        date.day == DateTime.now().day;
    if (isToday) {
      final pickedDt = DateTime(date.year, date.month, date.day, picked.hour, picked.minute);
      if (pickedDt.isBefore(DateTime.now())) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Veuillez choisir une heure dans le futur'),
          backgroundColor: AppColors.warning,
        ));
        return;
      }
    }
    setState(() => _scheduledTime = picked);
  }

  String? get _scheduledDeliveryAt {
    if (!_isScheduled || _scheduledDate == null || _scheduledTime == null) return null;
    return DateTime(
      _scheduledDate!.year, _scheduledDate!.month, _scheduledDate!.day,
      _scheduledTime!.hour, _scheduledTime!.minute,
    ).toIso8601String();
  }

  UserAddress? _effectiveAddress() => _manuallySelectedAddress ?? ref.read(defaultAddressProvider);

  Future<void> _placeOrder() async {
    final cart = ref.read(cartProvider);
    if (cart.isEmpty || cart.professionalId == null) return;

    if (_isScheduled && (_scheduledDate == null || _scheduledTime == null)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Veuillez sélectionner la date et l\'heure de livraison planifiée'),
        backgroundColor: AppColors.danger,
      ));
      return;
    }

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
      final body = <String, dynamic>{
        'professionalId': cart.professionalId,
        'items': orderItems,
        'deliveryAddress': addr.address,
        'deliveryLat': addr.lat ?? AppConstants.defaultLat,
        'deliveryLng': addr.lng ?? AppConstants.defaultLng,
        'deliveryCity': addr.city,
        'deliveryCountry': addr.country,
        'currency': 'XOF',
        'paymentMethod': _selectedPayment,
        'specialInstructions': _composeInstructions(addr.instructions, _noteCtrl.text),
        if (cart.promoCode != null) 'promoCode': cart.promoCode,
        if (_scheduledDeliveryAt != null) 'scheduledDeliveryAt': _scheduledDeliveryAt,
      };

      final res = await ApiClient.instance.post('/orders', data: body);
      final orderId = res['data']['id'];
      await ApiClient.instance.post('/payments/$orderId/initiate/$_selectedPayment');
      ref.read(cartProvider.notifier).clearCart();
      if (mounted) context.go('/order/$orderId');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceAll('Exception: ', '')),
        backgroundColor: AppColors.error,
      ));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

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

        // ── Adresse de livraison ───────────────────────────────────────────
        _Section(
          title: '📍 Adresse de livraison',
          child: Column(children: [
            _AddressTile(
              address: effectiveAddr,
              onTap: () async {
                final picked = await showAddressSelector(context);
                if (picked != null) setState(() {
                  _manuallySelectedAddress = picked;
                  _showManualInput = false;
                });
              },
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: OutlinedButton.icon(
                onPressed: _geoLoading ? null : _useGeolocation,
                icon: _geoLoading
                  ? const SizedBox(width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                  : const Icon(Icons.my_location_rounded, size: 16),
                label: const Text('Ma position', style: TextStyle(fontFamily: 'Nunito', fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              )),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton.icon(
                onPressed: () => setState(() => _showManualInput = !_showManualInput),
                icon: Icon(_showManualInput ? Icons.close_rounded : Icons.edit_location_alt_rounded, size: 16),
                label: const Text('Saisir manuellement', style: TextStyle(fontFamily: 'Nunito', fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.grey,
                  side: BorderSide(color: _showManualInput ? AppColors.primary : AppColors.lightGrey),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              )),
            ]),
            if (_showManualInput) ...[
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: TextField(
                  controller: _manualAddressCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Ex: Cotonou, Cadjèhoun, rue 123…',
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  style: const TextStyle(fontFamily: 'Nunito', fontSize: 14),
                  onSubmitted: (_) => _applyManualAddress(),
                )),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _applyManualAddress,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    padding: EdgeInsets.zero,
                  ),
                  child: const Icon(Icons.check_rounded, size: 20),
                ),
              ]),
            ],
          ]),
        ),
        const SizedBox(height: 16),

        // ── Type de livraison ──────────────────────────────────────────────
        _Section(
          title: '🕐 Type de livraison',
          child: Column(children: [
            Row(children: [
              Expanded(child: _DeliveryTypeCard(
                icon: Icons.flash_on_rounded,
                label: 'Immédiate',
                selected: !_isScheduled,
                onTap: () => setState(() { _isScheduled = false; _scheduledDate = null; _scheduledTime = null; }),
              )),
              const SizedBox(width: 10),
              Expanded(child: _DeliveryTypeCard(
                icon: Icons.schedule_rounded,
                label: 'Planifiée',
                selected: _isScheduled,
                onTap: () => setState(() => _isScheduled = true),
              )),
            ]),
            if (_isScheduled) ...[
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: _DateTimePicker(
                  icon: Icons.calendar_today_rounded,
                  label: _scheduledDate != null
                    ? '${_scheduledDate!.day.toString().padLeft(2,'0')}/${_scheduledDate!.month.toString().padLeft(2,'0')}/${_scheduledDate!.year}'
                    : 'Choisir la date',
                  active: _scheduledDate != null,
                  enabled: true,
                  onTap: _pickDate,
                )),
                const SizedBox(width: 10),
                Expanded(child: _DateTimePicker(
                  icon: Icons.access_time_rounded,
                  label: _scheduledTime != null ? _scheduledTime!.format(context) : 'Heure',
                  active: _scheduledTime != null,
                  enabled: _scheduledDate != null,
                  onTap: _pickTime,
                )),
              ]),
              if (_scheduledDate != null && _scheduledTime != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(children: [
                    const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Livraison planifiée le ${_scheduledDate!.day.toString().padLeft(2,'0')}/${_scheduledDate!.month.toString().padLeft(2,'0')} à ${_scheduledTime!.format(context)}',
                      style: const TextStyle(fontFamily: 'Nunito', fontSize: 12,
                          color: AppColors.success, fontWeight: FontWeight.w700),
                    ),
                  ]),
                ),
            ],
          ]),
        ),
        const SizedBox(height: 16),

        // ── Récapitulatif commande ─────────────────────────────────────────
        _Section(title: '🧾 Récapitulatif', child: Column(children: [
          ...cart.items.map((item) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              Text('${item.quantity}×',
                style: const TextStyle(fontFamily: 'Nunito', fontSize: 14,
                    fontWeight: FontWeight.w700, color: AppColors.primary)),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.product.localizedName('fr'),
                  style: const TextStyle(fontFamily: 'Nunito', fontSize: 14)),
                Text('${item.product.price.toStringAsFixed(0)} F / unité',
                  style: const TextStyle(fontFamily: 'Nunito', fontSize: 11, color: AppColors.grey)),
              ])),
              Text('${item.total.toStringAsFixed(0)} F',
                style: const TextStyle(fontFamily: 'Nunito', fontSize: 14, fontWeight: FontWeight.w700)),
            ]),
          )),
          const Divider(height: 20),
          _SummaryRow(label: 'Sous-total', value: '${cart.subtotal.toStringAsFixed(0)} F'),
          if (cart.hasPromo) ...[
            const SizedBox(height: 6),
            _SummaryRow(
              label: 'Code promo (${cart.promoCode})',
              value: '-${cart.promoDiscount.toStringAsFixed(0)} F',
              valueColor: AppColors.success,
            ),
          ],
          const SizedBox(height: 6),
          const _SummaryRow(label: 'Livraison', value: 'Calculée à la commande'),
          const Divider(height: 20),
          _SummaryRow(
            label: 'À payer (hors livraison)',
            value: '${cart.totalAfterPromo.toStringAsFixed(0)} F',
            isBold: true,
          ),
        ])),
        const SizedBox(height: 16),

        // ── Mode de paiement ──────────────────────────────────────────────
        _Section(
          title: '💳 Mode de paiement',
          child: _paymentMethods.isEmpty
            ? const Center(child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(color: AppColors.primary),
              ))
            : Column(children: _paymentMethods.map((pm) => GestureDetector(
              onTap: () => setState(() => _selectedPayment = pm['id']!),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _selectedPayment == pm['id'] ? AppColors.primary.withOpacity(0.08) : AppColors.offWhite,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _selectedPayment == pm['id'] ? AppColors.primary : AppColors.lightGrey,
                    width: _selectedPayment == pm['id'] ? 2 : 1,
                  ),
                ),
                child: Row(children: [
                  Text(pm['icon']!, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(pm['label']!, style: const TextStyle(fontFamily: 'Nunito', fontSize: 14, fontWeight: FontWeight.w700)),
                    Text(pm['sub']!, style: const TextStyle(fontFamily: 'Nunito', fontSize: 12, color: AppColors.grey)),
                  ])),
                  if (_selectedPayment == pm['id'])
                    const Icon(Icons.check_circle_rounded, color: AppColors.primary),
                ]),
              ),
            )).toList()),
        ),
        const SizedBox(height: 16),

        // ── Instructions spéciales ─────────────────────────────────────────
        _Section(title: '📝 Instructions spéciales (optionnel)', child: TextField(
          controller: _noteCtrl,
          maxLines: 2,
          decoration: const InputDecoration(hintText: 'Ex: sans oignons, sonner 2 fois…'),
        )),
        const SizedBox(height: 32),

        // ── Bouton passer la commande ──────────────────────────────────────
        ElevatedButton(
          onPressed: _loading ? null : _placeOrder,
          child: _loading
            ? const SizedBox(height: 20, width: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text('Payer ${cart.totalAfterPromo.toStringAsFixed(0)} F + livraison'),
        ),
        const SizedBox(height: 40),
      ]),
    );
  }
}

// ── Carte type de livraison ────────────────────────────────────────────────
class _DeliveryTypeCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _DeliveryTypeCard({required this.icon, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: selected ? AppColors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: selected ? AppColors.primary : AppColors.lightGrey),
      ),
      child: Column(children: [
        Icon(icon, size: 20, color: selected ? Colors.white : AppColors.grey),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontFamily: 'Nunito', fontSize: 13, fontWeight: FontWeight.w700,
            color: selected ? Colors.white : AppColors.grey)),
      ]),
    ),
  );
}

// ── Sélecteur date/heure ───────────────────────────────────────────────────
class _DateTimePicker extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final bool enabled;
  final VoidCallback onTap;
  const _DateTimePicker({required this.icon, required this.label, required this.active, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: enabled ? onTap : null,
    borderRadius: BorderRadius.circular(10),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: active ? AppColors.primary : AppColors.lightGrey),
        color: !enabled
          ? AppColors.lightGrey.withOpacity(0.3)
          : active ? AppColors.primary.withOpacity(0.06) : AppColors.offWhite,
      ),
      child: Row(children: [
        Icon(icon, size: 16, color: active ? AppColors.primary : AppColors.grey),
        const SizedBox(width: 8),
        Expanded(child: Text(label,
          style: TextStyle(fontFamily: 'Nunito', fontSize: 13, fontWeight: FontWeight.w700,
            color: active ? AppColors.nearBlack : AppColors.lightSubtext),
        )),
      ]),
    ),
  );
}

// ── Tile sélecteur d'adresse ───────────────────────────────────────────────
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
            decoration: BoxDecoration(color: AppColors.danger.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            alignment: Alignment.center,
            child: const Icon(Icons.add_location_alt_rounded, color: AppColors.danger, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Aucune adresse', style: TextStyle(fontFamily: 'Nunito', fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.nearBlack)),
            Text('Toucher pour ajouter une adresse de livraison', style: TextStyle(fontFamily: 'Nunito', fontSize: 12, color: AppColors.lightSubtext)),
          ])),
        ] else ...[
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
            alignment: Alignment.center,
            child: Text(address!.labelEmoji, style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(address!.label, style: const TextStyle(fontFamily: 'Nunito', fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.nearBlack)),
            const SizedBox(height: 2),
            Text('${address!.address}, ${address!.city}', maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: 'Nunito', fontSize: 12, color: AppColors.lightSubtext)),
          ])),
        ],
        const Icon(Icons.chevron_right_rounded, color: AppColors.lightSubtext),
      ]),
    ),
  );
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.lightGrey.withOpacity(0.8)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontFamily: 'Nunito', fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.nearBlack)),
      const SizedBox(height: 12),
      child,
    ]),
  );
}

class _SummaryRow extends StatelessWidget {
  final String label, value;
  final bool isBold;
  final Color? valueColor;
  const _SummaryRow({required this.label, required this.value, this.isBold = false, this.valueColor});

  @override
  Widget build(BuildContext context) => Row(children: [
    Text(label, style: TextStyle(fontFamily: 'Nunito', fontSize: 14,
        color: AppColors.grey, fontWeight: isBold ? FontWeight.w700 : FontWeight.w500)),
    const Spacer(),
    Text(value, style: TextStyle(fontFamily: 'Nunito',
        fontSize: isBold ? 16 : 14,
        fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
        color: valueColor ?? (isBold ? AppColors.nearBlack : AppColors.darkGrey))),
  ]);
}
