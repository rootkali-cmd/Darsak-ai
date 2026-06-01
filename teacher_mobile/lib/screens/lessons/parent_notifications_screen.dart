import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../services/api_service.dart';
import '../../services/whatsapp_service.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/empty_state.dart';

class ParentNotificationsScreen extends StatefulWidget {
  final String groupId;
  final String lessonId;

  const ParentNotificationsScreen({
    super.key,
    required this.groupId,
    required this.lessonId,
  });

  @override
  State<ParentNotificationsScreen> createState() => _ParentNotificationsScreenState();
}

class _ParentNotificationsScreenState extends State<ParentNotificationsScreen> {
  List<dynamic> _delayedStudents = [];
  List<dynamic> _cheatedStudents = [];
  String _lessonTitle = '';
  String _groupName = '';
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final api = ApiService();

      final delayedResp = await api.dio.get(
        '/notifications/whatsapp/delayed-students/${widget.groupId}?lesson_id=${widget.lessonId}',
      );
      final d = delayedResp.data;
      if (d is Map) {
        _delayedStudents = (d['delayed_students'] as List?) ?? [];
        _lessonTitle = d['lesson_title'] ?? '';
        _groupName = d['group_name'] ?? '';
      }

      final analyticsResp = await api.dio.get('/video-analytics/video/${widget.lessonId}');
      final a = analyticsResp.data;
      if (a is List) {
        _cheatedStudents = a.where((r) => r['is_flagged_cheated'] == true).toList();
      }
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _notifyParent(dynamic student, {bool isCheated = false}) async {
    final phone = student['parent_phone']?.toString() ?? '';
    final name = student['full_name']?.toString() ?? 'طالب';

    if (phone.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('رقم ولي أمر $name غير متوفر')),
        );
      }
      return;
    }

    final success = isCheated
        ? await WhatsAppService.notifyCheatedParent(
            parentPhone: phone,
            studentName: name,
            lessonTitle: _lessonTitle,
          )
        : await WhatsAppService.notifyParent(
            parentPhone: phone,
            studentName: name,
            lessonTitle: _lessonTitle,
          );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'تم فتح واتساب لـ $name' : 'فشل فتح واتساب'),
          backgroundColor: success ? AppTheme.success : AppTheme.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('إشعارات: $_lessonTitle')),
      body: _isLoading
          ? const AppLoadingIndicator()
          : _error != null
              ? Center(child: Text(_error!))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_delayedStudents.isNotEmpty) ...[
                        Text(
                          'الطلاب المتأخرون (${_delayedStudents.length})',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.warning),
                        ),
                        const SizedBox(height: 12),
                        ..._delayedStudents.map((s) => _buildStudentCard(s, isCheated: false)),
                        const SizedBox(height: 24),
                      ],
                      if (_cheatedStudents.isNotEmpty) ...[
                        Text(
                          'سلوك مشبوه (${_cheatedStudents.length})',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.danger),
                        ),
                        const SizedBox(height: 12),
                        ..._cheatedStudents.map((s) => _buildStudentCard(s, isCheated: true)),
                      ],
                      if (_delayedStudents.isEmpty && _cheatedStudents.isEmpty)
                        const EmptyState(message: 'لا توجد إشعارات', icon: Icons.notifications_off),
                    ],
                  ),
                ),
    );
  }

  Widget _buildStudentCard(dynamic student, {required bool isCheated}) {
    final name = student['full_name'] ?? 'بدون اسم';
    return Card(
      color: isCheated ? AppTheme.danger.withValues(alpha: 0.05) : null,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isCheated
              ? AppTheme.danger.withValues(alpha: 0.2)
              : AppTheme.warning.withValues(alpha: 0.2),
          child: Icon(
            isCheated ? Icons.warning : Icons.hourglass_empty,
            color: isCheated ? AppTheme.danger : AppTheme.warning,
          ),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(isCheated ? 'سلوك مشبوه' : 'لم يشاهد'),
        trailing: TextButton.icon(
          icon: const Icon(Icons.send, size: 18),
          label: const Text('إبلاغ ولي الأمر'),
          onPressed: () => _notifyParent(student, isCheated: isCheated),
        ),
      ),
    );
  }
}
