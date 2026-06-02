import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../services/api_service.dart';
import '../../services/video_upload_service.dart';
import '../../core/app_theme.dart';
import 'package:image_picker/image_picker.dart';

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
  bool _uploading = false;
  double _uploadProgress = 0;
  bool _videoUploaded = false;

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

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppTheme.danger),
    );
  }

  Future<void> _pickAndUploadVideo() async {
    final picker = ImagePicker();
    final xFile = await picker.pickVideo(source: ImageSource.gallery);
    if (xFile == null) return;

    setState(() {
      _uploading = true;
      _uploadProgress = 0;
    });

    try {
      await VideoUploadService.uploadVideo(
        lessonId: widget.lesson!['id'].toString(),
        filePath: xFile.path,
        filename: xFile.name,
        onProgress: (progress) {
          if (mounted) setState(() => _uploadProgress = progress);
        },
      );

      if (mounted) {
        setState(() {
          _uploading = false;
          _videoUploaded = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم رفع الفيديو بنجاح'), backgroundColor: AppTheme.success),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploading = false);
        _showError('فشل رفع الفيديو: $e');
      }
    }
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
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('سيتم فتح الفيديو قريباً')),
                  );
                },
                child: Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(child: Icon(Icons.play_circle_fill, size: 64, color: Colors.white70)),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('سيتم فتح الفيديو قريباً')),
                  );
                },
                icon: const Icon(Icons.play_circle),
                label: const Text('معاينة الفيديو'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
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
            if (_isEdit) ...[
              const SizedBox(height: 24),
              if (_uploading) ...[
                Text(
                  'جاري رفع الفيديو... ${(_uploadProgress * 100).toStringAsFixed(0)}%',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: _uploadProgress),
                const SizedBox(height: 16),
              ],
              if (!_uploading && !_videoUploaded && !hasVideo)
                OutlinedButton.icon(
                  onPressed: _pickAndUploadVideo,
                  icon: const Icon(Icons.video_file),
                  label: const Text('رفع فيديو'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
              if (_videoUploaded)
                ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('سيتم فتح الفيديو قريباً')),
                    );
                  },
                  icon: const Icon(Icons.play_circle),
                  label: const Text('معاينة الفيديو'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
            ],
            if (!_isEdit) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('إنشاء الدرس', style: TextStyle(fontSize: 16)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
