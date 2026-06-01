import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../../core/app_theme.dart';
import '../../services/video_streaming_service.dart';
import '../../services/analytics_tracking_service.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String lessonId;
  final String title;
  final bool isTeacher;

  const VideoPlayerScreen({
    super.key,
    required this.lessonId,
    required this.title,
    this.isTeacher = false,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _isLoading = true;
  String? _error;
  bool _isCompleted = false;
  StreamSubscription? _positionSub;
  StreamSubscription? _stateSub;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _stateSub?.cancel();
    _chewieController?.dispose();
    _videoController?.dispose();

    if (!widget.isTeacher) {
      AnalyticsTrackingService.stopTracking(
        widget.lessonId,
        position: _videoController?.value.position.inSeconds ?? 0,
        speed: _videoController?.value.playbackSpeed ?? 1.0,
        isCompleted: _isCompleted,
        eventType: 'exit',
      );
    }
    super.dispose();
  }

  Future<void> _initPlayer() async {
    try {
      int startPosition = 0;
      double startSpeed = 1.0;

      if (!widget.isTeacher) {
        final streamData = await VideoStreamingService.getStreamUrl(widget.lessonId);
        final resumeData = await VideoStreamingService.resumeState(widget.lessonId);
        startPosition = resumeData['last_position'] as int;
        startSpeed = (resumeData['current_speed'] as num?)?.toDouble() ?? 1.0;

        AnalyticsTrackingService.startTracking(widget.lessonId, initialPosition: startPosition);

        _videoController = VideoPlayerController.networkUrl(
          Uri.parse(streamData['stream_url']),
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
        );
      } else {
        final streamData = await VideoStreamingService.getStreamUrl(widget.lessonId);
        _videoController = VideoPlayerController.networkUrl(
          Uri.parse(streamData['stream_url']),
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
        );
      }

      await _videoController!.initialize();
      if (startPosition > 0) {
        await _videoController!.seekTo(Duration(seconds: startPosition));
      }
      if (startSpeed != 1.0) {
        _videoController!.setPlaybackSpeed(startSpeed);
      }

      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        allowMuting: true,
        showControls: true,
        showOptions: true,
        allowPlaybackSpeedChanging: !widget.isTeacher,
        cupertinoProgressColors: ChewieProgressColors(
          playedColor: AppTheme.accent,
          handleColor: AppTheme.accent,
          bufferedColor: AppTheme.accent.withValues(alpha: 0.3),
        ),
        materialProgressColors: ChewieProgressColors(
          playedColor: AppTheme.accent,
          handleColor: AppTheme.accent,
          bufferedColor: AppTheme.accent.withValues(alpha: 0.3),
        ),
      );

      if (!widget.isTeacher) {
        _setupTracking();
      }

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  void _setupTracking() {
    final duration = _videoController!.value.duration.inSeconds;

    _videoController!.addListener(() {
      final pos = _videoController!.value.position;
      final isEnded = duration > 0 && pos.inSeconds >= duration - 2;
      if (isEnded && !_isCompleted) {
        _isCompleted = true;
        AnalyticsTrackingService.stopTracking(
          widget.lessonId,
          position: pos.inSeconds,
          speed: _videoController!.value.playbackSpeed,
          isCompleted: true,
          eventType: 'completed',
        );
      }
    });
  }

  void _showSpeedPicker() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0].map((speed) {
            return ListTile(
              title: Text('${speed}x'),
              trailing: _videoController?.value.playbackSpeed == speed
                  ? const Icon(Icons.check, color: AppTheme.accent)
                  : null,
              onTap: () {
                _videoController?.setPlaybackSpeed(speed);
                Navigator.pop(ctx);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(widget.title, style: const TextStyle(color: Colors.white)),
        actions: [
          if (!widget.isTeacher)
            IconButton(
              icon: const Icon(Icons.speed),
              onPressed: _showSpeedPicker,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('تعذر تشغيل الفيديو', style: TextStyle(color: Colors.white70)),
                      const SizedBox(height: 8),
                      Text(_error ?? '', style: TextStyle(color: Colors.white30, fontSize: 12)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _isLoading = true;
                            _error = null;
                          });
                          _initPlayer();
                        },
                        child: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                )
              : _chewieController != null
                  ? Chewie(controller: _chewieController!)
                  : const Center(child: Text('No video controller')),
    );
  }
}
