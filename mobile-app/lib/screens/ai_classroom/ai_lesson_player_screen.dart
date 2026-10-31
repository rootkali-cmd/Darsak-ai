import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme.dart';

class AiClassroomWebViewScreen extends StatefulWidget {
  final String url;
  final String title;
  final bool preload;

  const AiClassroomWebViewScreen({
    super.key,
    required this.url,
    this.title = 'الفصل الذكي',
    this.preload = false,
  });

  @override
  State<AiClassroomWebViewScreen> createState() => _AiClassroomWebViewScreenState();
}

class _AiClassroomWebViewScreenState extends State<AiClassroomWebViewScreen>
    with SingleTickerProviderStateMixin {
  WebViewController? _controller;
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  bool _canGoBack = false;
  DateTime? _lastBackPress;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  static const _cacheKey = 'classroom_page_cache';
  static const _cacheUrlKey = 'classroom_cache_url';

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut);
    _fadeController.forward();
    _initWebView();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  Future<void> _initWebView() async {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      );

    if (controller.platform is AndroidWebViewController) {
      final android = controller.platform as AndroidWebViewController;
      await android.setMediaPlaybackRequiresUserGesture(false);
    }

    _registerBridge(controller);
    _registerNavigationHandler(controller);

    _controller = controller;

    await controller.loadRequest(Uri.parse(widget.url));
  }

  void _registerNavigationHandler(WebViewController controller) {
    controller.setNavigationDelegate(NavigationDelegate(
      onPageStarted: (_) {
        if (mounted) setState(() { _isLoading = true; _hasError = false; });
      },
      onPageFinished: (_) async {
        if (!mounted) return;
        final canGoBack = await controller.canGoBack();
        if (mounted) {
          setState(() { _isLoading = false; _canGoBack = canGoBack; });
          _injectMobileOverrides(controller);
          _cachePage();
        }
      },
      onWebResourceError: (error) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _hasError = true;
            _errorMessage = _mapError(error);
          });
        }
      },
    ));
  }

  String _mapError(WebResourceError error) {
    switch (error.errorCode) {
      case -2: return 'تحقق من اتصال الإنترنت';
      case -6: return 'الخادم غير متاح';
      case -8: return 'انتهت مهلة الاتصال';
      default: return 'حدث خطأ. حاول مرة أخرى';
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // JAVASCRIPT BRIDGE — expose native device capabilities to website
  // ═══════════════════════════════════════════════════════════════
  void _registerBridge(WebViewController controller) {
    // ── Toast ──
    controller.addJavaScriptChannel('DarsakToast', onMessageReceived: (msg) {
      final data = jsonDecode(msg.message);
      _showToast(data['message'] ?? '', isError: data['type'] == 'error');
    });

    // ── Haptic Feedback ──
    controller.addJavaScriptChannel('DarsakHaptic', onMessageReceived: (msg) {
      final data = jsonDecode(msg.message);
      switch (data['type']) {
        case 'light': HapticFeedback.lightImpact(); break;
        case 'medium': HapticFeedback.mediumImpact(); break;
        case 'heavy': HapticFeedback.heavyImpact(); break;
        case 'selection': HapticFeedback.selectionClick(); break;
        default: HapticFeedback.lightImpact();
      }
    });

    // ── Vibrate ──
    controller.addJavaScriptChannel('DarsakVibrate', onMessageReceived: (msg) {
      HapticFeedback.vibrate();
    });

    // ── Clipboard ──
    controller.addJavaScriptChannel('DarsakClipboard', onMessageReceived: (msg) async {
      final data = jsonDecode(msg.message);
      final action = data['action'] ?? 'read';
      if (action == 'write') {
        await Clipboard.setData(ClipboardData(text: data['text'] ?? ''));
        controller.runJavaScript('window.__bridgeClipboardResult?.("ok")');
      } else {
        final clip = await Clipboard.getData('text/plain');
        controller.runJavaScript(
          'window.__bridgeClipboardResult?.("${(clip?.text ?? '').replaceAll('"', '\\"')}")',
        );
      }
    });

    // ── Share ──
    controller.addJavaScriptChannel('DarsakShare', onMessageReceived: (msg) {
      final data = jsonDecode(msg.message);
      _showToast('تم نسخ الرابط');
      Clipboard.setData(ClipboardData(text: data['url'] ?? ''));
    });

    // ── System UI ──
    controller.addJavaScriptChannel('DarsakUI', onMessageReceived: (msg) {
      final data = jsonDecode(msg.message);
      switch (data['action']) {
        case 'fullscreen':
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
          break;
        case 'normal':
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
          break;
        case 'portrait':
          SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
          break;
        case 'landscape':
          SystemChrome.setPreferredOrientations([
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ]);
          break;
        case 'exit':
          Navigator.of(context).pop();
          break;
      }
    });

    // ── Navigation ──
    controller.addJavaScriptChannel('DarsakNav', onMessageReceived: (msg) async {
      final data = jsonDecode(msg.message);
      switch (data['action']) {
        case 'back':
          if (await controller.canGoBack()) {
            await controller.goBack();
          } else {
            Navigator.of(context).pop();
          }
          break;
        case 'reload':
          await controller.reload();
          break;
      }
    });

    // ── Device Info ──
    controller.addJavaScriptChannel('DarsakDevice', onMessageReceived: (msg) {
      final data = jsonDecode(msg.message);
      if (data['action'] == 'info') {
        final info = {
          'platform': 'android',
          'appVersion': '1.0.0',
          'bridgeVersion': '1.0',
          'darkMode': MediaQuery.platformBrightnessOf(context) == Brightness.dark,
        };
        controller.runJavaScript(
          'window.__bridgeDeviceResult?.(${jsonEncode(info)})',
        );
      }
    });

    // ── Storage (SharedPreferences) ──
    controller.addJavaScriptChannel('DarsakStorage', onMessageReceived: (msg) async {
      final data = jsonDecode(msg.message);
      final prefs = await SharedPreferences.getInstance();
      final action = data['action'] ?? 'get';
      final key = data['key'] ?? '';
      if (action == 'get') {
        final value = prefs.getString('bridge_$key') ?? data['default'] ?? '';
        controller.runJavaScript(
          'window.__bridgeStorageResult?.("${value.toString().replaceAll('"', '\\"')}")',
        );
      } else if (action == 'set') {
        await prefs.setString('bridge_$key', data['value'] ?? '');
        controller.runJavaScript('window.__bridgeStorageResult?.("ok")');
      } else if (action == 'remove') {
        await prefs.remove('bridge_$key');
        controller.runJavaScript('window.__bridgeStorageResult?.("ok")');
      }
    });

    // ── Close ──
    controller.addJavaScriptChannel('DarsakClose', onMessageReceived: (_) {
      Navigator.of(context).pop();
    });
  }

  // ═══════════════════════════════════════════════════════════════
  // INJECT MOBILE OVERRIDES — fix website for mobile viewport
  // ═══════════════════════════════════════════════════════════════
  void _injectMobileOverrides(WebViewController controller) {
    controller.runJavaScript('''
      (function() {
        // 1. Force viewport
        var meta = document.querySelector('meta[name="viewport"]');
        if (!meta) { meta = document.createElement('meta'); document.head.appendChild(meta); }
        meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no, viewport-fit=cover';

        // 2. Add safe-area CSS
        var s = document.createElement('style');
        s.id = 'darsak-mobile';
        s.textContent = `
          :root { --darsak-safe-top: env(safe-area-inset-top, 0px); --darsak-safe-bottom: env(safe-area-inset-bottom, 0px); }
          body { padding-top: var(--darsak-safe-top) !important; padding-bottom: var(--darsak-safe-bottom) !important; overflow-x: hidden; }
          input, textarea, select { font-size: 16px !important; }
          * { -webkit-tap-highlight-color: transparent; }
          ::selection { background: rgba(114, 46, 209, 0.3); }
        `;
        document.head.appendChild(s);

        // 3. Detect bridge availability
        window.DarsakBridge = {
          toast: (msg, type) => window.DarsakToast?.postMessage(JSON.stringify({message: msg, type: type || 'info'})),
          haptic: (type) => window.DarsakHaptic?.postMessage(JSON.stringify({type: type || 'light'})),
          vibrate: () => window.DarsakVibrate?.postMessage(JSON.stringify({})),
          clipboard: {
            read: () => new Promise(r => { window.__bridgeClipboardResult = r; window.DarsakClipboard?.postMessage(JSON.stringify({action:'read'})); }),
            write: (t) => new Promise(r => { window.__bridgeClipboardResult = r; window.DarsakClipboard?.postMessage(JSON.stringify({action:'write',text:t})); }),
          },
          share: (url) => window.DarsakShare?.postMessage(JSON.stringify({url: url})),
          ui: (action) => window.DarsakUI?.postMessage(JSON.stringify({action: action})),
          nav: (action) => window.DarsakNav?.postMessage(JSON.stringify({action: action})),
          device: () => new Promise(r => { window.__bridgeDeviceResult = r; window.DarsakDevice?.postMessage(JSON.stringify({action:'info'})); }),
          storage: {
            get: (key, def) => new Promise(r => { window.__bridgeStorageResult = r; window.DarsakStorage?.postMessage(JSON.stringify({action:'get',key:key,default:def})); }),
            set: (key, val) => new Promise(r => { window.__bridgeStorageResult = r; window.DarsakStorage?.postMessage(JSON.stringify({action:'set',key:key,value:val})); }),
            remove: (key) => new Promise(r => { window.__bridgeStorageResult = r; window.DarsakStorage?.postMessage(JSON.stringify({action:'remove',key:key})); }),
          },
          close: () => window.DarsakClose?.postMessage(JSON.stringify({})),
        };

        // 4. Mark as native app
        document.body?.classList.add('darsak-native-app');

        console.log('[DarsakBridge] v1.0 initialized');
      })();
    ''');
  }

  // ═══════════════════════════════════════════════════════════════
  // CACHE — cache page HTML for faster loads
  // ═══════════════════════════════════════════════════════════════
  Future<void> _cachePage() async {
    try {
      final html = await _controller?.runJavaScriptReturningResult(
        'document.documentElement.outerHTML',
      );
      if (html != null && html is String && html.length > 100) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_cacheKey, html);
        await prefs.setString(_cacheUrlKey, widget.url);
        await prefs.setString('${_cacheKey}_time', DateTime.now().toIso8601String());
      }
    } catch (_) {}
  }

  void _showToast(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.danger : const Color(0xFF1E1E1E),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<bool> _onWillPop() async {
    if (_canGoBack && _controller != null) {
      await _controller!.goBack();
      final canGoBack = await _controller!.canGoBack();
      if (mounted) setState(() => _canGoBack = canGoBack);
      return false;
    }
    final now = DateTime.now();
    if (_lastBackPress != null && now.difference(_lastBackPress!) < const Duration(seconds: 2)) {
      return true;
    }
    _lastBackPress = now;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('اضغط مرة أخرى للخروج'),
          duration: Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            if (_hasError)
              _buildErrorView()
            else if (_controller != null)
              FadeTransition(
                opacity: _fadeAnimation,
                child: WebViewWidget(controller: _controller!),
              ),
            if (_isLoading && !_hasError) _buildLoadingView(),
            if (!_isLoading && !_hasError) _buildFloatingBackButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingView() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.accent, width: 2),
              ),
              child: const Center(
                child: Text('AI', style: TextStyle(color: AppTheme.accent, fontSize: 22, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 24),
            const Text('جاري تحميل الفصل الذكي...', style: TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 16),
            SizedBox(
              width: 200,
              child: LinearProgressIndicator(
                backgroundColor: Colors.white12,
                valueColor: const AlwaysStoppedAnimation(AppTheme.accent),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded, size: 56, color: Colors.white24),
              const SizedBox(height: 16),
              Text(_errorMessage ?? 'حدث خطأ', style: const TextStyle(fontSize: 15, color: Colors.white70), textAlign: TextAlign.center),
              const SizedBox(height: 24),
              SizedBox(
                width: 200,
                child: ElevatedButton.icon(
                  onPressed: () { setState(() => _hasError = false); _initWebView(); },
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('إعادة المحاولة'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingBackButton() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: Directionality.of(context) == TextDirection.rtl ? 8 : null,
      right: Directionality.of(context) == TextDirection.ltr ? 8 : null,
      child: GestureDetector(
        onTap: () async {
          if (_canGoBack && _controller != null) {
            await _controller!.goBack();
            final canGoBack = await _controller!.canGoBack();
            if (mounted) setState(() => _canGoBack = canGoBack);
          } else {
            if (mounted) Navigator.pop(context);
          }
        },
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.black54,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white24),
          ),
          child: const Icon(Icons.arrow_back, color: Colors.white70, size: 20),
        ),
      ),
    );
  }
}
