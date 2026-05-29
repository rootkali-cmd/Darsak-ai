import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/auth_provider.dart';

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
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;

  late final AnimationController _gradientController;
  late final AnimationController _floatController;
  late final AnimationController _fadeController;
  late final AnimationController _slideController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  final List<_FloatingShape> _shapes = [];

  @override
  void initState() {
    super.initState();
    _gradientController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();
    _floatController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat(reverse: true);
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));

    _initShapes();
    _fadeController.forward();
    _slideController.forward();
  }

  void _initShapes() {
    final rng = math.Random(42);
    for (int i = 0; i < 10; i++) {
      _shapes.add(_FloatingShape(
        x: rng.nextDouble() * 600 - 300,
        y: rng.nextDouble() * 600 - 300,
        radius: 30 + rng.nextDouble() * 80,
        speed: 0.3 + rng.nextDouble() * 0.7,
        opacity: 0.04 + rng.nextDouble() * 0.06,
      ));
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _gradientController.dispose();
    _floatController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    await auth.login(
      _emailController.text.trim(),
      _passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.themeMode == ThemeMode.dark;

    final bgColor1 = isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF5F7FA);
    final bgColor2 = isDark ? const Color(0xFF0F0F1A) : const Color(0xFFE8ECF1);
    final bgColor3 = isDark ? const Color(0xFF0A0A14) : const Color(0xFFE0E4EA);

    return Scaffold(
      body: AnimatedBuilder(
        animation: Listenable.merge([_gradientController, _floatController]),
        builder: (context, _) {
          final gradientValue = math.sin(_gradientController.value * 2 * math.pi) * 0.5 + 0.5;
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(bgColor1, bgColor2, gradientValue)!,
                  Color.lerp(bgColor2, bgColor3, gradientValue)!,
                  Color.lerp(bgColor3, bgColor1, gradientValue)!,
                ],
              ),
            ),
            child: Stack(
              children: [
                CustomPaint(
                  size: Size.infinite,
                  painter: _ShapesPainter(
                    shapes: _shapes,
                    offset: _floatController.value,
                    backdropSize: MediaQuery.of(context).size,
                    isDark: isDark,
                  ),
                ),
                Center(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: _LoginCard(
                        formKey: _formKey,
                        emailController: _emailController,
                        passwordController: _passwordController,
                        obscurePassword: _obscurePassword,
                        onTogglePassword: () => setState(() => _obscurePassword = !_obscurePassword),
                        onLogin: _login,
                      ),
                    ),
                  ),
                ),
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
                        backgroundColor: (isDark ? AppTheme.darkSurface : AppTheme.lightSurface).withValues(alpha: 0.7),
                        foregroundColor: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: (isDark ? AppTheme.darkBorder : AppTheme.lightBorder).withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LoginCard extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final VoidCallback onTogglePassword;
  final VoidCallback onLogin;

  const _LoginCard({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.onTogglePassword,
    required this.onLogin,
  });

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final surfaceColor = (isDark ? AppTheme.darkSurface : AppTheme.lightSurface).withValues(alpha: 0.55);
    final borderColor = (isDark ? AppTheme.darkBorder : AppTheme.lightBorder).withValues(alpha: 0.3);
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textSecondary = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;
    final shadowColor = Colors.black.withValues(alpha: isDark ? 0.3 : 0.08);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        width: 420,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: 50,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(36),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderColor),
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppTheme.accent, AppTheme.accentLight],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.accent.withValues(alpha: 0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.school_rounded, color: Colors.white, size: 30),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'DarsakAI',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'تسجيل الدخول إلى حسابك',
                      style: TextStyle(color: textSecondary, fontSize: 14),
                    ),
                    const SizedBox(height: 28),
                    if (auth.error != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: AppTheme.danger.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.danger.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: AppTheme.danger, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                auth.error!,
                                style: const TextStyle(color: AppTheme.danger, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    TextFormField(
                      controller: emailController,
                      decoration: const InputDecoration(
                        labelText: 'البريد الإلكتروني',
                        prefixIcon: Icon(Icons.email_outlined, size: 20),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      textDirection: TextDirection.ltr,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'يرجى إدخال البريد الإلكتروني';
                        if (!v.contains('@')) return 'البريد الإلكتروني غير صالح';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: passwordController,
                      decoration: InputDecoration(
                        labelText: 'كلمة المرور',
                        prefixIcon: const Icon(Icons.lock_outline, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 20,
                          ),
                          onPressed: onTogglePassword,
                        ),
                      ),
                      obscureText: obscurePassword,
                      textDirection: TextDirection.ltr,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'يرجى إدخال كلمة المرور';
                        if (v.length < 6) return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
                        return null;
                      },
                      onFieldSubmitted: (_) => onLogin(),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: auth.isLoading ? null : onLogin,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
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
                    const SizedBox(height: 20),
                    Text(
                      'بمتابعتك فإنك توافق على شروط الاستخدام',
                      style: TextStyle(
                        color: textSecondary.withValues(alpha: 0.5),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FloatingShape {
  final double x;
  final double y;
  final double radius;
  final double speed;
  final double opacity;

  const _FloatingShape({
    required this.x,
    required this.y,
    required this.radius,
    required this.speed,
    required this.opacity,
  });
}

class _ShapesPainter extends CustomPainter {
  final List<_FloatingShape> shapes;
  final double offset;
  final Size backdropSize;
  final bool isDark;

  _ShapesPainter({
    required this.shapes,
    required this.offset,
    required this.backdropSize,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(backdropSize.width / 2, backdropSize.height / 2);

    for (final shape in shapes) {
      final x = center.dx + shape.x + offset * shape.speed * 30;
      final y = center.dy + shape.y + math.sin(offset * shape.speed * 2) * 20;

      final paint = Paint()
        ..color = (isDark ? Colors.white : AppTheme.accent).withValues(alpha: shape.opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

      canvas.drawCircle(Offset(x, y), shape.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ShapesPainter oldDelegate) => true;
}
