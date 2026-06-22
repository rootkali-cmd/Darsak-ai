import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/data_provider.dart';

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
      final api = context.read<DataProvider>().api;
      final res = await api.getList('/students/type/online');
      final all = List.from(res);
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
      builder: (ctx) => _buildDialog(
        title: 'قبول الطالب',
        content: 'هل تريد قبول ${student['full_name']}؟',
        confirmColor: AppTheme.success,
        confirmText: 'قبول',
      ),
    );
    if (confirmed != true) return;
    try {
      final api = context.read<DataProvider>().api;
      final res = await api.patch('/students/${student['id']}/approve', data: {});
      if (!mounted) return;
      final code = (res is Map ? res['code'] : null) ?? '';
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
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
        final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
        final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
        final textSecondary = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;
        return AlertDialog(
          backgroundColor: surfaceColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: borderColor)),
          title: Text('رفض الطالب', style: TextStyle(color: AppTheme.danger, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('هل تريد رفض ${student['full_name']}؟', style: TextStyle(color: textSecondary)),
              const SizedBox(height: 12),
              TextField(
                controller: reason,
                decoration: InputDecoration(
                  labelText: 'سبب الرفض (اختياري)',
                  labelStyle: TextStyle(color: textSecondary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('إلغاء', style: TextStyle(color: textSecondary))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('رفض', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    try {
      final api = context.read<DataProvider>().api;
      await api.patch('/students/${student['id']}/reject', data: {'reason': reason.text.trim()});
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textSecondary = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('طلبات التسجيل الأونلاين', style: TextStyle(color: textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildTab('قيد المراجعة (${_pending.length})', 0, AppTheme.warning, textSecondary),
              const SizedBox(width: 8),
              _buildTab('المقبولون (${_approved.length})', 1, AppTheme.success, textSecondary),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _tab == 0
                    ? _pending.isEmpty
                        ? _buildEmpty('لا توجد طلبات معلقة', Icons.inbox, textMuted)
                        : ListView.builder(
                            itemCount: _pending.length,
                            itemBuilder: (_, i) => _buildPendingCard(_pending[i], surfaceColor, borderColor, textPrimary, textSecondary, textMuted),
                          )
                    : _approved.isEmpty
                        ? _buildEmpty('لا يوجد طلاب مقبولين', Icons.check_circle_outline, textMuted)
                        : ListView.builder(
                            itemCount: _approved.length,
                            itemBuilder: (_, i) => _buildApprovedCard(_approved[i], surfaceColor, borderColor, textPrimary, textSecondary),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String label, int index, Color color, Color textSecondary) {
    final isActive = _tab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? color.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isActive ? color : Colors.transparent),
          ),
          child: Center(
            child: Text(label, style: TextStyle(color: isActive ? color : textSecondary, fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ),
      ),
    );
  }

  Widget _buildPendingCard(dynamic s, Color surface, Color border, Color textPrimary, Color textSecondary, Color textMuted) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(backgroundColor: AppTheme.warning.withValues(alpha: 0.15), child: const Icon(Icons.person_add, color: AppTheme.warning, size: 20)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s['full_name'] ?? '', style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(s['phone'] ?? '', style: TextStyle(color: textSecondary, fontSize: 13)),
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
              _info(Icons.family_restroom, 'ولي الأمر: ${s['parent_phone'] ?? '—'}', textMuted),
              _info(Icons.location_on, s['address'] ?? '—', textMuted),
              _info(Icons.school, s['grade_level'] ?? '—', textMuted),
              if (s['gender'] != null) _info(Icons.person, s['gender'], textMuted),
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

  Widget _buildApprovedCard(dynamic s, Color surface, Color border, Color textPrimary, Color textSecondary) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: border)),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: AppTheme.success.withValues(alpha: 0.15), child: const Icon(Icons.check_circle, color: AppTheme.success, size: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s['full_name'] ?? '', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600)),
                Text(s['phone'] ?? '', style: TextStyle(color: textSecondary, fontSize: 12)),
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

  Widget _info(IconData icon, String text, Color textMuted) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: textMuted),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(color: textMuted, fontSize: 12)),
      ],
    );
  }

  Widget _buildEmpty(String msg, IconData icon, Color textMuted) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: textMuted.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text(msg, style: TextStyle(color: textMuted, fontSize: 16)),
        ],
      ),
    );
  }

  AlertDialog _buildDialog({required String title, required String content, required Color confirmColor, required String confirmText}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final textSecondary = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;
    return AlertDialog(
      backgroundColor: surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: borderColor)),
      title: Text(title, style: TextStyle(color: confirmColor, fontWeight: FontWeight.bold)),
      content: Text(content, style: TextStyle(color: textSecondary)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text('إلغاء', style: TextStyle(color: textSecondary))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: confirmColor),
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmText, style: const TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
