import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/models/user.dart';

class Sidebar extends StatefulWidget {
  final int currentIndex;
  final Function(int) onItemSelected;
  final VoidCallback onLogout;
  final UserModel? user;

  const Sidebar({
    super.key,
    required this.currentIndex,
    required this.onItemSelected,
    required this.onLogout,
    required this.user,
  });

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  final List<_NavItem> _items = const [
    _NavItem(label: 'لوحة التحكم', icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard),
    _NavItem(label: 'الطلاب', icon: Icons.people_outline, activeIcon: Icons.people),
    _NavItem(label: 'المجموعات', icon: Icons.groups_outlined, activeIcon: Icons.groups),
    _NavItem(label: 'الحضور', icon: Icons.calendar_today_outlined, activeIcon: Icons.calendar_today),
    _NavItem(label: 'الدرجات', icon: Icons.grade_outlined, activeIcon: Icons.grade),
    _NavItem(label: 'الفواتير', icon: Icons.receipt_long_outlined, activeIcon: Icons.receipt_long),
    _NavItem(label: 'الامتحانات', icon: Icons.quiz_outlined, activeIcon: Icons.quiz),
    _NavItem(label: 'QR', icon: Icons.qr_code_outlined, activeIcon: Icons.qr_code),
    _NavItem(label: 'الإعدادات', icon: Icons.settings_outlined, activeIcon: Icons.settings),
    _NavItem(label: 'الاشتراك', icon: Icons.card_membership_outlined, activeIcon: Icons.card_membership),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textSecondary = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;

    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(
          left: BorderSide(color: borderColor),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: borderColor)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.accent, AppTheme.accentLight],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.school, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Darsak AI',
                      style: TextStyle(
                        color: textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'نظام إدارة التعليم',
                      style: TextStyle(
                        color: textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                final isSelected = widget.currentIndex == index;
                return Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: isSelected
                        ? AppTheme.accent.withValues(alpha: 0.1)
                        : Colors.transparent,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => widget.onItemSelected(index),
                      hoverColor: AppTheme.accent.withValues(alpha: 0.05),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Icon(
                              isSelected ? item.activeIcon : item.icon,
                              color: isSelected ? AppTheme.accent : textMuted,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              item.label,
                              style: TextStyle(
                                color: isSelected ? textPrimary : textMuted,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                fontSize: 14,
                              ),
                            ),
                            const Spacer(),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: isSelected ? 3 : 0,
                              height: 20,
                              decoration: BoxDecoration(
                                color: AppTheme.accent,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: borderColor)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppTheme.accent, AppTheme.accentLight],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          widget.user != null && widget.user!.fullName.isNotEmpty
                              ? widget.user!.fullName[0]
                              : 'م',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.user?.fullName ?? 'مدرس',
                            style: TextStyle(color: textSecondary, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (widget.user?.email != null)
                            Text(
                              widget.user!.email,
                              style: TextStyle(color: textMuted, fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: surfaceColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: borderColor),
                        ),
                        title: const Text('تسجيل الخروج', style: TextStyle(color: AppTheme.danger)),
                        content: const Text('هل أنت متأكد من تسجيل الخروج؟'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('إلغاء'),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('تسجيل الخروج', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) widget.onLogout();
                  },
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.danger.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.logout, size: 16, color: AppTheme.danger),
                          const SizedBox(width: 8),
                          const Text(
                            'تسجيل الخروج',
                            style: TextStyle(color: AppTheme.danger, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });
}
