import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/lecture_session.dart';

class SessionsProvider extends ChangeNotifier {
  List<LectureSession> _sessions = [];
  bool _isLoading = false;
  String? _error;

  List<LectureSession> get sessions => _sessions;
  bool get isLoading => _isLoading;
  String? get error => _error;

  SessionsProvider() {
    loadSessions();
  }

  Future<void> loadSessions() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString('lecture_sessions');
      if (data != null) {
        final list = jsonDecode(data) as List;
        _sessions = list.map((s) => LectureSession.fromJson(s)).toList();
      }
    } catch (e) {
      _error = 'فشل تحميل المحاضرات';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _saveSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode(_sessions.map((s) => s.toJson()).toList());
    await prefs.setString('lecture_sessions', data);
  }

  Future<bool> createSession(LectureSession session) async {
    try {
      _sessions.add(session);
      await _saveSessions();
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'فشل إضافة المحاضرة';
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateSession(LectureSession updated) async {
    try {
      final index = _sessions.indexWhere((s) => s.id == updated.id);
      if (index >= 0) {
        _sessions[index] = updated;
        await _saveSessions();
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _error = 'فشل تحديث المحاضرة';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteSession(String id) async {
    try {
      _sessions.removeWhere((s) => s.id == id);
      await _saveSessions();
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'فشل حذف المحاضرة';
      notifyListeners();
      return false;
    }
  }

  /// Get active sessions for a specific group on a specific day
  List<LectureSession> getSessionsForGroup(String groupId, DateTime date) {
    final weekday = date.weekday;
    return _sessions.where((s) => 
      s.isActive && 
      s.schedules.any((sch) => sch.groupId == groupId && sch.dayOfWeek == weekday)
    ).toList();
  }

  /// Check if a student has already been marked present for this session today
  /// (across any group occurrence)
  bool isStudentPresentForSession(String sessionId, String studentId, DateTime date) {
    // TODO: Check with API if student attended any occurrence of this session today
    // For now, return false (backend needs to support session-based attendance)
    return false;
  }
}
