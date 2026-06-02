import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../services/api_service.dart';
import '../home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with SingleTickerProviderStateMixin {
  final _pageController = PageController();
  int _currentStep = 0;
  final _nameCtrl = TextEditingController();
  final List<String> _selectedSubjects = [];
  final List<String> _selectedLevels = [];
  bool _saving = false;

  late final AnimationController _pulseController;

  final _subjectOptions = [
    'رياضيات', 'فيزياء', 'كيمياء', 'أحياء', 'عربي', 'إنجليزي',
    'فرنساوي', 'ألماني', 'تاريخ', 'جغرافيا', 'فلسفة', 'علوم',
    'دراسات', 'حاسب آلي',
  ];

  final _levelOptions = ['ابتدائي', 'إعدادي', 'ثانوي', 'جامعي'];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameCtrl.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentStep < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    } else {
      _saveAndContinue();
    }
  }

  Future<void> _saveAndContinue() async {
    setState(() => _saving = true);
    try {
      await ApiService().dio.patch('/auth/onboarding', data: {
        'full_name': _nameCtrl.text.trim(),
        'subjects': _selectedSubjects,
        'levels': _selectedLevels,
      });
    } catch (_) {}
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      PageRouteBuilder(
        pageBuilder: (_, _, _) => const HomeScreen(),
        transitionDuration: const Duration(milliseconds: 400),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: isDark
                ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
                : [const Color(0xFFEEF2FF), const Color(0xFFF8FAFC)],
          ),
        ),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 12),
                _buildProgressBar(isDark),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (i) => setState(() => _currentStep = i),
                    children: [
                      _buildWelcomeStep(isDark),
                      _buildNameStep(isDark),
                      _buildSubjectsStep(isDark),
                      _buildLevelsStep(isDark),
                    ],
                  ),
                ),
                _buildBottomControls(isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        children: List.generate(4, (i) {
          final isActive = i <= _currentStep;
          final isPast = i < _currentStep;
          return Expanded(
            child: Container(
              height: 4,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: isActive
                    ? AppTheme.accent
                    : (isDark ? Colors.white12 : Colors.black12),
                borderRadius: BorderRadius.circular(2),
                boxShadow: isPast
                    ? [BoxShadow(color: AppTheme.accent.withValues(alpha: 0.3), blurRadius: 4)]
                    : null,
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildBottomControls(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _saving ? null : _next,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                disabledBackgroundColor: AppTheme.accent.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 2,
                shadowColor: AppTheme.accent.withValues(alpha: 0.3),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _currentStep == 3 ? 'ابدأ' : 'التالي',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontFamily: 'Cairo',
                          ),
                        ),
                        if (_currentStep < 3) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded,
                              color: Colors.white, size: 20),
                        ],
                      ],
                    ),
            ),
          ),
          if (_currentStep > 0)
            TextButton(
              onPressed: _saving ? null : () => _saveAndContinue(),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.textSecondary,
              ),
              child: const Text(
                'تخطي',
                style: TextStyle(fontFamily: 'Cairo', fontSize: 15),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWelcomeStep(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 1),
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Transform.scale(
                scale: 1.0 + (_pulseController.value * 0.05),
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppTheme.primary, AppTheme.accent],
                    ),
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accent.withValues(alpha: 0.35),
                        blurRadius: 30,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.school_rounded,
                    size: 68,
                    color: Colors.white,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 32),
          const Text(
            'مرحباً بك في درسك AI',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              fontFamily: 'Cairo',
              height: 1.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'لنبدأ بإعداد حسابك التعليمي',
            style: TextStyle(
              fontSize: 16,
              fontFamily: 'Cairo',
              color: isDark ? AppTheme.textMuted : AppTheme.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : AppTheme.accent.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _buildFeatureRow(
                  Icons.person_outline_rounded,
                  'أخبرنا عن نفسك',
                  isDark,
                ),
                const SizedBox(height: 16),
                _buildFeatureRow(
                  Icons.menu_book_rounded,
                  'اختر المواد التي تدرسها',
                  isDark,
                ),
                const SizedBox(height: 16),
                _buildFeatureRow(
                  Icons.school_outlined,
                  'حدد المراحل الدراسية',
                  isDark,
                ),
              ],
            ),
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String text, bool isDark) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppTheme.accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppTheme.accent, size: 22),
        ),
        const SizedBox(width: 16),
        Text(
          text,
          style: TextStyle(
            fontSize: 15,
            fontFamily: 'Cairo',
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white : AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildNameStep(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : AppTheme.accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.person_rounded,
                color: AppTheme.accent, size: 44),
          ),
          const SizedBox(height: 28),
          const Text(
            'ما اسمك؟',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              fontFamily: 'Cairo',
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            'أدخل اسمك الكامل كما تريد أن يظهر في التطبيق',
            style: TextStyle(
              fontSize: 14,
              fontFamily: 'Cairo',
              color: isDark ? AppTheme.textMuted : AppTheme.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 36),
          TextFormField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _next(),
            style: TextStyle(
              fontSize: 18,
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : AppTheme.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'الاسم الكامل',
              hintStyle: TextStyle(
                color: isDark ? AppTheme.textMuted : AppTheme.textSecondary,
                fontFamily: 'Cairo',
              ),
              prefixIcon: const Icon(Icons.edit_rounded, color: AppTheme.accent),
              filled: true,
              fillColor: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppTheme.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : AppTheme.border,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppTheme.accent, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 18),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSubjectsStep(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : AppTheme.accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(Icons.menu_book_rounded,
                color: AppTheme.accent, size: 38),
          ),
          const SizedBox(height: 24),
          const Text(
            'ما المواد التي تدرسها؟',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              fontFamily: 'Cairo',
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _selectedSubjects.isEmpty
                ? 'اختر المواد التي تقوم بتدريسها'
                : 'تم اختيار ${_selectedSubjects.length} مواد',
            style: TextStyle(
              fontSize: 14,
              fontFamily: 'Cairo',
              color: isDark ? AppTheme.textMuted : AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _subjectOptions.map((subject) {
              final isSelected = _selectedSubjects.contains(subject);
              return _SubjectChip(
                label: subject,
                isSelected: isSelected,
                isDark: isDark,
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedSubjects.remove(subject);
                    } else {
                      _selectedSubjects.add(subject);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildLevelsStep(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : AppTheme.accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(Icons.school_outlined,
                color: AppTheme.accent, size: 38),
          ),
          const SizedBox(height: 24),
          const Text(
            'ما المراحل الدراسية؟',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              fontFamily: 'Cairo',
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _selectedLevels.isEmpty
                ? 'اختر المراحل التي تدرسها'
                : 'تم اختيار ${_selectedLevels.length} مراحل',
            style: TextStyle(
              fontSize: 14,
              fontFamily: 'Cairo',
              color: isDark ? AppTheme.textMuted : AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ..._levelOptions.map((level) {
            final isSelected = _selectedLevels.contains(level);
            final icons = {
              'ابتدائي': Icons.child_care_rounded,
              'إعدادي': Icons.emoji_objects_rounded,
              'ثانوي': Icons.lightbulb_rounded,
              'جامعي': Icons.account_balance_rounded,
            };
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedLevels.remove(level);
                      } else {
                        _selectedLevels.add(level);
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.accent.withValues(alpha: 0.12)
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.04)
                              : Colors.white),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.accent
                            : (isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : AppTheme.border),
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppTheme.accent.withValues(alpha: 0.12),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              )
                            ]
                          : null,
                    ),
                    child: Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.accent
                                : (isDark
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : AppTheme.accent.withValues(alpha: 0.1)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            icons[level] ?? Icons.school_rounded,
                            color: isSelected
                                ? Colors.white
                                : AppTheme.accent,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            level,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              fontFamily: 'Cairo',
                              color: isSelected
                                  ? AppTheme.accent
                                  : (isDark
                                      ? Colors.white
                                      : AppTheme.textPrimary),
                            ),
                          ),
                        ),
                        if (isSelected)
                          const Icon(Icons.check_circle_rounded,
                              color: AppTheme.accent, size: 26)
                        else
                          Icon(Icons.circle_outlined,
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.25)
                                  : AppTheme.textMuted,
                              size: 26),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

class _SubjectChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _SubjectChip({
    required this.label,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  static const _colors = [
    Color(0xFF6366F1),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
    Color(0xFFF43F5E),
    Color(0xFFF97316),
    Color(0xFFEAB308),
    Color(0xFF22C55E),
    Color(0xFF14B8A6),
    Color(0xFF06B6D4),
    Color(0xFF3B82F6),
    Color(0xFFA855F7),
    Color(0xFFD946EF),
    Color(0xFFFB923C),
    Color(0xFF84CC16),
  ];

  @override
  Widget build(BuildContext context) {
    final colorIndex = label.hashCode.abs() % _colors.length;
    final chipColor = _colors[colorIndex];

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? chipColor.withValues(alpha: 0.12)
              : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? chipColor
                : (isDark ? Colors.white.withValues(alpha: 0.08) : AppTheme.border),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: chipColor.withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 2))]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Icon(Icons.check_rounded, size: 16, color: chipColor),
              ),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontFamily: 'Cairo',
                color: isSelected
                    ? chipColor
                    : (isDark ? Colors.white70 : AppTheme.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
