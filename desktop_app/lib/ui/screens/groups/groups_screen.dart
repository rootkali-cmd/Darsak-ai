import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/data_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/group.dart';

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
                          Row(
                            children: [
                              Text(
                                'المجموعات',
                                style: TextStyle(color: textPrimary, fontSize: 22, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.accent.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${groups.length}',
                                  style: TextStyle(color: AppTheme.accent, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                          MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: ElevatedButton.icon(
                              onPressed: () => _showAddGroupDialog(context, data),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('إضافة مجموعة'),
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
                              Text('لا يوجد مجموعات', style: TextStyle(color: textSecondary, fontSize: 16)),
                              const SizedBox(height: 8),
                              Text('أنشئ مجموعتك الأولى لإضافة الطلاب', style: TextStyle(color: textMuted, fontSize: 13)),
                              const SizedBox(height: 20),
                              MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: ElevatedButton.icon(
                                  onPressed: () => _showAddGroupDialog(context, data),
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

  void _showAddGroupDialog(BuildContext context, DataProvider data) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;

    final nameController = TextEditingController();
    final subjectController = TextEditingController();
    final timeSlotController = TextEditingController();
    String selectedLevel = 'أولى ثانوي';
    String selectedDay = 'الأحد';

    final levels = ['أولى إعدادي', 'ثانية إعدادي', 'ثالثة إعدادي', 'أولى ثانوي', 'ثانية ثانوي', 'ثالثة ثانوي'];
    final days = ['الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: surfaceColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: borderColor),
          ),
          title: Text('إضافة مجموعة', style: TextStyle(color: textPrimary)),
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
                  TextField(
                    controller: subjectController,
                    decoration: const InputDecoration(
                      labelText: 'المادة',
                      hintText: 'مثال: رياضيات',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedLevel,
                    decoration: const InputDecoration(labelText: 'المرحلة الدراسية'),
                    items: levels.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                    onChanged: (v) => setDialogState(() => selectedLevel = v ?? selectedLevel),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedDay,
                    decoration: const InputDecoration(labelText: 'يوم المحاضرة'),
                    items: days.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                    onChanged: (v) => setDialogState(() => selectedDay = v ?? selectedDay),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: timeSlotController,
                    decoration: const InputDecoration(
                      labelText: 'وقت المحاضرة',
                      hintText: 'مثال: 10:00 - 11:30',
                    ),
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
                  if (nameController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('اسم المجموعة مطلوب'),
                        backgroundColor: AppTheme.danger,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  }
                  final group = GroupModel(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: nameController.text.trim(),
                    subject: subjectController.text.trim(),
                    level: selectedLevel,
                    dayOfWeek: selectedDay,
                    timeSlot: timeSlotController.text.trim().isNotEmpty ? timeSlotController.text.trim() : '—',
                  );
                  Navigator.pop(ctx);
                  context.read<DataProvider>().addGroupLocally(group);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم إنشاء المجموعة بنجاح'),
                      backgroundColor: AppTheme.success,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                child: const Text('إنشاء'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupCard extends StatefulWidget {
  final GroupModel group;
  final int studentCount;

  const _GroupCard({
    required this.group,
    required this.studentCount,
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
                      Icon(Icons.arrow_back, size: 16, color: AppTheme.accent),
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
