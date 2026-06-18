import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StudentAccount {
  final String studentId;
  final String studentCode;
  final String studentName;
  final String accessToken;
  final String refreshToken;
  final String teacherId;
  final String? teacherCode;
  final String? teacherName;

  StudentAccount({
    required this.studentId,
    required this.studentCode,
    required this.studentName,
    required this.accessToken,
    required this.refreshToken,
    required this.teacherId,
    this.teacherCode,
    this.teacherName,
  });

  Map<String, dynamic> toJson() => {
    'studentId': studentId,
    'studentCode': studentCode,
    'studentName': studentName,
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'teacherId': teacherId,
    'teacherCode': teacherCode,
    'teacherName': teacherName,
  };

  factory StudentAccount.fromJson(Map<String, dynamic> json) => StudentAccount(
    studentId: json['studentId'] ?? '',
    studentCode: json['studentCode'] ?? '',
    studentName: json['studentName'] ?? '',
    accessToken: json['accessToken'] ?? '',
    refreshToken: json['refreshToken'] ?? '',
    teacherId: json['teacherId'] ?? '',
    teacherCode: json['teacherCode'],
    teacherName: json['teacherName'],
  );
}

class AccountManager extends ChangeNotifier {
  static const _storageKey = 'student_accounts';
  static const _activeKey = 'active_student_index';
  static const int maxFreeAccounts = 5;

  List<StudentAccount> _accounts = [];
  int _activeIndex = 0;

  List<StudentAccount> get accounts => List.unmodifiable(_accounts);
  int get activeIndex => _activeIndex;
  StudentAccount? get activeAccount => _accounts.isNotEmpty ? _accounts[_activeIndex] : null;
  bool get canAddMore => _accounts.length < maxFreeAccounts;
  int get remainingSlots => maxFreeAccounts - _accounts.length;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null) {
      final list = jsonDecode(raw) as List;
      _accounts = list.map((e) => StudentAccount.fromJson(e)).toList();
    }
    _activeIndex = prefs.getInt(_activeKey) ?? 0;
    if (_activeIndex >= _accounts.length) _activeIndex = 0;
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final json = _accounts.map((a) => a.toJson()).toList();
    await prefs.setString(_storageKey, jsonEncode(json));
    await prefs.setInt(_activeKey, _activeIndex);
  }

  Future<bool> addAccount(StudentAccount account) async {
    final exists = _accounts.any((a) => a.studentId == account.studentId);
    if (exists) return false;
    if (_accounts.length >= maxFreeAccounts) return false;
    _accounts.add(account);
    _activeIndex = _accounts.length - 1;
    await _save();
    notifyListeners();
    return true;
  }

  Future<void> switchTo(int index) async {
    if (index < 0 || index >= _accounts.length) return;
    _activeIndex = index;
    await _save();
    notifyListeners();
  }

  Future<void> removeAccount(int index) async {
    if (index < 0 || index >= _accounts.length) return;
    _accounts.removeAt(index);
    if (_activeIndex >= _accounts.length) _activeIndex = 0;
    await _save();
    notifyListeners();
  }

  Future<void> updateAccount(int index, StudentAccount account) async {
    if (index < 0 || index >= _accounts.length) return;
    _accounts[index] = account;
    await _save();
    notifyListeners();
  }

  String getActiveToken() => activeAccount?.accessToken ?? '';
  String getActiveRefreshToken() => activeAccount?.refreshToken ?? '';
  String getActiveStudentId() => activeAccount?.studentId ?? '';
  String getActiveStudentCode() => activeAccount?.studentCode ?? '';
  String getActiveStudentName() => activeAccount?.studentName ?? '';
}
