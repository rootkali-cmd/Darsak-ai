import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../constants.dart';
import '../local_db.dart';
import 'conflict_resolver.dart';

class LocalSyncServer {
  HttpServer? _server;
  final List<_ClientConnection> _clients = [];
  bool _isRunning = false;
  int _port = LocalSyncConfig.port;

  final StreamController<Map<String, dynamic>> _eventController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onEvent => _eventController.stream;

  bool get isRunning => _isRunning;
  int get clientCount => _clients.length;
  List<String> get connectedDeviceIds =>
      _clients.map((c) => c.deviceId ?? 'unknown').toList();

  Future<void> start({int? port}) async {
    if (_isRunning) return;
    _port = port ?? LocalSyncConfig.port;

    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, _port);
      _isRunning = true;

      _server!.listen(
        (request) {
          if (request.uri.path == '/ws') {
            WebSocketTransformer.upgrade(request).then(
              (ws) => _handleClient(ws),
              onError: (_) {},
            );
          } else {
            request.response.statusCode = 404;
            request.response.close();
          }
        },
        onError: (_) => _isRunning = false,
      );
    } catch (_) {
      _isRunning = false;
    }
  }

  void _handleClient(WebSocket ws) {
    final client = _ClientConnection(ws);
    _clients.add(client);

    ws.listen(
      (data) {
        try {
          final message = jsonDecode(data as String) as Map<String, dynamic>;
          _handleMessage(client, message);
        } catch (_) {}
      },
      onDone: () => _clients.remove(client),
      onError: (_) => _clients.remove(client),
    );
  }

  void _handleMessage(_ClientConnection client, Map<String, dynamic> message) {
    final type = message['type'] as String?;
    if (type == null) return;

    switch (type) {
      case 'handshake':
        client.deviceId = message['device_id'] as String?;
        client.send({
          'type': 'handshake_ack',
          'device_id': LocalSyncConfig.deviceId,
          'server_time': DateTime.now().toIso8601String(),
        });
        break;

      case 'event':
        _handleEvent(client, message);
        break;

      case 'ping':
        client.send({'type': 'pong', 'ack_id': message['ack_id']});
        break;
    }
  }

  void _handleEvent(_ClientConnection client, Map<String, dynamic> message) {
    final event = message['event'] as Map<String, dynamic>? ?? message;
    final box = event['box'] as String?;
    final key = event['key'] as String?;
    final data = event['data'] as Map<String, dynamic>?;
    final timestamp = event['timestamp'] as String?;

    if (box == null || key == null || data == null) {
      client.send({
        'type': 'error',
        'ack_id': message['ack_id'],
        'error': 'Missing required fields: box, key, data',
      });
      return;
    }

    try {
      final existing = LocalDB.getData(box, key);
      if (existing != null) {
        ConflictResolver.resolve(
          localData: existing,
          remoteData: data,
          boxName: box,
          key: key,
          localDeviceId: LocalSyncConfig.deviceId,
          remoteDeviceId: client.deviceId ?? 'unknown',
          localTimestamp: existing['updated_at'] as String?,
          remoteTimestamp: timestamp,
        );
      } else {
        LocalDB.saveData(box, key, data);
      }

      _eventController.add(event);

      client.send({
        'type': 'ack',
        'ack_id': message['ack_id'],
        'box': box,
        'key': key,
      });
    } catch (e) {
      client.send({
        'type': 'error',
        'ack_id': message['ack_id'],
        'error': e.toString(),
      });
    }
  }

  void broadcast(Map<String, dynamic> event, {String? excludeDeviceId}) {
    final msg = jsonEncode({'type': 'event', 'event': event});
    for (final client in _clients) {
      if (excludeDeviceId != null && client.deviceId == excludeDeviceId) continue;
      try {
        client.ws.add(msg);
      } catch (_) {}
    }
  }

  Future<void> sendToDevice(String deviceId, Map<String, dynamic> event) async {
    final msg = jsonEncode({'type': 'event', 'event': event});
    for (final client in _clients) {
      if (client.deviceId == deviceId) {
        try {
          client.ws.add(msg);
        } catch (_) {}
        break;
      }
    }
  }

  Future<void> stop() async {
    for (final client in _clients) {
      try {
        await client.ws.close();
      } catch (_) {}
    }
    _clients.clear();
    try {
      await _server?.close(force: true);
    } catch (_) {}
    _server = null;
    _isRunning = false;
  }
}

class _ClientConnection {
  final WebSocket ws;
  String? deviceId;

  _ClientConnection(this.ws);

  void send(Map<String, dynamic> data) {
    try {
      ws.add(jsonEncode(data));
    } catch (_) {}
  }
}
