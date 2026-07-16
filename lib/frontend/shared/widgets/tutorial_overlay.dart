import 'package:flutter/material.dart';
import 'package:tanodmobile/app/theme/app_colors.dart';

// ─────────────────────────────────────────────────────────────
// Data model for a single tutorial step
// ─────────────────────────────────────────────────────────────

enum TutorialTooltipPosition { top, bottom, left, right }
enum TutorialHighlightShape { circle, roundedRect }

class TutorialStep {
  final GlobalKey targetKey;
  final String title;
  final String description;
  final TutorialTooltipPosition tooltipPosition;
  final TutorialHighlightShape highlightShape;
  final double highlightPadding;

  const TutorialStep({
    required this.targetKey,
    required this.title,
    required this.description,
    this.tooltipPosition = TutorialTooltipPosition.bottom,
    this.highlightShape = TutorialHighlightShape.roundedRect,
    this.highlightPadding = 8,
  });
}

// ─────────────────────────────────────────────────────────────
/// Overlay-based tutorial / coachmark system.
// ─────────────────────────────────────────────────────────────

class TutorialOverlay {
  TutorialOverlay._();

  static OverlayEntry? _entry;
  static int _currentStep = 0;
  static List<TutorialStep> _steps = [];
  static VoidCallback? _onComplete;
  static VoidCallback? _onSkip;

  /// Returns `true` while the overlay is visible.
  static bool get isActive => _entry != null;

  /// Show a multi-step tutorial overlay.
  static void show({
    required BuildContext context,
    required List<TutorialStep> steps,
    VoidCallback? onComplete,
    VoidCallback? onSkip,
  }) {
    hide();

    _steps = steps;
    _currentStep = 0;
    _onComplete = onComplete;
    _onSkip = onSkip;

    _entry = OverlayEntry(builder: (_) => _TutorialOverlayWidget());
    Overlay.of(context).insert(_entry!);
  }

  /// Dismiss the tutorial overlay.
  static void hide() {
    _entry?.remove();
    _entry = null;
  }

  static Future<void> _next() async {
    final nextStep = _currentStep + 1;
    if (nextStep < _steps.length) {
      await _scrollToTarget(_steps[nextStep].targetKey);
      _currentStep = nextStep;
      _entry?.markNeedsBuild();
    } else {
      hide();
      _onComplete?.call();
    }
  }

  static Future<void> _scrollToTarget(GlobalKey key) async {
    final ctx = key.currentContext;
    if (ctx != null && ctx.mounted) {
      try {
        await Scrollable.ensureVisible(
          ctx,
          alignment: 0.3,
          duration: const Duration(milliseconds: 400),
        );
      } catch (_) {}
    }
  }

  static Future<void> _previous() async {
    final prevStep = _currentStep - 1;
    if (prevStep >= 0) {
      await _scrollToTarget(_steps[prevStep].targetKey);
      _currentStep = prevStep;
      _entry?.markNeedsBuild();
    }
  }
}

// ─────────────────────────────────────────────────────────────
/// A self-contained tutorial widget that can be embedded directly
/// in any widget tree (no OverlayEntry needed).
/// Place this as the last child of a Stack to cover the entire screen.
// ─────────────────────────────────────────────────────────────

class TutorialOverlayWidget extends StatefulWidget {
  final List<TutorialStep> steps;
  final VoidCallback? onComplete;
  final VoidCallback? onSkip;

  const TutorialOverlayWidget({
    super.key,
    required this.steps,
    this.onComplete,
    this.onSkip,
  });

  @override
  State<TutorialOverlayWidget> createState() => _TutorialOverlayWidgetState();
}

class _TutorialOverlayWidgetState extends State<TutorialOverlayWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    final nextStep = _currentStep + 1;
    if (nextStep < widget.steps.length) {
      final ctx = widget.steps[nextStep].targetKey.currentContext;
      if (ctx != null && ctx.mounted) {
        try {
          await Scrollable.ensureVisible(
            ctx,
            alignment: 0.3,
            duration: const Duration(milliseconds: 400),
          );
        } catch (_) {}
      }
      setState(() => _currentStep = nextStep);
    } else {
      widget.onComplete?.call();
    }
  }

  Future<void> _previous() async {
    final prevStep = _currentStep - 1;
    if (prevStep >= 0) {
      final ctx = widget.steps[prevStep].targetKey.currentContext;
      if (ctx != null && ctx.mounted) {
        try {
          await Scrollable.ensureVisible(
            ctx,
            alignment: 0.3,
            duration: const Duration(milliseconds: 400),
          );
        } catch (_) {}
      }
      setState(() => _currentStep = prevStep);
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_currentStep];
    final isFirst = _currentStep == 0;
    final isLast = _currentStep == widget.steps.length - 1;

    return FadeTransition(
      opacity: _fadeAnim,
      child: Stack(
        children: [
          // ── Dark background with cutout ──
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _CutoutPainter(
                  step: step,
                  overlayColor: Colors.black.withValues(alpha: 0.55),
                ),
              ),
            ),
          ),

          // ── Tooltip card ──
          Positioned.fill(
            child: _TooltipCard(
              step: step,
              currentStep: _currentStep,
              totalSteps: widget.steps.length,
              isFirst: isFirst,
              isLast: isLast,
              onSkip: () {
                _animCtrl.reverse().then((_) => widget.onSkip?.call());
              },
              onPrevious: _previous,
              onNext: _next,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Internal overlay widget (used by static TutorialOverlay.show)
// ─────────────────────────────────────────────────────────────

class _TutorialOverlayWidget extends StatefulWidget {
  @override
  State<_TutorialOverlayWidget> createState() =>
      _TutorialOverlayWidgetState2();
}

class _TutorialOverlayWidgetState2 extends State<_TutorialOverlayWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final step = TutorialOverlay._steps[TutorialOverlay._currentStep];
    final isFirst = TutorialOverlay._currentStep == 0;
    final isLast =
        TutorialOverlay._currentStep == TutorialOverlay._steps.length - 1;

    return FadeTransition(
      opacity: _fadeAnim,
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _CutoutPainter(
                  step: step,
                  overlayColor: Colors.black.withValues(alpha: 0.55),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: _TooltipCard(
              step: step,
              currentStep: TutorialOverlay._currentStep,
              totalSteps: TutorialOverlay._steps.length,
              isFirst: isFirst,
              isLast: isLast,
              onSkip: () {
                TutorialOverlay.hide();
                TutorialOverlay._onSkip?.call();
              },
              onPrevious: TutorialOverlay._previous,
              onNext: TutorialOverlay._next,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Paints the dark overlay with a transparent cutout
// ─────────────────────────────────────────────────────────────

class _CutoutPainter extends CustomPainter {
  final TutorialStep step;
  final Color overlayColor;

  _CutoutPainter({required this.step, required this.overlayColor});

  @override
  void paint(Canvas canvas, Size size) {
    final RenderObject? renderBox =
        step.targetKey.currentContext?.findRenderObject();
    if (renderBox == null || !renderBox.attached) {
      // Fallback: paint full overlay
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = overlayColor,
      );
      return;
    }

    final target = renderBox is RenderBox
        ? renderBox.localToGlobal(Offset.zero, ancestor: null)
        : Offset.zero;
    final targetSize = renderBox is RenderBox ? renderBox.size : Size.zero;

    final pad = step.highlightPadding;
    final rect = Rect.fromLTWH(
      target.dx - pad,
      target.dy - pad,
      targetSize.width + pad * 2,
      targetSize.height + pad * 2,
    );

    // Full-screen path
    final full = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    // Cutout path
    Path cutout;
    if (step.highlightShape == TutorialHighlightShape.circle) {
      final center = rect.center;
      final radius = rect.shortestSide / 2;
      cutout = Path()..addOval(Rect.fromCircle(center: center, radius: radius));
    } else {
      cutout = Path()
        ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(14)));
    }

    // Difference: full - cutout = full with a transparent hole
    final overlayPath = Path.combine(PathOperation.difference, full, cutout);

    canvas.drawPath(overlayPath, Paint()..color = overlayColor);
  }

  @override
  bool shouldRepaint(covariant _CutoutPainter oldDelegate) =>
      oldDelegate.step != step || oldDelegate.overlayColor != overlayColor;
}

// ─────────────────────────────────────────────────────────────
// Tooltip card positioned near the highlighted widget
// ─────────────────────────────────────────────────────────────

class _TooltipCard extends StatelessWidget {
  final TutorialStep step;
  final int currentStep;
  final int totalSteps;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onSkip;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const _TooltipCard({
    required this.step,
    required this.currentStep,
    required this.totalSteps,
    required this.isFirst,
    required this.isLast,
    required this.onSkip,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final RenderObject? renderBox =
        step.targetKey.currentContext?.findRenderObject();
    if (renderBox == null || !renderBox.attached) return const SizedBox();

    final target = renderBox is RenderBox
        ? renderBox.localToGlobal(Offset.zero, ancestor: null)
        : Offset.zero;
    final targetSize = renderBox is RenderBox ? renderBox.size : Size.zero;
    final screenSize = MediaQuery.of(context).size;

    final pad = step.highlightPadding;
    final targetRect = Rect.fromLTWH(
      target.dx - pad,
      target.dy - pad,
      targetSize.width + pad * 2,
      targetSize.height + pad * 2,
    );

    return Stack(
      children: [
        // Position the tooltip
        Positioned(
          left: 20,
          right: 20,
          top: _tooltipTop(screenSize, targetRect),
          bottom: _tooltipBottom(screenSize, targetRect),
          child: _buildCard(context, screenSize),
        ),
      ],
    );
  }

  double? _tooltipTop(Size screen, Rect target) {
    switch (step.tooltipPosition) {
      case TutorialTooltipPosition.bottom:
        if (target.bottom + 200 < screen.height) return target.bottom + 16;
        return null;
      case TutorialTooltipPosition.top:
        return null;
      case TutorialTooltipPosition.left:
      case TutorialTooltipPosition.right:
        return (target.center.dy - 100).clamp(20, screen.height - 240);
    }
  }

  double? _tooltipBottom(Size screen, Rect target) {
    switch (step.tooltipPosition) {
      case TutorialTooltipPosition.bottom:
        return null;
      case TutorialTooltipPosition.top:
        if (target.top > 240) return screen.height - target.top + 16;
        return 20.0;
      case TutorialTooltipPosition.left:
      case TutorialTooltipPosition.right:
        return null;
    }
  }

  Widget _buildCard(BuildContext context, Size screenSize) {
    final double maxCardHeight = screenSize.height * 0.55;

    final alignment = switch (step.tooltipPosition) {
      TutorialTooltipPosition.top => Alignment.bottomCenter,
      TutorialTooltipPosition.bottom => Alignment.topCenter,
      TutorialTooltipPosition.left => Alignment.centerRight,
      TutorialTooltipPosition.right => Alignment.centerLeft,
    };

    return Align(
      alignment: alignment,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (step.tooltipPosition == TutorialTooltipPosition.bottom)
            _buildArrowUp(),
          Container(
            constraints: BoxConstraints(
              maxWidth: screenSize.width - 40,
              maxHeight: maxCardHeight,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Step indicator + Skip
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.forest.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${currentStep + 1} of $totalSteps',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.forest,
                            ),
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: onSkip,
                          child: Text(
                            'Skip',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.mutedInk.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Title
                    Text(
                      step.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Description
                    Text(
                      step.description,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: AppColors.mutedInk,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Navigation buttons
                    Row(
                      children: [
                        // Dot indicators
                        Expanded(
                          child: Row(
                            children: List.generate(
                              totalSteps.clamp(1, 12),
                              (i) => Container(
                              width: i == currentStep ? 14 : 6,
                              height: 6,
                              margin: const EdgeInsets.only(right: 4),
                                decoration: BoxDecoration(
                                  color: i == currentStep
                                      ? AppColors.forest
                                      : AppColors.mutedInk.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Previous
                        if (!isFirst)
                          GestureDetector(
                            onTap: onPrevious,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: AppColors.canvas,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Back',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.mutedInk,
                                ),
                              ),
                            ),
                          ),
                        if (!isFirst) const SizedBox(width: 8),

                        // Next / Finish
                        GestureDetector(
                          onTap: onNext,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.forest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              isLast ? 'Finish' : 'Next',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (step.tooltipPosition == TutorialTooltipPosition.top)
            _buildArrowDown(),
        ],
      ),
    );
  }

  Widget _buildArrowUp() {
    return Center(
      child: ClipPath(
        clipper: _ArrowClipper(flip: false),
        child: Container(
          width: 20,
          height: 10,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildArrowDown() {
    return Center(
      child: ClipPath(
        clipper: _ArrowClipper(flip: true),
        child: Container(
          width: 20,
          height: 10,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _ArrowClipper extends CustomClipper<Path> {
  final bool flip;
  _ArrowClipper({this.flip = false});

  @override
  Path getClip(Size size) {
    final path = Path()
      ..moveTo(0, flip ? size.height : 0)
      ..lineTo(size.width / 2, flip ? 0 : size.height)
      ..lineTo(size.width, flip ? size.height : 0)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant _ArrowClipper old) => old.flip != flip;
}
