import 'dart:math';

import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _masterController;
  late final AnimationController _tractorController;
  late final AnimationController _pulseController;
  late final AnimationController _progressController;

  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _taglineOpacity;
  late final Animation<Offset> _taglineSlide;
  late final Animation<double> _progressOpacity;

  @override
  void initState() {
    super.initState();

    // Master timeline for staggered entrance.
    _masterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..forward();

    // Logo: scale up + fade in (0–40%).
    _logoScale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _masterController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOutBack),
      ),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _masterController,
        curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
      ),
    );

    // Tagline: slide up + fade in (30–60%).
    _taglineOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _masterController,
        curve: const Interval(0.3, 0.6, curve: Curves.easeOut),
      ),
    );
    _taglineSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _masterController,
        curve: const Interval(0.3, 0.6, curve: Curves.easeOutCubic),
      ),
    );

    // Progress bar: fade in (55–80%).
    _progressOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _masterController,
        curve: const Interval(0.55, 0.8, curve: Curves.easeOut),
      ),
    );

    // Repeating tractor movement.
    _tractorController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    // Pulsing glow behind logo.
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    // Indeterminate progress shimmer.
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _masterController.dispose();
    _tractorController.dispose();
    _pulseController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F5127),
              Color(0xFF1A7A3D),
              Color(0xFF1F8C45),
              Color(0xFF14612E),
            ],
            stops: [0.0, 0.3, 0.65, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Subtle field-row texture.
            Positioned.fill(
              child: CustomPaint(painter: _FieldLinesPainter()),
            ),

            // Floating particles for depth.
            ..._buildParticles(size),

            // Moving tractors (background layer).
            _AnimatedTractor(
              controller: _tractorController,
              top: size.height * 0.18,
              tractorSize: 26,
              delay: 0.0,
              opacity: 0.10,
              screenWidth: size.width,
            ),
            _AnimatedTractor(
              controller: _tractorController,
              top: size.height * 0.38,
              tractorSize: 38,
              delay: 0.35,
              opacity: 0.12,
              screenWidth: size.width,
            ),
            _AnimatedTractor(
              controller: _tractorController,
              top: size.height * 0.58,
              tractorSize: 30,
              delay: 0.65,
              opacity: 0.08,
              screenWidth: size.width,
            ),
            _AnimatedTractor(
              controller: _tractorController,
              top: size.height * 0.75,
              tractorSize: 22,
              delay: 0.15,
              opacity: 0.06,
              screenWidth: size.width,
              reverse: true,
            ),

            // Centered content.
            AnimatedBuilder(
              animation: _masterController,
              builder: (context, _) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Pulsing glow behind logo.
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          final glow = 0.08 + _pulseController.value * 0.10;
                          return Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFD5A64E)
                                      .withValues(alpha: glow),
                                  blurRadius: 60,
                                  spreadRadius: 20,
                                ),
                                BoxShadow(
                                  color: Colors.white
                                      .withValues(alpha: glow * 0.3),
                                  blurRadius: 100,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: child,
                          );
                        },
                        child: Opacity(
                          opacity: _logoOpacity.value,
                          child: Transform.scale(
                            scale: _logoScale.value,
                            child: Image.asset(
                              'assets/images/logo.png',
                              width: 240,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Tagline with slide-up.
                      SlideTransition(
                        position: _taglineSlide,
                        child: Opacity(
                          opacity: _taglineOpacity.value,
                          child: Column(
                            children: [
                              Text(
                                'Kasama ng magsasaka,',
                                textAlign: TextAlign.center,
                                style: textTheme.titleMedium?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.3,
                                  height: 1.5,
                                ),
                              ),
                              Text(
                                'tuwing ani at araro.',
                                textAlign: TextAlign.center,
                                style: textTheme.titleMedium?.copyWith(
                                  color: const Color(0xFFD5A64E),
                                  fontWeight: FontWeight.w600,
                                  fontStyle: FontStyle.italic,
                                  letterSpacing: 0.3,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 48),

                      // Sleek progress bar.
                      Opacity(
                        opacity: _progressOpacity.value,
                        child: _ShimmerProgressBar(
                          controller: _progressController,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            // Partner footer (LEADS + DA).
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: AnimatedBuilder(
                animation: _masterController,
                builder: (context, child) {
                  final opacity = Tween<double>(begin: 0.0, end: 1.0)
                      .animate(CurvedAnimation(
                    parent: _masterController,
                    curve:
                        const Interval(0.7, 1.0, curve: Curves.easeOut),
                  ));
                  return Opacity(opacity: opacity.value, child: child);
                },
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // DA / PhilMech
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Image.asset(
                                  'assets/images/philmech.png',
                                  height: 30,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) =>
                                      const SizedBox(height: 30, width: 30),
                                ),
                                const SizedBox(width: 6),
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'DEPARTMENT OF',
                                      style: TextStyle(
                                        fontSize: 7,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white
                                            .withValues(alpha: 0.7),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    Text(
                                      'AGRICULTURE',
                                      style: TextStyle(
                                        fontSize: 7,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white
                                            .withValues(alpha: 0.7),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 14),
                              child: Container(
                                width: 1,
                                height: 26,
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                            ),
                            // LeadsAgri
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Image.asset(
                                  'assets/images/leads_agri.png',
                                  height: 30,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) =>
                                      const SizedBox(height: 30, width: 30),
                                ),
                                const SizedBox(width: 6),
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Leads',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white
                                            .withValues(alpha: 0.8),
                                      ),
                                    ),
                                    Text(
                                      'Agri',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFFD5A64E)
                                            .withValues(alpha: 0.9),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '© 2026 TanodTractor · Department of Agriculture · LAPC Program',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 8,
                            color: Colors.white.withValues(alpha: 0.35),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Powered by PHilMech & LeadsAgri',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 7,
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Generates floating dot particles for parallax depth.
  List<Widget> _buildParticles(Size size) {
    final rng = Random(42); // fixed seed for consistent layout
    return List.generate(12, (i) {
      final x = rng.nextDouble() * size.width;
      final yBase = rng.nextDouble() * size.height;
      final dotSize = 2.0 + rng.nextDouble() * 3.0;
      final alpha = 0.04 + rng.nextDouble() * 0.06;
      final speed = 0.3 + rng.nextDouble() * 0.5;

      return AnimatedBuilder(
        animation: _tractorController,
        builder: (context, _) {
          final y =
              (yBase - _tractorController.value * size.height * speed) %
                  size.height;
          return Positioned(
            left: x,
            top: y,
            child: Container(
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: alpha),
              ),
            ),
          );
        },
      );
    });
  }
}

/// A single tractor silhouette that glides across the screen.
class _AnimatedTractor extends StatelessWidget {
  const _AnimatedTractor({
    required this.controller,
    required this.top,
    required this.tractorSize,
    required this.delay,
    required this.opacity,
    required this.screenWidth,
    this.reverse = false,
  });

  final AnimationController controller;
  final double top;
  final double tractorSize;
  final double delay;
  final double opacity;
  final double screenWidth;
  final bool reverse;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final t = (controller.value + delay) % 1.0;
        final travel = screenWidth + tractorSize * 2;
        final x = reverse
            ? screenWidth + tractorSize - t * travel
            : -tractorSize + t * travel;

        return Positioned(
          top: top,
          left: x,
          child: Transform.flip(
            flipX: reverse,
            child: Opacity(
              opacity: opacity,
              child: Image.asset(
                'assets/images/tractor_green_color.png',
                width: tractorSize,
                height: tractorSize,
                color: Colors.white,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Horizontal shimmer progress bar.
class _ShimmerProgressBar extends StatelessWidget {
  const _ShimmerProgressBar({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      height: 3,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _ShimmerPainter(progress: controller.value),
          );
        },
      ),
    );
  }
}

class _ShimmerPainter extends CustomPainter {
  _ShimmerPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    // Track.
    final trackPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;
    final rr = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(2),
    );
    canvas.drawRRect(rr, trackPaint);

    // Shimmer highlight.
    final center = progress * (size.width + 80) - 40;
    final shimmerPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withValues(alpha: 0.0),
          const Color(0xFFD5A64E).withValues(alpha: 0.7),
          Colors.white.withValues(alpha: 0.9),
          const Color(0xFFD5A64E).withValues(alpha: 0.7),
          Colors.white.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
      ).createShader(Rect.fromLTWH(center - 40, 0, 80, size.height));

    canvas.drawRRect(rr, shimmerPaint);
  }

  @override
  bool shouldRepaint(_ShimmerPainter old) => old.progress != progress;
}

/// Draws subtle diagonal lines suggesting field rows.
class _FieldLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    const spacing = 48.0;
    final count = (size.width + size.height) ~/ spacing;

    for (var i = 0; i < count; i++) {
      final offset = i * spacing;
      canvas.drawLine(
        Offset(offset - size.height * 0.3, 0),
        Offset(offset + size.height * 0.3, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
