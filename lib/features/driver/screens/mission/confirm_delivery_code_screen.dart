// ─────────────────────────────────────────────────────────────────────────────
// ifè FOOD Driver — ConfirmDeliveryCodeScreen
//
// Écran plein écran (pas un Dialog superposé) pour la saisie du code de
// confirmation de livraison communiqué par le client.
//
// Remplace l'ancien _ConfirmCodeDialog (showDialog) : celui-ci provoquait un
// crash Flutter récurrent (InheritedElement.debugDeactivated:
// '_dependents.isEmpty' is not true) quand il était affiché par-dessus
// active_mission_screen.dart, qui contient un GoogleMap (PlatformView). Le
// clavier auto-focus du dialog redimensionnait l'écran sous-jacent avec la
// carte, désactivant/réactivant la vue native — bug Flutter connu avec les
// PlatformViews. Un écran plein écran séparé élimine complètement cette
// combinaison à risque : la carte n'est plus montée pendant la saisie.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';

class ConfirmDeliveryCodeScreen extends StatefulWidget {
  final int digits;
  const ConfirmDeliveryCodeScreen({super.key, required this.digits});

  @override
  State<ConfirmDeliveryCodeScreen> createState() => _ConfirmDeliveryCodeScreenState();
}

class _ConfirmDeliveryCodeScreenState extends State<ConfirmDeliveryCodeScreen> {
  final _ctrl = TextEditingController();
  bool _obscure = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _confirm() {
    final code = _ctrl.text.trim();
    if (code.length == widget.digits) {
      context.pop(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        title: const Text('Confirmer la livraison',
          style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800, color: Colors.black87)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
            const SizedBox(height: 24),
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.verified_user_rounded,
                  color: AppColors.success, size: 36),
            ),
            const SizedBox(height: 20),
            const Text('Code de confirmation',
              style: TextStyle(fontFamily: 'Nunito', fontSize: 20,
                  fontWeight: FontWeight.w900, color: Colors.black87)),
            const SizedBox(height: 8),
            Text(
              'Demandez le code à ${widget.digits} chiffres au client\npour confirmer la livraison.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Nunito', fontSize: 14,
                  color: Colors.black54, height: 1.4),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _ctrl,
              autofocus: true,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              maxLength: widget.digits,
              obscureText: _obscure,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _confirm(),
              style: const TextStyle(
                fontFamily: 'Nunito', fontSize: 28,
                fontWeight: FontWeight.w900, color: Colors.black87,
                letterSpacing: 12,
              ),
              decoration: InputDecoration(
                counterText: '',
                hintText: '·' * widget.digits,
                hintStyle: const TextStyle(
                  fontSize: 28, letterSpacing: 12,
                  color: Color(0xFFE0E0E0)),
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE0E0E0))),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE0E0E0))),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.success, width: 2)),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                    color: Colors.black54, size: 20),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
          ]),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () => context.pop(null),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFE0E0E0)),
                foregroundColor: Colors.black54,
                minimumSize: const Size(0, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Annuler',
                  style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700)),
            )),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(
              onPressed: _ctrl.text.trim().length == widget.digits ? _confirm : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Confirmer',
                  style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800)),
            )),
          ]),
        ),
      ),
    );
  }
}
