import 'package:audioplayers/audioplayers.dart';

/// Sound effects for the teacher app.
/// 
/// IMPORTANT: Add actual sound files to assets/sounds/ directory:
/// - success.mp3   : Short positive beep (student present)
/// - error.mp3     : Error/denial sound (student absent, barcode not found)
/// - warning.mp3   : Warning alert (already scanned, duplicate)
/// - info.mp3      : Info notification (exam reminder, notes)
/// - scan.mp3      : Quick scan beep (when barcode is read)
/// 
/// You can generate short beeps using:
/// https://www.soundjay.com/button-sounds-1.html
/// Or use any free sound effect library.
class SoundEffects {
  static final AudioPlayer _player = AudioPlayer();
  static bool _enabled = true;

  static Future<void> playSuccess() async {
    if (!_enabled) return;
    try {
      await _player.play(AssetSource('sounds/success.mp3'));
    } catch (_) {
      // Sound file not found, ignore
    }
  }

  static Future<void> playError() async {
    if (!_enabled) return;
    try {
      await _player.play(AssetSource('sounds/error.mp3'));
    } catch (_) {
      // Sound file not found, ignore
    }
  }

  static Future<void> playWarning() async {
    if (!_enabled) return;
    try {
      await _player.play(AssetSource('sounds/warning.mp3'));
    } catch (_) {
      // Sound file not found, ignore
    }
  }

  static Future<void> playInfo() async {
    if (!_enabled) return;
    try {
      await _player.play(AssetSource('sounds/info.mp3'));
    } catch (_) {
      // Sound file not found, ignore
    }
  }

  static Future<void> playScan() async {
    if (!_enabled) return;
    try {
      await _player.play(AssetSource('sounds/scan.mp3'));
    } catch (_) {
      // Sound file not found, ignore
    }
  }

  static void setEnabled(bool enabled) {
    _enabled = enabled;
  }

  static bool get isEnabled => _enabled;

  static void dispose() {
    _player.dispose();
  }
}
