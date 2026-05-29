import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/io.dart';
import '../utils/constants.dart';
import '../database/database_service.dart';
import '../sync/conflict_resolver.dart';
import '../models/student.dart';
import '../models/group.dart';

final class LocalSyncClient {
  IOWebSocketChannel? _channel;
  bool _isConnected = false;
  bool _isConnecting = false;
  String? _peerDeviceId;
  StreamSubscription? _channelSubscription;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  String? _currentPeerIp;

  final StreamController<Map<String, dynamic>> _eventController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onEvent => _eventController.stream;

  bool get isConnected => _isConnected;
  String? get peerDeviceId => _peerDeviceId;

  Future<bool> connect({String? peerIp}) async {
    if (_isConnected || _isConnecting) return true;
    _isConnecting = true;
    try {
      _currentPeerIp = peerIp ?? '127.0.0.1';
      final uri = 'ws://$_currentPeerIp:${LocalSyncConfig.port}/ws';
      _channel = IOWebSocketChannel.connect(
        Uri.parse(uri),
        pingInterval: const Duration(seconds: 15),
      );
      await _channel!.ready;
      _isConnected = true;
      _isConnecting = false;
      _reconnectAttempts = 0;
      _sendHandshake();
      _channelSubscription = _channel!.stream.listen(
        (data) {
          try {
            final message = jsonDecode(data as String) as Map<String, dynamic>;
            _handleMessage(message);
          } catch (_) {}
        },
        onDone: () => _onDisconnected(),
        onError: (_) => _onDisconnected(),
      );
      return true;
    } catch (_) {
      _isConnected = false;
      _isConnecting = false;
      _scheduleReconnect();
      return false;
    }
  }

  void _sendHandshake() {
    send({
      'type': 'handshake',
      'device_id': LocalSyncConfig.deviceId,
      'device_type': 'desktop',
    });
  }

  void _handleMessage(Map<String, dynamic> message) {
    final type = message['type'] as String?;
    if (type == null) return;
    switch (type) {
      case 'handshake_ack':
        _peerDeviceId = message['device_id'] as String?;
        break;
      case 'event':
        _handleEvent(message);
        break;
      case 'ack':
        break;
      case 'pong':
        break;
      case 'error':
        break;
    }
  }

  void _handleEvent(Map<String, dynamic> message) {
    final event = message['event'] as Map<String, dynamic>? ?? message;
    final box = event['box'] as String?;
    final key = event['key'] as String?;
    final data = event['data'] as Map<String, dynamic>?;
    final timestamp = event['timestamp'] as String?;
    if (box == null || key == null || data == null) return;
    try {
      final db = DatabaseService.instance;
      final isDelete = box == 'delete_student' || box == 'delete_group';
      if (!isDelete) {
        final existing = _getLocalData(db, box, key);
        if (existing != null) {
          ConflictResolver.resolve(
            localData: existing,
            remoteData: data,
            boxName: box,
            key: key,
            localDeviceId: LocalSyncConfig.deviceId,
            remoteDeviceId: _peerDeviceId ?? 'unknown',
            localTimestamp: existing['updated_at'] as String?,
            remoteTimestamp: timestamp,
          );
        } else {
          _saveLocalData(db, box, key, data);
        }
      } else {
        _saveLocalData(db, box, key, data);
      }
      _eventController.add(event);
    } catch (_) {}
  }

  Map<String, dynamic>? _getLocalData(DatabaseService db, String box, String key) {
    switch (box) {
      case 'students':
      case 'delete_student':
        return db.getStudent(key)?.toJson() ?? db.getStudentById(key)?.toJson();
      case 'groups':
      case 'delete_group':
        return db.getGroup(key)?.toJson();
      case 'attendance':
        return db.getAttendance(key);
      case 'grades':
        return db.getGrade(key);
      case 'invoices':
        return db.getInvoice(key);
      default:
        return null;
    }
  }

  void _saveLocalData(DatabaseService db, String box, String key, Map<String, dynamic> data) {
    switch (box) {
      case 'students':
        db.saveStudent(StudentModel.fromJson(data));
        break;
      case 'delete_student':
        db.deleteStudent(data['code'] as String? ?? key);
        break;
      case 'groups':
        db.saveGroup(GroupModel.fromJson(data));
        break;
      case 'delete_group':
        db.deleteGroup(data['id'] as String? ?? key);
        break;
      case 'attendance':
        db.saveAttendance(data);
        break;
      case 'grades':
        db.saveGrade(data);
        break;
      case 'invoices':
        db.saveInvoice(data);
        break;
    }
  }

  void _onDisconnected() {
    _isConnected = false;
    _peerDeviceId = null;
    _channelSubscription?.cancel();
    _channelSubscription = null;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    final delay = Duration(
      seconds: (LocalSyncConfig.reconnectDelay.inSeconds * (_reconnectAttempts + 1))
          .clamp(1, LocalSyncConfig.maxReconnectDelay.inSeconds),
    );
    _reconnectAttempts++;
    _reconnectTimer = Timer(delay, () => connect(peerIp: _currentPeerIp));
  }

  bool send(Map<String, dynamic> message) {
    if (!_isConnected || _channel == null) return false;
    try {
      _channel!.sink.add(jsonEncode(message));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> sendEvent({
    required String box,
    required String key,
    required Map<String, dynamic> data,
  }) async {
    final message = {
      'type': 'event',
      'event': {
        'box': box,
        'key': key,
        'data': data,
        'timestamp': DateTime.now().toIso8601String(),
      },
      'ack_id': '${DateTime.now().millisecondsSinceEpoch}',
    };
    if (isConnected) return send(message);
    return false;
  }

  Future<void> stop() async {
    _reconnectTimer?.cancel();
    _channelSubscription?.cancel();
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    _isConnected = false;
    _isConnecting = false;
  }
}
