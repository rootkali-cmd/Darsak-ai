import 'package:flutter/services.dart';

class NativeFilePicker {
  static const _channel = MethodChannel('com.darsakai/file_picker');

  static Future<String?> pickPdf() async {
    try {
      return await _channel.invokeMethod<String>('pickPdf');
    } on PlatformException {
      return null;
    }
  }

  static Future<String?> pickImage() async {
    try {
      return await _channel.invokeMethod<String>('pickImage');
    } on PlatformException {
      return null;
    }
  }

  static Future<String?> pickAny() async {
    try {
      return await _channel.invokeMethod<String>('pickAny');
    } on PlatformException {
      return null;
    }
  }

  static Future<String?> getSharedPdf() async {
    try {
      return await _channel.invokeMethod<String>('getSharedPdf');
    } on PlatformException {
      return null;
    }
  }
}
