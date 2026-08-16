import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

class OpenCodeException implements Exception {
  final String message;
  final int? statusCode;
  OpenCodeException(this.message, {this.statusCode});
  @override
  String toString() => message;
}

class OpenCodeApi {
  final String baseUrl;
  final String? password;
  final http.Client _client;

  OpenCodeApi({required this.baseUrl, this.password})
      : _client = http.Client() {
    _headers = {
      if (password != null && password!.isNotEmpty)
        'Authorization': 'Basic ${base64Encode(utf8.encode('opencode:$password'))}',
      'Accept': 'application/json',
    };
  }

  late final Map<String, String> _headers;

  Uri _uri(String path, [Map<String, String>? q]) {
    final u = Uri.parse('$baseUrl$path');
    if (q == null) return u;
    return u.replace(queryParameters: q);
  }

  Future<dynamic> _get(String path, [Map<String, String>? q]) async {
    final res = await _client.get(_uri(path, q), headers: _headers).timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw OpenCodeException('Connection timeout'),
        );
    if (res.statusCode != 200) {
      throw OpenCodeException('HTTP ${res.statusCode}: ${res.body}', statusCode: res.statusCode);
    }
    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  Future<dynamic> _post(String path, [Object? body, Map<String, String>? q]) async {
    final res = await _client
        .post(
          _uri(path, q),
          headers: {..._headers, 'Content-Type': 'application/json'},
          body: body == null ? null : jsonEncode(body),
        )
        .timeout(const Duration(seconds: 15));
    final text = utf8.decode(res.bodyBytes);
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw OpenCodeException('HTTP ${res.statusCode}: $text', statusCode: res.statusCode);
    }
    if (text.isEmpty) return null;
    return jsonDecode(text);
  }

  Future<void> _delete(String path) async {
    final res = await _client.delete(_uri(path), headers: _headers).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200 && res.statusCode != 204) {
      throw OpenCodeException('HTTP ${res.statusCode}: ${res.body}');
    }
  }

  Future<bool> checkHealth() async {
    try {
      await _get('/global/health');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<Session>> listSessions({int limit = 50, String? directory}) async {
    final data = await _get('/session', {
      'limit': '$limit',
      if (directory != null && directory.isNotEmpty) 'directory': directory,
    });
    if (data is List) {
      return data.whereType<Map<String, dynamic>>().map(Session.fromJson).toList();
    }
    if (data is Map && data['data'] is List) {
      return (data['data'] as List).whereType<Map<String, dynamic>>().map(Session.fromJson).toList();
    }
    return [];
  }

  Future<Session> createSession({String? parentID, String? title, String? directory}) async {
    final data = await _post('/session', {
      'parentID': ?parentID,
      'title': ?title,
    }, directory == null ? null : {'directory': directory});
    return Session.fromJson(data as Map<String, dynamic>);
  }

  Future<Session> getSession(String id) async {
    final data = await _get('/session/$id');
    return Session.fromJson(data as Map<String, dynamic>);
  }

  /// Lists a directory on the server. [directory] is the absolute workspace
  /// directory, [path] is a relative sub-path within it.
  Future<List<FileEntry>> listFiles(String directory, {String path = ''}) async {
    final data = await _get('/file', {
      'directory': directory,
      'path': path,
    });
    final list = data is List
        ? data
        : (data is Map && data['data'] is List ? data['data'] as List : []);
    return list
        .whereType<Map<String, dynamic>>()
        .map(FileEntry.fromJson)
        .toList();
  }

  /// Creates a directory on the server via a one-shot PTY mkdir command.
  Future<void> createDirectory(String absolutePath) async {
    await _post('/pty', {
      'command': 'mkdir',
      'args': ['-p', absolutePath],
    });
  }

  Future<List<ChatMessage>> listMessages(String sessionID, {int limit = 100}) async {
    final data = await _get('/session/$sessionID/message', {'limit': '$limit'});
    if (data is List) {
      return data.whereType<Map<String, dynamic>>().map(ChatMessage.fromPageItem).toList();
    }
    if (data is Map && data['data'] is List) {
      return (data['data'] as List).whereType<Map<String, dynamic>>().map(ChatMessage.fromPageItem).toList();
    }
    return [];
  }

  Future<void> sendMessage(String sessionID, String prompt) async {
    await _post('/session/$sessionID/message', {
      'parts': [
        {'type': 'text', 'text': prompt}
      ]
    });
  }

  Future<void> abort(String sessionID) async {
    await _post('/session/$sessionID/abort');
  }

  Future<void> deleteMessage(String sessionID, String messageID) async {
    await _delete('/session/$sessionID/message/$messageID');
  }

  Future<void> deleteSession(String sessionID) async {
    await _delete('/session/$sessionID');
  }

  Future<void> respondPermission(String sessionID, String permissionID, String response, {bool? remember}) async {
    await _post('/session/$sessionID/permissions/$permissionID', {
      'response': response,
      'remember': ?remember,
    });
  }

  Future<void> answerQuestion(String sessionID, String requestID, List<List<String>> answers) async {
    await _post('/question/$requestID/reply', {'answers': answers});
  }

  Future<void> rejectQuestion(String sessionID, String requestID) async {
    await _post('/question/$requestID/reject');
  }

  /// Opens an SSE stream to /global/event. Events are delivered as parsed maps.
  Stream<Map<String, dynamic>> eventStream() async* {
    final req = http.Request('GET', _uri('/global/event'));
    req.headers.addAll(_headers);
    final client = http.Client();
    try {
      final res = await client.send(req);
      if (res.statusCode != 200) {
        throw OpenCodeException('Event stream HTTP ${res.statusCode}');
      }
      final stream = res.stream.transform(utf8.decoder);
      var buffer = StringBuffer();
      await for (final chunk in stream) {
        buffer.write(chunk);
        var text = buffer.toString();
        var idx = text.indexOf('\n\n');
        while (idx != -1) {
          final block = text.substring(0, idx);
          text = text.substring(idx + 2);
          buffer = StringBuffer(text);
          final ev = _parseEventBlock(block);
          if (ev != null) yield ev;
          idx = text.indexOf('\n\n');
        }
      }
    } finally {
      client.close();
    }
  }

  Map<String, dynamic>? _parseEventBlock(String block) {
    String? event;
    String? data;
    for (final line in block.split('\n')) {
      if (line.startsWith('event:')) event = line.substring(6).trim();
      if (line.startsWith('data:')) data = line.substring(5).trim();
    }
    if (event == null) return null;
    dynamic payload;
    try {
      payload = jsonDecode(data ?? '{}');
    } catch (_) {
      payload = <String, dynamic>{};
    }
    return <String, dynamic>{'type': event, 'data': payload};
  }

  void dispose() => _client.close();
}

String truncate(String s, int n) => s.length <= n ? s : '${s.substring(0, n)}…';
