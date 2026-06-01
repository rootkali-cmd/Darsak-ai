import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../services/api_service.dart';
import '../../core/app_theme.dart';
import 'video_player_screen.dart';

class LessonDetailScreen extends StatefulWidget {
  final dynamic lesson;

  const LessonDetailScreen({super.key, this.lesson});

  @override
  State<LessonDetailScreen> createState() => _LessonDetailScreenState();
}

class _LessonDetailScreenState extends State<LessonDetailScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _subjectCtrl = TextEditingController();
  final _weekCtrl = TextEditingController();
  bool _isPublished = false;
  bool _saving = false;
  bool _deleting = false;

  bool get _isEdit => widget.lesson != null;

  @override
  void initState() {
    super.initState();
    final l = widget.lesson;
    _titleCtrl.text = l?['title'] ?? '';
    _descCtrl.text = l?['description'] ?? '';
    _subjectCtrl.text = l?['subject'] ?? '';
    _weekCtrl.text = l?['week_number']?.toString() ?? '';
    _isPublished = l?['is_published'] == true;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _subjectCtrl.dispose();
    _weekCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('العنوان مطلوب')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final api = ApiService();
      final body = {
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        'subject': _subjectCtrl.text.trim().isEmpty ? null : _subjectCtrl.text.trim(),
        'week_number': int.tryParse(_weekCtrl.text.trim()),
      };

      if (_isEdit) {
        body['is_published'] = _isPublished;
        await api.dio.put('/lessons/${widget.lesson!['id']}', data: body);
      } else {
        await api.dio.post('/lessons/', data: body);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEdit ? 'تم التحديث' : 'تم إنشاء الدرس'), backgroundColor: AppTheme.success),
        );
        Navigator.pop(context);
      }
    } on DioException catch (e) {
      _showError('فشل الحفظ: ${e.response?.statusCode} ${e.message}');
    } catch (e) {
      _showError('خطأ: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('حذف الدرس'),
        content: const Text('سيتم حذف الدرس نهائياً'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('حذف', style: TextStyle(color: AppTheme.danger))),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _deleting = true);
    try {
      await ApiService().dio.delete('/lessons/${widget.lesson!['id']}');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showError('فشل الحذف');
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  void _preview() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => VideoPlayerScreen(
        lessonId: widget.lesson!['id'].toString(),
        title: _titleCtrl.text,
        isTeacher: true,
      )),
    );
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppTheme.danger),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasVideo = widget.lesson?['tg_file_id'] != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'تعديل الدرس' : 'درس جديد'),
        actions: [
          if (_isEdit)
            IconButton(
              icon: const Icon(Icons.delete, color: AppTheme.danger),
              onPressed: _deleting ? null : _delete,
            ),
          IconButton(
            icon: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check),
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_isEdit && hasVideo) ...[
              GestureDetector(
                onTap: _preview,
                child: Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(child: Icon(Icons.play_circle_fill, size: 64, color: Colors.white70)),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (_isEdit && widget.lesson?['duration_seconds'] != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  'المدة: ${widget.lesson!['duration_seconds'] ~/ 60}:${(widget.lesson!['duration_seconds'] % 60).toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(labelText: 'العنوان *', prefixIcon: Icon(Icons.title)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descCtrl,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'الوصف', prefixIcon: Icon(Icons.description)),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _subjectCtrl,
                    decoration: const InputDecoration(labelText: 'المادة', prefixIcon: Icon(Icons.book)),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 100,
                  child: TextField(
                    controller: _weekCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'الأسبوع'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isEdit)
              SwitchListTile(
                title: const Text('منشور'),
                value: _isPublished,
                onChanged: (v) => setState(() => _isPublished = v),
                activeColor: AppTheme.success,
              ),
            const SizedBox(height: 24),
            if (!_isEdit)
              ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('إنشاء الدرس', style: TextStyle(fontSize: 16)),
              ),
          ],
        ),
      ),
    );
  }
}
