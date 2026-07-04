import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/glass_theme.dart';
import '../../services/api_service.dart';

class AdmissionQueueScreen extends StatefulWidget {
  const AdmissionQueueScreen({super.key});

  @override
  State<AdmissionQueueScreen> createState() => _AdmissionQueueScreenState();
}

class _AdmissionQueueScreenState extends State<AdmissionQueueScreen> {
  bool _loading = true;
  String? _error;
  List<dynamic> _requests = [];

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() { _loading = true; _error = null; });
    try {
      final api = ApiService();
      final resp = await api.dio.get('/admission/pending');
      final data = resp.data;
      setState(() {
        _requests = data is Map && data['items'] is List ? data['items'] : [];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = 'فشل تحميل الطلبات'; _loading = false; });
    }
  }

  Future<void> _approve(String id) async {
    try {
      final api = ApiService();
      final resp = await api.dio.post('/admission/$id/approve');
      if (!mounted) return;
      final data = resp.data;
      final code = data is Map ? data['student_code'] ?? '' : '';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(code.isNotEmpty ? 'تم القبول — كود الطالب: $code' : 'تم القبول بنجاح'),
        backgroundColor: AppTheme.success,
      ));
      _loadRequests();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل قبول الطلب'), backgroundColor: AppTheme.danger));
    }
  }

  Future<void> _reject(String id) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('رفض الطلب'),
        content: TextField(controller: reasonController, decoration: const InputDecoration(labelText: 'سبب الرفض (اختياري)', border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            child: const Text('رفض'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final api = ApiService();
      await api.dio.post('/admission/$id/reject', data: {'reason': reasonController.text.trim()});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم رفض الطلب'), backgroundColor: AppTheme.warning));
      _loadRequests();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل رفض الطلب'), backgroundColor: AppTheme.danger));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GlassTheme.glassAppBar('طلبات اونلاين'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!, style: TextStyle(color: GlassTheme.textPrimary(context))),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _loadRequests, child: const Text('إعادة المحاولة')),
                    ],
                  ),
                )
              : _requests.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.how_to_reg, size: 64, color: GlassTheme.textMuted(context)),
                          const SizedBox(height: 12),
                          Text('لا توجد طلبات معلقة', style: TextStyle(color: GlassTheme.textSecondary(context), fontSize: 16)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadRequests,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _requests.length,
                        itemBuilder: (ctx, i) => _buildRequestCard(_requests[i]),
                      ),
                    ),
    );
  }

  Widget _buildRequestCard(dynamic request) {
    final name = (request['full_name'] ?? '').toString();
    final phone = (request['phone'] ?? '').toString();
    final parentPhone = (request['parent_phone'] ?? '').toString();
    final grade = (request['grade_level'] ?? '').toString();
    final regType = (request['registration_type'] ?? '').toString();
    final createdAt = (request['created_at'] ?? '').toString();

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
                backgroundColor: AppTheme.accent.withValues(alpha: 0.15),
                child: Text(name.isNotEmpty ? name[0] : '?', style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: TextStyle(color: GlassTheme.textPrimary(context), fontWeight: FontWeight.bold, fontSize: 15)),
                    Text(grade.isNotEmpty ? grade : (regType == 'online' ? 'اونلاين' : 'سنتر'), style: TextStyle(color: GlassTheme.textSecondary(context), fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (phone.isNotEmpty) _infoRow(Icons.phone, 'الهاتف', phone),
          if (parentPhone.isNotEmpty) _infoRow(Icons.phone_android, 'هاتف ولي الأمر', parentPhone),
          if (createdAt.isNotEmpty) _infoRow(Icons.access_time, 'التاريخ', createdAt.substring(0, createdAt.length > 16 ? 16 : createdAt.length)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _approve(request['id']),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('قبول'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success, foregroundColor: Colors.white),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _reject(request['id']),
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('رفض'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger, foregroundColor: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: GlassTheme.textSecondary(context)),
          const SizedBox(width: 6),
          Text('$label: ', style: TextStyle(color: GlassTheme.textSecondary(context), fontSize: 12)),
          Expanded(child: Text(value, style: TextStyle(color: GlassTheme.textPrimary(context), fontSize: 12))),
        ],
      ),
    );
  }
}
