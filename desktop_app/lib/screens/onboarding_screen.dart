import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../providers/auth_provider.dart';
import 'dashboard_screen.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback toggleTheme;
  final ThemeMode themeMode;

  const OnboardingScreen({super.key, required this.toggleTheme, required this.themeMode});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with TickerProviderStateMixin {
  final _subjects = ['رياضيات', 'علوم', 'عربي', 'إنجليزي', 'تاريخ', 'جغرافيا', 'فلسفة', 'كيمياء', ' فيزياء', 'أحياء', 'حاسب آلي', 'تربية دينية', 'اقتصاد', 'إحصاء'];
  final _levels = ['أولى إعدادي', 'ثانية إعدادي', 'ثالثة إعدادي', 'أولى ثانوي', 'ثانية ثانوي', 'ثالثة ثانوي'];

  final Set<String> selectedSubjects = {};
  final Set<String> selectedLevels = {};
  final nameController = TextEditingController();

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  int _step = 0;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(duration: const Duration(milliseconds: 400), vsync: this);
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    nameController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_step < 2) {
      _fadeController.reverse().then((_) {
        setState(() => _step++);
        _fadeController.forward();
      });
    }
  }

  Future<void> _complete() async {
    final name = nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى إدخال اسمك'), backgroundColor: AppTheme.danger));
      return;
    }

    try {
      await context.read<AuthProvider>().saveOnboarding(
        fullName: name,
        subjects: selectedSubjects.toList(),
        levels: selectedLevels.toList(),
      );
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => DashboardScreen(toggleTheme: widget.toggleTheme, themeMode: widget.themeMode),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل حفظ البيانات، تحقق من الاتصال'), backgroundColor: AppTheme.danger));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.themeMode == ThemeMode.dark;
    final bgColor = isDark ? AppTheme.darkBg : AppTheme.lightBg;
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textSecondary = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;

    return Scaffold(
      backgroundColor: bgColor,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Container(
            width: 520,
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [AppTheme.accent, AppTheme.accentLight]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.school, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Text('مرحباً بك في درسك AI', style: TextStyle(color: textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                Text('لنبدأ بإعداد حسابك', style: TextStyle(color: textSecondary, fontSize: 14)),
                const SizedBox(height: 32),
                _buildStepIndicator(isDark),
                const SizedBox(height: 32),
                if (_step == 0) _buildNameStep(textPrimary, textSecondary),
                if (_step == 1) _buildSubjectsStep(textPrimary, textSecondary, isDark),
                if (_step == 2) _buildLevelsStep(textPrimary, textSecondary, isDark),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_step > 0)
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: TextButton(
                          onPressed: () {
                            _fadeController.reverse().then((_) {
                              setState(() => _step--);
                              _fadeController.forward();
                            });
                          },
                          child: const Text('السابق'),
                        ),
                      ),
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: ElevatedButton(
                        onPressed: _step < 2 ? _nextStep : _complete,
                        child: Text(_step < 2 ? 'التالي' : 'ابدأ'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final isActive = i <= _step;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 28 : 10,
          height: 6,
          decoration: BoxDecoration(
            color: isActive ? AppTheme.accent : (isDark ? Colors.white12 : Colors.black12),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }

  Widget _buildNameStep(Color textPrimary, Color textSecondary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ما اسمك؟', style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        TextField(
          controller: nameController,
          decoration: const InputDecoration(
            hintText: 'الاسم الكامل',
            prefixIcon: Icon(Icons.person),
          ),
        ),
      ],
    );
  }

  Widget _buildSubjectsStep(Color textPrimary, Color textSecondary, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ما المواد التي تدرسها؟', style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('اختر مادة أو أكثر', style: TextStyle(color: textSecondary, fontSize: 13)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _subjects.map((s) => FilterChip(
            label: Text(s),
            selected: selectedSubjects.contains(s),
            onSelected: (v) => setState(() => v ? selectedSubjects.add(s) : selectedSubjects.remove(s)),
            selectedColor: AppTheme.accent.withValues(alpha: 0.2),
            checkmarkColor: AppTheme.accent,
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildLevelsStep(Color textPrimary, Color textSecondary, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ما المراحل الدراسية؟', style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('اختر مرحلة أو أكثر', style: TextStyle(color: textSecondary, fontSize: 13)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _levels.map((l) => FilterChip(
            label: Text(l),
            selected: selectedLevels.contains(l),
            onSelected: (v) => setState(() => v ? selectedLevels.add(l) : selectedLevels.remove(l)),
            selectedColor: AppTheme.accent.withValues(alpha: 0.2),
            checkmarkColor: AppTheme.accent,
          )).toList(),
        ),
      ],
    );
  }
}
