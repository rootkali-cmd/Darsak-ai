import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/theme.dart';
import '../core/local_db.dart';
import '../providers/data_provider.dart';
import '../models/group.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> with TickerProviderStateMixin {
  late AnimationController _listController;
  late Animation<double> _listAnimation;

  @override
  void initState() {
    super.initState();
    _listController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _listAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _listController, curve: Curves.easeOutCubic),
    );
    _listController.forward();
  }

  @override
  void dispose() {
    _listController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final groups = data.groups;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textSecondary = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;

    return Scaffold(
      body: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: FadeTransition(
                opacity: _listAnimation,
                child: SlideTransition(
                  position: Tween<Offset>(begin: const Offset(0, 0.02), end: Offset.zero).animate(_listAnimation),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'المجموعات',
                    style: TextStyle(color: textPrimary, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: ElevatedButton.icon(
                      onPressed: () => _showCreateGroupDialog(context),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('إنشاء مجموعة'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (data.isLoading)
                const Center(child: CircularProgressIndicator())
              else if (groups.isEmpty)
                Container(
                  padding: const EdgeInsets.all(60),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.groups_outlined, size: 56, color: textMuted),
                      const SizedBox(height: 16),
                      Text('لا توجد مجموعات', style: TextStyle(color: textSecondary, fontSize: 16)),
                      const SizedBox(height: 8),
                      Text('أنشئ مجموعتك الأولى لإضافة الطلاب', style: TextStyle(color: textMuted, fontSize: 13)),
                      const SizedBox(height: 20),
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: ElevatedButton.icon(
                          onPressed: () => _showCreateGroupDialog(context),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('إنشاء مجموعة جديدة'),
                        ),
                      ),
                    ],
                  ),
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.4,
                  ),
                  itemCount: groups.length,
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    final studentCount = data.students.where((s) => s.groupId == group.id).length;
                    return _GroupCard(
                      group: group,
                      studentCount: studentCount,
                      onDelete: () => _deleteGroup(context, group.id),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateGroupDialog(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;

    final prefs = await SharedPreferences.getInstance();
    final onboardingSubjects = prefs.getStringList('onboarding_subjects') ?? [];
    final onboardingLevels = prefs.getStringList('onboarding_levels') ?? [];
    final allLevels = ['أولى إعدادي', 'ثانية إعدادي', 'ثالثة إعدادي', 'أولى ثانوي', 'ثانية ثانوي', 'ثالثة ثانوي'];
    final levels = onboardingLevels.isNotEmpty ? onboardingLevels : allLevels;

    final nameController = TextEditingController();
    final subjectController = TextEditingController();
    String selectedLevel = levels.isNotEmpty ? levels.first : 'أولى ثانوي';
    String selectedTime = '10:00';
    final Set<String> selectedDays = {'السبت'};

    final days = ['السبت', 'الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس'];
    final times = ['08:00', '09:00', '10:00', '11:00', '12:00', '01:00', '02:00', '03:00', '04:00', '05:00', '06:00'];
    final defaultSubjects = ['رياضيات', 'علوم', 'عربي', 'إنجليزي', 'تاريخ', 'جغرافيا', 'فلسفة', 'كيمياء', ' فيزياء', 'أحياء', 'حاسب آلي', 'تربية دينية', 'اقتصاد', 'إحصاء'];
    final subjects = onboardingSubjects.isNotEmpty ? onboardingSubjects : defaultSubjects;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: surfaceColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: borderColor),
          ),
          title: Text('إنشاء مجموعة جديدة', style: TextStyle(color: textPrimary)),
          content: SizedBox(
            width: 450,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'اسم المجموعة',
                      hintText: 'مثال: مجموعة الصباح',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: subjects.isNotEmpty ? (subjects.contains(subjectController.text) ? subjectController.text : null) : null,
                    decoration: const InputDecoration(labelText: 'المادة'),
                    items: [
                      ...subjects.map((s) => DropdownMenuItem(value: s, child: Text(s))),
                      const DropdownMenuItem(value: '__other__', child: Text('أخرى...')),
                    ],
                    onChanged: (v) {
                      if (v == '__other__') {
                        // Will be handled by the TextField below
                      } else {
                        setDialogState(() => subjectController.text = v!);
                      }
                    },
                  ),
                  if (!onboardingSubjects.contains(subjectController.text))
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: TextField(
                        controller: subjectController,
                        decoration: const InputDecoration(
                          labelText: 'أو اكتب مادة أخرى',
                          hintText: 'مثال: رياضيات',
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedLevel,
                    decoration: const InputDecoration(labelText: 'المرحلة الدراسية'),
                    items: levels.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                    onChanged: (v) => setDialogState(() => selectedLevel = v ?? selectedLevel),
                  ),
                  const SizedBox(height: 16),
                  Text('أيام المحاضرة (اختر حتى 3 أيام)', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: days.map((day) {
                      final isSelected = selectedDays.contains(day);
                      return FilterChip(
                        label: Text(day),
                        selected: isSelected,
                        onSelected: (selected) {
                          setDialogState(() {
                            if (selected && selectedDays.length < 3) {
                              selectedDays.add(day);
                            } else if (!selected) {
                              selectedDays.remove(day);
                            }
                          });
                        },
                        selectedColor: AppTheme.accent.withValues(alpha: 0.2),
                        checkmarkColor: AppTheme.accent,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedTime,
                    decoration: const InputDecoration(labelText: 'وقت المحاضرة'),
                    items: times.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (v) => setDialogState(() => selectedTime = v ?? selectedTime),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: ElevatedButton(
                onPressed: () {
                if (nameController.text.isNotEmpty && selectedDays.isNotEmpty) {
                  final group = GroupModel(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: nameController.text,
                    subject: subjectController.text,
                    level: selectedLevel,
                    dayOfWeek: selectedDays.join(' / '),
                    timeSlot: selectedTime,
                  );
                  Navigator.pop(ctx);
                  context.read<DataProvider>().addGroupLocally(group);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('تم إنشاء المجموعة بنجاح'),
                      backgroundColor: AppTheme.success,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  );
                }
              },
              child: const Text('إنشاء'),
            ),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteGroup(BuildContext context, String groupId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف المجموعة'),
        content: const Text('هل أنت متأكد من حذف هذه المجموعة؟'),
        actions: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: ElevatedButton(
              onPressed: () {
              LocalDB.deleteData(LocalDB.groupsBox, groupId);
              Navigator.pop(ctx);
              context.read<DataProvider>().loadData();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            child: const Text('حذف'),
          ),
          ),
        ],
      ),
    );
  }
}

class _GroupCard extends StatefulWidget {
  final GroupModel group;
  final int studentCount;
  final VoidCallback onDelete;

  const _GroupCard({
    required this.group,
    required this.studentCount,
    required this.onDelete,
  });

  @override
  State<_GroupCard> createState() => _GroupCardState();
}

class _GroupCardState extends State<_GroupCard> with SingleTickerProviderStateMixin {
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
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textSecondary = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
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
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _isHovered ? AppTheme.accent.withValues(alpha: 0.3) : borderColor,
              ),
              boxShadow: _isHovered
                  ? [
                      BoxShadow(
                        color: AppTheme.accent.withValues(alpha: 0.06),
                        blurRadius: 15,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : isDark
                      ? null
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [AppTheme.accent, AppTheme.accentLight]),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.groups, color: Colors.white, size: 20),
                    ),
                    const Spacer(),
                    if (_isHovered)
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.danger),
                        onPressed: widget.onDelete,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  widget.group.name,
                  style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  '${widget.group.subject} - ${widget.group.level}',
                  style: TextStyle(color: textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 14, color: textMuted),
                    const SizedBox(width: 4),
                    Text(
                      '${widget.group.dayOfWeek} - ${widget.group.timeSlot}',
                      style: TextStyle(color: textMuted, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.people, size: 14, color: AppTheme.accent),
                      const SizedBox(width: 6),
                      Text(
                        '${widget.studentCount} طالب',
                        style: TextStyle(color: AppTheme.accent, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
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
