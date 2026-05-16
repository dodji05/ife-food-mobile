import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/theme/app_theme.dart';

class ReviewScreen extends ConsumerStatefulWidget {
  final String orderId;
  const ReviewScreen({super.key, required this.orderId});
  @override ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  double _proRating = 0, _driverRating = 0;
  final _proComment = TextEditingController();
  final _driverComment = TextEditingController();
  bool _loading = false;

  Future<void> _submit() async {
    if (_proRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez noter l\'établissement')));
      return;
    }
    setState(() => _loading = true);
    try {
      await ApiClient.instance.post('/reviews/orders/${widget.orderId}', data: {
        'professionalRating': _proRating.round(),
        'driverRating': _driverRating > 0 ? _driverRating.round() : null,
        'professionalComment': _proComment.text.isEmpty ? null : _proComment.text,
        'driverComment': _driverComment.text.isEmpty ? null : _driverComment.text,
      });
      if (mounted) { context.go('/orders'); }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.offWhite,
    appBar: AppBar(title: const Text('Laisser un avis'), leading: const BackButton()),
    body: ListView(padding: const EdgeInsets.all(24), children: [
      const Text('Votre commande a été livrée 🎉', style: TextStyle(fontFamily: 'Nunito', fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.nearBlack)),
      const SizedBox(height: 6),
      const Text('Comment était votre expérience ?', style: TextStyle(fontFamily: 'Nunito', fontSize: 15, color: AppColors.grey)),
      const SizedBox(height: 32),

      // Restaurant rating
      _RatingBlock(
        title: '🏪 Notez l\'établissement',
        subtitle: 'Qualité des produits, présentation…',
        rating: _proRating,
        onRating: (r) => setState(() => _proRating = r),
        commentCtrl: _proComment,
        commentHint: 'Produits frais, belle présentation…',
      ),
      const SizedBox(height: 20),

      // Driver rating
      _RatingBlock(
        title: '🛵 Notez le livreur',
        subtitle: 'Rapidité, courtoisie, soin…',
        rating: _driverRating,
        onRating: (r) => setState(() => _driverRating = r),
        commentCtrl: _driverComment,
        commentHint: 'Rapide et souriant !',
      ),
      const SizedBox(height: 32),

      ElevatedButton(
        onPressed: _loading ? null : _submit,
        child: _loading
          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : const Text('Envoyer mon avis'),
      ),
      const SizedBox(height: 12),
      Center(child: TextButton(onPressed: () => context.go('/orders'),
        child: const Text('Passer', style: TextStyle(color: AppColors.grey, fontFamily: 'Nunito')))),
    ]),
  );
}

class _RatingBlock extends StatelessWidget {
  final String title, subtitle, commentHint;
  final double rating;
  final TextEditingController commentCtrl;
  final Function(double) onRating;

  const _RatingBlock({required this.title, required this.subtitle, required this.commentHint,
    required this.rating, required this.onRating, required this.commentCtrl});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.lightGrey.withOpacity(0.8))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontFamily: 'Nunito', fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.nearBlack)),
      const SizedBox(height: 2),
      Text(subtitle, style: const TextStyle(fontFamily: 'Nunito', fontSize: 13, color: AppColors.grey)),
      const SizedBox(height: 16),
      Center(child: RatingBar.builder(
        initialRating: rating, minRating: 0, itemCount: 5, itemSize: 44,
        itemBuilder: (_, __) => const Icon(Icons.star_rounded, color: AppColors.yellow),
        onRatingUpdate: onRating,
      )),
      const SizedBox(height: 8),
      Center(child: Text(_ratingLabel(rating), style: TextStyle(fontFamily: 'Nunito', fontSize: 14, fontWeight: FontWeight.w700,
        color: rating >= 4 ? AppColors.success : rating >= 2 ? AppColors.warning : AppColors.grey))),
      const SizedBox(height: 16),
      TextField(
        controller: commentCtrl, maxLines: 3,
        decoration: InputDecoration(hintText: commentHint, hintStyle: const TextStyle(color: AppColors.grey, fontFamily: 'Nunito', fontSize: 14)),
        style: const TextStyle(fontFamily: 'Nunito', fontSize: 14),
      ),
    ]),
  );

  String _ratingLabel(double r) {
    if (r == 0) return 'Sélectionnez une note';
    if (r <= 1) return 'Très mauvais 😞';
    if (r <= 2) return 'Mauvais 😕';
    if (r <= 3) return 'Correct 😐';
    if (r <= 4) return 'Bien 😊';
    return 'Excellent ! 🤩';
  }
}
