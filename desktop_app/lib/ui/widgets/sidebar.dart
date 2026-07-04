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
    _NavItem(label: 'طلبات التسجيل', icon: Icons.person_add_outlined, activeIcon: Icons.person_add),
    _NavItem(label: 'المجموعات', icon: Icons.groups_outlined, activeIcon: Icons.groups),
    _NavItem(label: 'الحضور', icon: Icons.calendar_today_outlined, activeIcon: Icons.calendar_today),
    _NavItem(label: 'الدرجات', icon: Icons.grade_outlined, activeIcon: Icons.grade),
    _NavItem(label: 'الفواتير', icon: Icons.receipt_long_outlined, activeIcon: Icons.receipt_long),
    _NavItem(label: 'الباقات', icon: Icons.workspace_premium_outlined, activeIcon: Icons.workspace_premium),
    _NavItem(label: 'الكورسات', icon: Icons.menu_book_outlined, activeIcon: Icons.menu_book),
    _NavItem(label: 'الامتحانات', icon: Icons.quiz_outlined, activeIcon: Icons.quiz),
    _NavItem(label: 'الإعدادات', icon: Icons.settings_outlined, activeIcon: Icons.settings),
    _NavItem(label: 'التقارير', icon: Icons.analytics_outlined, activeIcon: Icons.analytics),
    _NavItem(label: 'المساعدين', icon: Icons.support_agent_outlined, activeIcon: Icons.support_agent),
    _NavItem(label: 'الملف الشخصي', icon: Icons.person_outline, activeIcon: Icons.person),
    _NavItem(label: 'جهات الاتصال', icon: Icons.contact_phone_outlined, activeIcon: Icons.contact_phone),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      color: AppTheme.sidebarBg,
      child: Column(
        children: [
          // ── Header ──────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.sidebarHover, width: 0.5)),
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
                  children: const [
                    Text(
                      'دَرسَك AI',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'للمدرسين',
                      style: TextStyle(
                        color: AppTheme.sidebarText,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Navigation ──────────────────────────────
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                final isSelected = widget.currentIndex == index;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  child: Material(
                    color: isSelected ? AppTheme.sidebarActive.withValues(alpha: 0.15) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap: () => widget.onItemSelected(index),
                      borderRadius: BorderRadius.circular(8),
                      hoverColor: AppTheme.sidebarHover.withValues(alpha: 0.5),
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            Icon(
                              isSelected ? item.activeIcon : item.icon,
                              color: isSelected ? AppTheme.primaryLight : AppTheme.sidebarText,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                item.label,
                                style: TextStyle(
                                  color: isSelected ? Colors.white : AppTheme.sidebarText,
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isSelected)
                              Container(
                                width: 3,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryLight,
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

          // ── Footer ──────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppTheme.sidebarHover, width: 0.5)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppTheme.accent, AppTheme.accentLight],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          widget.user != null && widget.user!.fullName.isNotEmpty
                              ? widget.user!.fullName[0]
                              : 'م',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.user?.fullName ?? 'مدرس',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (widget.user?.email != null)
                            Text(
                              widget.user!.email,
                              style: const TextStyle(
                                color: AppTheme.sidebarText,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 36,
                  child: OutlinedButton(
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: AppTheme.darkSurface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(color: AppTheme.darkBorder),
                          ),
                          title: const Text(
                            'تسجيل الخروج',
                            style: TextStyle(color: AppTheme.danger),
                          ),
                          content: const Text('هل أنت متأكد من تسجيل الخروج؟'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('إلغاء'),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.danger,
                              ),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text(
                                'تسجيل الخروج',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) widget.onLogout();
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.danger, width: 0.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: EdgeInsets.zero,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.logout, size: 14, color: AppTheme.danger),
                        SizedBox(width: 6),
                        Text(
                          'تسجيل الخروج',
                          style: TextStyle(color: AppTheme.danger, fontSize: 12),
                        ),
                      ],
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
