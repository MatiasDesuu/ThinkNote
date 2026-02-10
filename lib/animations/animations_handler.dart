import 'package:flutter/material.dart';

class SaveAnimationController {
  late AnimationController _controller;
  late Animation<double> _fadeOutIconAnimation;
  late Animation<double> _progressAnimation;
  late Animation<double> _fadeInIconAnimation;
  final TickerProvider vsync;
  bool _isDisposed = false;

  SaveAnimationController({required this.vsync}) {
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: vsync,
    );

    _fadeOutIconAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.2, curve: Curves.easeOut),
      ),
    );

    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.8, curve: Curves.linear),
      ),
    );

    _fadeInIconAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.8, 1.0, curve: Curves.easeIn),
      ),
    );
  }

  bool get isAnimating =>
      !_isDisposed &&
      (_controller.isAnimating ||
          _controller.value > 0 && _controller.value < 0.99);
  AnimationController get controller => _controller;
  Animation<double> get fadeOutIconAnimation => _fadeOutIconAnimation;
  Animation<double> get progressAnimation => _progressAnimation;
  Animation<double> get fadeInIconAnimation => _fadeInIconAnimation;

  void start() {
    if (!_isDisposed) {
      if (!_controller.isAnimating) {
        _controller.forward(from: 0.0);
      }
    }
  }

  Future<void> complete() async {
    if (!_isDisposed && _controller.status != AnimationStatus.completed) {
      await _controller.forward(from: _controller.value);

      if (!_isDisposed && _controller.value < 1.0) {
        _controller.value = 1.0;
      }
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
      icon: AnimatedBuilder(
        animation: controller.controller,
        builder: (context, child) {
          final primaryColor = Theme.of(context).colorScheme.primary;
          final value = controller.controller.value;

          return Stack(
            alignment: Alignment.center,
            children: [
              if (value > 0.2 && value < 0.8)
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    strokeCap: StrokeCap.round,
                    valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                  ),
                ),

              Opacity(
                opacity:
                    controller.fadeOutIconAnimation.value +
                    controller.fadeInIconAnimation.value,
                child: Icon(Icons.save_rounded, size: 24, color: primaryColor),
              ),
            ],
          );
        },
      ),
      onPressed: controller.isAnimating ? null : onPressed,
    );
  }
}
