import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const SplashScreen({super.key, required this.onComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _pulseController;
  late Animation<double> _logoScale;
  late Animation<double> _logoFade;
  late Animation<double> _textFade;
  late Animation<Offset> _textSlide;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _textController = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);

    _logoScale = Tween<double>(begin: 0.3, end: 1.0).animate(CurvedAnimation(parent: _logoController, curve: Curves.elasticOut));
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _logoController, curve: Curves.easeIn));
    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(_textController);
    _textSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(CurvedAnimation(parent: _textController, curve: Curves.easeOut));
    _pulse = Tween<double>(begin: 0.95, end: 1.05).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

    _startSequence();
  }

  void _startSequence() async {
    await Future.delayed(const Duration(milliseconds: 300));
    _logoController.forward();
    await Future.delayed(const Duration(milliseconds: 600));
    _textController.forward();
    await Future.delayed(const Duration(milliseconds: 1600));
    widget.onComplete();
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0D1B2A), Color(0xFF102840), Color(0xFF0A2040)],
          ),
        ),
        child: Stack(
          children: [
            // Background decorations
            Positioned(top: -60, right: -60, child: _glow(300, AppColors.primary.withOpacity(0.07))),
            Positioned(bottom: -80, left: -80, child: _glow(280, AppColors.mintGreen.withOpacity(0.05))),

            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo
                  FadeTransition(
                    opacity: _logoFade,
                    child: ScaleTransition(
                      scale: _logoScale,
                      child: ScaleTransition(
                        scale: _pulse,
                        child: Container(
                          width: 110, height: 110,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [AppColors.primary, AppColors.mintGreen], begin: Alignment.topLeft, end: Alignment.bottomRight),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 40, spreadRadius: 5),
                              BoxShadow(color: AppColors.mintGreen.withOpacity(0.2), blurRadius: 60, spreadRadius: 10),
                            ],
                          ),
                          child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 52),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // App name
                  SlideTransition(
                    position: _textSlide,
                    child: FadeTransition(
                      opacity: _textFade,
                      child: Column(children: [
                        Text(
                          'ANTIGRAVITY',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 6,
                            shadows: [Shadow(color: AppColors.primary.withOpacity(0.5), blurRadius: 20)],
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Healthcare. Reimagined.',
                          style: TextStyle(color: Colors.white54, fontSize: 14, letterSpacing: 2, fontWeight: FontWeight.w300),
                        ),
                        const SizedBox(height: 32),
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          _dot(AppColors.primary),
                          _dot(AppColors.mintGreen),
                          _dot(AppColors.warning),
                        ]),
                      ]),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom tagline
            Positioned(
              bottom: 48, left: 0, right: 0,
              child: FadeTransition(
                opacity: _textFade,
                child: Column(children: [
                  const Text('Powered by', style: TextStyle(color: Colors.white30, fontSize: 11)),
                  const SizedBox(height: 4),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(6)),
                      child: const Text('Featherless AI', style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(6)),
                      child: const Text('flutter_map', style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                  ]),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _glow(double size, Color color) => Container(width: size, height: size, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
  Widget _dot(Color color) => Container(margin: const EdgeInsets.symmetric(horizontal: 4), width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}
