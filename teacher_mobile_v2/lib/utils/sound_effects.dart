import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

class SoundEffects {
  static final AudioPlayer _player = AudioPlayer();

  static Future<void> playScan() async {
    try {
      HapticFeedback.lightImpact();
      await _player.play(AssetSource('sounds/scan.mp3'));
    } catch (_) {
      try { HapticFeedback.lightImpact(); } catch (_) {}
    }
  }

  static Future<void> playSuccess() async {
    try {
      HapticFeedback.mediumImpact();
      await _player.play(AssetSource('sounds/success.mp3'));
    } catch (_) {
      try { HapticFeedback.mediumImpact(); } catch (_) {}
    }
  }

  static Future<void> playWarning() async {
    try {
      HapticFeedback.heavyImpact();
      await _player.play(AssetSource('sounds/warning.mp3'));
    } catch (_) {
      try { HapticFeedback.heavyImpact(); } catch (_) {}
    }
  }

  static Future<void> playError() async {
    try {
      HapticFeedback.heavyImpact();
      await _player.play(AssetSource('sounds/error.mp3'));
    } catch (_) {
      try { HapticFeedback.heavyImpact(); } catch (_) {}
    }
  }
}
