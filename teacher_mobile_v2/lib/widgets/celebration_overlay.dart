import 'dart:math';
import 'package:flutter/material.dart';

class CelebrationOverlay extends StatefulWidget {
  final VoidCallback onComplete;
  const CelebrationOverlay({super.key, required this.onComplete});

  @override
  State<CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends State<CelebrationOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_Confetti> _particles = [];
  final Random _random = Random();
  bool _showMessage = false;

  @override
  void initState() {
    super.initState();
    _initParticles();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..addListener(() {
        if (_controller.value >= 0.5 && !_showMessage) {
          setState(() => _showMessage = true);
        }
        setState(() {});
      });
    _controller.forward();
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted) widget.onComplete();
    });
  }

  void _initParticles() {
    for (int i = 0; i < 80; i++) {
      _particles.add(_Confetti(
        x: _random.nextDouble(),
        y: _random.nextDouble() * -0.3,
        speed: 0.3 + _random.nextDouble() * 0.5,
        size: 4 + _random.nextDouble() * 8,
        color: [
          Colors.red,
          Colors.blue,
          Colors.green,
          Colors.yellow,
          Colors.purple,
          Colors.orange,
          Colors.pink,
          Colors.teal,
        ][_random.nextInt(8)],
        wobble: _random.nextDouble() * 2,
        delay: _random.nextDouble() * 2,
        rotation: _random.nextDouble() * 6,
      ));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final progress = _controller.value;

    return Stack(
      children: [
        // Semi-transparent background
          Positioned.fill(
          child: Container(color: Colors.black.withOpacity(0.6 * min(progress * 4, 1.0))),
        ),
        // Confetti particles
        ..._particles.map((p) {
          final pProgress = ((progress - p.delay / 10).clamp(0.0, 1.0));
          final yPos = p.y + pProgress * p.speed;
          if (yPos > 1.1) return const SizedBox.shrink();

          final wobble = sin(progress * p.wobble * 8) * 0.03;
          final opacity = pProgress < 0.05 ? pProgress / 0.05 : 1.0;
          final scale = pProgress < 0.05 ? pProgress / 0.05 : 1.0;

          return Positioned(
            left: (p.x + wobble) * size.width,
            top: yPos * size.height,
            child: Transform.rotate(
              angle: p.rotation + progress * 3,
              child: Opacity(
                opacity: opacity,
                child: Container(
                  width: p.size,
                  height: p.size * 1.5,
                  decoration: BoxDecoration(
                    color: p.color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          );
        }),
        // Fireworks from bottom
        if (progress > 0.1 && progress < 0.5)
          Positioned(
            left: size.width * 0.08,
            bottom: size.height * 0.1,
            child: _buildRocket(progress, -1),
          ),
        if (progress > 0.15 && progress < 0.55)
          Positioned(
            right: size.width * 0.08,
            bottom: size.height * 0.05,
            child: _buildRocket(progress, 1),
          ),
        // Firework explosions
        if (progress > 0.25 && progress < 0.8) ...[
          Positioned(
            left: size.width * 0.2,
            top: size.height * 0.2,
            child: _buildExplosion(progress, 0.25),
          ),
          Positioned(
            right: size.width * 0.25,
            top: size.height * 0.15,
            child: _buildExplosion(progress, 0.3),
          ),
          Positioned(
            left: size.width * 0.5,
            top: size.height * 0.08,
            child: _buildExplosion(progress, 0.35),
          ),
        ],
        // Celebration emojis
        if (progress > 0.4)
          Positioned(
            left: size.width * 0.15,
            top: size.height * 0.4,
            child: _buildEmoji(progress, 0.4, 1),
          ),
        if (progress > 0.45)
          Positioned(
            right: size.width * 0.15,
            top: size.height * 0.35,
            child: _buildEmoji(progress, 0.45, -1),
          ),
        // Success message
        if (_showMessage)
          Center(
            child: AnimatedOpacity(
              opacity: _showMessage ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 500),
              child: Container(
                margin: const EdgeInsets.all(32),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withOpacity(0.4),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🎉', style: TextStyle(fontSize: 48)),
                    const SizedBox(height: 12),
                    Text(
                      '✅ تم تفعيل اشتراكك بنجاح',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.none,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRocket(double progress, int dir) {
    final rProgress = ((progress - 0.1) / 0.3).clamp(0.0, 1.0);
    final bottom = rProgress * 300;
    return Transform.rotate(
      angle: dir * 0.3,
      child: Text('🚀', style: TextStyle(fontSize: 28 + rProgress * 10),
    ));
  }

  Widget _buildExplosion(double progress, double start) {
    final eProgress = ((progress - start) / 0.15).clamp(0.0, 1.0);
    final scale = 0.5 + eProgress * 2;
    final opacity = eProgress < 0.5 ? eProgress * 2 : (1.0 - eProgress) * 2;
    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Transform.scale(
        scale: scale,
        child: Text(
          ['🎆', '🎇', '✨', '⭐'][_random.nextInt(4)],
          style: const TextStyle(fontSize: 40),
        ),
      ),
    );
  }

  Widget _buildEmoji(double progress, double start, int side) {
    final eProgress = ((progress - start) / 0.3).clamp(0.0, 1.0);
    final offset = side * (1.0 - eProgress) * 50;
    final opacity = eProgress < 0.2 ? eProgress * 5 : (eProgress < 0.7 ? 1.0 : (1.0 - eProgress) * 3.3);
    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(offset, 0),
        child: Text(
          ['🎊', '🎉', '💫', '🌟'][_random.nextInt(4)],
          style: TextStyle(fontSize: 32 + sin(eProgress * 10) * 8),
        ),
      ),
    );
  }
}

class _Confetti {
  final double x, y, speed, size, wobble, delay, rotation;
  final Color color;
  _Confetti({
    required this.x,
    required this.y,
    required this.speed,
    required this.size,
    required this.color,
    required this.wobble,
    required this.delay,
    required this.rotation,
  });
}
