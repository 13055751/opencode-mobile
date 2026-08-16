import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'logs.dart';
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

  void _log(String method, String path, Map<String, String>? q, int status,
      [String detail = '']) {
    final query = (q == null || q.isEmpty)
        ? ''
        : '?${q.entries.map((e) => '${e.key}=${e.value}').join('&')}';
    final suffix = detail.isEmpty ? '' : ' $detail';
    AppLog.instance.http('api', '$method $path$query → $status$suffix');
  }

  Future<dynamic> _get(String path, [Map<String, String>? q]) async {
    final res = await _getResponse(path, q);
    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  Future<http.Response> _getResponse(String path, [Map<String, String>? q]) async {
    final started = DateTime.now();
    AppLog.instance.http('api', 'GET $path …');
    try {
      final res = await _client.get(_uri(path, q), headers: _headers).timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw OpenCodeException('Connection timeout'),
          );
      if (res.statusCode != 200) {
        _log('GET', path, q, res.statusCode, res.body);
        throw OpenCodeException('HTTP ${res.statusCode}: ${res.body}',
            statusCode: res.statusCode);
      }
      _log('GET', path, q, res.statusCode);
      return res;
    } catch (e) {
      final ms = DateTime.now().difference(started).inMilliseconds;
      AppLog.instance.error('api', 'GET $path error after ${ms}ms: $e');
      rethrow;
    }
  }

  Future<dynamic> _post(String path, [Object? body, Map<String, String>? q]) async {
    String? _bodyPreview() {
      if (body == null) return null;
      try {
        final s = utf8.decode(utf8.encode(jsonEncode(body)));
        return s.length > 500 ? '${s.substring(0, 500)}…' : s;
      } catch (_) {
        return null;
      }
    }

    final started = DateTime.now();
    AppLog.instance.http('api', 'POST $path …');
    try {
      final res = await _client
          .post(
            _uri(path, q),
            headers: {..._headers, 'Content-Type': 'application/json'},
            body: body == null ? null : jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));
      final text = utf8.decode(res.bodyBytes);
      if (res.statusCode != 200 && res.statusCode != 201) {
        _log('POST', path, q, res.statusCode, text);
        throw OpenCodeException('HTTP ${res.statusCode}: $text',
            statusCode: res.statusCode);
      }
      _log('POST', path, q, res.statusCode, _bodyPreview() ?? '');
      if (text.isEmpty) return null;
      try {
        return jsonDecode(text);
      } catch (_) {
        return text;
      }
    } catch (e) {
      final ms = DateTime.now().difference(started).inMilliseconds;
      AppLog.instance.error('api', 'POST $path error after ${ms}ms: $e');
      rethrow;
    }
  }

  Future<void> _delete(String path) async {
    final started = DateTime.now();
    AppLog.instance.http('api', 'DELETE $path …');
    try {
      final res =
          await _client.delete(_uri(path), headers: _headers).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200 && res.statusCode != 204) {
        _log('DELETE', path, null, res.statusCode, res.body);
        throw OpenCodeException('HTTP ${res.statusCode}: ${res.body}');
      }
      _log('DELETE', path, null, res.statusCode);
    } catch (e) {
      final ms = DateTime.now().difference(started).inMilliseconds;
      AppLog.instance.error('api', 'DELETE $path error after ${ms}ms: $e');
      rethrow;
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

  /// Fetches a page of messages starting from the newest [limit] messages.
  /// Returns messages (ordered oldest→newest) plus an opaque [before] cursor
  /// for loading older pages (null when no older messages exist).
  Future<({List<ChatMessage> messages, String? before})> listMessagesPage(
    String sessionID, {
    int limit = 50,
    String? before,
  }) async {
    final res = await _getResponse('/session/$sessionID/message', {
      'limit': '$limit',
      if (before != null) 'before': before,
    });
    final data = jsonDecode(utf8.decode(res.bodyBytes));
    final list = data is List
        ? data
        : (data is Map && data['data'] is List ? data['data'] as List : []);
    return (
      messages: list
          .whereType<Map<String, dynamic>>()
          .map(ChatMessage.fromPageItem)
          .toList(),
      before: res.headers['x-next-cursor'] ?? res.headers['X-Next-Cursor'],
    );
  }

  Future<void> sendMessage(String sessionID, String prompt,
      {String? agent,
      String? modelProvider,
      String? modelID,
      String? variant,
      List<Map<String, dynamic>>? parts}) async {
    final bodyParts = parts ?? [
      {'type': 'text', 'text': prompt}
    ];
    await _post('/session/$sessionID/message', {
      'parts': bodyParts,
      if (agent != null) 'agent': agent,
      if (modelProvider != null && modelID != null)
        'model': {'providerID': modelProvider, 'modelID': modelID},
      if (variant != null && variant != 'default') 'variant': variant,
    });
  }

  /// Lists available slash commands from the server (GET /instance/command).
  Future<List<dynamic>> listCommands() async {
    final data = await _get('/instance/command');
    return data is List ? data : [];
  }

  /// Lists available agents (modes) from the server (GET /instance/agent).
  Future<List<dynamic>> listAgents() async {
    final data = await _get('/instance/agent');
    return data is List ? data : [];
  }

  /// Lists configured providers + models (GET /config/providers).
  Future<(List<Map<String, dynamic>>, Map<String, dynamic>)> listModels() async {
    final data = await _get('/config/providers');
    if (data is! Map<String, dynamic>) {
      return (<Map<String, dynamic>>[], <String, dynamic>{});
    }
    final all = (data['providers'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final defaults =
        (data['default'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    return (all, defaults);
  }

  /// Git working-tree status (GET /instance/vcs/status).
  Future<List<dynamic>> gitStatus() async {
    final data = await _get('/instance/vcs/status');
    return data is List ? data : [];
  }

  /// Git diff (GET /instance/vcs/diff).
  Future<List<dynamic>> gitDiff() async {
    final data = await _get('/instance/vcs/diff');
    return data is List ? data : [];
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
    AppLog.instance.sse('api', 'connecting to /global/event');
    try {
      final res = await client.send(req);
      if (res.statusCode != 200) {
        AppLog.instance.error('api', 'Event stream HTTP ${res.statusCode}');
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
          if (ev != null) {
            AppLog.instance
                .sse('api', 'event ${ev['type']} ${truncate(logJson(ev['data']), 200)}');
            yield ev;
          }
          idx = text.indexOf('\n\n');
        }
      }
    } catch (e) {
      AppLog.instance.error('api', 'event stream closed: $e');
      rethrow;
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
