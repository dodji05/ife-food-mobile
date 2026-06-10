import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_colors.dart';
import '../../providers/pro_provider.dart';
import '../../../../core/api/api_client.dart';

class ReviewsScreen extends ConsumerWidget {
  const ReviewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(reviewsProvider);

    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(title: const Text('Avis clients')),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (d) {
          final reviews = (d['reviews'] as List? ?? []);
          final avg = (d['average'] ?? 0.0) as num;
          final count = d['count'] ?? 0;

          return ListView(padding: const EdgeInsets.all(16), children: [
            // Rating overview
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [AppColors.accent.withOpacity(0.15), context.cardColor], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.accent.withOpacity(0.3)),
              ),
              child: Row(children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(avg.toStringAsFixed(1), style: const TextStyle(fontFamily: 'Nunito', fontSize: 48, fontWeight: FontWeight.w900, color: AppColors.accent)),
                  RatingBarIndicator(rating: avg.toDouble(), itemBuilder: (_, __) => const Icon(Icons.star_rounded, color: AppColors.accent), itemSize: 20, itemCount: 5),
                  const SizedBox(height: 4),
                  Text('$count avis clients', style: TextStyle(fontFamily: 'Nunito', fontSize: 13, color: context.textSecondary)),
                ]),
                const Spacer(),
                const Text('⭐', style: TextStyle(fontSize: 64)),
              ]),
            ),
            const SizedBox(height: 20),

            if (reviews.isEmpty) Center(child: Column(children: [
              const SizedBox(height: 40),
              const Text('💬', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              Text('Aucun avis pour le moment', style: TextStyle(fontFamily: 'Nunito', fontSize: 16, fontWeight: FontWeight.w700, color: context.textPrimary)),
              const SizedBox(height: 6),
              Text('Les avis apparaîtront après les premières livraisons', style: TextStyle(fontFamily: 'Nunito', fontSize: 13, color: context.textSecondary), textAlign: TextAlign.center),
            ])),

            ...reviews.map((r) => _ReviewCard(review: r, ref: ref)).toList(),
          ]);
        },
      ),
    );
  }
}

class _ReviewCard extends StatefulWidget {
  final Map<String, dynamic> review; final WidgetRef ref;
  const _ReviewCard({required this.review, required this.ref});
  @override State<_ReviewCard> createState() => _RCS();
}

class _RCS extends State<_ReviewCard> {
  bool _showReply = false;
  final _replyCtrl = TextEditingController();
  bool _loading = false;

  Future<void> _submitReply() async {
    if (_replyCtrl.text.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      await ApiClient.instance.post('/reviews/${widget.review['id']}/reply', data: {'reply': _replyCtrl.text.trim()});
      setState(() { _showReply = false; });
      widget.ref.invalidate(reviewsProvider);
    } finally { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.review;
    final reviewer = r['reviewer'] as Map? ?? {};
    final rating = (r['professionalRating'] ?? 0) as num;
    final date = DateTime.tryParse(r['createdAt'] ?? '') ?? DateTime.now();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: context.cardColor, borderRadius: BorderRadius.circular(14), border: Border.all(color: context.borderColor)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(radius: 18, backgroundColor: AppColors.primary.withOpacity(0.2),
            child: Text((reviewer['name'] ?? 'C').toString().substring(0, 1).toUpperCase(),
              style: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800, color: AppColors.primary, fontSize: 14))),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(reviewer['name'] ?? 'Client', style: TextStyle(fontFamily: 'Nunito', fontSize: 13, fontWeight: FontWeight.w700, color: context.textPrimary)),
            Text('${date.day}/${date.month}/${date.year}', style: TextStyle(fontFamily: 'Nunito', fontSize: 11, color: context.textSecondary)),
          ])),
          RatingBarIndicator(rating: rating.toDouble(), itemBuilder: (_, __) => const Icon(Icons.star_rounded, color: AppColors.accent), itemSize: 16, itemCount: 5),
        ]),
        if (r['professionalComment'] != null) ...[
          const SizedBox(height: 10),
          Text(r['professionalComment'], style: TextStyle(fontFamily: 'Nunito', fontSize: 14, color: context.textSecondary, height: 1.5)),
        ],
        // Existing reply
        if (r['professionalReply'] != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.primary.withOpacity(0.2))),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('🏪', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 8),
              Expanded(child: Text(r['professionalReply'], style: TextStyle(fontFamily: 'Nunito', fontSize: 13, color: context.textPrimary, height: 1.4))),
            ]),
          ),
        ],
        // Reply UI
        if (r['professionalReply'] == null) ...[
          const SizedBox(height: 10),
          if (!_showReply) TextButton.icon(
            onPressed: () => setState(() => _showReply = true),
            icon: const Icon(Icons.reply_rounded, size: 16, color: AppColors.primary),
            label: const Text('Répondre', style: TextStyle(fontFamily: 'Nunito', fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary)),
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
          ) else Column(children: [
            TextField(
              controller: _replyCtrl, maxLines: 3,
              style: TextStyle(fontFamily: 'Nunito', fontSize: 13, color: context.textPrimary),
              decoration: const InputDecoration(hintText: 'Votre réponse au client…'),
            ),
            const SizedBox(height: 8),
            Row(children: [
              TextButton(onPressed: () => setState(() => _showReply = false), child: const Text('Annuler')),
              const Spacer(),
              ElevatedButton(
                onPressed: _loading ? null : _submitReply,
                style: ElevatedButton.styleFrom(minimumSize: const Size(100, 36), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                child: _loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Publier'),
              ),
            ]),
          ]),
        ],
      ]),
    );
  }
}
