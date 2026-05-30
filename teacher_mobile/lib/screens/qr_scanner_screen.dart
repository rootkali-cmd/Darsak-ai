import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../core/theme.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  MobileScannerController? _controller;
  bool _isProcessing = false;
  final List<ScannedStudent> _scannedStudents = [];
  Timer? _clearTimer;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    _clearTimer?.cancel();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;
    final barcode = capture.barcodes.isNotEmpty ? capture.barcodes.first : null;
    if (barcode == null) return;
    final raw = barcode.rawValue;
    if (raw == null || raw.isEmpty) return;

    final student = _parseStudentQr(raw);
    if (student != null) {
      _processScan(student);
    }
  }

  ScannedStudent? _parseStudentQr(String raw) {
    final clean = raw.trim();
    // Format: darsak://student/{id}/{code}
    if (clean.startsWith('darsak://student/')) {
      final parts = clean.split('/');
      if (parts.length >= 5) {
        return ScannedStudent(
          id: parts[3],
          code: parts[4],
          name: 'طالب ${parts[4]}',
          status: 'present',
        );
      }
    }
    // Fallback: just a code
    if (clean.length <= 20 && RegExp(r'^[A-Z0-9]+$').hasMatch(clean)) {
      return ScannedStudent(
        id: clean,
        code: clean,
        name: 'طالب $clean',
        status: 'present',
      );
    }
    return null;
  }

  void _processScan(ScannedStudent student) {
    // Check if already scanned this session
    final alreadyScanned = _scannedStudents.any((s) => s.code == student.code);
    if (alreadyScanned) {
      _showNotification(
        title: 'تم المسح مسبقاً',
        subtitle: student.name,
        icon: Icons.info_outline,
        color: AppTheme.warning,
      );
      return;
    }

    setState(() => _isProcessing = true);

    // In real app: call API here
    // For now: simulate success
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;

      setState(() {
        _scannedStudents.insert(0, student);
        if (_scannedStudents.length > 50) {
          _scannedStudents.removeLast();
        }
        _isProcessing = false;
      });

      _showNotification(
        title: 'تم تسجيل الحضور',
        subtitle: '${student.name} — ${student.code}',
        icon: Icons.check_circle,
        color: AppTheme.success,
      );
    });
  }

  void _showNotification({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final notification = GlassNotification(
      title: title,
      subtitle: subtitle,
      icon: icon,
      color: color,
    );

    setState(() {
      _notifications.insert(0, notification);
      if (_notifications.length > 4) {
        _notifications.removeLast();
      }
    });

    // Auto remove after 3.5 seconds
    Future.delayed(const Duration(milliseconds: 3500), () {
      if (mounted) {
        setState(() {
          _notifications.remove(notification);
        });
      }
    });
  }

  final List<GlassNotification> _notifications = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera
          if (_controller != null)
            MobileScanner(
              controller: _controller!,
              onDetect: _onDetect,
              errorBuilder: (context, error, child) => _buildError(),
            ),

          // Overlay UI
          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      _IconBtn(
                        icon: Icons.arrow_back,
                        onTap: () => Navigator.pop(context),
                      ),
                      const Spacer(),
                      const Text(
                        'مسح QR للحضور',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      _IconBtn(
                        icon: Icons.flash_on,
                        onTap: () => _controller?.toggleTorch(),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Scan frame
                Center(
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.accent.withOpacity(0.6), width: 2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Stack(
                      children: [
                        Positioned(top: 0, left: 0, child: _CornerMarker()),
                        Positioned(top: 0, right: 0, child: _CornerMarker()),
                        Positioned(bottom: 0, left: 0, child: _CornerMarker()),
                        Positioned(bottom: 0, right: 0, child: _CornerMarker()),
                      ],
                    ),
                  ),
                ),

                const Spacer(),

                // Stats bar
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people, size: 18, color: AppTheme.success),
                      const SizedBox(width: 8),
                      Text(
                        '${_scannedStudents.length} طالب',
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 24),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isProcessing ? AppTheme.warning : AppTheme.success,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isProcessing ? 'جاري المعالجة...' : 'جاهز للمسح',
                        style: TextStyle(
                          color: _isProcessing ? AppTheme.warning : AppTheme.success,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Glass Notifications
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _notifications.asMap().entries.map((entry) {
                final idx = entry.key;
                final n = entry.value;
                final opacity = 1.0 - (idx * 0.18);
                final scale = 1.0 - (idx * 0.04);
                return Opacity(
                  opacity: opacity.clamp(0.3, 1.0),
                  child: Transform.scale(
                    scale: scale.clamp(0.85, 1.0),
                    child: _GlassCard(notification: n),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.camera_alt_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('تعذر الوصول للكاميرا', style: TextStyle(color: Colors.white, fontSize: 18)),
          const SizedBox(height: 8),
          Text('تحقق من إذن الكاميرا', style: TextStyle(color: Colors.grey[400], fontSize: 14)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('رجوع'),
          ),
        ],
      ),
    );
  }
}

// ── Helper Widgets ──

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

class _CornerMarker extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        border: const Border(
          top: BorderSide(color: AppTheme.accent, width: 3),
          left: BorderSide(color: AppTheme.accent, width: 3),
        ),
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(8)),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final GlassNotification notification;
  const _GlassCard({required this.notification});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface.withOpacity(0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: notification.color.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: notification.color.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: notification.color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(notification.icon, size: 18, color: notification.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  notification.title,
                  style: const TextStyle(color: AppTheme.darkTextPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                ),
                if (notification.subtitle != null)
                  Text(
                    notification.subtitle!,
                    style: const TextStyle(color: AppTheme.darkTextMuted, fontSize: 11),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Data Models ──

class ScannedStudent {
  final String id;
  final String code;
  final String name;
  final String status;

  ScannedStudent({required this.id, required this.code, required this.name, required this.status});
}

class GlassNotification {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color color;

  GlassNotification({required this.title, this.subtitle, required this.icon, required this.color});
}
