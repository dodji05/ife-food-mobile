import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override State<OnboardingScreen> createState() => _State();
}

class _State extends State<OnboardingScreen> {
  final _ctrl = PageController();
  int _page = 0;

  final _slides = [
    _Slide('🛒', 'Commandez\nen quelques secondes',
        'Restaurants, épiceries, pharmacies livrés chez vous partout dans le monde.',
        AppColors.primary),
    _Slide('🛵', 'Livraison\nrapide et suivie',
        'Suivez votre commande en temps réel sur la carte et contactez votre livreur.',
        AppColors.info),
    _Slide('🏪', 'Partenaires\nde confiance',
        'Des centaines de commerces vérifiés, notés par la communauté ifè FOOD.',
        AppColors.yellow),
  ];

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(child: Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Row(children: [
          RichText(text: const TextSpan(
            style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w900),
            children: [
              TextSpan(text: 'ifè ', style: TextStyle(fontSize: 18, color: AppColors.primary)),
              TextSpan(text: 'FOOD', style: TextStyle(fontSize: 18, color: AppColors.yellow)),
            ],
          )),
          const Spacer(),
          TextButton(
            onPressed: () => context.go('/auth/role'),
            child: const Text('Passer', style: TextStyle(
                fontFamily: 'Nunito', color: AppColors.lightSubtext,
                fontWeight: FontWeight.w600, fontSize: 14)),
          ),
        ]),
      ),
      Expanded(child: PageView.builder(
        controller: _ctrl, itemCount: _slides.length,
        onPageChanged: (i) => setState(() => _page = i),
        itemBuilder: (_, i) => _SlideWidget(slide: _slides[i]),
      )),
      Row(mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_slides.length, (i) => AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: i == _page ? 28 : 8, height: 8,
          decoration: BoxDecoration(
            color: i == _page ? _slides[i].color : AppColors.lightBorder,
            borderRadius: BorderRadius.circular(4)),
        ))),
      const SizedBox(height: 28),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: Column(children: [
        ElevatedButton(
          onPressed: () => _page < 2
              ? _ctrl.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.ease)
              : context.go('/auth/role'),
          child: Text(_page < 2 ? 'Suivant →' : 'Commencer'),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () => context.go('/auth/role'),
          child: const Text('J\'ai déjà un compte',
            style: TextStyle(fontFamily: 'Nunito', color: AppColors.lightSubtext,
                fontWeight: FontWeight.w600, fontSize: 14)),
        ),
      ])),
      const SizedBox(height: 16),
    ])),
  );
}

class _Slide { final String emoji, title, subtitle; final Color color;
  const _Slide(this.emoji, this.title, this.subtitle, this.color); }

class _SlideWidget extends StatelessWidget {
  final _Slide slide;
  const _SlideWidget({super.key, required this.slide});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width: 150, height: 150,
        decoration: BoxDecoration(
          color: slide.color.withOpacity(0.08), shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: slide.color.withOpacity(0.15), blurRadius: 40, spreadRadius: 10)]),
        child: Center(child: Text(slide.emoji, style: const TextStyle(fontSize: 70)))),
      const SizedBox(height: 40),
      Text(slide.title, textAlign: TextAlign.center,
        style: const TextStyle(fontFamily: 'Nunito', fontSize: 28, fontWeight: FontWeight.w900,
            color: AppColors.nearBlack, height: 1.2)),
      const SizedBox(height: 14),
      Text(slide.subtitle, textAlign: TextAlign.center,
        style: TextStyle(fontFamily: 'Nunito', fontSize: 15,
            color: AppColors.nearBlack.withOpacity(0.55), height: 1.6)),
    ]),
  );
}
