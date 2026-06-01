import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../core/app_theme.dart';
import '../../services/video_upload_service.dart';
import 'video_player_screen.dart';

class LessonDetailScreen extends StatefulWidget {
  final dynamic lesson;

  const LessonDetailScreen({super.key, this.lesson});

  @override
  State<LessonDetailScreen> createState() => _LessonDetailScreenState();
}

class _LessonDetailScreenState extends State<LessonDetailScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _subjectController = TextEditingController();
  final _weekController = TextEditingController();
  final _groupController = TextEditingController();
  bool _isPublished = false;
  bool _isLoading = false;
  bool _isUploading = false;
  double _uploadProgress = 0;

  bool get _isEditing => widget.lesson != null;

  @override
  void initState() {
    super.initState();
    final l = widget.lesson;
    _titleController.text = l?['title'] ?? '';
    _descController.text = l?['description'] ?? '';
    _subjectController.text = l?['subject'] ?? '';
    _weekController.text = l?['week_number']?.toString() ?? '';
    _groupController.text = l?['group_id']?.toString() ?? '';
    _isPublished = l?['is_published'] == true;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _subjectController.dispose();
    _weekController.dispose();
    _groupController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء إدخال عنوان الدرس')),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final api = ApiService();
      final data = {
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'subject': _subjectController.text.trim(),
        'week_number': int.tryParse(_weekController.text),
        'group_id': _groupController.text.trim().isNotEmpty ? _groupController.text.trim() : null,
      };
      if (_isEditing) {
        data['is_published'] = _isPublished;
        await api.dio.put('/lessons/${widget.lesson['id']}', data: data);
      } else {
        await api.dio.post('/lessons/', data: data);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEditing ? 'تم التحديث' : 'تم إنشاء الدرس')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل الحفظ: $e'), backgroundColor: AppTheme.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _uploadVideo() async {
    if (!_isEditing || widget.lesson == null) return;

    try {
      await VideoUploadService.checkOrCreateChannel();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل إعداد القناة: $e'), backgroundColor: AppTheme.danger),
        );
      }
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
    });

    try {
      await VideoUploadService.uploadVideo(
        lessonId: widget.lesson['id'],
        filePath: '', // Will be set by file picker in real UI
        filename: 'video_${widget.lesson['id']}.mp4',
        caption: _titleController.text,
        onProgress: (sent, total) {
          if (mounted) {
            setState(() => _uploadProgress = sent / total);
          }
        },
      );
      if (mounted) {
        setState(() {
          _isUploading = false;
          _isPublished = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم رفع الفيديو بنجاح'), backgroundColor: AppTheme.success),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل الرفع: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  void _previewVideo() {
    if (widget.lesson == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoPlayerScreen(
          lessonId: widget.lesson['id'].toString(),
          title: _titleController.text,
          isTeacher: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasVideo = widget.lesson?['tg_file_id'] != null;
    final dur = widget.lesson?['duration_seconds'];

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'تعديل الدرس' : 'درس جديد'),
        actions: [
          if (_isEditing)
            TextButton(
              onPressed: _save,
              child: const Text('حفظ'),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_isEditing && hasVideo) ...[
              Card(
                child: InkWell(
                  onTap: _previewVideo,
                  child: Container(
                    height: 180,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Icon(Icons.play_circle, size: 64, color: Colors.white),
                    ),
                  ),
                ),
              ),
              if (dur != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'المدة: ${(dur ~/ 60)}:${(dur % 60).toString().padLeft(2, '0')}',
                    style: const TextStyle(fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 16),
            ],
            if (_isUploading)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: LinearProgressIndicator(
                  value: _uploadProgress > 0 ? _uploadProgress : null,
                  backgroundColor: AppTheme.accent.withValues(alpha: 0.2),
                  color: AppTheme.accent,
                ),
              ),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'عنوان الدرس *',
                prefixIcon: Icon(Icons.title),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'الوصف',
                prefixIcon: Icon(Icons.description),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _subjectController,
              decoration: const InputDecoration(
                labelText: 'المادة',
                prefixIcon: Icon(Icons.book),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _weekController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'الأسبوع',
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _groupController,
                    decoration: const InputDecoration(
                      labelText: 'معرف المجموعة',
                      prefixIcon: Icon(Icons.group),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_isEditing) ...[
              SwitchListTile(
                title: const Text('منشور'),
                value: _isPublished,
                onChanged: (v) => setState(() => _isPublished = v),
                activeColor: AppTheme.success,
              ),
              const SizedBox(height: 12),
            ],
            if (_isEditing) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isUploading ? null : _uploadVideo,
                  icon: Icon(_isUploading ? Icons.hourglass_top : Icons.cloud_upload),
                  label: Text(_isUploading ? 'جاري الرفع...' : 'رفع فيديو'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.accent,
                    side: const BorderSide(color: AppTheme.accent),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (hasVideo)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _previewVideo,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('معاينة الفيديو'),
                  ),
                ),
            ],
            const SizedBox(height: 24),
            if (!_isEditing)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _save,
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('إنشاء الدرس'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
