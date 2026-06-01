import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';

class WhatsAppService {
  static Future<bool> notifyParent({
    required String parentPhone,
    required String studentName,
    required String lessonTitle,
  }) async {
    final phone = _cleanPhone(parentPhone);
    if (phone.isEmpty) return false;

    _fixOpener();

    final message = Uri.encodeComponent(
      'مساء الخير يا فندم، من منصة درسك AI: نحيطكم علماً بأن الطالب ($studentName) لم يشاهد حصة ($lessonTitle) حتى الآن، وتم تسجيله مؤجل لأن ميعاد الحصة الجديدة قد بدأ.',
    );

    final url = Uri.parse('https://wa.me/2$phone?text=$message');
    if (await canLaunchUrl(url)) {
      return await launchUrl(url, mode: LaunchMode.externalApplication);
    }

    final fallbackUrl = Uri.parse('whatsapp://send?phone=2$phone&text=$message');
    if (await canLaunchUrl(fallbackUrl)) {
      return await launchUrl(fallbackUrl, mode: LaunchMode.externalApplication);
    }

    return false;
  }

  static Future<bool> notifyCheatedParent({
    required String parentPhone,
    required String studentName,
    required String lessonTitle,
  }) async {
    final phone = _cleanPhone(parentPhone);
    if (phone.isEmpty) return false;

    _fixOpener();

    final message = Uri.encodeComponent(
      'مساء الخير يا فندم، من منصة درسك AI: نحيطكم علماً بأن الطالب ($studentName) تم تسجيل سلوك مشبوه أثناء مشاهدة حصة ($lessonTitle). نرجو المتابعة.',
    );

    final url = Uri.parse('https://wa.me/2$phone?text=$message');
    if (await canLaunchUrl(url)) {
      return await launchUrl(url, mode: LaunchMode.externalApplication);
    }

    final fallbackUrl = Uri.parse('whatsapp://send?phone=2$phone&text=$message');
    if (await canLaunchUrl(fallbackUrl)) {
      return await launchUrl(fallbackUrl, mode: LaunchMode.externalApplication);
    }

    return false;
  }

  static String _cleanPhone(String phone) {
    return phone.replaceAll(RegExp(r'[^\d]'), '').trim();
  }

  static Future<void> _fixOpener() async {
    try {
      await launchUrl(Uri.parse('https://wa.me/200000000000'), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }
}
