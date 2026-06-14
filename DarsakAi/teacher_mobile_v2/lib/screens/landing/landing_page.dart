import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../login_screen.dart';
import '../register_screen.dart';
import '../home_screen.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  final List<_SlideData> _slides = [
    _SlideData(
      icon: Icons.school_rounded,
      title: 'مرحباً بك في درسك AI',
      subtitle: 'أول منصة مصرية متكاملة لإدارة السناتر التعليمية بالذكاء الاصطناعي',
      color: Color(0xFF6366F1),
      gradient: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
    ),
    _SlideData(
      icon: Icons.people_rounded,
      title: 'إدارة الطلاب',
      subtitle: 'أضف طلابك بالباركود، تتابع حضورهم ودرجاتهم، وتتواصل مع أولياء الأمور — كل طالب وله ملف كامل',
      color: Color(0xFF3B82F6),
      gradient: [Color(0xFF3B82F6), Color(0xFF6366F1)],
    ),
    _SlideData(
      icon: Icons.qr_code_scanner_rounded,
      title: 'تسجيل الحضور بالباركود',
      subtitle: 'سجل حضور الطلاب في ثواني بمسح الباركود — لا حاجة للعد اليدوي أو الأوراق',
      color: Color(0xFFF59E0B),
      gradient: [Color(0xFFF59E0B), Color(0xFFEF4444)],
    ),
    _SlideData(
      icon: Icons.auto_awesome_rounded,
      title: 'ذكاء اصطناعي',
      subtitle: 'حلل أداء طلابك، ولّد اختبارات تلقائياً، واكتشف نقاط القوة والضعف — كل ده بالـ AI',
      color: Color(0xFF8B5CF6),
      gradient: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
    ),
    _SlideData(
      icon: Icons.play_circle_rounded,
      title: 'فيديوهات تعليمية',
      subtitle: 'ارفع دروس فيديو وشاركها مع طلابك — الطلاب يقدروا يشوفوا الدروس من موبايلهم',
      color: Color(0xFF10B981),
      gradient: [Color(0xFF10B981), Color(0xFF3B82F6)],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _slideController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));
    _slideAnim = Tween<Offset>(begin: const Offset(0.3, 0), end: Offset.zero).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    } else {
      _goToAuth();
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    }
  }

  void _goToAuth() {
    final auth = context.read<AuthProvider>();
    if (auth.isAuthenticated) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const RegisterScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0a0a1a), Color(0xFF0a0a1a)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Skip button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_currentPage > 0)
                      TextButton.icon(
                        onPressed: _prevPage,
                        icon: const Icon(Icons.arrow_back_ios, size: 14, color: Color(0xFF94A3B8)),
                        label: const Text('رجوع', style: TextStyle(color: Color(0xFF94A3B8), fontFamily: 'Cairo')),
                      )
                    else
                      const SizedBox(width: 80),
                    TextButton(
                      onPressed: _goToAuth,
                      child: const Text('تخطي', style: TextStyle(color: Color(0xFF94A3B8), fontFamily: 'Cairo')),
                    ),
                  ],
                ),
              ),

              // Page view
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _slides.length,
                  onPageChanged: (index) {
                    setState(() => _currentPage = index);
                    _fadeController.reset();
                    _slideController.reset();
                    _fadeController.forward();
                    _slideController.forward();
                  },
                  itemBuilder: (context, index) {
                    final slide = _slides[index];
                    return AnimatedBuilder(
                      animation: Listenable.merge([_fadeController, _slideController]),
                      builder: (context, child) {
                        return FadeTransition(
                          opacity: _fadeAnim,
                          child: SlideTransition(
                            position: _slideAnim,
                            child: _buildSlide(slide),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              // Dots + Next button
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Dots
                    Row(
                      children: List.generate(_slides.length, (index) {
                        final isActive = index == _currentPage;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: isActive ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isActive ? const Color(0xFF6366F1) : const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),

                    // Next / Start button
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _currentPage == _slides.length - 1
                          ? ElevatedButton(
                              key: const ValueKey('start'),
                              onPressed: _goToAuth,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6366F1),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                elevation: 8,
                                shadowColor: const Color(0xFF6366F1).withValues(alpha: 0.4),
                              ),
                              child: const Text('ابدأ الآن', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                            )
                          : ElevatedButton(
                              key: const ValueKey('next'),
                              onPressed: _nextPage,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6366F1),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                elevation: 8,
                                shadowColor: const Color(0xFF6366F1).withValues(alpha: 0.4),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('التالي', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, fontFamily: 'Cairo')),
                                  SizedBox(width: 6),
                                  Icon(Icons.arrow_forward_ios, size: 14),
                                ],
                              ),
                            ),
                    ),
                  ],
                ),
              ),

              // Login link
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('لديك حساب؟ ', style: TextStyle(color: Color(0xFF94A3B8), fontFamily: 'Cairo')),
                    GestureDetector(
                      onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                      child: const Text('تسجيل الدخول', style: TextStyle(color: Color(0xFF818CF8), fontWeight: FontWeight.w600, fontFamily: 'Cairo')),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSlide(_SlideData slide) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated icon
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 800),
            builder: (_, v, __) => Transform.scale(
              scale: v,
              child: Container(
                width: 120, height: 120,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: slide.gradient,
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: slide.color.withValues(alpha: 0.4),
                      blurRadius: 40,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: Icon(slide.icon, size: 60, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 40),
          // Title
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontFamily: 'Cairo',
              height: 1.3,
            ),
          ),
          const SizedBox(height: 16),
          // Subtitle
          Text(
            slide.subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF94A3B8),
              fontFamily: 'Cairo',
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _SlideData {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final List<Color> gradient;

  _SlideData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.gradient,
  });
}
