// ─────────────────────────────────────────────────────────────────────────────
// ifè FOOD — Configuration du Splash Screen / Loading
//
// Modifier SplashConfig pour changer le type d'animation :
//   SplashType.image   → assets/images/splash.png (défaut)
//   SplashType.lottie  → assets/animations/splash.json
//   SplashType.video   → assets/animations/splash.mp4
//   SplashType.custom  → widget Flutter personnalisé
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:video_player/video_player.dart';
import '../constants/app_constants.dart';
import '../theme/app_theme.dart';

enum SplashType { image, lottie, video, custom }

class SplashConfig {
  // ── Changer cette valeur pour basculer le type d'animation ──────────────
  // FIX: lottie → custom pour éviter un crash si assets/animations/splash.json est absent.
  // Remettre SplashType.lottie une fois le fichier Lottie ajouté dans assets/animations/.
  static const SplashType type = SplashType.custom;

  // Chemins des assets (selon le type choisi)
  static const String imagePath     = 'assets/images/splash.png';
  static const String lottiePath    = 'assets/animations/splash.json';
  static const String videoPath     = 'assets/animations/splash.mp4';

  // Durée minimale d'affichage (en ms)
  static const int minDurationMs    = AppConstants.splashMinDurationMs;

  // Fond du splash
  static const Color backgroundColor = Colors.white;

  // Taille du logo/animation
  static const double assetSize      = 160.0;

  // Texte de chargement (null = aucun)
  static const String? loadingText   = 'Chargement…';

  // Slogan (optionnel)
  static const String? tagline       = 'Commandez. Recevez. Savourez.';
}

// ─────────────────────────────────────────────────────────────────────────────
// Widget Splash Screen
// ─────────────────────────────────────────────────────────────────────────────
// Le SplashScreen est purement visuel.
// La navigation est entièrement gérée par AuthNotifier._bootstrap() + GoRouter redirect.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late Animation<double> _fade;
  VideoPlayerController? _videoCtrl;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();

    if (SplashConfig.type == SplashType.video) _initVideo();
  }

  Future<void> _initVideo() async {
    _videoCtrl = VideoPlayerController.asset(SplashConfig.videoPath);
    await _videoCtrl!.initialize();
    _videoCtrl!.play();
    setState(() {});
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _videoCtrl?.dispose();
    super.dispose();
  }

  Widget _buildAsset() {
    switch (SplashConfig.type) {
      case SplashType.image:
        return Image.asset(SplashConfig.imagePath,
            width: SplashConfig.assetSize, height: SplashConfig.assetSize,
            errorBuilder: (_, __, ___) => _fallbackLogo());

      case SplashType.lottie:
        return Lottie.asset(SplashConfig.lottiePath,
            width: SplashConfig.assetSize, height: SplashConfig.assetSize,
            errorBuilder: (_, __, ___) => _fallbackLogo());

      case SplashType.video:
        if (_videoCtrl?.value.isInitialized == true) {
          return SizedBox(
            width: SplashConfig.assetSize, height: SplashConfig.assetSize,
            child: VideoPlayer(_videoCtrl!),
          );
        }
        return _fallbackLogo();

      case SplashType.custom:
        return _fallbackLogo(); // Remplacer par votre widget
    }
  }

  // Fallback si l'asset échoue
  Widget _fallbackLogo() => Container(
    width: SplashConfig.assetSize, height: SplashConfig.assetSize,
    decoration: BoxDecoration(
      color: AppColors.primary, borderRadius: BorderRadius.circular(28),
    ),
    child: const Center(
      child: Text('ifè\nFOOD',
        textAlign: TextAlign.center,
        style: TextStyle(fontFamily: 'Nunito', fontSize: 24,
            fontWeight: FontWeight.w900, color: Colors.white, height: 1.1)),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: SplashConfig.backgroundColor,
    body: FadeTransition(
      opacity: _fade,
      child: Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildAsset(),
          const SizedBox(height: 32),
          // Logo textuel
          RichText(text: const TextSpan(
            style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w900),
            children: [
              TextSpan(text: 'ifè ', style: TextStyle(fontSize: 28, color: AppColors.primary)),
              TextSpan(text: 'FOOD', style: TextStyle(fontSize: 28, color: AppColors.yellow)),
            ],
          )),
          if (SplashConfig.tagline != null) ...[
            const SizedBox(height: 8),
            Text(SplashConfig.tagline!,
              style: const TextStyle(fontFamily: 'Nunito', fontSize: 13,
                  color: Color(0xFF7a9e82), fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 48),
          if (SplashConfig.loadingText != null) ...[
            const SizedBox(
              width: 24, height: 24,
              child: CircularProgressIndicator(
                  strokeWidth: 2.5, color: AppColors.primary),
            ),
            const SizedBox(height: 12),
            Text(SplashConfig.loadingText!,
              style: const TextStyle(fontFamily: 'Nunito', fontSize: 12,
                  color: Color(0xFF9AA89C), fontWeight: FontWeight.w600)),
          ],
        ],
      )),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Widget de chargement réseau (inline dans les écrans)
// ─────────────────────────────────────────────────────────────────────────────
class AppLoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;
  final String? message;
  const AppLoadingOverlay({super.key, required this.isLoading,
      required this.child, this.message});

  @override
  Widget build(BuildContext context) => Stack(children: [
    child,
    if (isLoading) Positioned.fill(child: Container(
      color: Colors.black.withOpacity(0.35),
      child: Center(child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const CircularProgressIndicator(color: AppColors.primary),
          if (message != null) ...[
            const SizedBox(height: 12),
            Text(message!, style: const TextStyle(
                fontFamily: 'Nunito', fontSize: 13, fontWeight: FontWeight.w700)),
          ],
        ]),
      )),
    )),
  ]);
}
