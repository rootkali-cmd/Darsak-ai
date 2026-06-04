import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class AttendanceProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  List<dynamic> _attendance = [];
  bool _loading = false;
  String? _error;

  List<dynamic> get attendance => _attendance;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> loadAttendance({String? date}) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final queryParams = <String, dynamic>{};
      if (date != null) queryParams['date'] = date;
      final res = await _api.dio.get(
        '/attendance/',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );
      final data = res.data;
      _attendance = data is List
          ? List<dynamic>.from(data)
          : (data is Map ? (data['data'] as List<dynamic>? ?? []) : []);
    } catch (e) {
      _error = e.toString();
    }
    _loading = false;
    notifyListeners();
  }

  Future<Map<String, dynamic>> markAttendance(Map<String, dynamic> data) async {
    return await _api.createAttendance(data);
  }

  Future<Map<String, dynamic>?> markAttendanceByBarcode(String barcode) async {
    try {
      return await _api.markAttendanceByBarcode(barcode);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> getStats() async {
    return await _api.getAttendanceStats();
  }

  Future<List<dynamic>> getStudentAttendance(dynamic studentId) async {
    try {
      final res = await _api.dio.get(
        '/attendance/',
        queryParameters: {'student_id': studentId.toString()},
      );
      final data = res.data;
      return data is List
          ? List<dynamic>.from(data)
          : (data is Map ? (data['data'] as List<dynamic>? ?? []) : []);
    } catch (_) {
      return [];
    }
  }
}
