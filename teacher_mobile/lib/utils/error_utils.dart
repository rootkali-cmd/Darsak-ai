import 'package:dio/dio.dart';

String getFriendlyErrorMessage(dynamic error) {
  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'انتهت مهلة الاتصال. تأكد من الإنترنت.';
      case DioExceptionType.connectionError:
        return 'لا يوجد اتصال بالإنترنت.';
      case DioExceptionType.badResponse:
        final status = error.response?.statusCode;
        if (status == 401) {
          return 'انتهت صلاحية الجلسة. سجل دخولك مرة أخرى.';
        }
        if (status == 403) {
          return 'ليس لديك صلاحية.';
        }
        if (status == 404) {
          return 'البيانات غير موجودة.';
        }
        if (status == 307 || status == 302) {
          return 'خطأ في الاتصال بالخادم. حاول مرة أخرى.';
        }
        if (status != null && status >= 500) {
          return 'خطأ في الخادم ($status). حاول لاحقاً.';
        }
        return 'خطأ في الاستجابة ($status).';
      case DioExceptionType.cancel:
        return 'تم إلغاء الطلب.';
      default:
        return 'حدث خطأ في الاتصال.';
    }
  }
  return 'حدث خطأ غير متوقع.';
}
