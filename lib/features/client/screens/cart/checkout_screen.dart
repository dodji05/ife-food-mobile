import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:kkiapay/kkiapay.dart';
import 'package:flutter_stripe/flutter_stripe.dart' as stripe;
import '../../../../core/utils/location_utils.dart';
import '../../providers/cart_provider.dart';
import '../../providers/addresses_provider.dart';
import '../../widgets/address_selector_modal.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/currency_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_colors.dart';
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

  // Delivery fee preview
  double? _deliveryFee;
  bool _feeLoading = false;
  bool _feeError = false;
  String? _lastFetchedAddressId;

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
    final scheduledFor = ref.read(cartProvider).scheduledFor;
    if (scheduledFor != null) {
      _isScheduled    = true;
      _scheduledDate  = scheduledFor;
      _scheduledTime  = TimeOfDay.fromDateTime(scheduledFor);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchDeliveryFee());
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

  Future<void> _fetchDeliveryFee() async {
    final addr = _effectiveAddress();
    final proId = ref.read(cartProvider).professionalId;
    if (addr == null || proId == null) return;
    // Skip if same address already fetched
    if (_lastFetchedAddressId == addr.id && _deliveryFee != null) return;
    setState(() { _feeLoading = true; _feeError = false; });
    try {
      final res = await ApiClient.instance.get('/geo/delivery-fee', params: {
        'professionalId': proId,
        'toLat': (addr.lat ?? AppConstants.defaultLat).toString(),
        'toLng': (addr.lng ?? AppConstants.defaultLng).toString(),
        if (addr.city.isNotEmpty) 'toCity': addr.city,
      });
      final fee = (res['data'] as num?)?.toDouble();
      if (!mounted) return;
      setState(() {
        _deliveryFee = fee;
        _feeError = false;
        _lastFetchedAddressId = addr.id;
      });
    } catch (_) {
      if (mounted) setState(() { _deliveryFee = null; _feeError = true; });
    } finally {
      if (mounted) setState(() => _feeLoading = false);
    }
  }

  Future<void> _useGeolocation() async {
    setState(() => _geoLoading = true);
    try {
      final granted = await ensureLocationPermission();
      if (!granted) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Permission de localisation refusée'),
          backgroundColor: AppColors.danger,
        ));
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
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
      _fetchDeliveryFee();
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
    _fetchDeliveryFee();
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
        'currency': ref.read(authProvider).user?.currency ?? 'XOF',
        'paymentMethod': _selectedPayment,
        'specialInstructions': _composeInstructions(addr.instructions, _noteCtrl.text),
        if (cart.promoCode != null) 'promoCode': cart.promoCode,
        if (_scheduledDeliveryAt != null) 'scheduledDeliveryAt': _scheduledDeliveryAt,
      };

      final res = await ApiClient.instance.post('/orders', data: body);
      final orderId = res['data']['id'] as String;
      final payRes  = await ApiClient.instance.post('/payments/$orderId/initiate/$_selectedPayment');
      final payData = (payRes['data'] as Map<String, dynamic>?) ?? {};
      ref.read(cartProvider.notifier).clearCart();
      if (!mounted) return;

      // KKiaPay : pas d'URL serveur → on ouvre le widget natif (mobile money/carte).
      if (payData['widget'] == true) {
        await _handleKkiapay(orderId, payData);
        if (mounted) context.go('/order/$orderId');
        return;
      }

      // Stripe : PaymentSheet native (carte internationale / diaspora).
      if (payData['stripe'] == true) {
        await _handleStripe(orderId, payData);
        if (mounted) context.go('/order/$orderId');
        return;
      }

      // PayPal : navigateur intégré → approbation → capture côté serveur.
      if (payData['paypal'] == true) {
        await _handlePaypal(orderId, payData);
        if (mounted) context.go('/order/$orderId');
        return;
      }

      // FedaPay : navigateur intégré (inAppBrowserView = Chrome Custom Tab /
      // SFSafariViewController) → bouton "Fermer" visible, l'utilisateur
      // revient automatiquement dans l'app en appuyant dessus.
      final checkoutUrl = payData['checkoutUrl'] as String?;
      if (checkoutUrl != null) {
        final uri = Uri.parse(checkoutUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
        }
      }
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

  /// Ouvre le widget KKiaPay natif. À la réussite, vérifie la transaction
  /// côté backend (POST /payments/:orderId/verify-kkiapay/:transactionId).
  Future<void> _handleKkiapay(String orderId, Map<String, dynamic> payData) async {
    final completer = Completer<void>();
    String? capturedTxId;

    void callback(Map<String, dynamic> response, BuildContext ctx) {
      final status = response['status'] as String?;
      if (status == PAYMENT_SUCCESS) {
        capturedTxId = response['transactionId']?.toString();
        Navigator.of(ctx).pop(); // ferme le widget
        if (!completer.isCompleted) completer.complete();
      } else if (status == PAYMENT_CANCELLED) {
        Navigator.of(ctx).pop();
        if (!completer.isCompleted) completer.complete();
      }
      // PENDING_PAYMENT / PAYMENT_INIT : on laisse le widget ouvert.
    }

    final widget = KKiaPay(
      amount:    (payData['amount'] as num?)?.toInt() ?? 0,
      reason:    'Commande ifè FOOD',
      phone:     payData['phone'] as String?,
      name:      payData['name'] as String?,
      email:     payData['email'] as String?,
      data:      orderId,
      apikey:    payData['publicKey'] as String? ?? '',
      sandbox:   payData['sandbox'] as bool? ?? true,
      theme:     '#1A6B3C',
      countries: const ['BJ', 'CI', 'SN', 'TG'],
      paymentMethods: const ['momo', 'card'],
      callback:  callback,
    );

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => widget),
    );
    // Si l'utilisateur ferme manuellement (retour) sans callback, on continue.
    if (!completer.isCompleted) completer.complete();
    await completer.future;

    // Vérification serveur APRÈS fermeture du widget — on attend le résultat
    // pour que la commande soit confirmée avant d'afficher le suivi.
    if (capturedTxId != null && capturedTxId!.isNotEmpty) {
      try {
        await ApiClient.instance
            .post('/payments/$orderId/verify-kkiapay/$capturedTxId');
      } catch (_) {
        // Best-effort : le bouton "J'ai payé — Vérifier le statut" du suivi
        // permettra une re-vérification (txId mémorisé côté serveur).
      }
    }
  }

  /// Affiche la PaymentSheet Stripe puis vérifie le paiement côté serveur.
  Future<void> _handleStripe(String orderId, Map<String, dynamic> payData) async {
    final clientSecret   = payData['clientSecret'] as String?;
    final publishableKey = payData['publishableKey'] as String?;
    if (clientSecret == null || publishableKey == null || publishableKey.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Stripe non configuré (clé manquante).'),
          backgroundColor: AppColors.error,
        ));
      }
      return;
    }
    try {
      // Init de la clé publishable (idempotent).
      stripe.Stripe.publishableKey = publishableKey;
      await stripe.Stripe.instance.applySettings();

      await stripe.Stripe.instance.initPaymentSheet(
        paymentSheetParameters: stripe.SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'ifè FOOD',
        ),
      );
      await stripe.Stripe.instance.presentPaymentSheet();

      // Succès PaymentSheet → on confirme côté serveur (le webhook le fait
      // aussi, mais on déclenche /check pour une confirmation immédiate).
      try {
        await ApiClient.instance.post('/payments/$orderId/check');
      } catch (_) {/* le suivi de commande pollera le statut */}
    } on stripe.StripeException catch (e) {
      if (mounted) {
        final cancelled = e.error.code == stripe.FailureCode.Canceled;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(cancelled
              ? 'Paiement annulé.'
              : 'Paiement refusé : ${e.error.localizedMessage ?? e.error.message ?? ''}'),
          backgroundColor: cancelled ? context.textSecondary : AppColors.error,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur Stripe : ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }

  /// Ouvre la page d'approbation PayPal dans le navigateur in-app, attend la
  /// fermeture, puis déclenche la capture côté backend.
  Future<void> _handlePaypal(String orderId, Map<String, dynamic> payData) async {
    // L'URL d'approbation est dans payData['approvalUrl'] (backend extrait
    // depuis PayPal links[rel='approve']).
    final approvalUrl = payData['approvalUrl'] as String?;
    if (approvalUrl == null || approvalUrl.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("PayPal non configuré — URL d'approbation manquante."),
          backgroundColor: AppColors.error,
        ));
      }
      return;
    }

    final uri = Uri.parse(approvalUrl);
    if (await canLaunchUrl(uri)) {
      // Ouvre dans le navigateur in-app (Chrome Custom Tab / SFSafariViewController)
      await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    }

    // Dès que l'utilisateur referme le navigateur, on tente la capture.
    // L'appel est idempotent : si l'ordre n'a pas encore été approuvé
    // (utilisateur qui annule), la capture échouera silencieusement et
    // le suivi de commande proposera "Vérifier le statut".
    try {
      await ApiClient.instance.post('/payments/$orderId/capture-paypal');
    } catch (_) {
      // Best-effort : le bouton "J'ai payé — Vérifier le statut" du suivi
      // de commande appellera /payments/:orderId/check qui retente la capture.
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
    final fmt  = ref.watch(currencyFormatterProvider);
    final defaultAddr = ref.watch(defaultAddressProvider);
    final effectiveAddr = _manuallySelectedAddress ?? defaultAddr;

    return Scaffold(
      backgroundColor: context.bgColor,
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
                if (picked != null) {
                  setState(() {
                    _manuallySelectedAddress = picked;
                    _showManualInput = false;
                  });
                  _fetchDeliveryFee();
                }
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
                  foregroundColor: context.textMuted,
                  side: BorderSide(color: _showManualInput ? AppColors.primary : context.borderColor),
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
                Text('${fmt.format(item.product.price)} / unité',
                  style: TextStyle(fontFamily: 'Nunito', fontSize: 11, color: context.textMuted)),
              ])),
              Text(fmt.format(item.total),
                style: const TextStyle(fontFamily: 'Nunito', fontSize: 14, fontWeight: FontWeight.w700)),
            ]),
          )),
          const Divider(height: 20),
          _SummaryRow(label: 'Sous-total', value: fmt.format(cart.subtotal)),
          if (cart.hasPromo) ...[
            const SizedBox(height: 6),
            _SummaryRow(
              label: 'Code promo (${cart.promoCode})',
              value: '-${fmt.format(cart.promoDiscount)}',
              valueColor: AppColors.success,
            ),
          ],
          const SizedBox(height: 6),
          if (_feeLoading)
            const _SummaryRow(label: 'Livraison', value: '…')
          else if (_feeError)
            Row(children: [
              Text('Livraison',
                style: TextStyle(fontFamily: 'Nunito', fontSize: 14, color: context.textMuted)),
              const Spacer(),
              const Text('Erreur de calcul',
                style: TextStyle(fontFamily: 'Nunito', fontSize: 13, color: AppColors.error)),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () { _lastFetchedAddressId = null; _fetchDeliveryFee(); },
                child: const Icon(Icons.refresh_rounded, size: 16, color: AppColors.primary),
              ),
            ])
          else
            _SummaryRow(
              label: 'Livraison',
              value: _deliveryFee != null
                ? fmt.format(_deliveryFee!)
                : 'Calculée à la commande',
            ),
          const Divider(height: 20),
          _SummaryRow(
            label: _deliveryFee != null ? 'Total estimé' : 'À payer (hors livraison)',
            value: _deliveryFee != null
              ? fmt.format(cart.totalAfterPromo + _deliveryFee!)
              : fmt.format(cart.totalAfterPromo),
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
                  color: _selectedPayment == pm['id'] ? AppColors.primary.withOpacity(0.08) : context.bgColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _selectedPayment == pm['id'] ? AppColors.primary : context.borderColor,
                    width: _selectedPayment == pm['id'] ? 2 : 1,
                  ),
                ),
                child: Row(children: [
                  Text(pm['icon']!, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(pm['label']!, style: const TextStyle(fontFamily: 'Nunito', fontSize: 14, fontWeight: FontWeight.w700)),
                    Text(pm['sub']!, style: TextStyle(fontFamily: 'Nunito', fontSize: 12, color: context.textMuted)),
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
            : Text(_deliveryFee != null
              ? 'Commander — ${fmt.format(cart.totalAfterPromo + _deliveryFee!)}'
              : 'Payer ${fmt.format(cart.totalAfterPromo)} + livraison'),
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
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: selected ? AppColors.primary : context.cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: selected ? AppColors.primary : context.borderColor),
      ),
      child: Column(children: [
        Icon(icon, size: 20, color: selected ? Colors.white : context.textPrimary),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontFamily: 'Nunito', fontSize: 13, fontWeight: FontWeight.w700,
            color: selected ? Colors.white : context.textPrimary)),
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
        border: Border.all(color: active ? AppColors.primary : context.borderColor),
        color: !enabled
          ? context.borderColor.withOpacity(0.3)
          : active ? AppColors.primary.withOpacity(0.06) : context.bgColor,
      ),
      child: Row(children: [
        Icon(icon, size: 16, color: active ? AppColors.primary : context.textMuted),
        const SizedBox(width: 8),
        Expanded(child: Text(label,
          style: TextStyle(fontFamily: 'Nunito', fontSize: 13, fontWeight: FontWeight.w700,
            color: active ? context.textPrimary : context.textSecondary),
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
        color: context.bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.borderColor),
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
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Aucune adresse', style: TextStyle(fontFamily: 'Nunito', fontSize: 14, fontWeight: FontWeight.w800, color: context.textPrimary)),
            Text('Toucher pour ajouter une adresse de livraison', style: TextStyle(fontFamily: 'Nunito', fontSize: 12, color: context.textSecondary)),
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
            Text(address!.label, style: TextStyle(fontFamily: 'Nunito', fontSize: 14, fontWeight: FontWeight.w800, color: context.textPrimary)),
            const SizedBox(height: 2),
            Text('${address!.address}, ${address!.city}', maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontFamily: 'Nunito', fontSize: 12, color: context.textSecondary)),
          ])),
        ],
        Icon(Icons.chevron_right_rounded, color: context.textSecondary),
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
      color: context.cardColor,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: context.borderColor.withOpacity(0.8)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: TextStyle(fontFamily: 'Nunito', fontSize: 14, fontWeight: FontWeight.w800, color: context.textPrimary)),
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
        color: context.textMuted, fontWeight: isBold ? FontWeight.w700 : FontWeight.w500)),
    const Spacer(),
    Text(value, style: TextStyle(fontFamily: 'Nunito',
        fontSize: isBold ? 16 : 14,
        fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
        color: valueColor ?? (isBold ? context.textPrimary : context.textSecondary))),
  ]);
}
