import 'dart:math';
import 'package:flutter/material.dart';

class AIThinkingLoader extends StatefulWidget {
  const AIThinkingLoader({super.key});

  @override
  State<AIThinkingLoader> createState() => _AIThinkingLoaderState();
}

class _AIThinkingLoaderState extends State<AIThinkingLoader> with TickerProviderStateMixin {
  late AnimationController _sweepCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _textCtrl;

  final _messages = const [
    'جاري تحضير قائمة الطلاب...',
    'ذكاء اصطناعي لتحليل الأداء...',
    'جاري مزامنة الحضور...',
    'تجهيز لوحة التحكم...',
    'AI يحلل بيانات الطلاب...',
  ];

  int _current = 0;
  int _next = 1;

  @override
  void initState() {
    super.initState();
    _sweepCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..repeat();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    _textCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _startCycle();
  }

  void _startCycle() {
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (!mounted) return;
      _textCtrl.forward(from: 0).then((_) {
        if (!mounted) return;
        setState(() {
          _current = _next;
          _next = (_next + 1) % _messages.length;
        });
        _textCtrl.reset();
        _startCycle();
      });
    });
  }

  @override
  void dispose() {
    _sweepCtrl.dispose();
    _pulseCtrl.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _logo(),
          const SizedBox(height: 40),
          _scrollingText(),
          const SizedBox(height: 24),
          _dots(),
        ]),
      ),
    );
  }

  Widget _logo() {
    return AnimatedBuilder(
      animation: Listenable.merge([_sweepCtrl, _pulseCtrl]),
      builder: (_, __) {
        final sweep = _sweepCtrl.value * 2 * pi;
        final pulse = 1.0 + _pulseCtrl.value * 0.06;
        return Transform.scale(
          scale: pulse,
          child: Container(
            width: 100, height: 100,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                begin: Alignment(-cos(sweep), -sin(sweep)),
                end: Alignment(cos(sweep), sin(sweep)),
                colors: const [Color(0xFF6366F1), Color(0xFF8B5CF6), Color(0xFFC4B5FD), Color(0xFF8B5CF6), Color(0xFF6366F1)],
                stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
              ),
              boxShadow: [BoxShadow(color: const Color(0xFF6366F1).withValues(alpha: 0.4), blurRadius: 30, spreadRadius: 4)],
            ),
            child: const Center(child: Icon(Icons.school_rounded, size: 52, color: Colors.white)),
          ),
        );
      },
    );
  }

  Widget _scrollingText() {
    return SizedBox(
      height: 60,
      child: AnimatedBuilder(
        animation: _textCtrl,
        builder: (_, __) {
          final p = _textCtrl.value;
          return Stack(alignment: Alignment.center, children: [
            // Next (coming from below)
            Opacity(opacity: p, child: Transform.translate(offset: Offset(0, 30 * (1 - p)), child: Transform.scale(scale: 0.85 + p * 0.15, child: _msg(_next)))),
            // Current (going up)
            Opacity(opacity: 1 - p, child: Transform.translate(offset: Offset(0, -30 * p), child: Transform.scale(scale: 1 - p * 0.15, child: _msg(_current)))),
          ]);
        },
      ),
    );
  }

  Widget _msg(int i) {
    return Text(_messages[i % _messages.length], textAlign: TextAlign.center,
      style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 15, fontFamily: 'Cairo'),
    );
  }

  Widget _dots() {
    return Row(mainAxisSize: MainAxisSize.min,
      children: List.generate(_messages.length, (i) => AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.symmetric(horizontal: 3),
        width: i == _current ? 16 : 6, height: 6,
        decoration: BoxDecoration(color: i == _current ? const Color(0xFF818CF8) : const Color(0xFF1E293B), borderRadius: BorderRadius.circular(3)),
      )),
    );
  }
}
