import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/data_provider.dart';

class TeacherContactsScreen extends StatefulWidget {
  const TeacherContactsScreen({super.key});

  @override
  State<TeacherContactsScreen> createState() => _TeacherContactsScreenState();
}

class _TeacherContactsScreenState extends State<TeacherContactsScreen> {
  List<dynamic> _contacts = [];
  bool _isLoading = true;

  final _platforms = {
    'whatsapp': {'label': 'واتساب', 'icon': Icons.chat, 'color': const Color(0xFF25D366)},
    'telegram': {'label': 'تيليجرام', 'icon': Icons.send, 'color': const Color(0xFF0088CC)},
    'instagram': {'label': 'إنستجرام', 'icon': Icons.camera_alt, 'color': const Color(0xFFE4405F)},
    'facebook': {'label': 'فيسبوك', 'icon': Icons.facebook, 'color': const Color(0xFF1877F2)},
    'tiktok': {'label': 'تيك توك', 'icon': Icons.music_note, 'color': const Color(0xFF010101)},
    'messenger': {'label': 'ماسنجر', 'icon': Icons.messenger, 'color': const Color(0xFF00B2FF)},
    'phone': {'label': 'هاتف', 'icon': Icons.phone, 'color': AppTheme.accent},
    'email': {'label': 'بريد إلكتروني', 'icon': Icons.email, 'color': AppTheme.warning},
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final res = await context.read<DataProvider>().api.getList('/teacher/contacts/');
      if (mounted) {
        setState(() {
          _contacts = List.from(res);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAddDialog() {
    String selectedPlatform = 'whatsapp';
    final valueController = TextEditingController();
    final labelController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
          final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;

          return AlertDialog(
            title: const Text('إضافة وسيلة تواصل'),
            content: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _platforms.entries.map((e) {
                      final isSelected = selectedPlatform == e.key;
                      final info = e.value;
                      return MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () => setSheetState(() => selectedPlatform = e.key),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? (info['color'] as Color).withValues(alpha: 0.15) : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected ? info['color'] as Color : (isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(info['icon'] as IconData, size: 16, color: info['color'] as Color),
                                const SizedBox(width: 6),
                                Text(
                                  info['label'] as String,
                                  style: TextStyle(
                                    color: isSelected ? info['color'] as Color : textPrimary,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: valueController,
                    decoration: InputDecoration(
                      hintText: selectedPlatform == 'phone' ? '01031524947' : '@username أو الرابط',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: labelController,
                    decoration: const InputDecoration(
                      hintText: 'الاسم المعروض (اختياري)',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('إلغاء'),
                ),
              ),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: ElevatedButton(
                  onPressed: () async {
                    if (valueController.text.trim().isEmpty) return;
                    Navigator.pop(ctx);
                    try {
                      await context.read<DataProvider>().api.post('/teacher/contacts/', data: {
                        'platform': selectedPlatform,
                        'value': valueController.text.trim(),
                        'label': labelController.text.trim().isEmpty ? null : labelController.text.trim(),
                      });
                      _load();
                    } catch (_) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('فشل الإضافة'), backgroundColor: AppTheme.danger),
                        );
                      }
                    }
                  },
                  child: const Text('إضافة'),
                ),
              ),
            ],
          );
        },
      ),
    ).then((_) {
      valueController.dispose();
      labelController.dispose();
    });
  }

  Future<void> _deleteContact(dynamic contact) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف وسيلة التواصل'),
        content: Text('هل تريد حذف "${contact['label'] ?? contact['platform']}"؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await context.read<DataProvider>().api.delete('/teacher/contacts/${contact['id']}');
      _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل الحذف'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textSecondary = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'قنوات التواصل',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: ElevatedButton.icon(
                      onPressed: _showAddDialog,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('إضافة'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else if (_contacts.isEmpty)
                _buildEmpty(textMuted, textSecondary)
              else
                _buildContactsList(textPrimary, textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty(Color textMuted, Color textSecondary) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          children: [
            Icon(Icons.contact_mail_outlined, size: 56, color: textMuted.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text('لا توجد قنوات تواصل', style: TextStyle(color: textSecondary, fontSize: 16)),
            const SizedBox(height: 8),
            Text('أضف قنوات التواصل ليتمكن الطلاب من الوصول إليك', style: TextStyle(color: textMuted, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildContactsList(Color textPrimary, Color textSecondary) {
    return Column(
      children: _contacts.map((contact) {
        final platform = contact['platform'] ?? '';
        final info = _platforms[platform] ?? {'label': platform, 'icon': Icons.link, 'color': AppTheme.textMuted};
        final color = info['color'] as Color;

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.15),
                  child: Icon(info['icon'] as IconData, color: color, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        contact['label'] ?? info['label'] as String,
                        style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        contact['value'] ?? '',
                        style: TextStyle(color: textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: IconButton(
                    onPressed: () => _deleteContact(contact),
                    icon: const Icon(Icons.delete_outline, size: 20),
                    style: IconButton.styleFrom(
                      foregroundColor: AppTheme.danger,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
