import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/auth_provider.dart';
import '../../../core/api/subscription_guard.dart';

class AssistantsScreen extends StatefulWidget {
  const AssistantsScreen({super.key});

  @override
  State<AssistantsScreen> createState() => _AssistantsScreenState();
}

class _AssistantsScreenState extends State<AssistantsScreen> {
  List<Map<String, dynamic>> _assistants = [];
  bool _loading = true;
  bool _authenticated = false;
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAccess());
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _checkAccess() async {
    final ok = await checkSubscription(context);
    if (!ok) return;
    await _showPasswordDialog();
  }

  Future<void> _showPasswordDialog() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: borderColor)),
        title: Text('أدخل كلمة مرور المساعدين', textAlign: TextAlign.center, style: TextStyle(color: textPrimary)),
        content: TextField(
          controller: _passwordController,
          obscureText: true,
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            hintText: 'كلمة المرور',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('دخول'),
          ),
        ],
      ),
    );
    if (result == true) {
      await _verifyPassword();
    } else {
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _verifyPassword() async {
    try {
      final auth = context.read<AuthProvider>();
      final dio = auth.client.dio;
      await dio.post('/assistants/verify-password', data: {'password': _passwordController.text.trim()});
      _authenticated = true;
      _passwordController.clear();
      await _loadAssistants();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('كلمة المرور غير صحيحة: $e'), backgroundColor: AppTheme.danger),
        );
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _loadAssistants() async {
    setState(() => _loading = true);
    try {
      final auth = context.read<AuthProvider>();
      final resp = await auth.client.dio.get('/assistants');
      final data = resp.data;
      _assistants = data is List ? (data as List).map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)).toList() : [];
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل البيانات: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _addAssistant() async {
    final nameController = TextEditingController();
    final subjectController = TextEditingController();
    final phoneController = TextEditingController();

    final result = await showDialog<Map<String, String>?>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
        final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
        final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
        return AlertDialog(
          backgroundColor: surfaceColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: borderColor)),
          title: Text('إضافة مساعد', textAlign: TextAlign.center, style: TextStyle(color: textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: InputDecoration(labelText: 'الاسم', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 12),
              TextField(controller: subjectController, decoration: InputDecoration(labelText: 'المادة', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 12),
              TextField(controller: phoneController, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: 'الهاتف', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, {
                'name': nameController.text.trim(),
                'subject': subjectController.text.trim(),
                'phone': phoneController.text.trim(),
              }),
              child: const Text('إضافة'),
            ),
          ],
        );
      },
    );

    if (result != null && result['name']!.isNotEmpty) {
      try {
        final auth = context.read<AuthProvider>();
        await auth.client.dio.post('/assistants', data: {
          'name': result['name'],
          'subject': result['subject'],
          'phone': result['phone'],
        });
        await _loadAssistants();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('فشل الإضافة: $e'), backgroundColor: AppTheme.danger),
          );
        }
      }
    }
  }

  Future<void> _deleteAssistant(Map<String, dynamic> assistant) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('حذف مساعد', style: TextStyle(color: AppTheme.danger)),
        content: Text('هل تريد حذف ${assistant['name']}؟'),
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
    if (confirmed == true) {
      try {
        final auth = context.read<AuthProvider>();
        await auth.client.dio.delete('/assistants/${assistant['id']}');
        await _loadAssistants();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('فشل الحذف: $e'), backgroundColor: AppTheme.danger),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_authenticated) {
      return const Center(child: CircularProgressIndicator());
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;
    return _loading
        ? const Center(child: CircularProgressIndicator())
        : Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.support_agent, size: 28, color: AppTheme.accent),
                    const SizedBox(width: 12),
                    Text('المساعدين', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textPrimary)),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: _addAssistant,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('إضافة مساعد'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: _assistants.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.support_agent_outlined, size: 64, color: textMuted),
                              const SizedBox(height: 16),
                              Text('لا يوجد مساعدين', style: TextStyle(fontSize: 16, color: textMuted)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _assistants.length,
                          itemBuilder: (context, index) {
                            final a = _assistants[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(16),
                                leading: CircleAvatar(
                                  backgroundColor: AppTheme.accent.withValues(alpha: 0.1),
                                  child: Text(
                                    (a['name'] ?? '?')[0],
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.accent),
                                  ),
                                ),
                                title: Text(a['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text(a['subject'] ?? '', style: TextStyle(color: textMuted)),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline, color: AppTheme.danger),
                                  onPressed: () => _deleteAssistant(a),
                                ),
                              ),
                            );
                          },
                        ),
                ),
        ],
      ),
    );
  }
}
