import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import '../../core/app_theme.dart';
import '../../core/error_utils.dart';
import '../../providers/auth_provider.dart';
import '../login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _user;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resp = await ApiService().dio.get('/auth/me');
      final data = resp.data;
      _user = data is Map<String, dynamic> ? data : null;
    } on DioException catch (e) {
      _error = 'فشل تحميل الملف الشخصي: ${getDioErrorMessage(e)}';
    } catch (e) {
      _error = 'حدث خطأ: $e';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل تريد تسجيل الخروج؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تسجيل الخروج', style: TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      context.read<AuthProvider>().logout();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  void _editProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _EditProfilePage(user: _user)),
    ).then((_) => _loadProfile());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الملف الشخصي')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _loadProfile, child: const Text('إعادة المحاولة')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadProfile,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const SizedBox(height: 24),
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
                        child: const Icon(Icons.person, size: 50, color: AppTheme.primary),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _user?['full_name'] ?? _user?['email'] ?? 'مدرس',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _user?['email'] ?? '',
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      _InfoCard(label: 'الاسم الكامل', value: _user?['full_name'] ?? '—'),
                      _InfoCard(label: 'البريد الإلكتروني', value: _user?['email'] ?? '—'),
                      _InfoCard(label: 'الدور', value: _user?['role'] ?? 'teacher'),
                      _InfoCard(label: 'كود المدرس', value: _user?['teacher_code']?.toString() ?? '—'),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _editProfile,
                        icon: const Icon(Icons.edit),
                        label: const Text('تعديل الملف الشخصي'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _logout,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.danger,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text('تسجيل الخروج'),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String label;
  final String value;

  const _InfoCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
        trailing: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      ),
    );
  }
}

class _EditProfilePage extends StatefulWidget {
  final Map<String, dynamic>? user;

  const _EditProfilePage({this.user});

  @override
  State<_EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<_EditProfilePage> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = widget.user?['full_name'] ?? '';
    _emailCtrl.text = widget.user?['email'] ?? '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ApiService().dio.put('/auth/me', data: {
        'full_name': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تحديث الملف الشخصي'), backgroundColor: AppTheme.success),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل التحديث: $e'), backgroundColor: AppTheme.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تعديل الملف الشخصي')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'الاسم الكامل', prefixIcon: Icon(Icons.person)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailCtrl,
              decoration: const InputDecoration(labelText: 'البريد الإلكتروني', prefixIcon: Icon(Icons.email)),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'جاري الحفظ...' : 'حفظ'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
