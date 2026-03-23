import 'package:flutter/material.dart';

class SaveAnimationController {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _progressOpacityAnimation;
  final TickerProvider vsync;
  bool _isDisposed = false;

  SaveAnimationController({required this.vsync}) {
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: vsync,
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeInBack)),
        weight: 20,
      ),
      TweenSequenceItem(tween: ConstantTween<double>(0.0), weight: 60),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 20,
      ),
    ]).animate(_controller);

    _progressOpacityAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween<double>(0.0), weight: 20),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 10,
      ),
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 40),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 10,
      ),
      TweenSequenceItem(tween: ConstantTween<double>(0.0), weight: 20),
    ]).animate(_controller);

    _rotationAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.8, curve: Curves.easeInOutCubic),
      ),
    );
  }

  bool get isAnimating =>
      !_isDisposed && (_controller.isAnimating || _controller.value > 0);
  AnimationController get controller => _controller;
  Animation<double> get scaleAnimation => _scaleAnimation;
  Animation<double> get progressOpacityAnimation => _progressOpacityAnimation;
  Animation<double> get rotationAnimation => _rotationAnimation;

  void start() {
    if (!_isDisposed) {
      _controller.animateTo(0.5, duration: const Duration(milliseconds: 700));
    }
  }

  Future<void> complete() async {
    if (!_isDisposed) {
      await _controller.forward(from: _controller.value);
      _controller.reset();
    }
  }

  void reset() {
    if (!_isDisposed) {
      _controller.reset();
    }
  }

  void dispose() {
    if (!_isDisposed) {
      _isDisposed = true;
      _controller.dispose();
    }
  }
}

class SaveButton extends StatelessWidget {
  final VoidCallback onPressed;
  final SaveAnimationController controller;

  const SaveButton({
    super.key,
    required this.onPressed,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Save Note',
      icon: AnimatedBuilder(
        animation: controller.controller,
        builder: (context, child) {
          final colorScheme = Theme.of(context).colorScheme;
          final primaryColor = colorScheme.primary;
          final value = controller.controller.value;

          return SizedBox(
            width: 24,
            height: 24,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (controller.progressOpacityAnimation.value > 0)
                  Opacity(
                    opacity: controller.progressOpacityAnimation.value,
                    child: RotationTransition(
                      turns: controller.rotationAnimation,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.0,
                        strokeCap: StrokeCap.round,
                        value: null,
                        valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                      ),
                    ),
                  ),

                if (value <= 0.2 || (value >= 0.8))
                  Transform.scale(
                    scale: controller.scaleAnimation.value,
                    child: Icon(
                      Icons.save_rounded,
                      size: 24,
                      color: primaryColor,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
      onPressed: controller.isAnimating ? null : onPressed,
    );
  }
}
