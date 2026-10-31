import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import '../../core/theme.dart';
import '../../core/api_service.dart';

class LessonViewerScreen extends StatefulWidget {
  final String courseId;
  final String lessonId;
  final String lessonTitle;

  const LessonViewerScreen({
    super.key,
    required this.courseId,
    required this.lessonId,
    required this.lessonTitle,
  });

  @override
  State<LessonViewerScreen> createState() => _LessonViewerScreenState();
}

class _LessonViewerScreenState extends State<LessonViewerScreen> {
  final ApiService _api = ApiService();
  Map<String, dynamic>? _lesson;
  bool _isLoading = true;
  String? _error;
  VideoPlayerController? _videoController;
  bool _videoInitialized = false;
  bool _videoError = false;

  @override
  void initState() {
    super.initState();
    _loadLesson();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _loadLesson() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final data = await _api.getLesson(widget.courseId, widget.lessonId);
      if (!mounted) return;
      final lesson = data['data'] ?? data;
      setState(() {
        _lesson = lesson is Map<String, dynamic> ? lesson : null;
        _isLoading = false;
      });
      _initVideo();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'فشل تحميل الدرس';
        _isLoading = false;
      });
    }
  }

  void _initVideo() {
    final videoUrl = _lesson?['video_signed_url'] ?? _lesson?['video_url'];
    if (videoUrl == null || videoUrl.toString().isEmpty) return;

    try {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(videoUrl))
        ..initialize().then((_) {
          if (mounted) setState(() => _videoInitialized = true);
        }).catchError((e) {
          if (mounted) setState(() => _videoError = true);
        });
    } catch (_) {
      setState(() => _videoError = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.lessonTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
          : _error != null
              ? _buildError()
              : _buildContent(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.white24),
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.white54, fontSize: 14), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadLesson,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('إعادة المحاولة'),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent, foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final lesson = _lesson!;
    final title = lesson['title'] ?? widget.lessonTitle;
    final description = lesson['description'] ?? '';
    final subject = lesson['subject'] ?? '';
    final videoUrl = lesson['video_signed_url'] ?? lesson['video_url'];
    final hasVideo = videoUrl != null && videoUrl.toString().isNotEmpty;
    final files = lesson['files'] as List<dynamic>? ?? [];
    final durationSec = lesson['duration_seconds'] ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasVideo) ...[
            _buildVideoPlayer(),
            const SizedBox(height: 16),
          ],
          Text(title, style: TextStyle(color: AppColors.textPrimary(context), fontSize: 20, fontWeight: FontWeight.bold)),
          if (subject.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(subject, style: TextStyle(color: AppColors.textSecondary(context), fontSize: 13)),
          ],
          if (durationSec > 0) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.timer_outlined, size: 14, color: AppColors.textSecondary(context)),
                const SizedBox(width: 4),
                Text(
                  _formatDuration(durationSec),
                  style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12),
                ),
              ],
            ),
          ],
          if (description.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(description, style: TextStyle(color: AppColors.textSecondary(context), fontSize: 14, height: 1.6)),
          ],
          if (files.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('ملفات الدرس', style: TextStyle(color: AppColors.textPrimary(context), fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...files.map((f) => _buildFileCard(f)),
          ],
          if (!hasVideo && files.isEmpty) ...[
            const SizedBox(height: 40),
            Center(
              child: Column(
                children: [
                  Icon(Icons.play_circle_outline, size: 64, color: AppColors.textSecondary(context).withValues(alpha: 0.3)),
                  const SizedBox(height: 12),
                  Text('لا يوجد محتوى متاح حالياً', style: TextStyle(color: AppColors.textSecondary(context))),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildVideoPlayer() {
    if (_videoError) {
      return Container(
        width: double.infinity,
        height: 220,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.white38, size: 40),
              const SizedBox(height: 8),
              const Text('فشل تحميل الفيديو', style: TextStyle(color: Colors.white54)),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  setState(() { _videoError = false; _videoInitialized = false; });
                  _initVideo();
                },
                child: const Text('إعادة المحاولة', style: TextStyle(color: AppTheme.accent)),
              ),
            ],
          ),
        ),
      );
    }

    if (!_videoInitialized || _videoController == null) {
      return Container(
        width: double.infinity,
        height: 220,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: AppTheme.accent),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: AspectRatio(
        aspectRatio: _videoController!.value.aspectRatio,
        child: Stack(
          alignment: Alignment.center,
          children: [
            VideoPlayer(_videoController!),
            GestureDetector(
              onTap: () {
                setState(() {
                  _videoController!.value.isPlaying
                      ? _videoController!.pause()
                      : _videoController!.play();
                });
              },
              child: Container(
                color: Colors.transparent,
                child: AnimatedOpacity(
                  opacity: _videoController!.value.isPlaying ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _videoController!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: VideoProgressIndicator(
                _videoController!,
                allowScrubbing: true,
                colors: VideoProgressColors(
                  playedColor: AppTheme.accent,
                  bufferedColor: AppTheme.accent.withValues(alpha: 0.3),
                  backgroundColor: Colors.white24,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileCard(Map<String, dynamic> file) {
    final name = file['file_name'] ?? file['name'] ?? 'ملف';
    final size = file['file_size'] ?? 0;
    final signedUrl = file['signed_url'];
    final ext = name.toString().split('.').last.toLowerCase();

    IconData icon;
    Color iconColor;
    if (ext == 'pdf') {
      icon = Icons.picture_as_pdf;
      iconColor = Colors.red;
    } else if (['doc', 'docx'].contains(ext)) {
      icon = Icons.description;
      iconColor = Colors.blue;
    } else if (['xls', 'xlsx'].contains(ext)) {
      icon = Icons.table_chart;
      iconColor = Colors.green;
    } else if (['ppt', 'pptx'].contains(ext)) {
      icon = Icons.slideshow;
      iconColor = Colors.orange;
    } else {
      icon = Icons.insert_drive_file;
      iconColor = AppTheme.accent;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.surfaceElevated(context),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: signedUrl != null ? () => _openFile(signedUrl.toString()) : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border(context)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.toString(),
                        style: TextStyle(color: AppColors.textPrimary(context), fontSize: 13, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (size > 0)
                        Text(
                          _formatFileSize(size),
                          style: TextStyle(color: AppColors.textSecondary(context), fontSize: 11),
                        ),
                    ],
                  ),
                ),
                if (signedUrl != null)
                  Icon(Icons.download, color: AppColors.textSecondary(context), size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openFile(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا يمكن فتح الملف'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  String _formatFileSize(dynamic bytes) {
    final b = (bytes as num?)?.toInt() ?? 0;
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
