import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback toggleTheme;
  final ThemeMode themeMode;

  const LoginScreen({
    super.key,
    required this.toggleTheme,
    required this.themeMode,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _floatController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _floatAnimation;

  final List<_FloatingShape> _shapes = [];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _floatController = AnimationController(
      duration: const Duration(seconds: 6),
      vsync: this,
    )..repeat(reverse: true);

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<double>(begin: 30, end: 0).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );
    _floatAnimation = Tween<double>(begin: -8, end: 8).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    _initShapes();
    _fadeController.forward();
    _slideController.forward();
  }

  void _initShapes() {
    final rng = math.Random(42);
    for (int i = 0; i < 8; i++) {
      _shapes.add(_FloatingShape(
        x: rng.nextDouble() * 400 - 200,
        y: rng.nextDouble() * 400 - 200,
        size: 60 + rng.nextDouble() * 120,
        rotation: rng.nextDouble() * 360,
        speed: 0.3 + rng.nextDouble() * 0.7,
        opacity: 0.03 + rng.nextDouble() * 0.05,
      ));
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final auth = context.read<AuthProvider>();
    final success = await auth.login(
      _emailController.text.trim(),
      _passwordController.text,
    );
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.error ?? 'فشل تسجيل الدخول'),
          backgroundColor: AppTheme.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // Background with gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [const Color(0xFF0F0F0F), const Color(0xFF1A1A2E)]
                    : [const Color(0xFFF8F9FA), const Color(0xFFE8ECF1)],
              ),
            ),
          ),
          // Floating shapes background
          AnimatedBuilder(
            animation: _floatAnimation,
            builder: (context, _) {
              return CustomPaint(
                size: size,
                painter: _ShapesPainter(
                  shapes: _shapes,
                  offset: _floatAnimation.value,
                  isDark: isDark,
                ),
              );
            },
          ),
          // Login card
          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.05),
                  end: Offset.zero,
                ).animate(_slideAnimation),
                child: _LoginCard(
                  emailController: _emailController,
                  passwordController: _passwordController,
                  obscurePassword: _obscurePassword,
                  onTogglePassword: () => setState(() => _obscurePassword = !_obscurePassword),
                  onLogin: _login,
                ),
              ),
            ),
          ),
          // Theme toggle button
          Positioned(
            top: 20,
            right: 20,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: IconButton(
                onPressed: widget.toggleTheme,
                icon: Icon(
                  widget.themeMode == ThemeMode.dark
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined,
                  size: 22,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: isDark
                      ? AppTheme.darkSurface.withValues(alpha: 0.8)
                      : AppTheme.lightSurface.withValues(alpha: 0.8),
                  foregroundColor: isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.lightTextSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginCard extends StatefulWidget {
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final VoidCallback onTogglePassword;
  final VoidCallback onLogin;

  const _LoginCard({
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.onTogglePassword,
    required this.onLogin,
  });

  @override
  State<_LoginCard> createState() => _LoginCardState();
}

class _LoginCardState extends State<_LoginCard> with SingleTickerProviderStateMixin {
  late AnimationController _hoverController;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.005).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textSecondary = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;

    return MouseRegion(
      onEnter: (_) {
        setState(() => _isHovered = true);
        _hoverController.forward();
      },
      onExit: (_) {
        setState(() => _isHovered = false);
        _hoverController.reverse();
      },
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, _) => Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(36),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                  blurRadius: 40,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.accent, AppTheme.accentLight],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accent.withValues(alpha: 0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.school, color: Colors.white, size: 28),
                ),
                const SizedBox(height: 24),
                // Title
                Text(
                  'Darsak AI',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'تسجيل الدخول إلى حسابك',
                  style: TextStyle(color: textSecondary, fontSize: 14),
                ),
                const SizedBox(height: 32),
                // Divider
                Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        borderColor,
                        borderColor.withValues(alpha: 0.3),
                        borderColor,
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Email field
                TextField(
                  controller: widget.emailController,
                  decoration: InputDecoration(
                    labelText: 'البريد الإلكتروني',
                    prefixIcon: const Icon(Icons.email_outlined, size: 20),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  textDirection: TextDirection.ltr,
                ),
                const SizedBox(height: 16),
                // Password field
                TextField(
                  controller: widget.passwordController,
                  decoration: InputDecoration(
                    labelText: 'كلمة المرور',
                    prefixIcon: const Icon(Icons.lock_outline, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                        widget.obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 20,
                      ),
                      onPressed: widget.onTogglePassword,
                    ),
                  ),
                  obscureText: widget.obscurePassword,
                  textDirection: TextDirection.ltr,
                  onSubmitted: (_) => widget.onLogin(),
                ),
                const SizedBox(height: 28),
                // Login button
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: auth.isLoading ? null : widget.onLogin,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: auth.isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'تسجيل الدخول',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Footer
                Text(
                  'بمتابعتك فإنك توافق على شروط الاستخدام',
                  style: TextStyle(
                    color: textSecondary.withValues(alpha: 0.6),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FloatingShape {
  final double x, y, size, rotation, speed, opacity;

  _FloatingShape({
    required this.x,
    required this.y,
    required this.size,
    required this.rotation,
    required this.speed,
    required this.opacity,
  });
}

class _ShapesPainter extends CustomPainter {
  final List<_FloatingShape> shapes;
  final double offset;
  final bool isDark;

  _ShapesPainter({
    required this.shapes,
    required this.offset,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    for (final shape in shapes) {
      final x = center.dx + shape.x + offset * shape.speed * 20;
      final y = center.dy + shape.y + math.sin(offset * shape.speed) * 15;

      final paint = Paint()
        ..color = (isDark ? Colors.white : AppTheme.accent).withValues(alpha: shape.opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(shape.rotation * math.pi / 180);

      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset.zero,
          width: shape.size,
          height: shape.size * 0.7,
        ),
        Radius.circular(shape.size * 0.1),
      );
      canvas.drawRRect(rect, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ShapesPainter oldDelegate) => true;
}
