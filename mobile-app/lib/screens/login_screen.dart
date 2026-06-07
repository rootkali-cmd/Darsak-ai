import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../core/theme.dart';
import 'teacher_connect_screen.dart';

class LoginScreen extends StatefulWidget {
  final String? teacherCode;
  const LoginScreen({super.key, this.teacherCode});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _codeController = TextEditingController();
  final _pinController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic));
    _fadeController.forward();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _pinController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final auth = context.read<AuthProvider>();
    final success = await auth.login(
      _codeController.text.trim(),
      _pinController.text.trim(),
      teacherCode: widget.teacherCode,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.error ?? 'خطأ في تسجيل الدخول'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child:
                            const Icon(Icons.school, color: Colors.white, size: 40),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'تسجيل دخول الطالب',
                        style: TextStyle(
                          color: AppColors.textPrimary(context),
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.teacherCode != null
                            ? 'مرحباً بك في DarsakAI'
                            : 'أدخل كود الطالب ورقم PIN السري',
                        style: TextStyle(color: AppColors.textSecondary(context), fontSize: 14),
                      ),
                      const SizedBox(height: 40),
                      TextFormField(
                        controller: _codeController,
                        textDirection: TextDirection.ltr,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textPrimary(context),
                          fontSize: 18,
                          letterSpacing: 2,
                        ),
                        decoration: InputDecoration(
                          labelText: 'كود الطالب',
                          hintText: 'STXXXXXXX',
                          hintStyle: TextStyle(color: AppColors.textSecondary(context)),
                          prefixIcon:
                              const Icon(Icons.badge, color: Color(0xFF2563EB)),
                          filled: true,
                          fillColor: AppColors.inputFill(context),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Color(0xFF2563EB)),
                          ),
                        ),
                        textInputAction: TextInputAction.next,
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'أدخل كود الطالب' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _pinController,
                        textDirection: TextDirection.ltr,
                        textAlign: TextAlign.center,
                        obscureText: true,
                        style: TextStyle(
                          color: AppColors.textPrimary(context),
                          fontSize: 24,
                          letterSpacing: 8,
                        ),
                        decoration: InputDecoration(
                          labelText: 'PIN',
                          hintText: '••••••',
                          hintStyle: TextStyle(color: AppColors.textSecondary(context)),
                          prefixIcon:
                              const Icon(Icons.lock, color: Color(0xFF2563EB)),
                          filled: true,
                          fillColor: AppColors.inputFill(context),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Color(0xFF2563EB)),
                          ),
                          counterText: '',
                        ),
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _login(),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                        ],
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'أدخل PIN';
                          final pin = v.trim();
                          if (pin.length < 6 || pin.length > 8) {
                            return 'PIN يجب أن يكون 6-8 أحرف وأرقام';
                          }
                          if (!RegExp(r'^[A-Za-z0-9]{6,8}$').hasMatch(pin)) {
                            return 'PIN: أحرف وأرقام فقط';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            disabledBackgroundColor:
                                const Color(0xFF2563EB).withValues(alpha: 0.3),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Text(
                                  'تسجيل الدخول',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      if (widget.teacherCode == null) ...[
                        const SizedBox(height: 16),
                        TextButton.icon(
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const TeacherConnectScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.qr_code, size: 18),
                          label: const Text('تسجيل عبر باركود المعلم'),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF2563EB),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
