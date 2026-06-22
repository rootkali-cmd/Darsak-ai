import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../core/glass_theme.dart';
import '../../core/app_theme.dart';
import '../../services/api_service.dart';

class OnlineRequestsScreen extends StatefulWidget {
  const OnlineRequestsScreen({super.key});

  @override
  State<OnlineRequestsScreen> createState() => _OnlineRequestsScreenState();
}

class _OnlineRequestsScreenState extends State<OnlineRequestsScreen> {
  List<dynamic> _pending = [];
  List<dynamic> _approved = [];
  bool _isLoading = true;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService().dio.get('/students/type/online');
      final all = res.data is List ? List.from(res.data) : [];
      setState(() {
        _pending = all.where((s) => s['approval_status'] == 'pending').toList();
        _approved = all.where((s) => s['approval_status'] == 'approved').toList();
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _approve(dynamic student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('قبول الطالب'),
        content: Text('هل تريد قبول ${student['full_name']}؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('قبول', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final res = await ApiService().dio.patch('/students/${student['id']}/approve', data: {});
      if (!mounted) return;
      final code = res.data['code'] ?? '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم القبول. الكود: $code'), backgroundColor: AppTheme.success),
      );
      _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل القبول'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  Future<void> _reject(dynamic student) async {
    final reason = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('رفض الطالب'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('هل تريد رفض ${student['full_name']}؟'),
            const SizedBox(height: 12),
            TextField(controller: reason, decoration: const InputDecoration(labelText: 'سبب الرفض (اختياري)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('رفض', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiService().dio.patch('/students/${student['id']}/reject', data: {'reason': reason.text.trim()});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم الرفض'), backgroundColor: AppTheme.success),
      );
      _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل الرفض'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF000000) : const Color(0xFFF5F5F5),
      appBar: GlassTheme.glassAppBar('طلبات الأونلاين'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _Tab('قيد المراجعة (${_pending.length})', _tab == 0, AppTheme.warning, () => setState(() => _tab = 0)),
                const SizedBox(width: 8),
                _Tab('المقبولون (${_approved.length})', _tab == 1, AppTheme.success, () => setState(() => _tab = 1)),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _tab == 0
                    ? _pending.isEmpty
                        ? _empty('لا توجد طلبات معلقة', Icons.inbox)
                        : RefreshIndicator(onRefresh: _load, child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _pending.length,
                            itemBuilder: (_, i) => _pendingCard(_pending[i]),
                          ))
                    : _approved.isEmpty
                        ? _empty('لا يوجد طلاب مقبولين', Icons.check_circle_outline)
                        : RefreshIndicator(onRefresh: _load, child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _approved.length,
                            itemBuilder: (_, i) => _approvedCard(_approved[i]),
                          )),
          ),
        ],
      ),
    );
  }

  Widget _pendingCard(dynamic s) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: GlassTheme.glassCard(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppTheme.warning.withValues(alpha: 0.15),
                child: const Icon(Icons.person_add, color: AppTheme.warning, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s['full_name'] ?? '', style: TextStyle(color: GlassTheme.textPrimary(context), fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(s['phone'] ?? '', style: TextStyle(color: GlassTheme.textSecondary(context), fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _info(Icons.family_restroom, 'ولي الأمر: ${s['parent_phone'] ?? '—'}'),
              _info(Icons.location_on, s['address'] ?? '—'),
              _info(Icons.school, s['grade_level'] ?? '—'),
              if (s['gender'] != null) _info(Icons.person, s['gender']),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _approve(s),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('قبول'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success, foregroundColor: Colors.white),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _reject(s),
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('رفض'),
                  style: OutlinedButton.styleFrom(foregroundColor: AppTheme.danger, side: const BorderSide(color: AppTheme.danger)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _approvedCard(dynamic s) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: GlassTheme.glassCard(context),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppTheme.success.withValues(alpha: 0.15),
            child: const Icon(Icons.check_circle, color: AppTheme.success, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s['full_name'] ?? '', style: TextStyle(color: GlassTheme.textPrimary(context), fontWeight: FontWeight.w600)),
                Text(s['phone'] ?? '', style: TextStyle(color: GlassTheme.textSecondary(context), fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: AppTheme.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
            child: Text(s['code'] ?? '—', style: const TextStyle(color: AppTheme.accent, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _info(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: GlassTheme.textMuted(context)),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(color: GlassTheme.textMuted(context), fontSize: 12)),
      ],
    );
  }

  Widget _empty(String msg, IconData icon) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: GlassTheme.textMuted(context).withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text(msg, style: TextStyle(color: GlassTheme.textSecondary(context), fontSize: 16)),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;
  const _Tab(this.label, this.active, this.color, this.onTap);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? color.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: active ? color : Colors.transparent),
          ),
          child: Center(
            child: Text(label, style: TextStyle(color: active ? color : GlassTheme.textSecondary(context), fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ),
      ),
    );
  }
}
