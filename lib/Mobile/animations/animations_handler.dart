import 'package:flutter/material.dart';

class SaveAnimationController {
  final TickerProvider vsync;
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _opacityAnimation;
  bool _isAnimating = false;

  SaveAnimationController({required this.vsync}) {
    _controller = AnimationController(
      vsync: vsync,
      duration: const Duration(milliseconds: 800),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.8).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeInOut),
        reverseCurve: const Interval(0.5, 1.0, curve: Curves.easeInOut),
      ),
    );

    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeInOut),
        reverseCurve: const Interval(0.5, 1.0, curve: Curves.easeInOut),
      ),
    );
  }

  bool get isAnimating => _isAnimating;

  void start() {
    _isAnimating = true;
    _controller.forward();
  }

  Future<void> complete() async {
    await _controller.reverse();
    _isAnimating = false;
  }

  void reset() {
    _controller.reset();
    _isAnimating = false;
  }

  void dispose() {
    _controller.dispose();
  }
}

class SaveButton extends StatelessWidget {
  final SaveAnimationController controller;
  final VoidCallback onPressed;

  const SaveButton({
    super.key,
    required this.controller,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller._controller,
      builder: (context, child) {
        return Transform.scale(
          scale: controller._scaleAnimation.value,
          child: Opacity(
            opacity: controller._opacityAnimation.value,
            child: FloatingActionButton(
              heroTag: 'saveButton',
              onPressed: onPressed,
              child: const Icon(Icons.save_rounded),
            ),
          ),
        );
      },
    );
  }
}
