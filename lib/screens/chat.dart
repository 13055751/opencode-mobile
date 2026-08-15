import 'dart:async';

import 'package:flutter/material.dart';

import '../api.dart';
import '../models.dart';
import '../widgets/permission_dialog.dart';
import '../widgets/question_dialog.dart';
import 'bubbles.dart';
import 'composer.dart';

class ChatScreen extends StatefulWidget {
  final OpenCodeApi api;
  final Session session;
  const ChatScreen({super.key, required this.api, required this.session});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<ChatMessage> _messages = [];
  bool _loading = true;
  bool _busy = false;
  StreamSubscription<Map<String, dynamic>>? _sub;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final msgs = await widget.api.listMessages(widget.session.id);
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(msgs);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
    _connectEvents();
  }

  void _connectEvents() {
    _sub?.cancel();
    _sub = widget.api.eventStream().listen(_onEvent, onError: (_) {});
  }

  Future<void> _onEvent(Map<String, dynamic> event) async {
    final type = event['type'] as String? ?? '';
    final data = (event['data'] as Map<String, dynamic>?) ?? {};

    switch (type) {
      case 'session.status':
        final status = SessionStatus.fromJson(data['status'] as Map<String, dynamic>? ?? {});
        setState(() => _busy = status.isBusy);
        break;
      case 'session.idle':
        setState(() => _busy = false);
        break;
      case 'session.error':
        setState(() => _busy = false);
        break;
      case 'message.updated':
        final info = data['info'];
        if (info is Map<String, dynamic>) {
          _upsertMessage(ChatMessage.fromJson(info));
        }
        break;
      case 'message.part.updated':
        final mid = data['sessionID'] as String?;
        final part = data['part'];
        if (part is Map<String, dynamic> && mid != null) {
          _updatePart(mid, part);
        }
        break;
      case 'message.part.delta':
        final mid = data['messageID'] as String?;
        final pid = data['partID'] as String?;
        final field = data['field'] as String?;
        final delta = data['delta'] as String?;
        if (mid != null && pid != null && field == 'text' && delta != null) {
          _appendPartText(mid, pid, delta);
        }
        break;
      case 'message.removed':
        final mid = data['messageID'] as String?;
        if (mid != null) {
          setState(() => _messages.removeWhere((m) => m.id == mid));
        }
        break;
      case 'permission.v2.asked':
        _showPermission(PermissionRequest.fromJson(data));
        break;
      case 'permission.asked':
        _showPermission(PermissionRequest.fromJson(data));
        break;
      case 'question.v2.asked':
      case 'question.asked':
        final qs = (data['questions'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(QuestionInfo.fromJson)
            .toList();
        if (qs.isNotEmpty) {
          final requestID = data['id'] as String? ?? '';
          final sessionID = data['sessionID'] as String? ?? widget.session.id;
          _showQuestion(sessionID, requestID, qs);
        }
        break;
    }
  }

  void _upsertMessage(ChatMessage msg) {
    setState(() {
      final i = _messages.indexWhere((m) => m.id == msg.id);
      if (i == -1) {
        _messages.add(msg);
      } else {
        _messages[i] = msg;
      }
    });
  }

  void _updatePart(String sessionID, Map<String, dynamic> part) {
    final p = Part.fromJson(part);
    setState(() {
      for (var i = 0; i < _messages.length; i++) {
        final m = _messages[i];
        if (m.sessionID != sessionID) continue;
        final found = m.parts.indexWhere((x) => x.callID == p.callID && x.raw['id'] == p.raw['id']);
        if (found != -1) {
          final newParts = [...m.parts];
          newParts[found] = p;
          _messages[i] = ChatMessage(
            id: m.id,
            role: m.role,
            sessionID: m.sessionID,
            agent: m.agent,
            modelID: m.modelID,
            parts: newParts,
          );
          return;
        }
      }
    });
  }

  void _appendPartText(String mid, String pid, String delta) {
    setState(() {
      for (var i = 0; i < _messages.length; i++) {
        final m = _messages[i];
        if (m.id != mid) continue;
        final found = m.parts.indexWhere((x) => x.raw['id'] == pid);
        if (found != -1) {
          final parts = [...m.parts];
          final old = parts[found];
          final newText = (old.text ?? '') + delta;
          final raw = {...old.raw, 'text': newText};
          parts[found] = Part(kind: PartKind.text, text: newText, raw: raw);
          _messages[i] = ChatMessage(id: m.id, role: m.role, sessionID: m.sessionID, parts: parts);
          return;
        }
        // live assistant message not yet in list
        final textRaw = {
          'id': pid,
          'type': 'text',
          'text': delta,
        };
        _messages[i] = ChatMessage(
          id: m.id,
          role: m.role,
          sessionID: m.sessionID,
          parts: [...m.parts, Part(kind: PartKind.text, text: delta, raw: textRaw)],
        );
        return;
      }
    });
  }

  void _showPermission(PermissionRequest req) {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PermissionDialog(
        req: req,
        onReply: (reply, remember) async {
          await widget.api.respondPermission(widget.session.id, req.id, reply, remember: remember);
        },
      ),
    );
  }

  void _showQuestion(String sessionID, String requestID, List<QuestionInfo> qs) {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => QuestionDialog(
        questions: qs,
        onSubmit: (answers) async {
          await widget.api.answerQuestion(sessionID, requestID, [answers]);
        },
      ),
    );
  }

  Future<void> _send(String text) async {
    setState(() {
      _busy = true;
      _messages.add(ChatMessage(
        id: 'local-${DateTime.now().millisecondsSinceEpoch}',
        role: 'user',
        sessionID: widget.session.id,
        parts: [Part(kind: PartKind.text, text: text, raw: {'type': 'text', 'text': text})],
      ));
    });
    try {
      await widget.api.sendMessage(widget.session.id, text);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('发送失败: $e')));
    }
  }

  Future<void> _abort() async {
    try {
      await widget.api.abort(widget.session.id);
      setState(() => _busy = false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('中断失败: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.session.displayTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            if (widget.session.agent != null)
              Text(
                widget.session.agent!,
                style: const TextStyle(fontSize: 12, color: Colors.white38),
              ),
          ],
        ),
        actions: [
          if (_busy)
            IconButton(onPressed: _abort, icon: const Icon(Icons.stop_circle_outlined)),
          IconButton(
            onPressed: () => showModalBottomSheet(
              context: context,
              builder: (_) => ChatActionsSheet(api: widget.api, session: widget.session),
            ),
            icon: const Icon(Icons.more_vert),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _messages.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.chat_bubble_outline, size: 48, color: Colors.white24),
                              SizedBox(height: 12),
                              Text('开始对话吧', style: TextStyle(color: Colors.white38)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _messages.length,
                          itemBuilder: (context, i) => MessageBubble(message: _messages[i]),
                        ),
            ),
            Composer(
              busy: _busy,
              onSend: _send,
              onAbort: _abort,
            ),
          ],
        ),
      ),
    );
  }
}
