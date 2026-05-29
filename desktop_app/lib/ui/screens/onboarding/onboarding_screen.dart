import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/auth_provider.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback toggleTheme;
  final ThemeMode themeMode;

  const OnboardingScreen({
    super.key,
    required this.toggleTheme,
    required this.themeMode,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with TickerProviderStateMixin {
  final _nameController = TextEditingController();

  final List<String> _subjects = [
    'رياضيات',
    'علوم',
    'عربي',
    'إنجليزي',
    'فيزياء',
    'كيمياء',
    'أحياء',
    'تاريخ',
    'جغرافيا',
    'دراسات',
  ];

  final List<String> _levels = [
    'الصف الأول',
    'الصف الثاني',
    'الصف الثالث',
    'الصف الرابع',
    'الصف الخامس',
    'الصف السادس',
  ];

  final Set<String> _selectedSubjects = {};
  final Set<String> _selectedLevels = {};
  bool _isLoading = false;

  late final AnimationController _fadeController;
  late final AnimationController _slideController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('يرجى إدخال الاسم الكامل'),
          backgroundColor: AppTheme.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await context.read<AuthProvider>().saveOnboarding(
            fullName: name,
            subjects: _selectedSubjects.toList(),
            levels: _selectedLevels.toList(),
          );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('حدث خطأ، يرجى المحاولة مرة أخرى'),
            backgroundColor: AppTheme.danger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;

    return Scaffold(
      backgroundColor: bgColor,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Container(
                width: 560,
                constraints: const BoxConstraints(maxHeight: 620),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                      blurRadius: 40,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [AppTheme.accent, AppTheme.accentLight],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
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
                              child: const Icon(Icons.school_rounded, color: Colors.white, size: 28),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'مرحباً بك في DarsakAI',
                                    style: TextStyle(
                                      color: textPrimary,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'لنكمل إعداد حسابك',
                                    style: TextStyle(color: textSecondary, fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 36),
                        Text(
                          'الاسم الكامل',
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            hintText: 'أدخل اسمك الكامل',
                            prefixIcon: Icon(Icons.person_outline, size: 20),
                          ),
                          textInputAction: TextInputAction.done,
                        ),
                        const SizedBox(height: 28),
                        Row(
                          children: [
                            Text(
                              'المواد التي تدرسها',
                              style: TextStyle(
                                color: textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (_selectedSubjects.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.accent.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${_selectedSubjects.length} مختارة',
                                  style: const TextStyle(
                                    color: AppTheme.accent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'اختر مادة أو أكثر',
                          style: TextStyle(color: textMuted, fontSize: 13),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _subjects.map((subject) {
                            final isSelected = _selectedSubjects.contains(subject);
                            return MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                child: FilterChip(
                                  label: Text(subject),
                                  selected: isSelected,
                                  onSelected: (v) {
                                    setState(() {
                                      v ? _selectedSubjects.add(subject) : _selectedSubjects.remove(subject);
                                    });
                                  },
                                  selectedColor: AppTheme.accent.withValues(alpha: 0.2),
                                  checkmarkColor: AppTheme.accent,
                                  backgroundColor: isDark
                                      ? AppTheme.darkSurface2
                                      : AppTheme.lightSurface2,
                                  labelStyle: TextStyle(
                                    color: isSelected ? AppTheme.accent : textSecondary,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: BorderSide(
                                      color: isSelected
                                          ? AppTheme.accent.withValues(alpha: 0.5)
                                          : borderColor,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 28),
                        Row(
                          children: [
                            Text(
                              'المراحل الدراسية',
                              style: TextStyle(
                                color: textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (_selectedLevels.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.accent.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${_selectedLevels.length} مختارة',
                                  style: const TextStyle(
                                    color: AppTheme.accent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'اختر مرحلة أو أكثر',
                          style: TextStyle(color: textMuted, fontSize: 13),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _levels.map((level) {
                            final isSelected = _selectedLevels.contains(level);
                            return MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                child: FilterChip(
                                  label: Text(level),
                                  selected: isSelected,
                                  onSelected: (v) {
                                    setState(() {
                                      v ? _selectedLevels.add(level) : _selectedLevels.remove(level);
                                    });
                                  },
                                  selectedColor: AppTheme.accent.withValues(alpha: 0.2),
                                  checkmarkColor: AppTheme.accent,
                                  backgroundColor: isDark
                                      ? AppTheme.darkSurface2
                                      : AppTheme.lightSurface2,
                                  labelStyle: TextStyle(
                                    color: isSelected ? AppTheme.accent : textSecondary,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: BorderSide(
                                      color: isSelected
                                          ? AppTheme.accent.withValues(alpha: 0.5)
                                          : borderColor,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 36),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _save,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'حفظ',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
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
