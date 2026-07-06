import 'package:flutter/material.dart';
import '../../core/glass_theme.dart';
import '../../core/app_theme.dart';
import '../../services/api_service.dart';

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
      final res = await ApiService().dio.get('/teacher/contacts/');
      if (mounted) {
        setState(() {
          _contacts = res.data is List ? List.from(res.data) : [];
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          decoration: BoxDecoration(
            color: GlassTheme.cardBg(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('إضافة وسيلة تواصل', style: TextStyle(color: GlassTheme.textPrimary(context), fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _platforms.entries.map((e) {
                  final isSelected = selectedPlatform == e.key;
                  final info = e.value;
                  return GestureDetector(
                    onTap: () => setSheetState(() => selectedPlatform = e.key),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? (info['color'] as Color).withValues(alpha: 0.15) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isSelected ? info['color'] as Color : GlassTheme.cardBorder(context)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(info['icon'] as IconData, size: 16, color: info['color'] as Color),
                          const SizedBox(width: 6),
                          Text(info['label'] as String, style: TextStyle(color: isSelected ? info['color'] as Color : GlassTheme.textPrimary(context), fontSize: 13)),
                        ],
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
                  hintStyle: TextStyle(color: GlassTheme.textMuted(context)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: labelController,
                decoration: InputDecoration(
                  hintText: 'الاسم المعروض (اختياري)',
                  hintStyle: TextStyle(color: GlassTheme.textMuted(context)),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (valueController.text.trim().isEmpty) return;
                    Navigator.pop(ctx);
                    try {
                      await ApiService().dio.post('/teacher/contacts/', data: {
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
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
                  child: const Text('إضافة', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiService().dio.delete('/teacher/contacts/${contact['id']}');
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
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF000000) : const Color(0xFFF5F5F5),
      appBar: GlassTheme.glassAppBar('قنوات التواصل'),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: AppTheme.accent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _contacts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.contact_mail_outlined, size: 56, color: GlassTheme.textMuted(context).withValues(alpha: 0.4)),
                      const SizedBox(height: 16),
                      Text('لا توجد قنوات تواصل', style: TextStyle(color: GlassTheme.textSecondary(context), fontSize: 16)),
                      const SizedBox(height: 8),
                      Text('أضف قنوات التواصل ليتمكن الطلاب من الوصول إليك', style: TextStyle(color: GlassTheme.textMuted(context), fontSize: 13)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _contacts.length,
                    itemBuilder: (_, i) {
                      final contact = _contacts[i];
                      final platform = contact['platform'] ?? '';
                      final info = _platforms[platform] ?? {'label': platform, 'icon': Icons.link, 'color': GlassTheme.textMuted(context)};
                      final color = info['color'] as Color;

                      return Dismissible(
                        key: Key(contact['id'] ?? i.toString()),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          decoration: BoxDecoration(color: AppTheme.danger, borderRadius: BorderRadius.circular(16)),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        confirmDismiss: (_) async => _deleteContact(contact).then((_) => false),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: GlassTheme.glassCard(context),
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
                                    Text(contact['label'] ?? info['label'] as String,
                                        style: TextStyle(color: GlassTheme.textPrimary(context), fontWeight: FontWeight.w600)),
                                    Text(contact['value'] ?? '',
                                        style: TextStyle(color: GlassTheme.textSecondary(context), fontSize: 12)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
